<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll;
- TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap;
- a built-in skill, SKILL.md.

Everything is tested autonomously in the fastmain Exp hive. A harness drives WPF demo apps through Copilot Chat, and each run is logged in the notes repo.

The current request is to implement the open ideas:
- hover simulation;
- tighter name-filter matching;
- a "why isn't this visible" check;
- a style audit;
- "currently failing" status on binding failures, only if feasible and genuinely helpful.

The user also asked to analyze all the chat logs in XamlAgentDemos-notes and act on the highest-impact improvements. Autopilot is on: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments:
   - planned and implemented the tools, skill and harness;
   - ran all 17 demos with many feedback fixes (findings #1–101);
   - consolidated the tools (list inputs, `xaml_get_status`);
   - brought UwpTap and MauiTap to parity (compile-checked only);
   - fixed the DesignerUndoService assert;
   - PrecedenceWars run-final5 passed 5/5.

   The user asked whether the XamlAgentDemos changes should be committed. Answer: no. They're leftover agent fixes from a run; reset with `git -C Q:\source\XamlAgentDemos checkout -- .`

2. Current request: implement the open ideas, then analyze the chat logs.
   - **Done:** tighter property nameFilter matching (`CreatePropertyNameMatcher`) and its unit test.
   - **Done:** hover/unhover in xaml_interact. HoverAsync and the cursor helpers are written, the descriptions are updated, and it builds clean.
   - **Done:** `xaml_explain_visibility` (ExplainVisibilityAsync plus its provider registration). It builds clean (0 warnings, 0 errors).
   - **Written, NOT yet built:** `xaml_audit_styles` (AuditStylesAsync plus its provider registration).
   - **Done:** the chatlog-analysis agent finished. Its report is summarized in technical_details.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`, on top of about 23 earlier uncommitted files.

**XamlAgentService.cs** (`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`)
- `CreatePropertyNameMatcher` (about line 898). Used in GetElementPropertiesAsync and GetItemPropertiesAsync.
- InteractAsync (about lines 1968–2062):
  - a hover branch: `isHover`, ThrowIfDebuggerPaused, then HoverAsync;
  - after a hover it runs HitTestAsync to fill `cursorTarget`;
  - hover-specific checksNote and note;
  - the action list now includes hover/unhover.
- `HoverAsync` (about line 2066):
  - gets the bounds through GetElementBoundsRequest;
  - for unhover, calls MoveCursorAway;
  - checks for a minimized window, zero size or invisible element;
  - accepts an optional `value` "x,y" in DIPs multiplied by DpiScale;
  - checks the point is inside the element and the client rect;
  - calls MoveCursorOverWindow and reports any CoveringWindow as an error.
- Visibility section, about lines 2324–2650:
  - `VisibilityCause` class plus the helpers `GetEffective(holder, name)`, `TryParseDouble` and `Label(ILiveNodeWithChildren)`.
  - `ExplainVisibilityAsync(elementId, ct)`: walks the element and up to 30 ancestors and checks:
    - Visibility (and IsVisible on MAUI) and Opacity < 0.05, both rank 1;
    - zero ActualWidth/ActualHeight, rank 2. This is skipped when a rank-1 cause exists. It looks for an explicit Width/Height/Max*/\*Request ≤ 0, a parent Grid row/column with ActualWidth/ActualHeight 0 (through ResolveObjectPathAsync `ColumnDefinitions[n]`), or a missing definition;
    - empty Text, rank 3;
    - Foreground transparent, or equal to the nearest ancestor's Background, rank 2;
    - HitTestAsync for clipping or covered elements, when no other causes were found;
    - matching binding failures, by TargetName or by same file with line within 0..15 and a Target type prefix.
  - Output: verdict, ranked causes (with elementId, property, value, valueSource, location, fix), checkedOk, hitTest, bindingFailures and a note.
- Style-audit section, about lines 2651–2935:
  - `DefaultAuditProperties` and `DefaultMauiAuditProperties`.
  - `internal static FindMajority(IEnumerable<string>)` and `internal static ParseExpectedValues(string)` (split on '|' only; throws InvalidArgument). These are unit-testable.
  - `DescribeAuditSource`.
  - `AuditStylesAsync(app, rootElementId, type, properties, expected, maxElements, ct)`:
    - walks the tree and matches type with MatchesType;
    - caps at 300 elements, default 100;
    - per element: RequestPropertiesAsync, then the style label (explicit Style source, else ImplicitStyleReference, else "no app style"), with the key from GetStyleKeyAsync (cached);
    - takes the winning values per property;
    - outputs styles groups, per-property value groups, outliers (versus expected, or versus the majority when ≥3 elements and majority > 50%), localValuesInXaml (hard-coded, up to 50), findings and failed.

**XamlAgentImaging.cs**
- CursorMoveResult, MoveCursorOverWindow, MoveCursorAway and the related P/Invokes (from the previous segment).

**XamlDiagnosticsFunctionProvider.cs**
- Updated the xaml_interact description and its action/value parameter descriptions for hover.
- New `xaml_explain_visibility` (elementIds batch through RunBatchAsync) after xaml_hit_test.
- New `xaml_audit_styles`: type, rootElementId, app, properties, expected, maxElements; RunAsync.
- Description constants are at lines 36–39: ProgressDescription, AppDescription, ElementIdDescription, ElementIdsDescription.
- The nameFilter description was updated earlier.

**XamlAgentToolsTests.cs**
- Added `PropertyNameMatcher_PrefersExactNamesThenFallsBackToSubstring`. That makes 15 tests; they haven't been run yet.

**SQL todos:**
- hover-sim: code done.
- name-filter: done.
- why-not-visible: code done.
- style-audit: written, not built.
- binding-current: pending.
- retest: pending.
</work_done>

<technical_details>
**Chat-log analysis**
- Data: 46 runs, 2,564 tool calls, 1,572 of them `xaml_*`. Ranked recommendations:
  1. **Results over 20 KB are spilled by Copilot Chat to a temp file and never read** (18 times). Fix:
     - set the LimitSize budget to about 16 KB (it's currently MaxResultLength=100_000, about line 790);
     - with includeAll, drop Default-source values unless `includeDefaults` is set;
     - drop `propertyType` when it equals `valueType`; drop `declaringType`;
     - omit `valueSourceLocation` when it equals the element's source;
     - map enum numeric values to names (#50; e.g., Visibility "0").
  2. Address elements by name (`#Name` or a plain name) wherever elementId is accepted, resolved in FindElement. On ELEMENT_GONE, re-resolve by name + type + source. Have apply_hot_reload return an old→new ID map. (67 of 140 finds were exact-name lookups.)
  3. View-model inspection: `nameFilter="DataContext.IsBusy"` drill-down, reusing the item-path logic (ResolveObjectPathAsync; its regex already allows segments without an index, but GetElementPropertiesAsync only routes to item paths when nameFilter contains '['). Also commandState/canExecute. PrecedenceWars used about 82 debugger calls.
  4. Multi-step `xaml_interact` (steps[], captureAfter); captures taken in the same batch showed the earlier state.
  5. Binding retest sweep (clearFirst, visit).
  6. Apply-and-verify for hot reload; flag added event handlers.
  7. Restart guidance in SKILL.md and the apply summary.
  8. Area/grid hit test with a compact pass/fail table; reject points outside the element.
  9. WCAG contrast check plus "accessible name doesn't match the visible label".
  10. Triggers (#35), template selection (#56), markup vs code Local (#40).
  11. Capture popups; `xaml_select_element` and `xaml_get_accessibility_results` were never used; SKILL note that find_resource already lists shadowed definitions.
- Its scratch scripts are in the session files folder.

**Binding "currently failing" plan** (not done)
- Per failure:
  - `likelyFixedInSource`: read DocumentName from disk and regex BindingPath with word boundaries within ±5 lines of SourceInfo.LineNumber;
  - live target lookup: same file, same type, closest element line ≤ the failure line, matching name; report the current evaluated value of the property parsed from Target ("Border.Visibility, Name='X'");
  - `newSinceLastRead`: count delta from a per-service snapshot dictionary.
- GetBindingFailuresAsync is at about line 2780 now (it moved after the insertions).

**Hover**
- Moves the user's real mouse and may raise or activate the app window.
- Check whether the KeepAwake script jiggles the mouse; that would interfere with hover tests.

**Build** (from `Q:\src\VS_xaml`):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
Then grep `.vs\diag.txt` for "error CS|warning CS|Warning\(s\)|Error\(s\)". The unit test project is `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`.

**Tests**
```
out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
```
Tests use the `[Test]` attribute and FluentAssertions.

**Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`)
- `& "$h\Redeploy.ps1"` patches the System.Drawing redirect to 10.0.0.0 and relaunches the Exp instance.
- Wait 60–75 s, then check that the DLL hash matches `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\Microsoft.VisualStudio.DesignTools.Diagnostics.dll`.
- `& "$h\Run-Demo.ps1" -Name X -Tag T` takes about 6 minutes.
- Start the KeepAwake script before testing.

**Reading events.jsonl**
- `tool.execution_start`: data.toolName and data.arguments.
- `tool.execution_complete`: data.result.content.
- The task_complete summary holds the feedback answers.

**Conventions and quirks**
- TestPass.md: write with `[IO.File]::WriteAllLines`. The findings table runs up to #101; #99/#100 are open (binding status, hover/filter). Add #102 onward.
- The edit tool fuzzy-matches, so always verify the result.
- Git: never push, rebase or amend; offer a single local commit only.
- Skill examples must use generic names, not demo names.
- Remind the user to re-enable UAC. PR 807376 fixes the redirect properly.
- Internal helpers:
  - `XamlAgentService.RequestPropertiesAsync` must be followed by `MainThreadFactory.SwitchToMainThreadAsync`;
  - `GetWinningValues`, `GetPropertySource`, `StyleSourceKinds`, `GetStyleKeyAsync`, `SourceResolver(host, endpoint).Resolve/ResolvePath`;
  - `FindElement(host, id)` returns `(Endpoint, IElement)`; `GetEndpoints(host)` requires the UI thread;
  - `MatchesType`, `ValidatePattern`, `SplitAlternatives` (splits on '|' and ',');
  - `RunBatchAsync(items, name, describe, func)`.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all tools.
  - Locations: InteractAsync about 1968, HoverAsync about 2066, HitTestAsync about 2177, Visibility section about 2324–2650, Audit section about 2651–2935, Resources after that, GetBindingFailuresAsync about 2780+, LimitSize about 790, GetElementPropertiesAsync about 1017.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions: hit_test about 243, explain_visibility about 259, audit_styles about 271, interact about 287.
- `...\AgentTools\XamlAgentImaging.cs`: cursor helpers (lines 47–162).
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md` and `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
  - Must document: hover, filter matching, explain_visibility, audit_styles, binding status, restart guidance, the find_resource shadowing note, and the 16 KB output budget.
- `src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`
  - Matcher test added. Still to add: FindMajority and ParseExpectedValues tests, and the binding source-check helper test.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: test results and findings log.
</important_files>

<next_steps>
1. Build to verify that AuditStylesAsync and its registration compile, and fix any errors (for example tuple deconstruction in `rows`, or `Label(element)`).
2. Add unit tests for FindMajority and ParseExpectedValues, then run the unit tests.
3. Implement high-impact items from the analysis:
   a. Output budget of about 16 KB in LimitSize; compact the property schema (drop Default values unless includeDefaults, the redundant type fields, and duplicate locations); show enum names.
   b. Name-based element addressing in FindElement (`#Name` or unique name), plus stale-ID re-resolution.
   c. DataContext drill-down via nameFilter "DataContext.X" (route to the item-path logic), if feasible.
   d. Optionally, a contrast check in explain_visibility or the a11y tool.
4. Binding failure status fields: likelyFixedInSource, live target plus current value, newSinceLastRead. Keep them only if reliable.
5. Update SKILL.md, copilot-tools.md and the tool descriptions, including restart guidance and the find_resource note.
6. Build with 0 warnings, run the unit tests, redeploy and verify the hash.
7. Retest:
   - PrecedenceWars (hover);
   - VanishingSave (visibility);
   - StyleMaze (audit);
   - BindingStorm (binding status).

   Log rows and findings #102+ in TestPass.md, then reset the demo repo.
8. Stop the KeepAwake shell, then call task_complete with a summary. Note that hover moves the real mouse and may raise the app window, and remind the user about UAC.
</next_steps>