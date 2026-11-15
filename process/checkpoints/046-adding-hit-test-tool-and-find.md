<overview>
The user is building Copilot "XAML Diagnostics" agent tools (`xaml_*` tools in Diagnostics.dll, WPF TAP messages, and a built-in SKILL.md) for Visual Studio. They had me test all 17 demo apps autonomously in the fastmain Exp hive, log every run and fix in the notes repo, and improve the tools and skill.

Their latest request: using the feedback from the testing, think of:
- new test cases;
- new `xaml_*` tools, or ways to make the current tools more robust;
- SKILL.md additions that help people write better XAML with fewer errors.

Then make any fixes I see fit. Autopilot mode: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments: planned the feature, implemented the tools and skill, and built a test harness. All 17 demos have run; findings #1–58 are logged in `Q:\source\XamlAgentDemos-notes\TestPass.md`.

2. Previous segment (paused-debugger test, VanishingSave `paused1`):
   - Fixed: capture hung on a paused app, apply_hot_reload falsely reported success, and other tools silently returned cached data. Added a ContinueDebuggerHint, IsWindowResponding, and DEBUGGER_PAUSED errors.

3. This segment, finishing that work:
   - Graded paused1 4/4 against DEMO.md.
   - Improved `GetPropertyNotFoundHint` for indexed paths such as `ColumnDefinitions[2].Width`: collection items aren't visual-tree elements, so edit the XAML and hot reload.
   - Built (0 errors) and logged the paused1 row and findings #59–62 in TestPass.md.
   - Redeployed with Redeploy.ps1, which succeeded.
   - The desktop seemed locked (LogonUI present; but a harness note says LogonUI can be a false lock signal over RDP, so use OpenInputDesktop). Waited 9 minutes, then added a "## Pending (desktop locked)" section to TestPass.md listing the paused2 re-test and optional reruns.
   - Stopped KeepAwake (PID 77596) and called task_complete.

4. Current request (improvements from the feedback). Reviewed the open findings:
   - #5: ColumnDefinition widths aren't visible.
   - #11: find_elements can't list all or named elements, and wildcard-looking filters behave as exact names.
   - #12: no point hit-test or occlusion check.
   - #13: effective IsHitTestVisible from an ancestor isn't shown.
   - #14: no element-recreation info after hot reload.
   - #15: type=Window doesn't find MainWindow.
   - #16, #17: hot reload and run_build ambiguity.
   - #35: inactive triggers aren't reported.
   - #40: Local value from markup vs code can't be told apart.
   - #43: ancestor clipping missing from bounds; a resize-window tool was requested.
   - #50: enum values show as numbers; a virtualization report was requested.
   - #56: which DataTemplate an item got.
   - #58: mockup diff tool requested.

   Implemented so far (NOT yet built):
   - New tool `xaml_hit_test` (WPF only), backed by a new TAP message `HitTestRequest = 564`.
   - find_elements: glob support (`*`, `?`) for `type` and `name`, a new `namedOnly` parameter, `type="*"` to list everything, and fixed descriptions and hints. The old description said "substring" but the code did exact matching.
   - xaml_interact result note: automation invoke bypasses hit testing, so use xaml_hit_test to check whether a real click reaches the element.
   - Was about to update copilot-tools.md when compaction happened.
</history>

<work_done>
Repo `Q:\src\VS_xaml`; all changes are uncommitted.

Files changed in this request:
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`
  - Added `HitTestRequest = 564`.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`, after ElementBoundsResponse (~637–762). Added:
  - `HitTestRequest {Handle, UsePoint, X, Y}`.
  - `HitTestElementInfo {Handle, TypeName, Name, TemplatedParent, Property, Value}`.
  - `HitTestResponse : ResponseWithError` with:
    - RootX/Y and ScreenX/Y;
    - PointInsideElement, InputTarget, ElementReceivesInput, Stack;
    - IsVisible, IsHitTestVisible, IsEnabled, EffectiveOpacity, Blockers;
    - VisibleFraction (-1 when the element has no area) and ClippedBy.
- NEW `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs` (partial class):
  - `HandleHitTest` → `FillHitTest`:
    - InputTarget comes from the root's `InputHitTest`.
    - Stack comes from `VisualTreeHelper.HitTest`, with a filter that skips invisible and non-hit-testable elements; max 15 entries.
  - `FillInteractiveState` walks the visual/logical parents:
    - Visibility, IsHitTestVisible and IsEnabled blockers are reported only when not coerced (DependencyPropertyHelper.GetValueSource.IsCoerced).
    - An IsEnabledCore blocker (command CanExecute) is reported when IsEnabled is coerced but the parent is enabled.
    - Opacity <= 0 is a blocker; opacity is multiplied up the chain.
  - `FillClipping` intersects the element's bounds with each self/ancestor clip: `VisualTreeHelper.GetClip`, ClipToBounds, and `LayoutInformation.GetLayoutClip`. Then it intersects with the root's RenderSize.
  - `DescribeHit` adds the outermost TemplatedParent.
  - `Describe` uses `objectIdentityService.GetHandle`.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`
  - Registered the HitTestRequest observer in the constructor.
- `src\Xaml\Shared\Source\WpfTap\WpfTapItems.projitems`
  - Added a Compile entry for TapAgentToolsService.HitTest.cs (line 31).
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
  - `FindElementsAsync`:
    - Signature is now `(app, type, name, sourceFile, line, bool namedOnly, maxResults, ct)`; validation allows namedOnly alone.
    - New helpers `IsWildcard`, `MatchesGlob` (Regex), `MatchesName`; `MatchesType` handles globs.
    - The hint now suggests `type="*X"` and xaml_list_windows (~565–682).
  - `GetPropertyNotFoundHint`: new branch for indexed paths (`[`) (~803).
  - The InteractAsync note mentions xaml_hit_test.
  - New `HitTestAsync(elementId, point, ct)` (~1391–1520):
    - Parses `point` as "x,y" (DIPs, element-relative).
    - Gated by SupportsAgentTools plus a WPF-only platform check that throws UnsupportedByTap with a fallback hint.
    - Maps handles to element IDs and source via `host.TreeContainer.GetElement`.
    - Builds a `summary` sentence list (click reaches or doesn't reach the element, blockers, opacity, clipping, zero size), plus the response fields and a note.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`:
  - find_elements has new parameter descriptions and the `namedOnly` parameter.
  - New `[CopilotFunction("xaml_hit_test", …)]`, NotRequired confirmation, after xaml_get_element_bounds (~197–207).

Earlier this segment (built and deployed):
- The ColumnDefinitions hint. (Note: this was built in the previous step but the deploy happened before… actually Redeploy ran after that build, so it's deployed.)
- TestPass.md: the paused1 row, findings #59–62, and the Pending section.

Not done yet:
- [ ] Update copilot-tools.md (the tool table row for xaml_hit_test, find_elements notes, TAP message table 564, and the WPF files list now including TapAgentToolsService.HitTest.cs; mention that 564 is WPF-only).
- [ ] Update SKILL.md:
  - tool table (~line 33) with xaml_hit_test;
  - the GhostClicks/overlay workflow (~140) to use xaml_hit_test;
  - find_elements wildcards and namedOnly;
  - XAML authoring guidance.
- [ ] Build Diagnostics.csproj plus WpfCoreTap.csproj and WpfTap.csproj (Framework); fix compile errors.
- [ ] Deploy, then test xaml_hit_test on GhostClicks/VanishingSave if the desktop is usable.
- [ ] Log new findings and changes in TestPass.md, plus the proposed new test cases.
</work_done>

<technical_details>
- **Build Diagnostics.csproj:**
  ```
  cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
  Check for " 0 Error(s)".
  - WpfTap projects: `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj` and `...\Framework\WpfTap.csproj`.
  - The contract (XamlTapContract) is probably compiled into those projects or shared. If types aren't found, build the contract project too.
- **Possible compile issues to watch:**
  - C# version support for property patterns (`is FrameworkElement { TemplatedParent: DependencyObject owner }`) and `??=` in the TAP projects (the .NET Framework TAP may use an older LangVersion).
  - The XamlJsonData namespace for HitTestRequest in XamlAgentService (same as ElementBoundsRequest, so it should resolve).
  - A static local function `Label` that calls itself recursively.
  - `SupportedPlatform` enum pattern `is not (A or B)`.
- **Deploy:** run `& "$h\Redeploy.ps1"`, where `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`. It:
  - closes VS;
  - deploys elevated (UAC is off);
  - patches the System.Drawing redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` (temporary until PR 807376);
  - relaunches `devenv /rootsuffix Exp`.
- **Run a demo:** `Run-Demo.ps1 -Name X -Tag runN` (with `-ResumeDir` for follow-ups); prompts come from prompts.json. `node $h\peek.js <events.jsonl>` gives a tool timeline.
- **TAP compatibility:** TAP and VS ship together. A TAP that doesn't know a message never replies, which causes a 10 s timeout. So gate on DiagnosticBits.SupportsAgentTools, and gate hit-test to WPF only (UWP/WinUI/MAUI TAPs don't implement 564).
- **Lock detection:** the session runs over RDP, so LogonUI.exe can be a false lock signal. Use OpenInputDesktop. A minimized RDP client breaks SendKeys, CopyFromScreen and UIA input.
- **Writing files:**
  - TestPass.md: `[IO.File]::WriteAllLines` (UTF-8, no BOM).
  - XamlAgentService.cs: no BOM, CRLF.
- **Edit tool:** it fuzzy-matches "closest lines", so verify the results.
- **Skill examples** must use generic names (no demo names), so the agent can't cheat.
- **Git:** never push, rebase or amend. Offer a single new local commit at the end.
- **Unresolved or ideas not yet implemented:**
  - #5: ColumnDefinition widths (could add to TAP bounds or hit-test, e.g. report the Grid's column/row actual sizes).
  - #14: element recreation info after hot reload.
  - #35: inactive triggers.
  - #40: markup vs code Local values.
  - #50: enum names and a virtualization report.
  - #56: which DataTemplate an item got.
  - #58: mockup diff.
  - A resize-window tool.
  - Whether WPF `VisualTreeHelper.HitTest` respects IsHitTestVisible natively (the filter handles it anyway).
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of every tool. This request: find_elements globs and namedOnly (~565–682), the indexed-path hint (~803), the interact note (~1387), and HitTestAsync (~1391–1520).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions. find_elements (~87–102); xaml_hit_test (~197–207).
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs` (new)
  - TAP hit-test logic.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`
  - Handler registration; FillBounds; InvokeOnDispatcher.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (~637–762) and `...\Networking\XamlMessageType.cs` (~350–355)
  - The new contract.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\WpfTapItems.projitems`
  - Compile include for the new file.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Needs the xaml_hit_test row, TAP message 564, and the WPF file list.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md` (+ `references\xaml-authoring.md`, `references\enablement-and-troubleshooting.md`)
  - Tool table ~33; workflows ~57–145; Rules ~149+.
  - Needs: hit_test, wildcard guidance, and XAML authoring tips.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results; findings #1–62; Harness notes; Pending section at the end.
</important_files>

<next_steps>
1. Update copilot-tools.md:
   - xaml_hit_test row: Read, new TAP message, WPF only;
   - message 564 in the table;
   - WPF files list;
   - a find_elements note.
2. Update SKILL.md:
   - Add `xaml_hit_test` to the tool table.
   - In "can't click / invisible" workflows, use xaml_hit_test before setting properties. Mention that interact invoke bypasses hit testing.
   - Describe find_elements wildcards (`*Window`, `*Button`, `*`) and namedOnly.
   - Add XAML-authoring advice drawn from the demo failures to `references\xaml-authoring.md` or SKILL.md, for example:
     - verify binding paths against the view-model property names;
     - don't set disabled Opacity=0 (use about 0.4);
     - overlays need IsHitTestVisible=False or a null Background;
     - implicit styles don't cross template boundaries (DataTemplate TextBlock);
     - use BasedOn for derived styles;
     - avoid key shadowing of brushes;
     - DynamicResource for theme-switched resources;
     - ScrollViewer/StackPanel kills virtualization; set VirtualizingPanel.IsVirtualizingWhenGrouping;
     - UseLayoutRounding to avoid fractional pixels;
     - x:Uid/localizable text with no fixed widths (GermanReady);
     - DataTemplate DataType namespace matches;
     - AutomationProperties.Name for icon buttons.
   - Keep the examples generic.
3. Build Diagnostics.csproj, WpfCoreTap.csproj and WpfTap.csproj. Fix errors.
4. Redeploy. If the desktop is usable, run GhostClicks and/or VanishingSave (`paused2` with a temporary `pre-VanishingSave.ps1` that calls Debugger.Break; delete it afterwards) to validate xaml_hit_test and the paused fixes.
5. Log in TestPass.md:
   - new findings #63+ (hit_test tool, find_elements globs/namedOnly, interact note);
   - a "Proposed new test cases" section, e.g.:
     - a click-through overlay;
     - a disabled command (CanExecute);
     - an element clipped by a ScrollViewer;
     - derived Window/Button discovery;
     - paused debugger;
     - code-built bindings without source;
     - a DataTemplate selection mismatch;
     - a hot reload rude edit;
     - multi-window/multi-app;
     - remaining open tool ideas (#5, 14, 35, 40, 50, 56, 58, resize).
6. Wrap up:
   - Remind the user to re-enable UAC, that the redirect patch is temporary until PR 807376, and about the XAML language service assert.
   - Offer a single local commit (no push).
   - Ask about updating skills (writing-skills).
   - Call task_complete with a summary that answers all three questions.
</next_steps>