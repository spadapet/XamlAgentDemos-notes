<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` CopilotFunctions in Diagnostics.dll;
- new TAP messages handled inside the running app;
- a built-in skill, SKILL.md.

All 17 WPF demo apps are tested autonomously in the fastmain Exp hive, and every run is logged in the notes repo.

The current request runs in autopilot (decide without asking, verify, then call task_complete):
- add list inputs to the tools;
- fold the four status tools into `xaml_get_status`;
- don't merge the binding or accessibility tools yet;
- bring WinUI, UWP and MAUI up to the new WPF functionality;
- keep the demo apps WPF-only, re-run the tests, and log the results.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the tools, the skill and a test harness, then ran all 17 demos (findings #1–70 are in TestPass.md).
   - Added `xaml_hit_test` (WPF, TAP 564), wildcards, `namedOnly`, `nullBackground`, `lastHotReloadUpdate`, and authoring guidance.
   - Earlier in the current request:
     - added the `SupportsHitTest = 0x40` bit;
     - native UwpTap and MAUI hit tests (compile-verified);
     - fixed the native resource-tool handle-space bug;
     - service: `GetStatusAsync`, `RunBatchAsync`;
     - provider: list inputs, `Cross`, removed the old status tools;
     - updated the docs;
     - fixed a unit-test hang (`ReadHotReloadPaneLines` now uses `ThreadHelperBase`).

2. **This segment**
   - **Batching tests:** added 2 RunBatchAsync unit tests (multiple items with per-item failure and a hoisted note; single item returned as-is, DEBUGGER_PAUSED rethrown, more than 50 items gives INVALID_ARGUMENT). All pass.
   - **SQL todos:** cap-bit, native-hittest, maui-hittest, host-lists, get-status and docs-skill marked done.
   - **Deployed:** Redeploy.ps1 kept the redirect patch. KeepAwake runs async (shellId `keepawake`).
   - **GhostClicks run-consolidated:**
     - `supportsHitTest` was false on WPF.
     - Root cause: the host platform classes masked tapStatus to `SupportsAgentTools` only.
     - Fixed in WpfDiagnosticPlatform.cs, WinRTDiagnosticPlatform.cs and DiagnosticsMobile `DiagnosticPlatform.cs`: they now use `(tapStatus & (SupportsAgentTools | SupportsHitTest))`.
   - **Agent feedback from that run, and the fixes:**
     - `nameFilter` with `|` returned nothing → `SplitAlternatives` (`|` or `,`) for `nameFilter` and for find_elements `name`/`type`, plus a hint when 0 properties match.
     - Regex patterns like `*[BTRS]*` silently matched nothing → `ValidatePattern` throws INVALID_ARGUMENT for `[](){}^$+\`.
     - A `sourceFile` search returned 0 after hot reload → it counts `skippedNoSource` elements and adds a hint.
     - Provider descriptions and the SKILL.md find_elements row were updated.
     - Unit test `Filters_SplitAlternativesAndRejectRegex` added (8/8 pass).
   - **GhostClicks run-consolidated2:**
     - 3 `xaml_hit_test` calls, 15 tool calls (was 21), 0 failures, all causes fixed and verified live.
     - Feedback:
       - `noChange` is confusing when edits were already applied → added status `alreadyApplied` (`WasHotReloadUpdatedWithin(60s)`), with matching note and SKILL.md wording.
       - Wanted an area-scan hit-test option and a compact output (not done; noted).
   - **Rebuilt and redeployed.** Run-Batch of PrecedenceWars, BindingStorm, A11ySweep, VanishingSave and StyleMaze failed at first:
     - a checked-build assert dialog blocked VS DTE: DesignTools telemetry "The scope change-document was not disposed correctly", from `TelemetryScopeBase` (designer/language service, not our code);
     - its text was saved to `test-runs\PrecedenceWars\run-consolidated\assert-change-document.txt`;
     - dismissed it with WM_COMMAND IDIGNORE (5);
     - the harness now calls `Close-Asserts` in Invoke-Dte busy retries, Start-Demo (start and poll loop) and Stop-Demo.
   - **Re-ran the batch (shellId `batch2`, still running).**
     - PrecedenceWars completed: 0 failed calls, 5 `xaml_get_status`, 16 `xaml_explain_property_value`. Explain calls used `elementIds` lists (up to 3 ids) with a single `propertyNames` entry, and `nameFilter` used `|` alternatives.
     - The agent used a debugger sub-agent (pause/evaluate; evaluation failed because a native frame was on top) and `ask_question` (autopilot answered "user not available").
     - Fixes:
       - hover verified by precedence only;
       - Reports needs a restart (busy state set at startup).
     - Feedback:
       - `alreadyApplied` came with empty code output;
       - IsEnabled explain shows coercion but not the disabling ancestor;
       - wants a way to re-run startup logic.
     - BindingStorm was in progress when the summary was written.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

**Modified this segment:**
- **`XamlAgentService.cs`:**
  - `SplitAlternatives`, `ValidatePattern` (internal);
  - FindElements: validation, alternatives, `skippedNoSource` hint;
  - GetElementProperties: `nameFilters` alternatives and a no-match hint;
  - `WasHotReloadUpdatedWithin` and the `alreadyApplied` status.
- **`XamlDiagnosticsFunctionProvider.cs`:** descriptions for `type`, `name` and `nameFilter`.
- **Host platform masks:** `WpfDiagnosticPlatform.cs`, `WinRTDiagnosticPlatform.cs`, DiagnosticsMobile `Platform\DiagnosticPlatform.cs`.
- **SKILL.md:** find_elements row (`|` alternatives, no regex) and the hot-reload `alreadyApplied` wording.
- **`XamlAgentToolsTests.cs`:** 3 new tests (8 total, all pass); usings added (System, Collections.Generic, Threading.Tasks, Newtonsoft.Json.Linq).
- **Harness `Harness.psm1`** (session files): `Close-Asserts` hooks.

**Earlier in this request (still uncommitted):**
- **TAP side:**
  - TapContract `DiagnosticBits.cs` and `PublicAPI.Unshipped.txt`;
  - UwpTap: `DiagnosticBits.h`, `UwpTap.cpp`, `UwpTap.h`, `XamlMessageType.h`;
  - XamlTapContract `XamlMessageType.cs`;
  - WPF and MAUI `VisualTreeService.cs`;
  - MauiTap `TapAgentToolsService.cs` and `TapAgentToolsService.HitTest.cs`.
- **Diagnostics:** `XamlInAppCopilotExtension.cs`.
- **Docs:** `references\enablement-and-troubleshooting.md`, `Documentation\copilot-tools.md`.

**Status:**
- [x] Build: 0 errors (copilot.proj). Unit tests: 8/8.
- [x] Deployed, including the latest changes (`alreadyApplied` confirmed live in PrecedenceWars).
- [ ] batch2 still running: BindingStorm, A11ySweep, VanishingSave, StyleMaze.
- [ ] Log this round in TestPass.md (findings #71+ and results rows).
- [ ] Wrap-up.
</work_done>

<technical_details>
**Build**
- `cd Q:\src\VS_xaml; . src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then grep `Error\(s\)|: error `.
- `.vs\copilot.proj` includes:
  - TapContract, DiagnosticsBase, RuntimeHostBase, XamlTapContract;
  - WpfCoreTap, WpfTap, Diagnostics, MauiTap.

**Tests**
- Run `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics`.
- Then run `Test-Xaml.ps1 -Suite diagnostics -Filter XamlAgentToolsTests` inside `Start-Job` + `Wait-Job -Timeout 240`.

**Deploy and test**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `& "$h\Redeploy.ps1"`: closes VS, deploys elevated, checks the System.Drawing.Common redirect is 10.0.0.0, relaunches Exp and opens a new chat.
- `& "$h\Run-Demo.ps1" -Name X -Tag T` or `Run-Batch.ps1 -Names a,b -Tag T`.
  - Output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>` (transcript.md, events.jsonl, fix.diff, dialogs.log, runner.log).
  - Parse tool args from events.jsonl where `type == 'tool.execution_start'` (`data.toolName`, `data.arguments`).
- `read_powershell` delay is capped at 600.

**PowerShell gotchas**
- `R` is an alias for Invoke-History, so don't name helper functions `R`.
- For CRLF files, normalize here-string replacements to `` `r`n `` and preserve the BOM with `UTF8Encoding($bom)`.

**Dialogs and window access**
- A checked-build assert dialog blocks the UI thread: DTE calls hang, `Save-VsScreenshot` hangs, and UIA Invoke on its buttons fails.
- Find it with EnumWindows by title "Assertion Failed", then dismiss with SendMessage WM_COMMAND (0x111), wParam=5 (IDIGNORE).
- Use a direct `CopyFromScreen` for screenshots.

**Error codes**
- NO_APPS, APP_NOT_FOUND, ELEMENT_GONE, INVALID_ARGUMENT, PROPERTY_NOT_FOUND;
- UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_ERROR, TAP_TIMEOUT, DEBUGGER_PAUSED;
- NOT_AVAILABLE, WINDOW_NOT_FOUND, WINDOW_MINIMIZED.

**RunBatchAsync** (internal static)
- Max 50 items.
- One item returns the raw result.
- Several items return `{count, failed, results, note}`.
- TAP_TIMEOUT, DEBUGGER_PAUSED and NO_APPS are rethrown.

**Constraints**
- Demo apps are WPF-only; WinUI, UWP and MAUI are verified by compiling only.
- Never push, rebase or amend; offer a single local commit at the end.

**Open feedback ideas (not built)**
- hit-test area scan / dead-click-zone scan, and compact hit-test output;
- IsEnabled explain should name the disabling ancestor;
- hot reload should flag stale startup state;
- element recreation mapping after hot reload;
- plus the earlier list in #70.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
  - All tool implementations.
  - Approximate locations: `WasHotReloadUpdatedWithin` ~148; RunBatchAsync ~320; FindElementsAsync ~690; `SplitAlternatives`/`ValidatePattern` ~775; GetElementPropertiesAsync ~880; apply hot reload status ~2090.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**
  - Tool definitions; descriptions on lines 95, 96 and 112 updated.
- **Platform masks:**
  - `...\Diagnostics\Tool\Platform\Wpf\WpfDiagnosticPlatform.cs:40`
  - `...\Uwp\WinRTDiagnosticPlatform.cs:46`
  - `...\DiagnosticsMobile\Platform\DiagnosticPlatform.cs:38`
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`**: 8 tests.
- **`...\AgentTools\skills\xaml-diagnostics\SKILL.md`**: line 25 (find_elements) and line 67 (hot reload status).
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`**
  - Results table at line 15+, Findings at 48+ (last is #70, ~line 121), Harness notes ~123, Proposed test cases ~141.
- **Harness `Harness.psm1`, `Run-Demo.ps1`, `Run-Batch.ps1`, `Redeploy.ps1`** in the session `files\harness` folder.
</important_files>

<next_steps>
1. **Finish the batch.** Wait for batch2 (`read_powershell` shellId `batch2`, delay 600) to finish BindingStorm, A11ySweep, VanishingSave and StyleMaze. Review each transcript: stats, list-input usage, `xaml_get_status` usage, feedback answers, fix.diff. Fix clear issues, rebuild, redeploy and re-run if needed.
2. **Update TestPass.md.**
   - Add Results rows for the run-consolidated runs (GhostClicks ×2, PrecedenceWars, plus the batch).
   - Add Findings #71+:
     - consolidation into `xaml_get_status`;
     - list inputs and RunBatchAsync;
     - cross-platform hit test and the SupportsHitTest bit;
     - native resource handle-space fix;
     - unit-test hang fix;
     - host mask dropping SupportsHitTest (fixed);
     - nameFilter/name/type alternatives, regex rejection, sourceFile skip hint;
     - `alreadyApplied` status;
     - the telemetry "change-document" assert;
     - the PrecedenceWars feedback.
   - Harness note: `Close-Asserts` hooks.
   - Mark #12 and #69 as resolved where applicable.
3. **Wrap up:**
   - stop KeepAwake (shellId `keepawake`) and delete `.vs\copilot.proj`;
   - mark SQL todos build-deploy, retest and test-pass done;
   - remind the user about the redirect patch (PR 807376) and the DesignTools telemetry asserts;
   - offer a single local commit;
   - ask about skill updates;
   - call task_complete with a summary: tool inventory changes (4 tools folded into `xaml_get_status`; list inputs for properties/styles/explain/set/hit_test), cross-platform hit test (WinUI/UWP native, MAUI approximate, compile-verified), the fixes, and test results.
</next_steps>