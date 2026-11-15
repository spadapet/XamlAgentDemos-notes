<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to GitHub Copilot, so AI models can inspect, debug and fix running XAML apps through VS and the TAP.

That work is implemented as a prototype and committed locally:
- 22 in-proc `xaml_*` Copilot agent tools plus a built-in skill.
- New capability-gated TAP messages for WPF, UWP/WinUI and MAUI.
- Style and resource tools.

The latest request is to come up with high "wow factor" demo ideas, with sample WPF apps, showing what these capabilities make possible that couldn't be done before.

Standing constraint: never push, rebase or amend. Add new local commits only, and stop for the user's review.
</overview>

<history>
1. **Earlier segments (summarized):**
   - Planned and implemented the XAML Copilot tools, the `xaml-diagnostics` skill, Copilot registration, the hot reload log buffer, and TAP handlers for WPF, UwpTap (C++) and MAUI.
   - Re-routed the in-app toolbar to the new tools, and added style and resource tools.
   - Added unit tests and documentation, and updated repo skills with lessons learned (building-locally including git safecrlf, and xaml-build-test-deploy).
   - Commits: `e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`, `723bc2667ffa`.

2. **The user asked for a code review of all the changes.**
   - Ran a code-review subagent over `e92845d6d4a8~1..723bc2667ffa`. It found 4 Medium issues and nothing critical or high:
     1. A null `ThreadHelperBase.Factory` before the package loads.
     2. The hot reload log `Skip(count)` returning nothing once the 500-entry ring buffer is full.
     3. `errorsOnly` also returning Info-level entries.
     4. `xaml_interact` blocking the TAP's message thread with no limit on app event handlers.
   - I verified #1 and #3 myself and reported the findings.

3. **The user said "Yes fix everything and make a commit".**
   - Fixed all four (details in Work Done).
   - Built all affected projects through a temporary traversal `.vs\copilot.proj`: 0 errors.
   - Ran the unit tests: 5 of 5 passed.
   - Committed `309c315ca805` "XAML Copilot tools: fix code review findings". Not pushed.

4. **Current request:** "Come up with some great demo ideas with a big 'wow factor'... show off something that couldn't be done before and really seem like a useful time saver. One example might be to fix all of the binding failures... there must be more impressive demos... You can create sample WPF apps for demonstrating these scenarios. Make as many as you want."
   - Confirmed the 22 tool names and the installed .NET SDKs.
   - Brainstormed demo ideas (listed in Next Steps).
   - No apps have been created yet.
</history>

<work_done>
Commit `309c315ca805` (local only) contains these fixes:
- **`XamlAgentService.cs`:**
  - Added `private static JoinableTaskFactory MainThreadFactory => ThreadHelperBase.Factory ?? ThreadHelper.JoinableTaskFactory;` and replaced all 9 `ThreadHelperBase.Factory.SwitchToMainThreadAsync` calls with it.
  - `errorsOnly` now filters with `e.IsWarningOrError`.
  - `ApplyHotReloadAsync` now uses `LatestSequence` together with `GetEntriesAfter(seq)`.
- **`XamlHotReloadLogBuffer.cs`:**
  - Each entry has a `Sequence` property and an `IsWarningOrError` property.
  - Added a static `lastSequence`, which is incremented under the lock.
  - Added the `LatestSequence` property and the `GetEntriesAfter(long)` method.
- **WPF and MAUI `TapAgentToolsService.cs`:** the automation action is queued on the UI thread and waited on for at most `ActionWaitTimeout` = 3 seconds. After that, the TAP returns `ActionStillRunningResult` ("started but hasn't finished... Don't repeat the action; capture an image").
  - WPF uses `BeginInvoke` with a new `RunActionSafe` wrapper that catches exceptions.
  - MAUI uses `dispatcher.InvokeAsync(...).Wait(timeout)` and unwraps `AggregateException`. It needed a new `using System.Threading.Tasks`.
- **`UwpTap.cpp` `HandleElementAutomationAction`:**
  - Uses `WinrtRunOnUIThreadAsync` with a `shared_ptr<ActionState>` captured by value, plus `future.wait_for(3s)`.
  - If the action is still running, it returns only a `Result` message.
- **`XamlAgentToolsTests.cs`:** added `HotReloadLog_GetEntriesAfter_ReturnsNewEntriesWhenBufferIsFull`, and added an Info-level "Rude edit check passed" entry to the filter test.
- **Docs:** the skill `SKILL.md` and `copilot-tools.md` now describe the "still running" interact result.

All commits, none pushed: `e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`, `723bc2667ffa`, `309c315ca805`.

Demo work: not started. No sample apps or files have been created.
</work_done>

<technical_details>
- **Tool names**, from `XamlDiagnosticsFunctionProvider.cs`:
  - App and status: `xaml_list_apps`, `xaml_get_diagnostics_status`.
  - Tree and properties: `xaml_get_visual_tree`, `xaml_find_elements`, `xaml_get_element_properties`, `xaml_set_element_property`.
  - Styles and resources: `xaml_get_element_styles`, `xaml_explain_property_value`, `xaml_find_resource`, `xaml_get_resource_dictionaries`.
  - Layout and interaction: `xaml_get_element_bounds`, `xaml_interact`, `xaml_select_element`.
  - Binding failures: `xaml_get_binding_failures`, `xaml_clear_binding_failures`.
  - Hot reload: `xaml_get_hot_reload_status`, `xaml_get_hot_reload_log`, `xaml_apply_hot_reload`.
  - Live Preview: `xaml_list_windows`, `xaml_capture_image`.
  - Accessibility: `xaml_run_accessibility_check`, `xaml_get_accessibility_results`.
- **Installed .NET SDKs:** 10.0.115, 10.0.301, 10.0.404, 11.0.100-rc.3, 11.0.100. Use net10.0-windows (or net11.0-windows) WPF for the samples. `dotnet build` is fine for standalone sample apps outside the VS repo; the VS repo itself requires msbuild/Invoke-Build.
- **Build quirks:**
  - In pwsh 7, reset `PSModulePath` to the Windows PowerShell defaults before running `Prime-ForCopilot.ps1`.
  - Don't pipe builds into `Select-Object -First`.
  - UwpTap needs project references.
- **Git:** `core.safecrlf=true` and `autocrlf=true`, so files must use CRLF before `git add`. Use `git -C Q:\src\VS_xaml`. Commit trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- **Tests:** `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter "A,B"`. Quote the comma-separated list.
- **TAP capability gating:** the TAP reports `SupportsAgentTools` (0x20). The host refuses to send messages 560–563 to a TAP that doesn't report it.
- **XAML source info:** F5 Debug builds have it. For attach scenarios, set `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1`.
- **Not yet decided:** where to put the demo sample apps. Options: outside the VS repo (for example `Q:\src\XamlAgentDemos`), in the session `files\` folder, or inside the repo. Committing them into the VS repo is probably unwanted. I was considering asking the user about location via `ask_user`, defaulting to outside the repo.
</technical_details>

<important_files>
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The core service behind the tools.
  - `MainThreadFactory` is at about lines 55-59; the hot reload log and apply code is at about 1376-1440.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlHotReloadLogBuffer.cs`
  - The ring buffer of hot reload log entries, now with sequence numbers.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tool definitions, with their names and parameters (lines 51-342).
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`, `src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.cs`, `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`
  - The TAP-side handlers for interact. In UwpTap.cpp, the handler is at about line 1669.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`
  - The skill's workflows. Demo scripts should follow it.
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - The feature documentation.
</important_files>

<next_steps>
Current task: design high-impact demos and create sample WPF apps for them.

Planned demo ideas (each should be a small, focused WPF app with seeded bugs and a DEMO.md: the prompt to type, the expected tool flow, and why this was impossible or slow before):
1. **Dark mode is broken in N places (ThemeBreaker):**
   - Bugs: StaticResource instead of DynamicResource, hard-coded colors, and style precedence problems.
   - The AI toggles the theme with `xaml_interact` and captures images before and after.
   - It traces each wrong value to its source with `xaml_explain_property_value` and `xaml_find_resource`.
   - It fixes them through hot reload, then re-verifies.
2. **The vanishing Save button (mystery):** several stacked causes at once:
   - Visibility bound to a failing binding.
   - Opacity set by a style trigger.
   - The button covered by another element.
   - A zero-width Grid column.

   The AI uses the tree, bounds, property sources and binding failures together to find them.
3. **Binding storm:** binding failures that only appear after navigating tabs and dialogs. The AI exercises the whole app with `xaml_interact` to surface every failure, fixes them all, hot reloads, and confirms zero remain. This amplifies the user's own example.
4. **Accessibility ship-blocker sweep:** icon buttons with no names, low contrast, images with no alt text. The AI runs the checker, fixes the issues at their source locations, re-runs it to reach zero, and drives the app with UI Automation to prove it works.
5. **Match the designer's mockup:** a mockup PNG (generated from a "target" XAML render, for example via a `--render-mockup` switch). The AI compares it with `xaml_capture_image`, adjusts live with `xaml_set_element_property`, writes the result to XAML, and hot reloads until it matches.
6. **Ready for German? (localization/responsive stress):** the AI sets long strings and window sizes live, and detects clipping and overlap from `xaml_get_element_bounds` data.
7. **Optional:**
   - A bug report reproduced from steps: "Save stays disabled after Cancel". The AI drives the UI and inspects IsEnabled and the binding values.
   - "What code is behind this pixel?": map a screenshot region to an element, then to its source XAML and view model.

Immediate next steps:
- Decide where to put the samples. Possibly ask the user with `ask_user`, defaulting to outside the VS repo, for example `Q:\src\XamlAgentDemos`, as one solution with multiple net10.0-windows WPF projects.
- Create the apps, a top-level README listing the demos and their wow points, and a DEMO.md per app. Build each with `dotnet build` and confirm they launch.
- Present a concise demo list to the user, ranked by wow factor.
- If the samples end up in the VS repo, commit them as a new commit with CRLF line endings, no push. Otherwise no commit is needed.
</next_steps>