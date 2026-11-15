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
   - Brought UwpTap and MauiTap to parity.
   - Fixed the DesignerUndoService assert.
   - The XamlAgentDemos changes are leftover agent fixes and should be reset, not committed.
2. Current request, earlier segments:
   - Implemented:
     - the nameFilter matcher;
     - hover/unhover in xaml_interact;
     - `xaml_explain_visibility` and `xaml_audit_styles`;
     - name addressing (`#Name`) and stale-ID re-resolution;
     - the 16 KB output budget with compaction;
     - DataContext drill-down;
     - binding status fields (occurrencesSinceLastRead/isNew/pathStillInSource).
   - Added unit tests.
3. This segment:
   - Finished SKILL.md:
     - "Reproduce" step 5 now uses hover/unhover and says it moves the real mouse.
     - The style workflow mentions xaml_audit_styles with `type` and `expected`.
   - Updated copilot-tools.md:
     - new table rows for xaml_explain_visibility and xaml_audit_styles;
     - hover added to xaml_interact, and binding status fields;
     - a 16 KB budget paragraph, plus a #Name/DataContext paragraph.
   - Rebuilt Diagnostics and Unit (0 warnings, 0 errors). Unit tests passed 18/18.
   - Started KeepAwake (async shellId `keepawake`, still running). Reset the demo repo. Redeployed with Redeploy.ps1; the hash matched (05FB4EFE…).
   - Ran the r9 retests in async shellId `demos`: PrecedenceWars → VanishingSave → StyleMaze → BindingStorm.
     - The first three finished.
     - BindingStorm was running at the time of compaction.
   - **PrecedenceWars r9:**
     - Hover worked: the IsMouseOver trigger was detected, and #Name was used everywhere.
     - Issues:
       - `nameFilter="Text|DataContext.IsBusy"` was rejected with INVALID_ARGUMENT.
       - Check snapshots were full of null fields.
       - Bound properties showed `value="System.Windows.Data.BindingExpression"`.
   - **VanishingSave r9:**
     - It used explain_visibility. Problems found:
       - The WPF TAP reports `Visibility` as an enum number ("0"/"2"), so every ancestor with Visibility=0 was falsely flagged as a rank-1 cause.
       - Binding values showed as `" -> 2"`.
       - `checkedOk` listed "size 0x0".
       - A WPF child in a 0-width Grid column keeps its own ActualWidth, so the gridCell check (which only ran on zero size) missed the cause.
     - `ColumnDefinitions[*]...|RowDefinitions[*]` failed the whole call because RowDefinitions was null.
     - The model was confused by `applied=true` when the code hot reload had failed.
   - **StyleMaze r9:** audit_styles was used 3 times with no failures. The model's feedback wasn't captured, because the follow-up came back while the main turn was still finishing.
   - After those runs, made the code fixes listed in work_done. They have **not yet been rebuilt**.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`, on top of about 23 earlier uncommitted files.

**XamlAgentService.cs** — changes this segment, not yet compiled:

GetElementPropertiesAsync (about line 1136):
- A mixed filter is now supported. The leading plain names, before the first item or DataContext path, are read as the element's own properties with a recursive call.
- The remaining paths are read through GetItemPropertiesAsync.
- The two results are merged as JObjects using BatchSerializer, which ignores nulls.

Property DTO (about line 1221):
- `value` is null when evaluatedValue is set and the raw value ends with "Expression".

GetItemPropertiesAsync (about line 1515):
- When there's more than one group, InvalidArgument and PropertyNotFound from ResolveObjectPathAsync are caught per group.
- The failing group is added to items as `{path, error, message}` instead of failing the whole call.

ReadCheckPropertiesAsync (about line 2340):
- Serializes with BatchSerializer.
- Strips valueType, propertyType, valueSourceLocation, valueLocation, isCollection, isAttached and readOnly from the check entries.

New `internal static NormalizeVisibility(string value, SupportedPlatform platform)` (about line 2558):
- Maps the enum number to its name:
  - WpfFramework/WpfCore: 0 Visible, 1 Hidden, 2 Collapsed.
  - Others: 0 Visible, 1 Collapsed.
- Strips anything after a space.
- Applied to `visibility.Value` in ExplainVisibilityAsync. `visibility` is a tuple local; it's assigned through `visibility.Value =`, which needs to compile.

AddCause Value:
- A binding now shows `{Binding} -> X` when the raw value is empty or "...Expression".

Size and grid-cell restructure (about lines 2694–2767):
- `noRank1` and `reasons` are hoisted.
- The explicit-size loop runs only when the size is zero.
- The Grid-cell check now runs whenever `reasons.Count == 0 && noRank1` and the parent is a Grid. The zero-only skip was removed. A redundant extra `{ }` block and the odd formatting `{                        var index` are left over and could be tidied.
- The generic zero-size cause is added only when the size is zero, there's no rank-1 cause and no reasons.
- `checkedOk` gets the size only when it isn't zero and there are no reasons.

ApplyHotReload result (about lines 3664 and 3688):
- The summary is prefixed with "Code changes did NOT apply…" when codeStatus is "failed".
- `applied` is false when codeStatus is "failed".
- New `xamlApplied` field when includeCodeChanges is set.

**Earlier this segment, built and tested:**
- SKILL.md edits.
- copilot-tools.md edits.

**Status:**
- [x] Hover, explain_visibility, audit_styles, name filter, #Name, budget, DataContext, binding status
- [x] SKILL.md hover and audit notes; copilot-tools.md
- [ ] Rebuild Diagnostics after the latest fixes; consider adding unit tests for NormalizeVisibility and mixed-filter grouping; rerun the unit tests
- [ ] Document in copilot-tools.md/SKILL.md:
  - the mixed nameFilter (`Text|DataContext.X`);
  - `xamlApplied`;
  - the per-group item errors.
- [ ] SKILL.md restart guidance, and a note that find_resource lists shadowed definitions (optional)
- [ ] Read the BindingStorm r9 result, redeploy, and re-run VanishingSave (and possibly PrecedenceWars) to verify the fixes
- [ ] Log findings #102+ in TestPass.md, reset the demo repo, stop KeepAwake, and call task_complete
</work_done>

<technical_details>
**Build** (from `Q:\src\VS_xaml`):
```
cd Q:\src\VS_xaml; [Environment]::CurrentDirectory='Q:\src\VS_xaml'; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoRestore -NoProjectReferences *> .vs\diag.txt
```
- Then grep the output for `error CS|warning CS|Warning\(s\)|Error\(s\)`.
- Unit project: `src\Xaml\Diagnostics\Test\Unit\Unit.csproj`, with output to `.vs\unit.txt`.

**Run the unit tests:**
```
out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe -class "*XamlAgentToolsTests"
```
Currently 18 tests.

**Harness** (`$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`):
- `& "$h\Redeploy.ps1"` patches the System.Drawing redirect to 10.0.0.0 and relaunches the Exp instance.
- Wait 75 s, then compare the hash of `C:\vs\fastmain\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics\Microsoft.VisualStudio.DesignTools.Diagnostics.dll` with the newest file under `out\binaries\x86chk`.
- `& "$h\Run-Demo.ps1" -Name X -Tag T`:
  - takes 4–7 minutes;
  - writes its output to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>\` (events.jsonl, runner.log).
- Reset the demo repo with `git -C Q:\source\XamlAgentDemos checkout -- . ; git -C Q:\source\XamlAgentDemos clean -fdq`.
- The 17 demo names are in prompts.json.
- In events.jsonl:
  - `tool.execution_start` has data.toolName, data.arguments and data.toolCallId.
  - `tool.execution_complete` has data.result.content, data.success and data.error.message.

**Quirks:**
- **WPF TAP Visibility:** it reports Visibility as the enum number, even for non-binding values. That's why NormalizeVisibility exists.
- **SupportedPlatform enum:** the members are Invalid, WindowsUIXaml, WpfFramework, WpfCore, Unused, WinUI, Maui and DotNetWeb. There's no `Uwp` member; UWP is WindowsUIXaml.
- **Edit tool:** it fuzzy-matches and often reports "closest matching lines". Always check the result.
- **TestPass.md:** must be written with `[IO.File]::WriteAllLines`.
- **Git:** never push, rebase or amend; offer a single local commit only.
- **Skill examples:** must use generic names.
- **Reminders for the user:** re-enable UAC; PR 807376 fixes the System.Drawing redirect.

**Hover:** moves the real mouse and may raise the app window.

**Chat-log analysis items not done** (mention as future work):
- an old→new ID map after hot reload;
- multi-step xaml_interact (steps[], captureAfter);
- a WCAG contrast check;
- commandState/CanExecute;
- popup capture.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Implementation of all the tools. Approximate line numbers:
    - GetElementPropertiesAsync: 1132
    - GroupItemFilters: about 1330
    - ResolveObjectPathAsync: about 1400
    - GetItemPropertiesAsync: 1513
    - InteractAsync checks: about 2190
    - ReadCheckPropertiesAsync: about 2340
    - NormalizeVisibility: about 2558
    - ExplainVisibilityAsync: about 2585
    - size/grid-cell section: 2694–2767
    - apply hot reload result: about 3640–3700
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - Tool definitions and descriptions.
  - JsonSettings (ignores nulls) at line 42.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. Hover and audit notes were added this segment.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`: tools documentation. Updated this segment.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: unit tests (18).
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: test log. r9 rows and findings #102+ still need to be added.
</important_files>

<next_steps>
1. Rebuild Diagnostics and fix any compile errors. Watch for:
   - the tuple `visibility.Value` assignment;
   - the leftover braces in the grid block;
   - `SupportedPlatform` being reachable through the existing usings.
2. Optionally add unit tests (`NormalizeVisibility_MapsEnumNumbers`, and a mixed-filter case), then rebuild Unit and run the tests.
3. Read the BindingStorm r9 result: `read_powershell` shellId `demos`, then check the binding status fields and the DataContext usage in its events.jsonl.
4. Update SKILL.md and copilot-tools.md for:
   - the mixed nameFilter;
   - `xamlApplied`;
   - per-group item errors;
   - restart guidance.
5. Redeploy and verify the hash. Re-run VanishingSave (tag r10) to confirm there are no false Visibility causes and the grid-cell cause is detected. Optionally re-run PrecedenceWars.
6. Log the r9/r10 rows and findings #102+ in TestPass.md:
   - hover works;
   - false Visibility=0 causes fixed;
   - mixed filter supported;
   - `applied` false when code fails;
   - null RowDefinitions handled per group;
   - check snapshots compacted.
7. Reset the demo repo, then stop the `keepawake` shell.
8. Call task_complete. The summary should:
   - list the implemented features and the chat-log-driven improvements;
   - say that hover moves the real mouse;
   - list future-work items;
   - remind the user about UAC;
   - offer a single local commit.
</next_steps>