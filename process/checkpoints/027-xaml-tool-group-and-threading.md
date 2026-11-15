<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. That covers Live Visual Tree, properties, styles/resources, Live Preview, binding failures, accessibility, Hot Reload and TAP capabilities. The prototype is committed (c15a32e78cc0): 22 `xaml_*` tools in Diagnostics.dll, the `xaml-diagnostics` skill, a FirstPartyToolsProvider entry and demo apps. The current work makes the tools appear and work in Copilot SDK/CLI sessions: self-registration (done and verified), a "XAML Diagnostics" tool group in the Tools UI (requested, not yet edited), and fixing UI-thread asserts in `XamlAgentService` (in progress).
</overview>

<history>
1. **Earlier work (prior compactions):**
   - Planned, implemented, reviewed and committed the prototype.
   - Created 17 demo WPF apps in `Q:\source\XamlAgentDemos`.
   - Extended `DeployToVs.ps1` to deploy the skill. This change is still uncommitted.
   - Diagnosed the missing tools: CLI/SDK sessions only get tools from providers registered directly with Copilot (`CopilotFunctionRegistry.GetSessionToolsAsync` has no active responder for those sessions). FirstPartyToolsProvider entries never reach them.

2. **Self-registration fix (done):**
   - Created `AgentTools\XamlDiagnosticsCopilotRegistration.cs`, modeled on the CMake provider.
     - Watches UIContext 5C69788A (`GuidList.UICONTEXT_DiagnosticToolWindowsAvailable`).
     - Waits for the Copilot UIContext `a8984974-3a2f-4e50-810a-4cc51f6c1a04` and skips if it's a zombie.
     - Gets an `ICopilotRegistrationService` proxy via `CopilotDescriptors.InteractionService` and calls `RegisterFunctionProviderAsync(Moniker, Identity)`.
     - Holds the registration until cancelled, then calls `UnregisterFunctionProviderAsync` with `VsShellUtilities.ShutdownToken`.
     - Serializes registrations by awaiting the previous JoinableTask.
   - Added `public static readonly CopilotFunctionProviderIdentity Identity = new("XAML Diagnostics");` to `XamlDiagnosticsFunctionProvider`.
   - Wired it into `XamlDiagnosticsPackage`: a field, creation at the end of `Initialize` after the test-contract `AddService`, disposal in `Dispose`, and a `using ...AgentTools`.
   - Updated `Documentation\copilot-tools.md`.
   - Built Diagnostics.csproj successfully. Deleted the temp probes.
   - The user confirmed the `xaml_*` tools now appear under the built-in tools in the AI Customization Tools page.

3. **User asked whether the XAML tools can get their own category (no code changes yet):**
   - Answered yes:
     - The Tools page groups by `CopilotFunctionDescriptor.Group` (`VsToolMapping.SourceDisplayNameOf`). A null `Group` falls under "Built-in".
     - `CopilotFunctionAttribute.Group` is copied into the descriptor (`CopilotFunctionHandler.cs:198`).
     - The Debugger heading comes from a different mechanism: the custom agent's tool source (`AgentToolSourceProvider`).
     - `Group` is `[Localizable(true)]`. Planning uses the literal "Planning".

4. **Latest request:** "Yes, add the code for the Group for the XAML tools. Don't compile yet." The user also reported a debug assert and asked for both thread issues to be fixed:
   - Assert: `GetEndpoints must be called on the UI thread`, from `XamlAgentService.ListAppsAsync` → `GetEndpoints`, with the continuation running on the threadpool.
   - The user added: "Same for use of IBindingFailures, it's used from the wrong thread (must be UI thread)."
   - Investigation so far:
     - `GetHostAsync` (lines ~65-100) switches to the main thread, then awaits `LoadPackageAsync` and `Task.WhenAny(hostSource.Task, Task.Delay(...))`.
     - It evidently returns on a background thread, and callers then call `GetEndpoints` (which requires the UI thread, line 114-118) immediately.
     - The binding-failure methods are `GetBindingFailuresAsync` (line 1257, uses `host.BindingFailuresProvider?.BindingFailures` at 1262-1263) and `ClearBindingFailuresAsync` (line 1301, at 1304).
   - **No edits have been made yet for the Group or the thread fix.**
</history>

<work_done>
**Uncommitted changes in `Q:\src\VS_xaml`:**
- `src\Xaml\Scripts\DeployToVs.ps1`: skill-deploy change, from earlier.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsCopilotRegistration.cs`: new.
- `AgentTools\XamlDiagnosticsFunctionProvider.cs`: `Identity` field added at line 30.
- `XamlDiagnosticsPackage.cs`: registration wired in.
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`: registration note.

**Status:**
- [x] Self-registration. Built and verified by the user.
- [ ] Add `Group = "XAML Diagnostics"` to all 22 `[CopilotFunction(...)]` attributes (do not compile).
- [ ] Fix UI-thread asserts (`GetEndpoints`, `IBindingFailures`) in `XamlAgentService`.
- [ ] Commit, only when the user asks.
</work_done>

<technical_details>
**Attribute format.** The attributes look like this, so `Group` can be appended after the confirmation argument as a named property:
```
[CopilotFunction("xaml_list_apps",
    "description...",
    CopilotConfirmationRequirement.NotRequired)]
```
Some attributes have more arguments, so check each one. The 22 tools start at these lines in `XamlDiagnosticsFunctionProvider.cs`: 52, 61, 70, 83, 98, 110, 120, 131, 143, 156, 174, 184, 201, 217, 228, 242, 251, 263, 277, 287, 333, 343.
- Consider a `private const string ToolGroup = "XAML Diagnostics";` and `Group = ToolGroup` in each attribute.

**Thread fix approach:**
- Make `GetHostAsync` end with `await XamlAgentService.MainThreadFactory.SwitchToMainThreadAsync(cancellationToken);` before returning, so every caller is on the UI thread.
- Also make sure the binding-failure methods access `IBindingFailures` on the UI thread: switch explicitly before using `failures`, and after any await.
- Audit other paths where an await (Task.WhenAny, `SendTapMessageAsync`, `Task.Delay`, `await TaskScheduler.Default` at ~1547/1575) is followed by UI-only calls (`GetEndpoints`, `FindEndpoint`, `FindElement`, host members). Re-switch where needed.
- `MainThreadFactory` = `ThreadHelperBase.Factory ?? ThreadHelper.JoinableTaskFactory`.

**Copilot internals:**
- CLI session tools come from registry providers (`VsToolsSessionProvider`, which logs `[tool registry]`) plus the active agent's tools.
- Logs live in `%TEMP%\VSGitHubCopilotLogs\<guid>\*_VSGitHubCopilot.chat.log`.

**User preferences:**
- Never push, rebase or amend. Make only new commits, and only when asked.
- Builds: prime with `src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` in the same process, then run `msbuild Diagnostics.csproj /restore` (it takes about 8 minutes). Never build the whole repo. The user said don't compile for this step.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool attributes to add `Group` to. The constants (`PermissionScope`, etc.) are around lines 32-35.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - `GetHostAsync` is at ~65-100. `GetEndpoints` is at 114 and asserts on the UI thread. `FindElement` is at ~148.
  - `ListAppsAsync` is at ~197. `GetDiagnosticsStatusAsync` is at ~247.
  - Binding failures are at 1257 and 1301. `ApplyHotReloadAsync` is at ~1413. Capture is at ~1515-1590. Accessibility is at ~1600.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsCopilotRegistration.cs`
  - New registrar, done.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\XamlDiagnosticsPackage.cs`
  - Creates and disposes the registrar.
- `Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Backends\HostTools\VsToolMapping.cs`
  - Grouping logic, reference only.
</important_files>

<next_steps>
1. Add `Group = "XAML Diagnostics"` (via a const) to all 22 `CopilotFunction` attributes. Don't compile.
2. Fix the thread affinity in `XamlAgentService`:
   - Switch back to the main thread at the end of `GetHostAsync`.
   - Make sure `IBindingFailures` use in `GetBindingFailuresAsync`/`ClearBindingFailuresAsync` is on the UI thread.
   - Audit the other awaits that are followed by UI-only calls.
3. Report the changes briefly and tell the user the code isn't compiled yet. Offer a build and deploy (`DeployToVs.ps1`) and a commit when asked.
4. At session end, ask whether to update a skill. Candidate lessons: CLI sessions require direct `ICopilotRegistrationService` registration; diagnose missing tools via `[tool registry]` logs; `Group` controls the Tools UI category.
</next_steps>