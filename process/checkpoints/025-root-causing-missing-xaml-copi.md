<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. That covers the Live Visual Tree, properties, styles/resources, Live Preview, binding failures, accessibility checks, Hot Reload and TAP capabilities. The prototype (22 `xaml_*` tools in Diagnostics.dll, a `xaml-diagnostics` skill, and a FirstPartyToolsProvider entry in the Copilot repo) is implemented and committed, with 17 demo WPF apps alongside.

The current task is diagnosing why, in the user's fastmain Experimental instance, the skill shows up in the Copilot session but the `xaml_*` tools do not. The root cause is now essentially identified.
</overview>

<history>
1. **Earlier work (before previous compactions):**
   - Planned, implemented, reviewed and committed the prototype as `c15a32e78cc0`, "Expose XAML Diagnostics to GitHub Copilot (prototype)".
   - Created demo apps in `Q:\source\XamlAgentDemos` (commits `d4ddfb1`, `a3f6100`, `1ce572f`).
   - Extended `DeployToVs.ps1` to deploy the skill tree. This change is uncommitted.
   - The user F5-deployed the Copilot solution into fastmain's Exp hive, then reported the tools still missing (skill present) after running with `/log`.

2. **This segment: investigating the missing tools.**
   - **PowerShell probe was misleading.** `%TEMP%\xamlfnprobe.ps1` hit "type initializer threw", then `TypeLoadException` on `PolyType.IShapeable` and later `Nerdbank.Streams.MultiplexingStream`. These were binding artifacts:
     - The probe loaded the .NET 8 out-of-proc copies from `...\GitHub Copilot\42.42.42.42\Conversations.Service\` (Copilot.dll, PolyType).
     - It also picked a wrong Nerdbank.Streams version.
   - **C# AppDomain probe proved the provider is fine.**
     - Built `%TEMP%\xamlprobe\probe.exe` (netfx csc). It creates an AppDomain with `ApplicationBase=C:\vs\fastmain\Common7\IDE` and `ConfigurationFile=%LOCALAPPDATA%\Microsoft\VisualStudio\18.0_ca393f20Exp\devenv.exe.config`.
     - Result: **`XamlDiagnosticsFunctionProvider.GetFunctionsAsync` returns all 22 functions.**
     - Binding matched VS: Copilot.dll 18.14 from `CommonExtensions\Microsoft\Microsoft.VisualStudio.Copilot.Contracts\`, and Nerdbank.Streams 2.13 from `PublicAssemblies\Nerdbank.Streams.2.x`.
   - **fastmain loads the F5 build.** The Exp `devenv.exe.config` codeBase points `Microsoft.VisualStudio.Copilot.Vsix` to the Exp extension `42.42.42.42`, and that DLL contains the XAML moniker string. The installed one does not.
   - **Matched logs to instances.**
     - fastmain (pid 63740, started 1:43 PM) is VSLogs prefix `VSDE0226DA`. Its GlobalBrokeredServiceContainer log shows the XAML CopilotFunctions proxy requested at 18:44:29Z.
     - `VSACC52D26` is a different instance, `C:\vs\test`.
   - **Found the decisive trace.** The chat log `%TEMP%\VSGitHubCopilotLogs\976a804a-1046-43e8-b704-0eca2a0d0025\20261113_184358.808_VSGitHubCopilot.chat.log` (fastmain) has `CliBackend` `[tool registry] received=34 exposed=12 dropped=22`.
     - Providers listed: AskQuestion, Output, McpToolAggregator, Planning, PerformanceProfilerActivation, CodeTestingSdkPlugin, Edits, Context, TestExplorer.
     - **There are no FirstPartyToolsProvider-sourced tools at all** (no XAML tools, no debugger tools), at every republish through 18:56.
   - **Traced the code path.**
     - `CopilotFunctionRegistry.GetSessionToolsAsync` (Copilot.Core\Functions\CopilotFunctionRegistry.cs, around lines 309–343) merges first-party tools only when `activeResponders` contains the session and `!DisallowRecommendedTools`.
     - `activeResponders` is set by `UpdateSessionResponderAsync`, which is called only from `ChatModeSelectorViewModel` (lines 546, 566) and `SessionViewModel` (line 2445, which sets it to null).
     - The session uses the Copilot SDK/CLI backend (`CopilotSdkSession`, `VsToolsSessionProvider.StartAsync` → `registry.SubscribeForToolsAsync`).
     - Was examining `ChatModeSelectorViewModel` around lines 520–600 to see whether the CLI/SDK backend session ever registers a responder (`GetSelectedResponderIdentity`).
</history>

<work_done>
- **VS repo** `Q:\src\VS_xaml`:
  - HEAD is `c15a32e78cc0` (the prototype commit).
  - Uncommitted: `src\Xaml\Scripts\DeployToVs.ps1` skill-deploy change (around lines 460–485).
- **No code changes this segment** (investigation only).
- **Temp artifacts to delete at the end:** `%TEMP%\xamlfnprobe.ps1` and `%TEMP%\xamlprobe\` (probe.cs, probe.exe).
- **Status:**
  - Provider and TAP code are verified working: 22 tools via VS-equivalent binding.
  - Registration is present in the loaded `Copilot.Vsix`.
  - The tools don't reach the session because of how the CLI/SDK backend sources first-party tools.
</work_done>

<technical_details>
- **Root cause (high confidence):**
  - `FirstPartyToolsProvider` `AllFromProviderTool` entries reach a chat session only through `CopilotFunctionRegistry.GetFirstPartyToolsAsync`. That requires an active responder registered for the session via `UpdateSessionResponderAsync`, with `DisallowRecommendedTools == false`.
  - In the fastmain session (CliBackend / Copilot SDK harness), the registry inventory contained no first-party-provider tools. Either no responder is registered for the SDK session, or the responder disallows recommended tools.
  - So **all** FirstPartyToolsProvider tools are absent in CLI-backend sessions, not just XAML.
  - Still unverified: whether the UI context `5C69788A` was active when the user checked (i.e. whether they were debugging a XAML app). It doesn't matter for this root cause, because the first-party provider moniker never appears at all.
- **Fix options:**
  1. Register the XAML provider directly in the function registry so it's a "registry/extension" tool that `CliFunctionProvider.Classify` allows.
     - Via `ICopilotRegistrationService.RegisterFunctionProviderAsync`, the pattern used by vc/CMake, or the same mechanism used by `PerformanceProfilerActivationFunctionsService` / `CodeTestingSdkPlugin.TestProjectFunctions`, which do appear.
     - It can be done from Diagnostics.dll when the XAML diagnostics connection becomes active, and unregistered when it ends.
  2. Change the Copilot backend so SDK sessions include first-party tools. This is a larger Copilot-team change.
  3. Have the user switch to the non-CLI (legacy) agent backend to test.

  Option 1 is likely the best prototype fix. Investigate how `PerformanceProfilerActivationFunctionsService` / `CodeTestingSdkPlugin` register.
- **CliFunctionProvider filter:** `FirstPartyProviderNames` doesn't include the XAML moniker, so registry-sourced XAML tools would be exposed unless they're in `ExcludedRegistryTools` (they aren't).
- **Logging locations:**
  - The useful Copilot traces are in `%TEMP%\VSGitHubCopilotLogs\<guid>\*_VSGitHubCopilot.chat.log`; search `[tool registry]`.
  - VSLogs svclogs only show proxy requests.
- **Assembly layout:**
  - devenv's Copilot.dll lives in `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\Microsoft.VisualStudio.Copilot.Contracts\`.
  - The extension's `Conversations.Service` folder is .NET 8 out-of-proc; don't use it for netfx probing.
  - netfx PolyType is in `PrivateAssemblies\PolyType.1.x`.
- **Earlier ruled out:**
  - UI-context gate (the skill uses the same context).
  - The CLI harness drop filter.
  - Confirmation-parameter rules (Required tools have `ICopilotFunctionBroker`).
  - Late tool arrival (tools are reselected per request).
- **User preferences:**
  - Never push, rebase or amend. Make only new commits when asked, then stop for review.
  - Builds: prime via the `building-locally` skill (`src\Shared\Tools\Scripts\Prime-ForCopilot.ps1`). Never build the whole repo.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Core\Functions\CopilotFunctionRegistry.cs`
  - First-party tools are merged only for sessions with an active responder: `GetSessionToolsAsync` at ~309–331, `GetFirstPartyToolsAsync` at ~335–344.
  - Also relevant: `SubscribeForToolsAsync` at ~346, `UpdateSessionResponderAsync` at ~387, and `RegisterFunctionProviderAsync` (find it) for the direct-registration fix.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.UI.Core\ChatModeSelectorViewModel.cs`
  - The only callers that set the session responder (lines 546, 566).
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\HostTools\VsToolsSessionProvider.cs` and `CliFunctionProvider.cs`
  - The CLI backend's tool inventory and filter; this is where the `[tool registry]` trace comes from.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\CopilotSdk\CopilotSdkSession.cs` (~line 906) and `CopilotSdkSession.Tools.cs`
  - SDK session tool wiring.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`
  - The XAML entry is at lines 260–269; `ToolsState` is at ~319–515.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The XAML provider (verified working). It's the likely place to add direct registry registration.
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`
  - Contains the uncommitted skill-deploy change.
</important_files>

<next_steps>
1. Optionally finish confirming why the SDK session has no active responder or first-party tools. Check `GetSelectedResponderIdentity` and whether SDK sessions use `ChatModeSelectorViewModel`.
2. Report the root cause to the user concisely, with log evidence: the `[tool registry]` lines show no first-party-provider tools in CliBackend sessions, so all `FirstPartyToolsProvider` entries, debugger tools included, are missing there.
3. Propose and implement a fix after a quick confirmation with the user (`ask_user` if the approach is ambiguous). The likely choice is to register `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions` directly with the function registry, the way PerformanceProfiler / CodeTestingSdkPlugin / CMake do.
   - Find that registration mechanism (grep `RegisterFunctionProviderAsync`, `PerformanceProfilerActivationFunctionsService`).
   - Optionally gate it on the XAML diagnostics UI context.
   - Keep the FirstPartyToolsProvider entry for the legacy backend, or remove it to avoid duplicates. Check registry dedupe by DisplayName.
4. Rebuild the affected project(s) after priming, redeploy (`DeployToVs.ps1`, and F5 for Copilot if changed), and have the user retest. Verify via `[tool registry]` lines in the chat log containing `xaml_`.
5. Commit only if asked (a new commit only). `DeployToVs.ps1` is still uncommitted.
6. Delete `%TEMP%\xamlfnprobe.ps1` and `%TEMP%\xamlprobe\`.
7. At session end, consider asking whether to update a skill. A good candidate: how to diagnose missing Copilot tools via `VSGitHubCopilotLogs` `[tool registry]` traces, and how CLI-backend sessions source tools.
</next_steps>