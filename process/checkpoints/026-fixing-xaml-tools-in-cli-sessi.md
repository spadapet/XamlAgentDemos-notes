<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. That covers Live Visual Tree, properties, styles/resources, Live Preview, binding failures, accessibility checks, Hot Reload and TAP capabilities. The prototype is implemented and committed:
- 22 `xaml_*` tools in Diagnostics.dll
- the `xaml-diagnostics` skill
- a FirstPartyToolsProvider entry in the Copilot repo
- 17 demo WPF apps

The current task is fixing why, in the user's fastmain Experimental instance (debugging a XAML app, CLI/SDK Copilot backend), the skill shows up but the `xaml_*` tools don't. The root cause is confirmed, and a fix was being designed: register the provider directly with `ICopilotRegistrationService`, following the CMake pattern.
</overview>

<history>
1. **Earlier work (before previous compactions):**
   - Planned, implemented, reviewed and committed the prototype as `c15a32e78cc0`.
   - Created the demo apps in `Q:\source\XamlAgentDemos`.
   - Extended `DeployToVs.ps1` to deploy the skill tree. This change is still uncommitted.
   - The user F5-deployed the Copilot solution into fastmain Exp and reported the tools missing while the skill was present (ran with `/log`).

2. **Investigating the missing tools (previous segment):**
   - A netfx AppDomain probe proved `XamlDiagnosticsFunctionProvider.GetFunctionsAsync` returns all 22 functions under VS binding.
   - Confirmed the Exp hive loads the F5-built `Copilot.Vsix` (42.42.42.42), which contains the XAML FirstPartyToolsProvider entry.
   - Found `[tool registry]` traces in `%TEMP%\VSGitHubCopilotLogs\<guid>\*_VSGitHubCopilot.chat.log` showing no XAML tools received.

3. **This segment: confirmed the root cause.**
   - The brokered-service log shows the XAML provider proxy was requested at 18:44:29Z and 18:44:35Z, so FirstPartyToolsProvider did subscribe.
   - The latest chat log (`e1f0b4de-...\20261113_184916.412_VSGitHubCopilot.chat.log`) shows `[tool registry] received=31` with providers AskQuestion, Output, McpToolAggregator, Planning, PerformanceProfilerActivationFunctionsService, CodeTestingSdkPlugin.TestProjectFunctions, Edits, Context and TestExplorer. That list is only **directly registered** providers.
   - The user's prompt "I am debugging a XAML app now" appears in the same log, so debugging was active.
   - `CopilotFunctionRegistry.GetSessionToolsAsync` returns only registered providers when `activeResponders` has no entry for the session. The CLI/SDK sessions have none, so FirstPartyToolsProvider tools (including XAML) are never merged.
   - Debugger tools appear in CLI sessions through a different path: `[inject] agent-resolved=90`, the active agent's declared tools, in `CopilotSdkSession.Tools.cs` `SelectedHostContributions`.
   - `CliFunctionProvider.Classify`: providers not in `FirstPartyProviderNames` are "registry/extension allowed" unless in `ExcludedRegistryTools`. A directly registered XAML provider would therefore be exposed.
   - The UIContext `5C69788A` (DiagnosticToolWindowsAvailable) rule is `Debugging | DiagnosticConnectionActive` (`XamlDiagnosticsPackage.cs:69-73`), so it is active while debugging.
   - `CopilotFunctionHandler.SubscribeForFunctionsAsync` (`Copilot\Functions\CopilotFunctionHandler.cs:92`) just publishes `GetFunctionsAsync`, which is fine.
   - Studied the CMake registration pattern (`CMakeCopilotFunctionProvider.cs` ~300-500):
     - UIContext/setting changes → `UpdateToolsStatus`.
     - That cancels and starts a `FunctionsRegistrationTask`.
     - The task waits for the Copilot UIContext (`a8984974-3a2f-4e50-810a-4cc51f6c1a04`, skipped if `IsZombie`).
     - It then calls `serviceBroker.GetProxyAsync<ICopilotRegistrationService>(CopilotDescriptors.InteractionService)` and `RegisterFunctionProviderAsync(moniker, identity, token)`.
     - It stays registered until cancelled, then calls `UnregisterFunctionProviderAsync(moniker, VsShellUtilities.ShutdownToken)`.
   - Was reviewing `XamlDiagnosticsPackage.Initialize` (lines 137-205, `Dispose` 207-231) and `XamlDiagnosticsFunctionProvider.cs` (lines 1-70) to decide where to hook in.
</history>

<work_done>
- **VS repo** `Q:\src\VS_xaml`:
  - HEAD is `c15a32e78cc0` (the prototype commit).
  - Uncommitted: the `src\Xaml\Scripts\DeployToVs.ps1` skill-deploy change.
- **No code changes this segment.** Investigation only; the fix is designed but not implemented.
- **Temp artifacts to delete at the end:** `%TEMP%\xamlfnprobe.ps1` and `%TEMP%\xamlprobe\`.
- Note for the user: my earlier interim suggestion that PerformanceProfiler proved first-party merging works was wrong. That provider is directly registered.
</work_done>

<technical_details>
- **Root cause (confirmed):**
  - In CLI/SDK backend sessions there's no active responder in `CopilotFunctionRegistry.activeResponders`. `GetSessionToolsAsync` (CopilotFunctionRegistry.cs ~309-331) therefore returns only directly registered providers, and FirstPartyToolsProvider `AllFromProviderTool` entries never reach the session.
  - The skill works because skills use a separate MEF path (`MefAgentSkillsPaths`, UIContext-gated).
- **Fix approach:** register `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions` (0.1) directly via `ICopilotRegistrationService.RegisterFunctionProviderAsync`, the same way CMake, C++ (`vc\designtime\Managed\Copilot\CopilotCppFunctionHandler.cs:670`) and BuildInsights do.
  - Gate it on UIContext `GuidList.UICONTEXT_DiagnosticToolWindowsAvailable` (5C69788A) plus the Copilot UIContext `a8984974-3a2f-4e50-810a-4cc51f6c1a04`.
  - Unregister on deactivation and on package dispose.
  - Identity: `new CopilotFunctionProviderIdentity("XAML Diagnostics")` or similar.
  - Keep the FirstPartyToolsProvider entry: for legacy-backend sessions, `GetSessionToolsAsync` removes registry tools whose DisplayName matches first-party tools, so there are no duplicates.
- **CLI filter:** `CliFunctionProvider.cs:87` `FirstPartyProviderNames` doesn't include XAML, so the tools get "registry/extension allowed". `ExcludedRegistryTools` is at :71.
- **Package context:** `XamlDiagnosticsPackage` is a synchronous `Shell.Package` that loads when debugging. Its `Initialize` gets the `VisualStudioXamlDiagnosticsHost` via MEF. Use `SVsBrokeredServiceContainer` → `GetFullAccessServiceBroker()` for the broker, and `ThreadHelper.JoinableTaskFactory`.
- **Code conventions:**
  - Diagnostics code files use the dashed copyright header.
  - Use `#pragma warning disable VSCOPILOT_API` for Copilot APIs (and `VSCOPILOT_BACKEND` for skills).
  - `XamlDiagnosticsFunctionProvider` already exposes a static `Moniker`.
- **Logging:** the useful traces are in `%TEMP%\VSGitHubCopilotLogs\<guid>\*_VSGitHubCopilot.chat.log`; search `[tool registry]` and `[inject]`.
- **User preferences:**
  - Never push, rebase or amend. Make only new commits when asked.
  - Builds: prime with `src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` per the `building-locally` skill, in the same process. Never build the whole repo.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\XamlDiagnosticsPackage.cs`
  - The place to start/stop the new registrar: `Initialize` at 137-205, `Dispose` at 207-231.
  - UIContext rules at 64-78.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The provider: `ServiceName`/`Moniker`/`ServiceDescriptor` at lines 25-29. Verified working.
  - Add the new registrar class next to it, e.g. `AgentTools\XamlDiagnosticsCopilotRegistration.cs`. It must be added to the csproj if the project is non-SDK-style, so check.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsSkillsProvider.cs`
  - Skill provider, gated on 5C69788A.
- `Q:\src\VS_xaml\src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs` (~300-510)
  - The reference registration pattern to copy.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Core\Functions\CopilotFunctionRegistry.cs`
  - Root-cause code: `GetSessionToolsAsync` at ~309, `UpdateSessionResponderAsync` at ~387, `RegisterFunctionProviderAsync` at 183.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\HostTools\CliFunctionProvider.cs`
  - The CLI exposure filter: `Classify` at ~112.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`
  - XAML entry at 267-269. Keep it for the legacy backend.
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`
  - Holds the uncommitted skill-deploy change.
</important_files>

<next_steps>
1. Briefly report the confirmed root cause to the user, with log evidence. Correct the earlier claim: debugger tools reach CLI sessions through agent-resolved tools, and PerformanceProfiler/CodeTesting are directly registered providers.
2. Implement `XamlDiagnosticsCopilotRegistration` in Diagnostics.dll, modeled on CMake:
   - Subscribe to `UIContext.FromUIContextGuid(5C69788A)` changes, plus the Copilot UIContext (skip if zombie).
   - On active, start a registration task: get the `ICopilotRegistrationService` proxy via `CopilotDescriptors.InteractionService`, call `RegisterFunctionProviderAsync(XamlDiagnosticsFunctionProvider.Moniker, identity)`, hold until cancelled, then `UnregisterFunctionProviderAsync`.
   - Serialize with a semaphore/ReentrantSemaphore. Catch and log exceptions.
   - Use `[MethodImpl(NoInlining)]` around Copilot-type usage.
   - Create it in `XamlDiagnosticsPackage.Initialize` and dispose it in `Dispose`.
3. Prime and build only the Diagnostics project, deploy with `DeployToVs.ps1`, and have the user restart fastmain Exp. Verify that `[tool registry]` lines show `Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions` and `xaml_*` in the exposed list.
4. Update docs/plan if relevant (the registration mechanism note in `src\Xaml\Diagnostics` docs/README).
5. Commit only if asked, as a new commit. `DeployToVs.ps1` is still uncommitted.
6. Delete `%TEMP%\xamlfnprobe.ps1` and `%TEMP%\xamlprobe\`.
7. At session end, ask whether to update a skill. Candidate content: diagnosing missing Copilot tools via `VSGitHubCopilotLogs` `[tool registry]`/`[inject]` traces, and the fact that CLI-backend sessions ignore FirstPartyToolsProvider entries, so providers must self-register.
</next_steps>