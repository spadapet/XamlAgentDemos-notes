<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. The scope covers the Live Visual Tree, properties, styles and resources, Live Preview, binding failures, accessibility checks, Hot Reload and TAP capabilities. A prototype has been implemented and committed locally, 17 demo WPF apps were created, and `DeployToVs.ps1` was extended to deploy the skill files.

The current issue is in the user's fastmain Experimental instance: the `xaml-diagnostics` skill appears in the Copilot session, but the `xaml_*` tools do not. We are tracing why. The latest finding is that the provider's static type initializer throws.
</overview>

<history>
1. **Earlier work (before previous compactions):**
   - Planned and implemented the prototype: 22 `xaml_*` tools, TAP messages, a skill, and style/resource tools. It was reviewed, fixed and committed as `c15a32e78cc0`.
   - Created 17 demo apps in `Q:\source\XamlAgentDemos`.
   - Extended `DeployToVs.ps1` to deploy the skill tree (uncommitted).
   - Found that the installed Copilot DLL lacked the XAML first-party entry; the user then F5-deployed the Copilot solution into fastmain's Exp hive.

2. **The user ran fastmain with `/log`; the tools were still missing while the skill was present.** Findings this segment:
   - **ActivityLog and MEF cache:** no errors. `XamlDiagnosticsFunctionProvider`, the skills provider and `XamlAgentService` are all in the cache.
   - **CLI harness filter** (`CliFunctionProvider.Classify`): the XAML provider is not in `FirstPartyProviderNames`. Its tools therefore classify as "registry/extension allowed", so the harness does **not** drop them. This rules out the earlier leading hypothesis.
   - **Tool reselection:** `CopilotSdkSession.Tools.cs` re-selects tools per request, so tools that arrive late are supported.
   - **UI context:** the skill provider is gated on the same UI context (`5C69788A`, `UICONTEXT_DiagnosticToolWindowsAvailable`) as the tools entry. Since the skill appeared, the UI context was active and is not the problem.
   - **Proxy requests:** the GlobalBrokeredServiceContainer svclog (`%TEMP%\VSLogs\VSDE0226DA...GlobalBrokeredServiceContainer.OZVG.svclog`) shows "Requesting proxy to Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions (0.1)" at 18:44:29, completing at 18:44:35 with no logged error.
   - **Subscription failure path:**
     - `FirstPartyToolSubscriptions` calls `SubscribeForFunctionsAsync`.
     - The base `CopilotFunctionHandler` implementation calls `GetFunctionsAsync`, which runs `LookupFunctionsAsync`. That method reflects over the `[CopilotFunction]` methods.
     - Any exception there leads to `OnError`. The cached list stays empty, the subscription is never retried, and no tools appear.
   - **Confirmation rule:** `CopilotLocalFunctionDescriptorHelpers.GetInputs` throws if a `Confirmation.Required` tool lacks an `ICopilotFunctionBroker` or `CopilotFunctionInvocationContext` parameter. Our 5 Required tools do have `ICopilotFunctionBroker broker`, so that rule is satisfied.
   - **Repro script:** wrote `%TEMP%\xamlfnprobe.ps1` and ran it under Windows PowerShell 5.1 (.NET Framework). It loads `C:\vs\fastmain\...\XamlDiagnostics\Microsoft.VisualStudio.DesignTools.Diagnostics.dll` with a guarded AssemblyResolve over:
     - the Exp Copilot dirs: `...\18.0_ca393f20Exp\Extensions\Microsoft\GitHub Copilot\42.42.42.42\Conversations.Service` and its parent,
     - `C:\vs\fastmain\Common7\IDE` (recursive).

     It invokes the provider's private constructor with a null service, then calls `GetFunctionsAsync`.
   - **Result:** "The type initializer for `XamlDiagnosticsFunctionProvider` threw an exception." The inner exception has not been printed yet.
   - The Diagnostics DLL references `Microsoft.VisualStudio.Copilot, Version=18.14.0.0`.
   - An earlier run hit a StackOverflow, but that came from the resolver recursing and has been fixed.
</history>

<work_done>
- **VS repo** `Q:\src\VS_xaml`:
  - HEAD is `c15a32e78cc0`, "Expose XAML Diagnostics to GitHub Copilot (prototype)".
  - Uncommitted: `src\Xaml\Scripts\DeployToVs.ps1` deploys the skill tree (around lines 460–485).
- **Demo repo** `Q:\source\XamlAgentDemos`: commits `d4ddfb1`, `a3f6100` and `1ce572f`.
- **This segment:** investigation only, no code changes.
- **Temp file:** `%TEMP%\xamlfnprobe.ps1` is the probe script; delete it when done.
</work_done>

<technical_details>
- **Static fields that run in the type initializer** of `XamlDiagnosticsFunctionProvider` (`AgentTools\XamlDiagnosticsFunctionProvider.cs`, around lines 28–37). One of these is likely the culprit:
  - `Moniker` and `ServiceDescriptor = CopilotDescriptors.CreateDescriptor(Moniker)`
  - `MiscellaneousContextMoniker = new ServiceMoniker("Microsoft.VisualStudio.Copilot.MiscellaneousContextProvider", new Version(CopilotDescriptors.CurrentContextProviderVersion))`. A version-string format problem or a missing member here is suspicious.
  - `JsonSettings`, a Newtonsoft `JsonSerializerSettings`
- **Version-mismatch theory:** the Diagnostics DLL was compiled against Copilot 18.14.0.0, but the runtime Copilot DLL is the F5 build (42.42.42.42) or the install's copy.
  - A missing field or method, for example `CopilotDescriptors.CurrentContextProviderVersion` absent or different, would throw `MissingFieldException` inside the type initializer.
  - That would make every `GetFunctionsAsync` call fail inside VS, so the subscription faults silently.
- **The probe may not exactly match VS binding:** it resolves `Microsoft.VisualStudio.Copilot` from the Exp extension folder first. Still, the type-initializer failure is a strong lead.
- **First-party tool flow:**
  1. `ToolsState` (FirstPartyToolsProvider.cs, around lines 318–500) subscribes to providers.
  2. `FirstPartyToolSubscriptions.ProviderSubscription.OnError` swallows errors with no trace logging and no retry.
  3. `FirstPartyToolEvaluator` matches the cached functions; `AllFromProviderTool` returns all of them.
  4. The UI-context gate is `XamlDiagnosticsToolsUIContext`, defined at FirstPartyToolsProvider.cs line 62.
- `AllFromProviderTool` is otherwise only used by SSMS providers.
- **CLI harness** (`CliFunctionProvider.cs`): the XAML tools would be allowed, since they aren't in `ExcludedRegistryTools`.
- **Alternative registration** (used by vc/CMake): `ICopilotRegistrationService.RegisterFunctionProviderAsync`.
- **User git preference:** never push, rebase or amend. Make only a new commit when asked, then stop for review.
- **Builds:** prime first via the `building-locally` skill (`src\Shared\Tools\Scripts\Prime-ForCopilot.ps1`). Never build the whole repo.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The XAML tool provider. Its static fields at lines ~28–37 are the suspect.
  - The Required tools are at ~157, 185, 202, 229 and 264.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`
  - The XAML entry is at lines 260–269; the UI-context constant is at line 62.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolSubscriptions.cs`
  - `OnError` silently swallows subscription failures.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot\Functions\CopilotFunctionHandler.cs` and `CopilotLocalFunctionDescriptorHelpers.cs`
  - The function discovery rules.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\HostTools\CliFunctionProvider.cs`
  - The harness filter; ruled out.
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`
  - Contains the uncommitted skill-deploy change.
</important_files>

<next_steps>
1. Print the inner exception from the type initializer. Modify the probe to catch it and output `$_.Exception.InnerException.InnerException.ToString()`, or call `[Runtime.CompilerServices.RuntimeHelpers]::RunClassConstructor($t.TypeHandle)` and dump the full chain.
2. Fix the root cause in `XamlDiagnosticsFunctionProvider`. For example, if `CopilotDescriptors.CurrentContextProviderVersion` or another Copilot API mismatches at runtime, hardcode or lazily compute `MiscellaneousContextMoniker` and avoid fragile static dependencies.
3. Re-run the probe until `GetFunctionsAsync` returns all 22 functions, which also validates `LookupFunctionsAsync` and `GetInputs` for every tool.
4. Rebuild only the Diagnostics project after priming, redeploy with `DeployToVs.ps1`, and have the user retest by debugging a WPF app and checking the Copilot tools picker.
5. Optionally suggest adding trace logging in `ProviderSubscription.OnError` (Copilot repo) so future failures are visible.
6. Commit only if the user asks (a new commit only); the `DeployToVs.ps1` change is still uncommitted. Delete `%TEMP%\xamlfnprobe.ps1` at the end.
</next_steps>