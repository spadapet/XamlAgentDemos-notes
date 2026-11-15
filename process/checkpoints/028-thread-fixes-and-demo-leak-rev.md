<overview>
The user wants Visual Studio's XAML Diagnostics exposed to Copilot so AI can inspect and debug running XAML apps. That covers Live Visual Tree, properties, styles/resources, Live Preview images, binding failures, accessibility, Hot Reload and TAP capabilities. The prototype is committed (c15a32e78cc0): 22 `xaml_*` tools in Diagnostics.dll, the `xaml-diagnostics` skill, a FirstPartyToolsProvider entry and 17 demo WPF apps in `Q:\source\XamlAgentDemos`. Since then, the work has been making the tools appear and run correctly in Copilot sessions: self-registration, a Tools UI group and UI-thread fixes. Now the user is questioning whether the demo apps' DEMO.md files let the model "cheat".
</overview>

<history>
1. **Earlier work (prior compactions):**
   - Planned, implemented, reviewed and committed the prototype.
   - Created the demo apps.
   - Extended `DeployToVs.ps1` to deploy SKILL.md.
   - Diagnosed why the tools were missing: CLI/SDK sessions only get tools from providers registered directly via `ICopilotRegistrationService`.
   - Added `XamlDiagnosticsCopilotRegistration.cs` self-registration. The user verified the tools appeared.

2. **User asked for the tools to show under a "XAML Diagnostics" category, and reported thread asserts:**
   - Asserts: `GetEndpoints must be called on the UI thread`, plus IBindingFailures used from the wrong thread. Then all tools failed with threading errors. The user closed VS and asked me to fix, compile and test.
   - Added `private const string ToolGroup = "XAML Diagnostics";` and `Group = ToolGroup` to all 22 `[CopilotFunction]` attributes.
   - Thread fixes in `XamlAgentService.cs`:
     - `GetHostAsync` switches back to the main thread before returning.
     - `SendTapMessageAsync` switches to the main thread after awaiting the send.
     - `GetStyleKeyAsync` has a `finally` that switches to the main thread.
     - `GetHotReloadStatusAsync` switches after the try/catch.
     - `ApplyHotReloadAsync` switches after `ApplyXamlChangesAsync` and after each `Task.Delay` in the loop.
     - `RunAccessibilityCheckAsync` switches after `viewModel.RunAsync()`.
   - Built Diagnostics.csproj successfully (about 3 minutes).
   - Deployed elevated via `DeployToVs.ps1 -VSInstallPath c:\vs\fastmain -Diagnostics -NonInteractive`: 42 files copied, 0 failed. The window closed during the "Updating devenv configuration" step. The DLL timestamp was confirmed as new.

3. **User asked: "Are you sure all of the tools are now running their code on the right thread?"**
   - Audited every await, lazy LINQ, the accessibility view model, imaging and log buffer.
   - Concluded the code paths are correct:
     - All lists in results are materialized with ToArray/ToList on the UI thread.
     - The hot reload log is lock-protected.
     - Capture moves to a background thread only for Win32/frozen-bitmap work.
     - There's no ConfigureAwait(false) or Task.Run.
   - Said runtime testing is still needed.

4. **Latest request:** the user showed a screenshot.
   - The prompt was "Find and fix every binding failure, even the ones you haven't hit yet". The agent read `DEMO.md`, ran `git status` and read `xaml-authoring.md`.
   - The user asked: "Is DEMO.md guiding the model to do stuff that it should be figuring out on its own? In normal apps, the user won't have a file that tells it exactly how to find the errors".
   - I started investigating. I listed the md files in `Q:\source\XamlAgentDemos`: each `src\<App>\DEMO.md` (about 2-3.4KB), plus `README.md`, `BugRepro\bug-report.md`, `DesignPolish\design-tokens.md` and a huge `XamlDiagnosticsToolsSession.md` (3.2MB, a session log).
   - I haven't read the DEMO.md contents yet. The output of `Get-Content .\BindingStorm\DEMO.md` was empty because the actual path is `src\BindingStorm\DEMO.md`.
</history>

<work_done>
**Uncommitted changes in `Q:\src\VS_xaml`:**
- `src\Xaml\Scripts\DeployToVs.ps1`: skill deploy.
- `AgentTools\XamlDiagnosticsCopilotRegistration.cs`: new.
- `AgentTools\XamlDiagnosticsFunctionProvider.cs`: `Identity` field, `ToolGroup` const, and `Group = ToolGroup` on all 22 tools.
- `AgentTools\XamlAgentService.cs`: UI-thread switches.
- `XamlDiagnosticsPackage.cs`: registrar wiring.
- `Documentation\copilot-tools.md`: registration note.

The build succeeded and the change is deployed to `c:\vs\fastmain`. It hasn't been tested at runtime by me; the user's session screenshot shows the tools are running.

**Status:**
- [x] Registration
- [x] Group
- [x] Thread fixes, built and deployed
- [ ] Answer the DEMO.md "cheating" question, and possibly restructure the demos
- [ ] Commit, only when the user asks
</work_done>

<technical_details>
**Threading:**
- `ThreadHelperBase.ThrowIfNotOnUIThread` uses `JoinableTaskContext.IsOnMainThread`.
- `BindingFailures.CheckThreadAccess` requires the owner thread (main).
- `MainThreadFactory` = `ThreadHelperBase.Factory ?? ThreadHelper.JoinableTaskFactory`.

**Tools UI grouping:** the Tools UI groups by `CopilotFunctionDescriptor.Group`. A null Group means "Built-in".

**Copilot logs:** `%TEMP%\VSGitHubCopilotLogs\<guid>\*_VSGitHubCopilot.chat.log`.

**Environment:**
- The shell isn't elevated. `c:\vs\fastmain` still needs elevation for deploy, so run `Start-Process pwsh -Verb RunAs`.
- VS installs: `18\Main`, `18\IntPreview` (running), `c:\vs\rtm`, `c:\vs\test`, `c:\vs\fastmain`.

**Builds:** prime with `src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` in the same process, then run `msbuild src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj /restore /m`.

**User preferences:** never push, rebase or amend. Make only new commits, and only when asked.

**DEMO.md concern:** the demo apps live in the same folder/solution the model opens. DEMO.md files (and possibly code comments, README.md and the 3.2MB `XamlDiagnosticsToolsSession.md`) likely spell out the planted bugs, so the agent can read answers instead of discovering them with the tools.

Likely remedies:
- Move DEMO.md/README/session log out of the app source tree, into a separate `docs`/presenter folder outside the solution directory, or outside the repo the agent opens.
- Strip hint comments from the XAML/C# (for example "BUG:" comments).
- Optionally add `.copilotignore`-style exclusion, or keep the presenter notes elsewhere.
- Keep legitimate inputs like `bug-report.md` and `design-tokens.md`, which mimic real artifacts a user might have.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The tool façade.
  - Thread fixes are at `GetHostAsync` (~65-103), `SendTapMessageAsync` (~172-202), `GetStyleKeyAsync` (~954-979), hot reload status (~1325-1345), apply (~1428-1445) and accessibility (~1615-1640).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The 22 tool attributes. `ToolGroup` is at line 32.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsCopilotRegistration.cs`
  - The registrar.
- `Q:\source\XamlAgentDemos\src\<App>\DEMO.md` (17 apps), `README.md`, `XamlDiagnosticsToolsSession.md`
  - Presenter notes that may leak answers to the agent.
</important_files>

<next_steps>
1. Read the DEMO.md files (start with `src\BindingStorm\DEMO.md`) and README.md.
2. Grep the demo XAML/C# for hint comments (BUG, TODO, "intentional", "wrong", "typo").
3. Answer the user: yes or no, with evidence of what leaks.
4. Propose a fix: move presenter notes out of the agent-visible tree (for example `Q:\source\XamlAgentDemos-notes\` or a folder outside the solution/git root), and scrub giveaway comments. Keep realistic artifacts such as bug-report.md and design-tokens.md. The user didn't ask for changes yet, so ask before moving files, or do it if clearly requested. Also mention that the agent ran `git status`, which could reveal diffs.
5. Commit the VS_xaml changes only when asked.
6. At session end, ask whether to update a skill. Lessons:
   - CLI sessions need `ICopilotRegistrationService` registration.
   - `Group` sets the Tools category.
   - Agent tool code must re-switch to the UI thread after awaits.
</next_steps>