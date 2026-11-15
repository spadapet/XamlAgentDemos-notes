<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` CopilotFunctions in Diagnostics.dll;
- new TAP messages handled inside the running app;
- a built-in skill, SKILL.md.

All 17 WPF demo apps were tested autonomously in the fastmain Exp hive, and every run is logged in the notes repo.

The current request runs in autopilot (decide without asking, verify, then call task_complete):
- add list (batch) inputs to the tools;
- fold the four status tools into one `xaml_get_status`;
- don't merge the binding or accessibility tools yet;
- implement the new WPF TAP functionality (hit test 564, null background) for WinUI, UWP and MAUI;
- keep the demo apps WPF-only, update them if needed, re-run the tests, and log the results.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented the tools, the skill and a test harness, and ran all 17 demos. Findings #1–70 are in `Q:\source\XamlAgentDemos-notes\TestPass.md`.
   - Added `xaml_hit_test` (WPF, TAP 564), find_elements wildcards and `namedOnly`, the `nullBackground` flag, `lastHotReloadUpdate`, and SKILL.md authoring guidance.

2. **User asked whether tools can be combined and whether every platform has the TAP changes**
   - Recommended list inputs and folding the status tools into one, while keeping clear, question-first tool names. The user agreed and gave the current request.

3. **Current request, previous segments**
   - Added the `SupportsHitTest = 0x40` capability bit everywhere.
   - Wrote the native WinUI/UWP `HandleElementHitTest` and the MAUI hit-test handler.
   - Fixed the native resource-tool handle-space bug.
   - Service: `GetStatusAsync`, `RunBatchAsync`, `CollectIssues`, `GetHotReloadStateAsync`, `GetWindowInfos`.
   - Provider: started converting the tools to array inputs.

4. **Current request, this segment**
   - **Provider:**
     - converted `xaml_hit_test` to `string[] elementIds` × optional `string[] points` via `Cross` + `RunBatchAsync`, with an all-platform description;
     - deleted the `xaml_get_hot_reload_status` and `xaml_list_windows` CopilotFunctions;
     - added the `Cross` helper;
     - changed the capture_image windowId description to say it comes from xaml_get_status;
     - added `using System.Collections.Generic` and `System.Linq`.
   - **Old tool names replaced:**
     - the error/hint strings in XamlAgentService;
     - XamlInAppCopilotExtension (the prompt now says "start with xaml_get_status");
     - the unit test assertion.
   - **Native builds:** all 4 UwpTap variants compile with 0 errors (StaticCrt, StaticCrt.WinUI3, OneCore.StaticCrt, OneCore.StaticCrt.WinUI3).
   - **Managed build fixes:**
     - added `SupportsHitTest = 64` to `TapContract\PublicAPI\PublicAPI.Unshipped.txt` (RS0016);
     - added TapContract.csproj and DiagnosticsBase.csproj to `.vs\copilot.proj`.

     The managed build now has 0 errors.
   - **Docs updated:**
     - SKILL.md: start steps use xaml_get_status; tool table; list-input paragraph; hit test on all platforms with the MAUI approximation caveat and `supportsHitTest`; all old names replaced.
     - `enablement-and-troubleshooting.md`.
     - `copilot-tools.md`: the get_status row, hit_test row, 564 gated on SupportsHitTest, both bits, native and MAUI file lists, a platform hit-test note, a native identity-ID note, and a new "## Batching" section.
     - No old names remain in src\Xaml, src\Copilot, or harness prompts.json.
   - **Unit tests hung.**
     - cdb showed `XamlAgentService.ReadHotReloadPaneLines` calling `ThreadHelper.ThrowIfNotOnUIThread()`, which hit `Debug.Fail` (a hidden message box) in tests. This came from an earlier output-pane change.
     - Fixed it by switching to `ThreadHelperBase.ThrowIfNotOnUIThread()`, matching the rest of the file.
     - Rebuilt Diagnostics, then Build-Xaml. All 5 XamlAgentToolsTests pass.
   - Was about to add unit tests for `RunBatchAsync` and had just viewed its code.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

**Modified files:**
- **TAP and contract:**
  - TapContract `DiagnosticBits.cs` and `PublicAPI.Unshipped.txt`;
  - UwpTap: `DiagnosticBits.h`, `UwpTap.cpp`, `UwpTap.h`, `XamlMessageType.h`;
  - XamlTapContract `XamlMessageType.cs`;
  - WPF and MAUI `VisualTreeService.cs`;
  - MauiTap `TapAgentToolsService.cs` and the new `TapAgentToolsService.HitTest.cs`.
- **Diagnostics:**
  - `XamlAgentService.cs`, `XamlDiagnosticsFunctionProvider.cs`, `XamlInAppCopilotExtension.cs`;
  - unit test `XamlAgentToolsTests.cs`;
  - SKILL.md, `references\enablement-and-troubleshooting.md`, `Documentation\copilot-tools.md`.

**Status:**
- [x] cap-bit, native-hittest, maui-hittest (all compile)
- [x] host-lists: properties, styles, explain, set and hit_test take lists
- [x] get-status: the four old tools are removed and references updated
- [x] docs-skill (mostly done)
- [x] unit tests pass (5/5)
- [ ] Add RunBatchAsync unit tests (in progress)
- [ ] build-deploy (Redeploy.ps1)
- [ ] retest the demos in VS, then log results
- [ ] Update the SQL todos to done (cap-bit, native-hittest, maui-hittest, host-lists, get-status, docs-skill)
</work_done>

<technical_details>
**RunBatchAsync** (XamlAgentService ~316–387)
- `internal static Task<object> RunBatchAsync<T>(IReadOnlyList<T> items, string itemsName, Func<T,object> label, Func<T,Task<object>> run)`.
- Throws INVALID_ARGUMENT when there are 0 items or more than 50 (`MaxBatchItems`).
- One item returns `run`'s result as-is.
- Several items return an anonymous object `{count, failed, results (List<JObject>), note}`:
  - a failed item is `label` + `error`/`message`/`hint`;
  - TAP_TIMEOUT, DEBUGGER_PAUSED and NO_APPS are rethrown;
  - an identical `note` across more than one success is hoisted.
- Tests read anonymous properties via reflection: `GetValue(obj, "prop")`.
- The test project can see internals (it does `new XamlAgentService()`).

**Native TAP element identity**
- Native TAP handles are identity-service IDs: `m_identityService->GetId(obj).GetId()`, looked up with `TryGetObject<T>(ObjectIdentifier(handle))`.

**Build**
- `.vs\copilot.proj` is a Traversal project that includes:
  - TapContract
  - DiagnosticsBase
  - RuntimeHostBase
  - XamlTapContract
  - WpfCoreTap
  - WpfTap
  - Diagnostics
  - MauiTap
- Command: `. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then grep for `Error(s)` and `error`.
- Diagnostics gets `DiagnosticBits` through DiagnosticsBase (a linked file). MauiTap gets it through the TapContract project.
- A new public enum member needs a PublicAPI.Unshipped.txt entry.

**Unit tests**
- Build Diagnostics.csproj first, then `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics`, which doesn't rebuild references by default.
- Then run `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter XamlAgentToolsTests` wrapped in `Start-Job` + `Wait-Job -Timeout 240`.
- Building Unit.csproj directly fails with NETSDK1047 (a restore issue), so use Build-Xaml.
- Tests run in a process chain: vstest → testhost → `DesignTools.Tests.Unit.XamlDiagnostics.exe` → `XUnitTestExecutor.exe`.
- A hidden Debug.Fail assert hangs the run. Debug it with cdb on XUnitTestExecutor using `!eestack -ee`.

**Editing**
- The edit tool reports "old_str did not match exactly" on CRLF files but applies the edit. Always check the diff it shows.
- For bulk replacements, use the PowerShell `Fix` pattern: ReadAllText/Replace, then WriteAllText with `UTF8Encoding($bom)` to preserve the BOM.
- Beware `$nl2`-style variable interpolation in double-quoted strings.
- Use full paths: .NET's current directory differs from the PowerShell location.

**Error codes**
- NO_APPS, APP_NOT_FOUND, ELEMENT_GONE, INVALID_ARGUMENT, PROPERTY_NOT_FOUND, UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_ERROR, TAP_TIMEOUT, DEBUGGER_PAUSED, NOT_AVAILABLE, WINDOW_NOT_FOUND, WINDOW_MINIMIZED.

**Deploy and test**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `& "$h\Redeploy.ps1"`:
  - closes VS and deploys elevated;
  - patches the System.Drawing.Common redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config`;
  - relaunches `devenv /rootsuffix Exp`. Wait about 60 s.
- `& "$h\Run-Demo.ps1" -Name X -Tag runN`:
  - output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`;
  - use `node $h\peek.js events.jsonl` for a timeline;
  - prompts are in `prompts.json` (no old tool names).
- Run `KeepAwake.ps1` async during tests.
- If the RDP window is minimized, SendKeys and CopyFromScreen fail.

**Constraints**
- Demo apps are WPF only, so WinUI, UWP and MAUI are verified by compiling only.
- Skill examples use generic names.
- Never push, rebase or amend; offer a single local commit at the end.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
  - Implementation of every tool.
  - Approximate locations: batching ~316–387; GetStatusAsync ~393; CreateAppInfo ~430; HitTestAsync ~1513; ReadHotReloadPaneLines ~2082 (now uses ThreadHelperBase).
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**
  - Tool definitions: get_status, list-input tools, hit_test ~241, `Cross` ~458.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`**
  - 5 tests. RunBatchAsync tests are to be added here.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`**: the native hit test and handle fixes.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.HitTest.cs`**: the MAUI hit test.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\TapContract\PublicAPI\PublicAPI.Unshipped.txt`**: SupportsHitTest entry at line 150.
- **SKILL.md, `references\*.md`, `Documentation\copilot-tools.md`**: updated docs.
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`**: log this round as findings #71+, including:
  - the native resource handle-space fix;
  - the ReadHotReloadPaneLines test-hang fix;
  - the tool consolidation;
  - the list inputs;
  - the cross-platform hit test.
</important_files>

<next_steps>
1. **Add 2–3 unit tests to XamlAgentToolsTests:**
   - a single item returns the raw result;
   - multiple items where one throws `XamlAgentException(ElementGone)` give `failed == 1`, the error entry carries the label fields, and an identical note is hoisted;
   - more than 50 items, or an empty list, throws INVALID_ARGUMENT;
   - TAP_TIMEOUT is rethrown.

   Build Diagnostics, run Build-Xaml, then run Test-Xaml with a timeout.
2. **Update the SQL todos** to done.
3. **build-deploy:** run `& "$h\Redeploy.ps1"`, check the BOMs are intact, and wait about 60 s for VS Exp.
4. **retest:**
   - start KeepAwake async;
   - re-run demos: GhostClicks (hit test with a points list), PrecedenceWars (explain with several propertyNames), BindingStorm, A11ySweep, VanishingSave, and others;
   - check the agent uses xaml_get_status and batching;
   - compare tool-call counts with earlier runs;
   - ask follow-up questions about tool clarity;
   - fix any issues;
   - log everything in TestPass.md.
5. **Wrap up:**
   - stop KeepAwake and delete `.vs\copilot.proj`;
   - remind the user about UAC, the redirect patch (PR 807376) and the language service assert;
   - offer a single local commit;
   - ask about skill updates (writing-skills);
   - call task_complete with a summary: the tool inventory changes (4 tools folded into xaml_get_status; list inputs), cross-platform hit test, fixes, and test results.
</next_steps>