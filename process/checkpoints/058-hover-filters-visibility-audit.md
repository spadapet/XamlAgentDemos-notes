<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll;
- TAP messages for WPF, WinUI/UWP and MAUI;
- a built-in skill, SKILL.md.

The tools are tested autonomously in the fastmain Exp hive. A harness drives WPF demo apps through Copilot Chat, and every run is logged in a notes repo.

The current request is to implement the open ideas:
- hover simulation;
- tighter name-filter matching;
- a "why isn't this visible" check;
- a style audit;
- "currently failing" marks on binding failures, but only if feasible and genuinely helpful.

The user also asked to analyze all the chat logs in XamlAgentDemos-notes for the highest-impact improvements. Autopilot mode is on: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments:
   - planned and implemented the tools, the skill and the test harness;
   - ran all 17 demos and made many feedback fixes (#1–101);
   - consolidated the tools: list inputs, `xaml_get_status`;
   - gave UwpTap and MauiTap the same TAP messages (compile-checked only);
   - fixed the DesignerUndoService assert.

   The last segment:
   - finished PrecedenceWars run-final5 (5/5). The IsEnabled ancestor note was verified naming `StackPanel 'ToolbarPanel'`;
   - simplified the bound-ancestor wording;
   - rebuilt (0 warnings, 0 errors), ran 14/14 unit tests and redeployed (hash match);
   - added a run-final5 row to TestPass.md and marked #98 "Verified in run-final5";
   - stopped keepawake2;
   - called task_complete.

2. The user asked whether the changes in `Q:\source\XamlAgentDemos` should be committed.
   - Answer: no. They're the run-final5 agent fixes left uncommitted. They match `run-final5\fix.diff`, and the harness resets the repo before each run.
   - Clean-up command: `git -C Q:\source\XamlAgentDemos checkout -- .`
   - task_complete was called.

3. The user asked to implement the open ideas (current work).
   - Pulled the earlier feedback:
     - VanishingSave wanted a `why_not_visible` that combines binding state, visibility/opacity, size and grid allocation, clipping and overlapping siblings, with ranked causes and source locations;
     - StyleMaze wanted a brand/style audit that groups elements by effective style and key properties and flags deviations by cause;
     - BindingStorm wanted historical vs currently-failing entries, plus the target's current value;
     - PrecedenceWars wanted hover simulation, and said property filters return unrelated fields.
   - Implemented tighter property nameFilter matching (done).
   - Started hover simulation (partially done).
   - The user then added: analyze all the chat logs. A background general-purpose agent `chatlog-analysis` (id `ef238cd9-00ad-482f-8704-296968dd56fb`) was launched. It produces a ranked improvement report (quantitative per-tool stats, multi-call patterns, fallbacks to non-xaml tools, misleading outputs, grouped feedback, top-10 recommendations) and is read-only. Wait for its notification, then read it with read_agent.
</history>

<work_done>
Edits this segment (all uncommitted in `Q:\src\VS_xaml`, on top of about 23 earlier uncommitted files):

**XamlAgentService.cs**
- New `internal static Func<string,bool> CreatePropertyNameMatcher(string[] filters, IEnumerable<string> propertyNames)`, after SplitAlternatives (about line 898). How each alternative matches:
  - a wildcard (`*`/`?`) is a glob;
  - otherwise an exact match (case-insensitive, or on the part after the last '.', e.g. Grid.Row) if any property has that name;
  - otherwise a substring.
- It's used in GetElementPropertiesAsync (about line 1003) and GetItemPropertiesAsync (about line 1311). The no-match hint text was updated (about line 1066).
- InteractAsync (about line 1989):
  - new `isHover` branch for actions "hover"/"unhover". It calls ThrowIfDebuggerPaused, then **`this.HoverAsync(endpoint, element, action, value, cancellationToken)`, which is NOT YET WRITTEN**;
  - the error hint for hover uses `response?.Result`;
  - the check delay is 600 ms for hover, 300 ms otherwise.

**XamlAgentImaging.cs**
- New `CursorMoveResult` class (Moved, RaisedWindow, ActivatedWindow, CoveringWindow).
- New `MoveCursorOverWindow(IntPtr appWindow, int x, int y)`:
  - uses PMv2 DPI context;
  - checks that WindowFromPoint's root belongs to the app process; otherwise SetWindowPos HWND_TOP NOACTIVATE, then SetForegroundWindow;
  - saves the original cursor position;
  - moves the cursor to x+1,y+1, then x,y.
- New `MoveCursorAway(Rect avoid)`: restores the saved cursor position, or moves to avoid.Left-20, avoid.Top-20.
- New NativeMethods: WindowFromPoint, GetAncestor (GA_ROOT=2), SetWindowPos plus SWP flags, SetForegroundWindow, SetCursorPos, GetCursorPos, SetThreadDpiAwarenessContext, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2=-4.

**XamlDiagnosticsFunctionProvider.cs**
- The `xaml_get_element_properties` nameFilter description now explains exact-first matching and wildcards.

**Todos (SQL)**
- pending: hover-sim (in progress), name-filter (code done, needs unit test), why-not-visible, style-audit, binding-current, retest.

**Not built since these edits.**
</work_done>

<technical_details>
- **Hover design:**
  - It moves the real cursor from the VS side, using the physical screen coordinates of the element bounds (ElementBoundsRequest → ElementBoundsInfo: ScreenX/Y/Width/Height, RootWindowHandle, DpiScale, IsVisible, Found, Error).
  - It's platform-agnostic, so it works for WPF, WinUI/UWP and MAUI (MAUI bounds are approximate).
  - HoverAsync plan:
    1. run on a background thread (`await TaskScheduler.Default` or Task.Run);
    2. get the bounds;
    3. error if not found, zero size, or minimized (ScreenX <= -30000);
    4. the point is the center, or `value` "x,y" in DIPs from the element's top-left × DpiScale;
    5. call MoveCursorOverWindow;
    6. if CoveringWindow is set, return a response with Error;
    7. return an `ElementAutomationActionResponse { Result = "..." }` describing what happened (raised/activated window). Optionally hit-test afterwards to confirm the input target.
  - "unhover" calls MoveCursorAway with the element's screen rect.
  - Tell the agent to read IsMouseOver/Background via checkProperties.
  - Update the xaml_interact description and action list (`hover`, `unhover`), and note that hover moves the user's real mouse and may bring the app window to the front.
- **Why-not-visible plan:**
  - A new tool, probably `xaml_explain_visibility`, taking elementIds and composed VS-side:
    - HitTestAsync (blockers, opacity, clipping, zero size, overlay);
    - properties of the element and its ancestors (Visibility, Opacity, Width/Height/ActualWidth/ActualHeight, MaxWidth, Margin, RenderTransform);
    - Grid allocation: the parent's Row/ColumnDefinitions via item paths `ColumnDefinitions[n].Width|ActualWidth`;
    - bounds versus the window;
    - binding failures on the element (match TargetName or the source file/line);
    - Foreground equal to Background.
  - Output: ranked causes with source locations.
  - MAUI uses IsVisible and WidthRequest.
  - HitTestAsync is at about line 2040 and returns an anonymous object (summary, blockers, visibleFraction, clippedBy...).
- **Style-audit plan:**
  - A new tool, `xaml_audit_styles`. Inputs: app, optional rootElementId, type filter (e.g. "*Button"), properties (e.g. Background|Foreground|FontFamily|Style), optional expected "Prop=Value".
  - It walks the elements (find logic), requests properties for each (cap about 200), and groups them by effective value plus value source plus style name/location.
  - It flags outliers and local overrides (Local source with file/line), elements using only the theme default style, and different implicit styles.
- **Binding "currently failing" plan:**
  - IBindingFailure has no element handle, only these fields: Target ("Border.Visibility, Name='HighPriorityBanner'"), TargetName, BindingPath, DocumentName (full path), SourceInfo line/column (the binding attribute's location), Count, OriginalError.
  - Feasible additions per failure:
    - `sourceStillHasBinding` / "likelyFixedInSource": read the file from disk and regex-check `BindingPath` with word boundaries near the line (±5 lines);
    - live target lookup: an element in the same file with the same type, source line ≤ failure line (closest) and the same name; if none, "noLiveTarget (view closed/not realized; may be historical)"; if found, the current evaluatedValue of the target property (parsed from Target between '.' and ',');
    - `newSinceLastRead`: count delta from a per-service snapshot dictionary.
  - GetBindingFailuresAsync is at about line 2350.
- **TAP model:**
  - TapPropertyValue: PropertyName, Value (binding text for bound values), EvaluatedValue, Overridden, IsValueBindingExpression, SourceInfo, Type, DeclaringType.
  - TapPropertySource: Handle, TargetType, Name, Source (BaseValueSource), SourceInfo.
  - Tree elements: IElement (TypeFullName, Name, SourceInfo, Children, Handle, IsInTree); FindElements walks `host.TreeContainer.GetElementTree(endpoint).RootNode`.
- **Build** (from `Q:\src\VS_xaml`; set `[Environment]::CurrentDirectory` too):
  ```
  . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
  ```
  The unit test project is `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`.
- **Unit tests:**
  ```
  out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
  ```
  Tests use the `[Test]` attribute; there are currently 14.
- **Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
  - Redeploy: `& "$h\Redeploy.ps1"`. It patches the System.Drawing redirect to 10.0.0.0 and relaunches the Exp instance; wait about 60–75 s, then check that the DLL hash matches `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\Microsoft.VisualStudio.DesignTools.Diagnostics.dll`.
  - Run a demo: `& "$h\Run-Demo.ps1" -Name X -Tag T` (about 6 min).
  - Before testing, start a KeepAwake script; check the harness folder for it. Note that a mouse-jiggling keep-awake would interfere with hover tests, so verify what it does.
- **Reading events.jsonl:**
  - `tool.execution_start` gives data.toolName, data.toolCallId and data.arguments;
  - `tool.execution_complete` gives data.result.content (a JSON string);
  - the task_complete arguments' summary holds the final answer and the feedback answers.
- TestPass.md: write with `[IO.File]::WriteAllLines`. The findings table is numbered up to #101, with #99/#100 open for binding status and hover/filter.
- The edit tool fuzzy-matches, so verify each result.
- Git: never push, rebase or amend; offer a single local commit only. Skill examples must use generic names, not demo names.
- PR 807376 fixes the redirect properly. Remind the user to re-enable UAC.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all tools.
  - New CreatePropertyNameMatcher (about line 898) and the hover branch in InteractAsync (about line 1989).
  - HoverAsync must be added near ReadCheckPropertiesAsync (about line 2040).
  - Other locations: GetElementBoundsAsync about line 1860, HitTestAsync about line 2040, GetBindingFailuresAsync about line 2350.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentImaging.cs`
  - Cursor helpers (lines 63–162) and new P/Invokes (about lines 424–453).
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions: xaml_interact at about line 259 (update the action list and description for hover/unhover).
  - Add the new tools here, using the RunAsync/RunBatchAsync/RunConfirmedAsync patterns.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md` and `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Must document hover, filter matching, the new tools and the binding status fields.
- `src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`
  - Add tests for CreatePropertyNameMatcher and the binding source-check helper.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`
  - Results table and findings; add rows and findings #102 onward.
</important_files>

<next_steps>
1. Write `HoverAsync` in XamlAgentService (see the plan above). Update the xaml_interact description and action list, then build.
2. Add unit tests for CreatePropertyNameMatcher: "Background" excludes BackgroundSizing; "Row" matches Grid.Row; substring fallback; wildcard.
3. Implement the visibility tool (`xaml_explain_visibility`) as a VS-side composition.
4. Implement the style audit tool (`xaml_audit_styles`).
5. Implement the binding-failure status fields: likelyFixedInSource via the file check, live target plus current value, and newSinceLastRead. Keep them only if they're reliable.
6. Read the chatlog-analysis agent report when notified, and implement its top high-impact recommendations that aren't covered.
7. Update SKILL.md, copilot-tools.md, and the tool descriptions.
8. Build (0 warnings, 0 errors), run the unit tests, redeploy and verify the hash.
9. Re-test:
   - PrecedenceWars (hover);
   - VanishingSave (visibility);
   - StyleMaze (audit);
   - BindingStorm (binding status).

   Then log rows and findings in TestPass.md and reset the demo repo.
10. Stop any KeepAwake shell, then call task_complete with a summary. Mention the user-visible effect of hover: it moves the real mouse and may raise the app window.
</next_steps>