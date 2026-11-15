<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio. The pieces are:
- `xaml_*` CopilotFunctions in Diagnostics.dll.
- New TAP messages for WPF, UwpTap (UWP/WinUI) and MauiTap.
- A built-in skill (`SKILL.md`).

I test them autonomously against 17 WPF demo apps in the fastmain Exp hive and log every run in the notes repo (`Q:\source\XamlAgentDemos-notes`). The session runs in autopilot: decide without asking, verify, then call task_complete.

Current request:
- Add list inputs to the tools.
- Fold four tools into `xaml_get_status`.
- Don't merge the binding or accessibility tools.
- Bring WinUI, UWP and MAUI up to WPF parity.
- Re-run the tests (the test apps are WPF only).
- Make tool and code improvements based on test-run feedback.
- Fix the assert dialog the user saw during a tool call.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the tools, the skill and the harness, and ran all demos (findings #1–70).
   - Added `xaml_hit_test`, the SupportsHitTest bit, native UwpTap and MAUI hit tests, list inputs (`RunBatchAsync`) and `xaml_get_status`.
   - Fixed the platform masks, added filter alternatives, `alreadyApplied`, `pairwise`, hit-test findings for disabled and minimized windows, the WINDOW_NOT_FOUND hint, the `earlierErrors` split, the pane note and the OUTPUT_TOO_LARGE guard.
   - Fixed the "Change-Document scope not disposed" assert in `DesignerUndoService`.
   - Batch2 (run-consolidated, 5 demos) had 0 real failed calls.

2. **This segment**
   - **Unit test fix.** The LimitSize test used `[TestMethod]` (fixed to `[Test]`). It still failed with CS0012 because the Unit project doesn't reference Copilot.dll.
     - Moved `MaxResultLength` and `LimitSize` from `XamlDiagnosticsFunctionProvider` into `XamlAgentService`. They now use fully qualified `Newtonsoft.Json.JsonConvert` with default settings.
     - The provider's `RunAsync` now calls `XamlAgentService.LimitSize`.
   - **Builds and tests.** The SurfaceDesigner.csproj build succeeded (0 errors), and so did `copilot.proj`. Unit tests: **9/9 pass**.
     - Build-Xaml compiles the tests against the *last built* Diagnostics.dll, so build copilot.proj first.
   - **Redeploy.** Ran Redeploy.ps1: the redirect is 10.0.0.0 and Exp relaunched. DeployToVs does copy SurfaceDesigner.dll.
   - **Feedback batch.** Started `Run-Batch.ps1 -Names VanishingSave,StyleMaze,A11ySweep,BindingStorm,PrecedenceWars -Tag run-feedback` (async, shellId `batch3`).
     - VanishingSave finished: 1 harness-counted failure, and the run was otherwise successful.
     - StyleMaze had started at 22:34. The batch was still running when the context was compacted.
   - **TestPass.md.** Added findings #71–#84 after the #70 row:
     - consolidation and list inputs; cross-platform hit test and the mask fix;
     - filter alternatives; alreadyApplied; pairwise;
     - disabled and minimized hit-test findings; WINDOW_NOT_FOUND hint;
     - earlierErrors; pane note; Click-handler guidance; OUTPUT_TOO_LARGE;
     - the assert root cause and fix; the transcript and harness quirks.
   - **New harness summarizer** `Summarize-Run.ps1` (Python isn't installed).
     - Summarized the run-consolidated runs: GhostClicks ×2 (2.1 and 1.8 min, 0 failed), PrecedenceWars (4.3 min, 0 failed), BindingStorm (5.6 min; its 6 "FAIL"s are false positives because binding entries contain an `error` field, plus one WINDOW_NOT_FOUND), A11ySweep (5.5 min, 1 WINDOW_MINIMIZED), VanishingSave (2.5 min, 0 failed), StyleMaze (4.7 min; partial hot-reload errors).
   - **VanishingSave run-feedback feedback.**
     - (a) `includeAll` on 5 elements returned OUTPUT_TOO_LARGE (104 KB). The agent wanted per-element or automatic truncation instead.
     - (b) It wanted to inspect and set Grid `ColumnDefinitions[2].Width` live; this is the third time that was asked for.
     - (c) `alreadyApplied` was still ambiguous.
     - (d) A static initializer warning about "next launch vs live" should be surfaced.
   - **Implementing collection item paths (in progress, not yet compiled).** This uses only existing TAP messages, so it works on all platforms. It mirrors LPE's `ElementValueBase.ValueAsPlatformObject`: for a collection property's `Handle`, send `CollectionRequest`; for item and object handles, send `PropertyChainRequest`. Added in `XamlAgentService.cs`:
     - `SplitItemPath(string)` (internal static): splits "ColumnDefinitions[2].Width" into `(objectPath "ColumnDefinitions[2]", leaf "Width")`. Without `[`, it returns `(null, name)`. With no leaf, it returns `(path, null)`.
     - `ResolveObjectPathAsync(endpoint, handle, elementId, objectPath, ct)`: returns a list of `(Handle, Type, Path)`.
       - Segments are split on `.` and parsed with the regex `^(?<name>[^\[\]]+)(\[(?<index>\d+|\*)\])?$`. `*` is allowed only in the last segment.
       - For an indexed segment it sends `CollectionRequest` with `CollectionRequestInfo{Object, StartIndex, ElementCount = 1 or MaxBatchItems}`.
       - Errors: PROPERTY_NOT_FOUND / INVALID_ARGUMENT (simple value, collection without an index, index out of range showing CollectionSize, non-collection indexed) and TAP_ERROR.
     - `GetItemPropertiesAsync(...)`: used when `get_element_properties` gets a `nameFilter` containing `[`, e.g. "ColumnDefinitions[*]" or "RowDefinitions[1].Height|ActualHeight".
       - Returns `{id, type, name, source, items:[{path, type, properties:[{name, value, valueSource, isBinding, readOnly}]}], note}`.
       - With no filter it lists non-default values plus Actual* properties.
       - It switches to the main thread before `SourceResolver`.
     - `SetElementPropertyAsync`: supports item paths through `targetHandle` and `fullPropertyName`. The output `property` shows the full path. `Object = targetHandle`, and it re-reads from `targetHandle`.
     - `ExplainPropertyValueAsync`: supports item paths (targetHandle, leafName matching; the attached-property default shortcut only applies when objectPath is null; output property shows the path).
     - `GetPropertyNotFoundHint` for `[` paths now points to `nameFilter='ColumnDefinitions[*]'`.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

**This segment:**
- `Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:
  - LimitSize and MaxResultLength (around line 790, before Zip).
  - `GetElementPropertiesAsync` branch (around line 919).
  - `GetPropertyNotFoundHint` (around line 1027).
  - `SplitItemPath`, `ResolveObjectPathAsync` and `GetItemPropertiesAsync` (around lines 1062–1240).
  - Set and Explain item-path support.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: LimitSize removed; it calls `XamlAgentService.LimitSize`.
- `Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: `[Test]`, and uses `XamlAgentService.LimitSize/MaxResultLength`.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: findings #71–84 added. Results rows for the run-consolidated and run-feedback runs are not yet added.
- Harness: `Summarize-Run.ps1` added in session `files\harness`.

**Earlier, still uncommitted:** TAP contract, UwpTap, WPF/MAUI taps, platform masks, `XamlInAppCopilotExtension`, docs, SKILL.md, copilot-tools.md, and the `DesignerUndoService.cs` assert fix (`Abandon()` + `Detach`). These were built and deployed.

**Status:**
- [x] 9/9 unit tests pass (before the item-path change).
- [x] Deployed the build containing the assert fix and the LimitSize move.
- [ ] Item-path feature: not compiled or tested yet.
- [ ] batch3 still running (StyleMaze onward).
- [ ] TestPass.md results rows and the new finding for item paths.
</work_done>

<technical_details>
**Build**
- Prime and build in the same process:
  - `Set-Location Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then grep `Error\(s\)|: error `.
- SurfaceDesigner: `src\Xaml\Designer\Source\SurfaceDesigner\SurfaceDesigner.csproj`.

**Tests**
- Build copilot.proj FIRST, then run a Start-Job that primes and runs:
  - `Build-Xaml.ps1 -Component Diagnostics *> .vs\bx.txt`
  - `Test-Xaml.ps1 -Suite diagnostics -Filter XamlAgentToolsTests`
- Check bx.txt for `: error`, because stale tests still run when the build fails.
- Tests use `[Test]`. The Unit project has no Copilot.dll reference, so testable helpers must live in `XamlAgentService`.
- Use absolute paths in PowerShell: the cwd is `src\Xaml`, and `[IO.File]` resolves relative paths against the process directory.

**Harness**
- `$h=C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `Redeploy.ps1`; `Run-Batch.ps1 -Names ... -Tag T` writes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`.
- `Summarize-Run.ps1 -Dirs ...` prints duration, tool counts, FAIL lines, TASK_COMPLETE text and FEEDBACK. The feedback is usually the second task_complete summary.
- KeepAwake runs async (shellId `keepawake`). `read_powershell` max delay is 600.

**TAP and host behavior**
- TAP collection model: `ValueBase.Handle`/`IsHandle`/`IsCollection`. `CollectionResponse{Elements: List<CollectionElementValue{Index, Handle, Value, ValueType}>, CollectionSize}`. Paging is assumed to honor StartIndex; this is unverified.
- RunBatchAsync: max 50 items. One item returns the raw result; several return `{count, failed, results, note}`.

**Constraints**
- Never push, rebase or amend. Offer one local commit at the end.
- Demo apps are WPF only. Other platforms are compile-verified.

**Uncertainties**
- Whether `SetPropertyRequest` on a collection item handle works in each TAP (LPE does it, so it probably does).
- The 100 KB output limit is a guess.
- The assert fix was not reproduced directly.

**Open feedback ideas not built**
- Partial batch results instead of OUTPUT_TOO_LARGE, e.g. drop trailing results and list the omitted elementIds.
- Hit-test area scan.
- IsEnabled explain naming the disabling ancestor.
- Hot-reload element recreation mapping.
- Event-handler preflight.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: all tool logic.
  - RunBatchAsync ~335; LimitSize ~790; Zip ~810; GetElementProperties ~915; NotFound hint ~1027; RequestPropertiesAsync ~1045.
  - New item-path helpers ~1062–1240; Set ~1240; Explain ~1450.
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: tool definitions and descriptions. The `xaml_get_element_properties`, `xaml_set_element_property` and `xaml_explain_property_value` descriptions should mention item paths. RunAsync is ~437.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. Document item paths here.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Documentation\copilot-tools.md`: tool docs.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: unit tests. Add a `SplitItemPath` test.
- `Q:\src\VS_xaml\src\Xaml\Designer\Source\SurfaceDesigner\Documents\DesignerUndoService.cs`: the assert fix.
- `Q:\source\XamlAgentDemos-notes\TestPass.md`: results table (~line 17–46), findings (#71–84 newly added after #70), harness notes, proposed tests.
</important_files>

<next_steps>
1. **Build and test the item-path feature.**
   - Build copilot.proj and fix any compile errors in the new code (CollectionResponse/CollectionElementValue namespaces are in RuntimeHost.TapOM, which is already imported).
   - Add a unit test for `SplitItemPath` and run the unit tests (expect 10 to pass).
2. **Document item paths.**
   - Update the tool descriptions in the provider, e.g. "propertyNames/setters/nameFilter accept collection item paths like 'ColumnDefinitions[2].Width'; nameFilter 'RowDefinitions[*]' lists items".
   - Add a SKILL.md row and a copilot-tools.md note.
   - Remove the SKILL.md wording saying ColumnDefinitions can't be changed live, if present.
3. **Optional: partial batch results.** In LimitSize, or in RunBatchAsync for oversized batches, keep results up to the budget and return `omittedElementIds` plus a hint, instead of a flat OUTPUT_TOO_LARGE.
4. **Finish batch3.** Wait for it to complete with `read_powershell` on shellId `batch3`. Summarize each run-feedback dir with Summarize-Run.ps1 and check dialogs.log for asserts (this verifies the Change-Document fix).
5. **Redeploy and verify the item-path feature live.** Redeploy, then re-run VanishingSave (tag `run-itempath`) to check that the agent uses `ColumnDefinitions[2].Width`.
6. **Update TestPass.md.**
   - Results rows for: GhostClicks run-consolidated/2, PrecedenceWars, BindingStorm, A11ySweep, VanishingSave and StyleMaze run-consolidated, and the run-feedback runs.
   - New finding #85: item paths; #86: partial batch results, if built.
   - Harness note about Summarize-Run.ps1.
7. **Wrap up.**
   - Stop KeepAwake (`keepawake`), delete `.vs\copilot.proj`, and mark the SQL todos done.
   - Remind the user about the redirect PR 807376.
   - Offer one local commit and ask about skill updates.
   - Call task_complete with a summary covering:
     - the tool consolidation and list inputs;
     - cross-platform parity (compile-verified);
     - the feedback fixes (pairwise, hit-test findings, earlierErrors, OUTPUT_TOO_LARGE, item paths);
     - the assert fix;
     - the test results.
</next_steps>