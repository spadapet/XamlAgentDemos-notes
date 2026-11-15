<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` tools in Diagnostics.dll.
- TAP messages for WPF, UwpTap (WinUI/UWP) and MauiTap.
- A built-in skill (SKILL.md).

Everything is tested autonomously in the fastmain Exp hive: a harness drives WPF demo apps through Copilot Chat, and every run is logged in the notes repo.

The current request has two parts:
- Implement the open ideas: hover simulation, tighter name-filter matching, a "why isn't this visible" check, a style audit, and "currently failing" status for binding failures (only if feasible and helpful).
- Analyze all chat logs in XamlAgentDemos-notes and act on the highest-impact improvements.

Autopilot is on: decide without asking, verify, then call task_complete.
</overview>

<history>
1. Earlier segments:
   - Planned and implemented the tools, the skill and the harness.
   - Ran all 17 demos and fixed issues from their feedback (findings #1–101).
   - Consolidated the tools: list inputs, and `xaml_get_status`.
   - Brought UwpTap and MauiTap to parity (compile-checked only).
   - Fixed the DesignerUndoService assert.
   - The user asked whether the XamlAgentDemos changes should be committed. Answer: no, they're leftover agent fixes; reset with `git -C Q:\source\XamlAgentDemos checkout -- .`
2. Current request (open ideas plus chat-log analysis):
   - Previous segment:
     - Implemented the property nameFilter matcher, hover/unhover in xaml_interact, `xaml_explain_visibility` and `xaml_audit_styles`.
     - A sub-agent analyzed 46 runs (2,564 tool calls) and ranked the improvements (see technical_details).
   - This segment:
     - Built Diagnostics: 0 warnings, 0 errors (the audit compiles).
     - Implemented these chat-log analysis items:
       - #1: output budget plus compaction.
       - #2: name addressing plus stale-ID re-resolution.
       - #3: DataContext drill-down.
     - Implemented binding failure status fields.
     - Added unit tests: unit tests passed 17/17 before the binding-status test was added, and haven't been rerun since.
     - Updated tool descriptions and most of SKILL.md.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`, on top of about 23 earlier uncommitted files.

**XamlAgentService.cs** (`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`):

Element addressing:
- New field `knownNames` (ConcurrentDictionary from ID to (Name, Type)) near line 55.
- `FindElement` (about line 213) accepts `#Name`, `a1:#Name`, or a bare identifier (`IsXamlName`).
  - It routes these to the new `FindElementByName(host, appKey, name, typeFullName, elementId)`, which walks the trees and requires a unique match. It errors with candidate IDs when there are several matches.
  - On a stale numeric ID, it re-resolves through `knownNames` before throwing ELEMENT_GONE.
- `GetElementId` now records named elements in `knownNames`.
- Added `internal static IsXamlName`.

Output budget (LimitSize / TryTrimBatch):
- `MaxResultLength` is now 16_000 (was 100_000), about line 872.
- LimitSize's preview is now `Math.Min(len, 8000)`.
- TryTrimBatch:
  - A `results` batch is still trimmed with an `omitted` list, as before.
  - Otherwise it trims the tail of the largest top-level array and adds `omittedFromList`, `omittedCount` and `omittedNote`.
  - Removal now uses size estimation instead of re-serializing after each removal (which was O(n²)).

GetElementPropertiesAsync (about line 1132):
- Routes to item paths when nameFilter contains '[' or any alternative starts with `DataContext.` or `BindingContext.`.
- Default-source values (not binding, not overridden) are collected into a `defaultValues` name→value SortedDictionary.
- Removed `declaringType`. `propertyType` is emitted only when it differs from `valueType`.
- `valueSourceLocation` is set to null when the source is Local and the location equals the element's source (compared as JSON).
- `elementSource` is computed once.

Item paths and DataContext:
- `SplitItemPath` handles `DataContext.X.Y`, returning ("DataContext.X", "Y").
- New `internal static IsDataContextPath`.
- GetItemPropertiesAsync keeps all members for DataContext paths.
- ResolveObjectPathAsync gives a clear error when the object on the path is null ("DataContext isn't set here").

GetBindingFailuresAsync (about line 3255):
- Each failure now has `occurrencesSinceLastRead`, `isNew` and `pathStillInSource`. The note was updated.
- New fields: `bindingFailureCounts` (ConcurrentDictionary) and `bindingFailuresRead` (bool).
- `ReadLinesCached` reads each file once per call.
- `internal static bool? BindingPathStillInSource(lines, line, path)`: a regex with `(?<![\w.])path(?![\w])`, searched within ±5 lines.
- ClearBindingFailuresAsync also clears `bindingFailureCounts`.

**XamlDiagnosticsFunctionProvider.cs**:
- ElementIdDescription and ElementIdsDescription mention `#Name` and the hot-reload survival.
- The nameFilter description mentions `DataContext.` and `BindingContext.`.
- The binding failures description explains the new fields.

**XamlAgentToolsTests.cs**:
- Updated the LimitSize preview expectation to 8000.
- Added DataContext cases to the SplitItemPath test.
- New tests: `BindingPathStillInSource_SearchesNearbyLines`, `IsXamlName_AcceptsIdentifiersOnly`, and `StyleAudit_FindsMajorityAndParsesExpectedValues`.
- The earlier `PropertyNameMatcher_PrefersExactNamesThenFallsBackToSubstring` test is still there.

**SKILL.md** (`AgentTools\skills\xaml-diagnostics\SKILL.md`):
- Tool table: added rows for xaml_explain_visibility and xaml_audit_styles, and added hover to xaml_interact.
- Element-ID section covers `#Name`, the 16 KB / omittedNote behavior, and the DataContext drill-down.
- Binding workflow step 5 explains occurrencesSinceLastRead and pathStillInSource.
- The can't-see workflow calls explain_visibility first.

Status:
- [x] Hover, name filter, explain_visibility and audit_styles: code done; Diagnostics builds clean.
- [x] Binding status fields (not yet compiled after the last edits).
- [ ] Rebuild Diagnostics and Unit, then run the tests.
- [ ] SKILL.md still needs:
  - an audit_styles workflow (style consistency) and a hover note;
  - restart guidance;
  - a note that find_resource lists shadowed definitions.
- [ ] Update copilot-tools.md.
- [ ] Redeploy and retest the demos.
- [ ] Log findings #102+ in TestPass.md.
</work_done>

<technical_details>
**Chat-log analysis**, ranked:
1. Results over 20 KB are spilled to a temp file and never read. Done: 16 KB budget plus compaction.
2. Name addressing and stale-ID re-resolution. Done. Not done: an old→new ID map from apply_hot_reload.
3. DataContext drill-down. Done. Not done: commandState/CanExecute.
4. Multi-step xaml_interact (steps[], captureAfter): not done.
5. Binding retest sweep: partially covered by the status fields.
6. Apply-and-verify for hot reload; flag added event handlers.
7. Restart guidance in SKILL.md.
8. Area/grid hit test.
9. WCAG contrast check, and accessible name vs visible label.
10. Triggers, template selection, and markup vs code Local values.
11. Popup capture. xaml_select_element and xaml_get_accessibility_results were never used.

Optional items (multi-step interact, contrast) can be skipped if time is short; mention them as future work.

**Hover:**
- Moves the user's real mouse and may raise the app window.
- KeepAwake mouse jiggling could interfere with hover tests.

**Build** (from `Q:\src\VS_xaml`):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
- Then grep the output for `error CS|warning CS|Warning\(s\)|Error\(s\)`.
- Unit test project: `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`. Same command, output to `.vs\unit.txt`.

**Run the unit tests:**
```
out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
```

**Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
- `& "$h\Redeploy.ps1"` patches the System.Drawing redirect to 10.0.0.0 and relaunches the Exp instance (`devenv /rootsuffix exp`).
- Wait 60–75 s, then verify the DLL hash at `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\Microsoft.VisualStudio.DesignTools.Diagnostics.dll`.
- `& "$h\Run-Demo.ps1" -Name X -Tag T` takes about 6 minutes.
- Start the KeepAwake script first.
- In events.jsonl:
  - `tool.execution_start` has data.toolName and data.arguments.
  - `tool.execution_complete` has data.result.content.

**Quirks:**
- The edit tool fuzzy-matches and silently dropped lines several times. Always check the result.
- TestPass.md must be written with `[IO.File]::WriteAllLines`.
- Git: never push, rebase or amend; offer a single local commit only.
- Skill examples must use generic names.
- Remind the user to re-enable UAC. PR 807376 fixes the redirect.

**Internal helpers:**
- `RequestPropertiesAsync` must be followed by `MainThreadFactory.SwitchToMainThreadAsync`.
- Also available: `GetPropertySource`, `SourceResolver(host, endpoint).Resolve`, `GetEndpoints(host)` (UI thread only), `RunBatchAsync`, `SplitAlternatives` (splits on '|' and ',').

**Assumptions not yet verified live:**
- The TAP exposes the DataContext VM object as IsHandle, with CLR members in the PropertyChain.
- Binding SourceInfo.LineNumber is 1-based.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all the tools.
  - Approximate line numbers: FindElement 213, LimitSize 876, TryTrimBatch 898, GetElementPropertiesAsync 1132, SplitItemPath 1355, ResolveObjectPathAsync 1385, InteractAsync/HoverAsync about 2050+, visibility/audit sections about 2400–3000, FindMajority 2815, GetBindingFailuresAsync 3255, BindingPathStillInSource about 3349.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions.
  - Description constants at lines 36–39; get_element_properties about 104; binding failures about 324.
- `...\AgentTools\XamlAgentImaging.cs`: cursor helpers for hover.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill (partially updated, see work_done).
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`: needs the new tools and features documented.
- `src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: unit tests (new ones added).
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: test results and findings log (add #102+).
</important_files>

<next_steps>
1. Rebuild Diagnostics.csproj and Unit.csproj (0 warnings expected), then run the XamlAgentToolsTests (should be 18).
2. Finish SKILL.md:
   - a "Controls of one type look inconsistent" workflow using xaml_audit_styles;
   - a hover note in the interact or reproduce workflow (it moves the real mouse; use `unhover`);
   - restart guidance (when hot reload can't apply: stop and F5);
   - a note that find_resource already lists shadowed definitions.
3. Update copilot-tools.md with:
   - hover, explain_visibility, audit_styles;
   - #Name addressing, the DataContext drill-down, binding status fields;
   - the 16 KB budget and compaction (defaultValues, omittedFromList).
4. Optional, if time allows: multi-step xaml_interact (steps[] / captureAfter), and a contrast check.
5. Redeploy with Redeploy.ps1, verify the hash, and start KeepAwake.
6. Retest:
   - PrecedenceWars (hover, #Name);
   - VanishingSave (explain_visibility);
   - StyleMaze (audit_styles);
   - BindingStorm (binding status, DataContext).
7. Log the rows and findings #102+ in TestPass.md, then reset the demo repo.
8. Stop the KeepAwake shell, then call task_complete. The summary should:
   - list the implemented features and the chat-log-driven improvements;
   - note that hover moves the real mouse;
   - remind the user about UAC;
   - offer a single local commit.
</next_steps>