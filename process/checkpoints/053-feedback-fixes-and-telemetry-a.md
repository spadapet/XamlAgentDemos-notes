<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` CopilotFunctions in Diagnostics.dll;
- new TAP messages that run inside the debugged app;
- a built-in skill, SKILL.md.

The 17 WPF demo apps are tested autonomously in the fastmain Exp hive, and every run is logged in the notes repo.

The current request runs in autopilot (decide without asking, verify, then call task_complete):
- add list inputs to the tools;
- fold the four status tools into `xaml_get_status`;
- don't merge the binding or accessibility tools yet;
- bring WinUI, UWP and MAUI up to WPF functionality;
- update the test apps (WPF-only) and re-run the tests.

The user's latest message asked for two things:
- keep improving the tools and code based on test-run feedback;
- fix the assert dialog that popped up, which seemed tied to a tool call.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the tools, the skill and an automation harness, then ran all 17 demos (findings #1–70 are in TestPass.md).
   - Added `xaml_hit_test`, the `SupportsHitTest` capability bit, native UwpTap and MAUI hit tests, list inputs with `RunBatchAsync`, and `xaml_get_status` (replacing four tools).
   - Fixed the host platform masks that dropped `SupportsHitTest`.
   - Added `|` alternatives, regex rejection, the `skippedNoSource` hint and the `alreadyApplied` status.
   - Added `Close-Asserts` hooks to the harness.

2. **This segment: batch run `run-consolidated` (shellId `batch2`) completed**
   - All 5 demos had 0 failed tool calls: PrecedenceWars, BindingStorm, A11ySweep, VanishingSave, StyleMaze.
   - The A11ySweep transcript showed an empty follow-up. The agent had answered in plain text and autopilot then nudged it; the transcript renderer used the last (empty) user message. The real answer is the `assistant.message` after the "Thanks." `user.message` in events.jsonl.

3. **Feedback-driven fixes made this segment**
   - **`pairwise` for `xaml_explain_property_value`.**
     - New bool parameter: zips `elementIds[i]` with `propertyNames[i]` instead of crossing them.
     - `XamlAgentService.Zip` (internal) throws INVALID_ARGUMENT when the lengths differ.
     - Unit test assertions were added to the Filters test.
     - SKILL.md row and copilot-tools.md updated, including documentation of filter alternatives.
   - **Hit test:** when the target is disabled, the finding now says input skips disabled elements, so this isn't an overlay (from VanishingSave feedback).
   - **Hit test:** new finding when the window is minimized (ScreenX/Y ≤ -30000). It says to restore the window via WindowState=Normal and notes that `xaml_interact` still works (from A11ySweep).
   - **WINDOW_NOT_FOUND hint:** explains that window IDs change when dialogs are reopened; call `xaml_get_status` or omit windowId (from BindingStorm).
   - **`alreadyApplied` note:** explains that code-set values (constructor/Loaded) persist and startup code isn't re-run (from VanishingSave/PrecedenceWars).
   - **SKILL.md:** hot reload doesn't wire new `Click=` event attributes on existing elements; prefer a Command or trigger, or say a restart is needed (from A11ySweep).
   - **`GetHotReloadLog`:** added `dotNetHotReloadPaneNote`, which says the pane lines are raw across projects and sessions (from BindingStorm).
   - **Apply hot reload:** snapshots `RuntimeErrors` before applying.
     - `errors` now contains only errors new to this call.
     - New `earlierErrors` field plus `earlierErrorsNote` say they may be stale.
     - Status and `applied` are computed from new errors only (from StyleMaze).
   - **Output size guard:** `XamlDiagnosticsFunctionProvider.LimitSize`, with `MaxResultLength = 100_000` (internal).
     - Oversized results are replaced by `{error: OUTPUT_TOO_LARGE, message, hint (nameFilter, fewer elementIds, depth/maxNodes), preview: first 4000 chars}`.
     - Added the error code `OutputTooLarge = "OUTPUT_TOO_LARGE"` in `XamlAgentException.cs`.
     - Added unit test `LimitSize_ReplacesOversizedResultWithPreviewAndHint`. It uses the wrong attribute `[TestMethod]`; it must be `[Test]` (see Next steps).
   - **Assert fix (user's explicit request): "The scope Change-Document was not disposed correctly"**
     - It's a DEBUG finalizer assert in `TelemetryScopeBase`.
     - Root cause: `DesignerUndoService.UndoTransactionTelemetryScope` is started for root or placeholder text-edit transactions (`CreatePlaceholderTextUndoUnit`, triggered by agent text edits to an open .xaml). When the markup document is torn down (`MarkupDocument` dispose → `MarkupDocumentUndoProvider.Detach` → `DesignerUndoService.Detach`), the scope is never ended.
     - Fix: added `UndoTransactionTelemetryScope.Abandon()`, which unregisters the change list and calls `End(UserCancel)` without reporting node changes. `DesignerUndoService.Detach()` now calls `this.transactionTelemetryScope?.Abandon();` first.
     - Not compiled yet.

4. **Build/test status:** the `copilot.proj` build passed (0 errors) before the LimitSize test was added. The latest test build failed with CS0246 `TestMethod` at XamlAgentToolsTests.cs:139, so the test run used the stale 8 tests.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

**Modified this segment:**
- **`Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`:**
  - `Zip`;
  - hit test disabled and minimized findings (~1631–1660);
  - WINDOW_NOT_FOUND hint (~2285);
  - `alreadyApplied` note;
  - `dotNetHotReloadPaneNote`;
  - `errorsBefore` / `earlierErrors` split in `ApplyHotReloadAsync` (~2050–2120).
- **`...\AgentTools\XamlDiagnosticsFunctionProvider.cs`:** `pairwise` parameter on explain (~129–145); `LimitSize` + `MaxResultLength` before `Cross` (~459); `RunAsync` wraps its result in `LimitSize`.
- **`...\AgentTools\XamlAgentException.cs`:** `OutputTooLarge`.
- **`...\AgentTools\skills\xaml-diagnostics\SKILL.md`:** explain row (`pairwise`), and the Click-handler / code-set values paragraph under "Apply a fix".
- **`Diagnostics\Documentation\copilot-tools.md`:** batching paragraph (`pairwise`, filter alternatives).
- **`Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`:** Zip assertions; new LimitSize test (needs `[Test]`).
- **`Designer\Source\SurfaceDesigner\Documents\DesignerUndoService.cs`:** `Abandon()` and `Detach()` changes.

**Earlier this request (still uncommitted):**
- **TAP side:**
  - TapContract `DiagnosticBits.cs` and `PublicAPI.Unshipped.txt`;
  - UwpTap: `DiagnosticBits.h`, `UwpTap.cpp`, `UwpTap.h`, `XamlMessageType.h`;
  - XamlTapContract `XamlMessageType.cs`;
  - WPF and MAUI `VisualTreeService.cs`;
  - MauiTap `TapAgentToolsService*.cs`.
- **Platform masks:** WpfDiagnosticPlatform, WinRTDiagnosticPlatform, DiagnosticsMobile `DiagnosticPlatform`.
- **Diagnostics:** `XamlInAppCopilotExtension.cs`.
- **Docs:** `enablement-and-troubleshooting.md`.
- **Harness `Harness.psm1`** (session files): `Close-Asserts`.

**Status:**
- [x] batch2 done: 5/5 runs, 0 failed calls.
- [ ] Fix the test attribute, rebuild `copilot.proj` plus the Designer project, and run unit tests (expect 9 pass).
- [ ] Redeploy and re-run the affected demos to verify live.
- [ ] TestPass.md logging.
- [ ] Wrap-up.
</work_done>

<technical_details>
**Build**
- Run in the same process:
  - `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then grep `Error\(s\)|: error `.
- `.vs\copilot.proj` includes TapContract, DiagnosticsBase, RuntimeHostBase, XamlTapContract, WpfCoreTap, WpfTap, Diagnostics and MauiTap.
- It does NOT include the Designer SurfaceDesigner project. Find the csproj owning `DesignerUndoService.cs` under `src\Xaml\Designer\Source\SurfaceDesigner` and build it; it's probably also deployed by DeployToVs.

**Tests**
- Use `Start-Job` with Prime, then `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics *> .vs\bx.txt`, then `Test-Xaml.ps1 -Suite diagnostics -Filter XamlAgentToolsTests`, with `Wait-Job -Timeout 540`.
- Check `.vs\bx.txt` for errors: Build-Xaml failure isn't obvious, and stale tests still run.
- The test framework uses `[Test]` (DesignTools.Tests.Foundation), not `[TestMethod]`.

**Harness**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `& "$h\Redeploy.ps1"` closes VS, deploys elevated, checks the System.Drawing.Common redirect is 10.0.0.0, relaunches Exp and opens a new chat.
- `& "$h\Run-Batch.ps1" -Names a,b -Tag T` or `Run-Demo.ps1 -Name X -Tag T`.
  - Output: `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`.
- `read_powershell` max delay is 600.
- KeepAwake runs async (shellId `keepawake`).

**Feedback extraction**
- Find the `user.message` whose `data.content` starts with `Thanks.`.
- Take the first `assistant.message` with content after it, or the `task_complete` summary argument.

**Editing and dialogs**
- CRLF/BOM-preserving replace helper: in single-quoted here-strings, don't add stray quotes.
- Checked-build assert dialogs block DTE. Dismiss with WM_COMMAND IDIGNORE(5); the harness `Close-Asserts` does this.

**Batching and hot reload behavior**
- RunBatchAsync: max 50 items. One item returns the raw result; several return `{count, failed, results, note}`. TAP_TIMEOUT, DEBUGGER_PAUSED and NO_APPS abort the batch.
- WPF InputHitTest skips disabled elements.
- MarkupChangeErrorManager `RuntimeErrors` accumulate until the document changes again.

**Constraints**
- Demo apps are WPF-only; WinUI, UWP and MAUI are verified by compiling only.
- Never push, rebase or amend; offer one local commit at the end.

**Open feedback ideas (not built)**
- hit-test area scan and compact output;
- IsEnabled explain should name the disabling ancestor;
- re-run startup logic;
- element recreation mapping after hot reload;
- per-edit hot reload verify;
- inspect/reset ColumnDefinition live;
- event-handler preflight warning.

**Uncertainties**
- The 100 KB limit is a guess.
- The Designer assert fix is unverified (it was not reproduced directly).
- `Abandon` touches `markupDocument.UnregisterChangeList` during teardown. That should be safe since it holds its own reference, but it is unverified.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**: all tool implementations (Zip near `AlternativeSeparators`, ~775; hit test ~1600–1690; GetHotReloadLog ~1989; ApplyHotReloadAsync ~2030–2130; capture window ~2280).
- **`...\AgentTools\XamlDiagnosticsFunctionProvider.cs`**: tool definitions, RunAsync (~425), LimitSize/Cross (~459+).
- **`...\AgentTools\XamlAgentException.cs`**: error codes.
- **`...\AgentTools\skills\xaml-diagnostics\SKILL.md`**: the skill (line 28 explain row; ~67–68 apply-fix guidance).
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`**: unit tests. Line 139 must change `[TestMethod]` → `[Test]`.
- **`Q:\src\VS_xaml\src\Xaml\Designer\Source\SurfaceDesigner\Documents\DesignerUndoService.cs`**: the assert fix (`UndoTransactionTelemetryScope.Abandon` ~255; `Detach` ~970).
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UtilityBase\Telemetry\TelemetryScopeBase.cs:173`**: the finalizer assert source (unchanged).
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`**: results table (~15), findings (~48+, last is #70), harness notes (~123).
</important_files>

<next_steps>
1. **Fix and test.**
   - Fix `XamlAgentToolsTests.cs:139` to `[Test]`.
   - Rebuild `copilot.proj`, plus the SurfaceDesigner project for the DesignerUndoService change; verify 0 errors.
   - Run unit tests and expect 9/9 pass.
2. **Redeploy and re-run.**
   - Redeploy with `& "$h\Redeploy.ps1"`, and confirm DeployToVs also copies the Designer DLL.
   - Re-run, e.g. `Run-Batch.ps1 -Names VanishingSave,StyleMaze,A11ySweep,BindingStorm,PrecedenceWars -Tag run-feedback`.
   - Watch dialogs.log for asserts, review the feedback, and fix further issues.
3. **Update TestPass.md.**
   - Add results rows for the run-consolidated runs (GhostClicks ×2 and the 5-demo batch) and for the new runs.
   - Add findings #71+:
     - consolidation into `xaml_get_status`; list inputs and RunBatchAsync;
     - cross-platform hit test and the SupportsHitTest bit; host mask bug;
     - native resource handle fix; unit-test hang fix;
     - filter alternatives, regex rejection, sourceFile hint; `alreadyApplied`; `pairwise`;
     - disabled and minimized hit-test findings; WINDOW_NOT_FOUND hint;
     - earlierErrors split; OUTPUT_TOO_LARGE guard;
     - the Click-handler skill guidance; pane note;
     - the Change-Document telemetry assert root cause and fix;
     - the transcript renderer quirk.
   - Harness note: `Close-Asserts`.
4. **Wrap up.**
   - Stop KeepAwake (shellId `keepawake`), delete `.vs\copilot.proj`, and mark the SQL todos done.
   - Remind the user about the redirect patch (PR 807376).
   - Offer a single local commit and ask about skill updates.
   - Call task_complete with a summary:
     - tool inventory changes: 4 tools folded into `xaml_get_status`; list inputs for properties, styles, explain (+ `pairwise`), set and hit_test;
     - cross-platform parity: WinUI/UWP native hit test, MAUI approximate, compile-verified;
     - the fixes and the assert fix;
     - test results.
</next_steps>