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
   - Added `xaml_hit_test` (WPF, TAP message 564), find_elements wildcards and `namedOnly`, the `nullBackground` flag, `lastHotReloadUpdate`, and SKILL.md authoring guidance. All of that was built and deployed.

2. **User asked whether tools can be combined and whether every platform has the TAP changes**
   - Recommended list inputs and folding the status tools into one, while keeping clear, question-first tool names. The user agreed.

3. **Current request (in progress)**
   - Previous segment, native and MAUI TAP work:
     - Added the `SupportsHitTest = 0x40` capability bit everywhere.
     - Wrote the native WinUI/UWP `HandleElementHitTest`.
     - Fixed the native resource-tool handle-space bug.
     - Wrote the MAUI hit-test handler.
   - This segment:
     - **Native compile:** UwpTap.StaticCrt and UwpTap.StaticCrt.WinUI3 both report 0 errors, and the logs show UwpTap.cpp was actually compiled (not a cache hit).
     - **OneCore compile:** started the OneCore variants in async shell `onecore`, logging to `.vs\native-<name>.txt`. The result hasn't been read yet.
     - **Service (`XamlAgentService.cs`):**
       - `ListAppsAsync` became `GetStatusAsync(app)`.
       - Extracted `CollectIssues`, `GetHotReloadStateAsync(host, ct)` and `GetWindowInfos`.
       - Added the `WindowBoundsNote` const and `RunBatchAsync`.
       - Gated `HitTestAsync` on `SupportsHitTest` and made its note platform-neutral.
     - **Provider:**
       - Added `xaml_get_status` and removed `xaml_list_apps` and `xaml_get_diagnostics_status`.
       - Added array inputs to properties, styles, explain and set_element_property.
       - Was about to convert hit_test, remove `xaml_get_hot_reload_status` and `xaml_list_windows`, and add the `Cross` helper.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

**TAP changes from the previous segment (native compiled; MAUI not yet compiled):**
- **DiagnosticBits.cs / DiagnosticBits.h:** `SupportsHitTest = 0x40`.
- **UwpTap XamlMessageType.h:** `ElementHitTestRequest = 564`.
- **WPF and MAUI VisualTreeService:** set the bit.
- **UwpTap.cpp:**
  - `HandleElementHitTest` (~2445–2820), registered at ~303.
  - Status now reports `SupportsAgentTools | SupportsHitTest`.
  - Resource handle fixes at ~2112 and ~2309: use the identity-service ID, not `ToHandle`.
- **UwpTap.h:** handler declaration.
- **MauiTap:** new `AgentTools\TapAgentToolsService.HitTest.cs`, registered in `TapAgentToolsService.cs`.

**`XamlAgentService.cs` (this segment, not yet compiled):**
- **Batching section (~316–387):**
  - `internal const int MaxBatchItems = 50`.
  - `BatchSerializer`, a Newtonsoft serializer that ignores nulls.
  - `internal static Task<object> RunBatchAsync<T>(IReadOnlyList<T> items, string itemsName, Func<T,object> label, Func<T,Task<object>> run)`:
    - throws INVALID_ARGUMENT when there are 0 items or more than 50;
    - one item returns its result unchanged;
    - more items return `{count, failed, results[], note}`;
    - each failed item gets `label` + `error`/`message`/`hint`;
    - TAP_TIMEOUT, DEBUGGER_PAUSED and NO_APPS are rethrown, so one of them aborts the whole batch;
    - a `note` that every success repeats is hoisted to the top level.
- **`GetStatusAsync(string app, ct)`** (~393) returns:
  - `isDebugging`, `debuggerState`, `diagnosticsActive`, `notAvailableReason`;
  - `apps` (`CreateAppInfo` now takes `windows[]` and adds `supportsHitTest` and `windows`; `windowCount` was removed);
  - `issues`, `issuesSummary`, `hotReload`, `windowsNote`, `hint`.
- **`CollectIssues(host, endpoints)`:** the old GetDiagnosticsStatusAsync body; returns `List<object>`.
- **`GetHotReloadStateAsync(host, ct)`:** private; options, `dotNetHotReloadEnabled`, `isProcessingChanges`, `lastHotReloadUpdate`, the env var, `errors` and `hint`. The per-app list was removed.
- **`GetWindowInfos(host, endpoints)`:** yields `(endpoint, {windowId, title, bounds, dpiScale, visible, minimized})`. `ListWindowsAsync` was removed.
- **HitTestAsync:**
  - The gate is now `DiagnosticBits.SupportsHitTest`, with a message about an older VS or remote tools TAP.
  - The note is now platform-neutral (WPF InputHitTest / WinUI FindElementsInHostCoordinates / MAUI approximation; InputTransparent).

**`XamlDiagnosticsFunctionProvider.cs` (this segment):**
- `AppDescription` now references xaml_get_status.
- Added the `ElementIdsDescription` const.
- `xaml_get_status(app?)` replaces list_apps and diagnostics_status.
- Converted to `string[] elementIds` via `XamlAgentService.RunBatchAsync`:
  - `get_element_properties`;
  - `get_element_styles`;
  - `explain_property_value`, which also takes `string[] propertyNames` and calls `XamlDiagnosticsFunctionProvider.Cross(elementIds, propertyNames)`. `Cross` is **not yet defined**; it should return `List<(string, string)>` using Item1/Item2.
- **`set_element_property`** now takes:
  - `string[] elementIds`;
  - `string[] setters` (`"Name=Value"`, split at the first '=');
  - `string[] resetProperties`.

  It validates the input before confirmation and builds a confirmation detail listing up to 10 changes.

**Todos:**
- [x] cap-bit, native-hittest (compiled), maui-hittest (written, not compiled). The SQL rows still need updating to done.
- [~] host-lists: properties, styles, explain and set are done. Hit_test isn't done.
- [~] get-status: service done. The provider still has old tools and references to remove.
- [ ] docs-skill, build-deploy, retest
</work_done>

<technical_details>
**Native TAP element identity**
- Element handles that the host and LVT use are identity-service IDs: `m_identityService->GetId(obj).GetId()`.
- Look elements up with `TryGetObject<T>(ObjectIdentifier(handle))`.
- The int64/ToHandle overload is the wrong ID space for host handles.

**Native TAP builds**
- Projects:
  - `Shared\Source\UwpTap\UwpTap.StaticCrt\UwpTap.StaticCrt.vcxproj`
  - `UwpTap.StaticCrt.WinUI3\...vcxproj`
  - the OneCore variants under `OneCore.StaticCrt\`
- Command: `Invoke-Build.ps1 -Project <vcxproj> -Platform x64 -NoRestore -NoProjectReferences`.

**MauiTap.csproj**
- netstandard2.0, SDK glob, built against MAUI 6.0.312 references, defines `MAUI_TAP`.

**CopilotFunction tool parameters**
- `string[]` parameters work; avoid object arrays.
- Confirmation goes through `RunConfirmedAsync(progressMessage, progress, broker, title, detail, func, ct)`, and NotRequired tools use `RunAsync`.
- Both switch to the UI thread first.

**Error codes** (`XamlAgentErrorCodes` in XamlAgentException.cs)
- NO_APPS, APP_NOT_FOUND, ELEMENT_GONE, INVALID_ARGUMENT, PROPERTY_NOT_FOUND, UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_ERROR, TAP_TIMEOUT, DEBUGGER_PAUSED, NOT_AVAILABLE, WINDOW_NOT_FOUND, WINDOW_MINIMIZED.

**Edit tool quirk**
- The edit tool reports "old_str did not match exactly" on these CRLF files, but the edits apply correctly. Always review the diff it shows: one edit silently dropped a `failed++` line (now fixed) and left stray lines (fixed).

**Build**
- Recreate `.vs\copilot.proj` as a Traversal project with:
  - `src\Xaml\...RuntimeHostBase`
  - `XamlTapContract`
  - `WpfCoreTap`
  - `WpfTap`
  - `Diagnostics`
  - `MauiTap`
- Command: `. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then check for " 0 Error(s)".
- XamlJsonData.cs compiles into several assemblies, so new type names must avoid colliding with RuntimeHost types (CS0433).
- `[IO.File]::WriteAllText` strips the BOM; prefer the edit tool. XamlAgentService.cs has no BOM and uses CRLF.

**Deploy and test**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `& "$h\Redeploy.ps1"`:
  - closes VS and deploys elevated;
  - patches the System.Drawing.Common redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config`;
  - relaunches `devenv /rootsuffix Exp`. Wait about 60 s.
- `& "$h\Run-Demo.ps1" -Name X -Tag runN`:
  - output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`;
  - use `node $h\peek.js events.jsonl` for a timeline;
  - prompts are in harness `prompts.json` and may reference old tool names.
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
  - Approximate locations: batching section ~316–387; GetStatusAsync ~393; CreateAppInfo ~430; CollectIssues ~465; HitTestAsync ~1513 (gate ~1537); GetHotReloadStateAsync ~1875; GetWindowInfos ~2155.
  - Error strings at ~183, ~195, ~201 and ~675, plus the capture strings (~2174, ~2224), still mention xaml_list_apps, xaml_get_diagnostics_status or xaml_list_windows.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**
  - Tool definitions: get_status ~53; properties, styles, explain ~101–141; set_property ~170–227; hit_test ~240.
  - The hot_reload_status and list_windows tools still exist further down (they call methods that were removed).
  - The capture_image windowId description references xaml_list_windows.
  - `Cross` still needs adding near `RunAsync`.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`** and **`UwpTap.h`**: the native hit test and handle fixes.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.HitTest.cs`**: the MAUI hit test (not yet compiled).
- **`XamlInAppCopilotExtension.cs:136`** and **`Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs:84`**: both reference `xaml_list_apps` and need updating to `xaml_get_status`.
- **Docs:**
  - `AgentTools\skills\xaml-diagnostics\SKILL.md` (11 references to old tools);
  - `references\enablement-and-troubleshooting.md` (3);
  - `Diagnostics\Documentation\copilot-tools.md` (5).
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`**: log this round as findings #71+, including the native resource handle-space bug fix.
</important_files>

<next_steps>
1. **Finish the provider:**
   - convert `xaml_hit_test` to `string[] elementIds` plus optional `string[] points`: cross each element with each point, or use the center when no points are given. Use RunBatchAsync with label `{id, point}` and a description covering all platforms;
   - delete the `xaml_get_hot_reload_status` and `xaml_list_windows` CopilotFunctions;
   - add `private static List<(string, string)> Cross(string[] a, string[] b)` (null-safe);
   - change the capture_image windowId description to "from xaml_get_status".
2. **Update the remaining references** to the old tools:
   - the service error hints (~183, 195, 201, 675, 2174, 2224);
   - XamlInAppCopilotExtension;
   - the unit test;
   - SKILL.md, the references and copilot-tools.md;
   - harness prompts.json, if it mentions them.
3. **Read the `onecore` shell result** and fix any errors.
4. **Compile MauiTap and Diagnostics** through `.vs\copilot.proj` and fix any errors. Update the SQL todos.
5. **docs-skill:**
   - SKILL.md: update the tool table (now 4 fewer tools, net −3 with get_status), the list-input usage, and hit test on all platforms;
   - copilot-tools.md: 564 on all platforms, the SupportsHitTest bit, batching semantics.
6. **build-deploy:** run Redeploy.ps1 and check that the BOMs are intact.
7. **retest:**
   - start KeepAwake;
   - re-run GhostClicks, PrecedenceWars, BindingStorm, A11ySweep, VanishingSave and others;
   - compare tool-call counts against earlier runs;
   - log everything in TestPass.md.
8. **Wrap up:**
   - stop KeepAwake and delete `.vs\copilot.proj`;
   - remind the user about UAC, the redirect patch (PR 807376) and the language service assert;
   - offer a single local commit;
   - ask about skill updates;
   - call task_complete.
</next_steps>