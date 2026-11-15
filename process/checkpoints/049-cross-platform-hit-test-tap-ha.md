<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` CopilotFunctions in Diagnostics.dll;
- new TAP messages handled inside the running app;
- a built-in skill, SKILL.md.

All 17 WPF demo apps were tested autonomously in the fastmain Exp hive, and every run is logged in the notes repo.

Current request, in autopilot (decide without asking, verify, then call task_complete):
- add list (batch) inputs to the tools;
- fold the four status tools into one `xaml_get_status`;
- do not merge the binding or accessibility tools yet;
- implement the new WPF TAP functionality (hit test 564, null background) for WinUI, UWP and MAUI;
- keep the demo apps WPF only, update them if needed, re-run the tests, and log the results.
</overview>

<history>
1. **Earlier segments:**
   - Planned and implemented the tools, the skill and a test harness, and ran all 17 demos. Findings #1–70 are in `Q:\source\XamlAgentDemos-notes\TestPass.md`.
   - Added `xaml_hit_test` (WPF, TAP message 564), find_elements wildcards and `namedOnly`, the `nullBackground` flag, `lastHotReloadUpdate` tracking, and SKILL.md authoring guidance. Built and deployed.

2. **User asked whether tools can be combined and whether the TAP changes reached every platform.**
   - Answered: batching inputs is safe; merging tools behind mode parameters hides capabilities from the model.
   - Recommended list inputs, folding the four status tools into one, and keeping clear, question-first tool names.

3. **Current request (in progress):**
   - Created SQL todos: cap-bit, native-hittest, maui-hittest, host-lists, get-status, docs-skill, build-deploy, retest.
   - Added the `SupportsHitTest = 0x40` capability bit everywhere.
   - Wrote the native WinUI/UWP hit-test handler and registered it.
   - Found and fixed a native resource-tool handle bug (details below).
   - Wrote the MAUI hit-test handler and registered it.
   - Started a native compile: UwpTap.StaticCrt reported 0 errors; WinUI3 was still building.
   - Began reading `XamlDiagnosticsFunctionProvider.cs` to do host-lists and get-status.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`. Changes from the previous round (WPF hit test, etc.) were built and deployed earlier.

This round (not yet built, except the native UWP compile):
- **`Shared\Source\TapContract\TapOM\DiagnosticBits.cs`**: `SupportsHitTest = 0x40`.
- **`Shared\Source\UwpTap\DiagnosticBits.h`**: `SupportsHitTest = 0x40`.
- **`UwpTap\XamlMessageType.h`**: `ElementHitTestRequest = 564`.
- **`XamlTapContract\Networking\XamlMessageType.cs`**: updated the 564 comment. BOM restored.
- **`WpfTap\WpfVisualTreeService\VisualTreeService.cs`** (~86) and **`MauiTap\VisualTreeService\VisualTreeService.cs`** (~90): set SupportsHitTest.
- **`UwpTap\UwpTap.cpp`**:
  - Status (~312) is `SupportsAgentTools | SupportsHitTest`.
  - Registered `HandleElementHitTest` at line 303.
  - **Bug fix:** `TryGetResourceTarget` (~2309) now uses `identityService.GetObject(ObjectIdentifier(handle))`.
  - **Bug fix:** `GetResourceOwnerHandle` (~2112) now returns `identityService.GetId(dependencyObject).GetId()` instead of `GetHandle` (`ToHandle`).
  - Added an anonymous namespace (~2445) with `RectArea`, `IntersectRects`, `RoundTo3`, `HasNullBackground`, `TryGetClipBounds` and `IsSelfOrAncestor`.
  - Added `HandleElementHitTest` (~2550–2820). It:
    - takes the point via `TransformToVisual(nullptr)`;
    - computes the screen point from the automation peer bounding rectangle, falling back to the HWND and `ClientToScreen` under `#ifndef ONECORE_BUILD`;
    - finds blockers by walking parents for Visibility, IsHitTestVisible, Control IsEnabled (pending logic: report only the outermost disabled Control) and Opacity;
    - computes clipping from Clip geometry, ScrollContentPresenter, and the XamlRoot size;
    - builds the stack with `FindElementsInHostCoordinates(rootPoint, subtree, false)`, searching open popups (`GetOpenPopupsForXamlRoot`, wrapped in try) before the top ancestor, max 15;
    - sets InputTarget to the first hit;
    - leaves TemplatedParent unset (it's WPF-only).
- **`UwpTap\UwpTap.h`**: declared `value HandleElementHitTest(value request);` (line 114).
- **`MauiTap\AgentTools\TapAgentToolsService.HitTest.cs`** (new):
  - `HandleHitTest`, `FillHitTest` (uses `GetBoundingBox`; NullBackground is set for a Layout or Border with no Background or BackgroundColor), `FillInteractiveState` (IsVisible, InputTransparent with CascadeInputTransparent, the IsEnabled pending logic, Opacity), `FillClipping`, `GetClipBounds` (ScrollView, IsClippedToBounds, RectangleGeometry Clip);
  - `GetHitStack`: `VisualTreeElementExtensions.GetVisualTreeElements(root, new Rect(x,y,1,1))`, filtered by `CanReceiveInput` and sorted by draw order (pre-order index, descending);
  - `DescribeHit` (Name = StyleId) and `IsSelfOrAncestor`.
  - It hasn't been compiled yet.
- **`MauiTap\AgentTools\TapAgentToolsService.cs`**: registered the 564 observer `HandleHitTest`.

Todo status:
- [x] cap-bit (the SQL row isn't updated yet)
- [x] native-hittest, written. UWP compiled with 0 errors, but I haven't checked it wasn't a cache hit. WinUI3 build result is pending in shell `nativebuild`; logs are in `Q:\src\VS_xaml\.vs\native-*.txt`.
- [x] maui-hittest, written but not compiled.
- [ ] host-lists
- [ ] get-status
- [ ] docs-skill
- [ ] build-deploy
- [ ] retest
</work_done>

<technical_details>
**Native TAP element identity**
- Element handles that the host and LVT use are identity-service IDs: `m_identityService->GetId(DependencyObject).GetId()` (incrementing; `VisualTreeServiceCallback.cpp:148`).
- They are not XamlDiagnostics `ToHandle`/`GetHandle` values.
- Look elements up with `TryGetObject<T>(ObjectIdentifier(handle))`. The int64 overload uses the ToHandle space and is wrong for host handles.

**Native handler pattern**
- Run work with `GetDispatcher(ObjectIdentifier(handle))` and `WinrtRunOnUIThread(dispatcher, DispatcherPriority::Normal, [&]{...})`.
- Build JSON with `value ret = value::object(); ret[L"X"] = ToJSON(...)`.
- Report errors as Error plus `HResult = E_FAIL`, using `CurrentExceptionMessage()`.
- `CreateAutomationPeer(*m_factoryProvider, el)`, `FormatDouble` and `GetRootWindowHandle` are available.
- `stdafx.h` includes the Controls, Primitives and Media headers.

**Native TAP projects** (under `Shared\Source\UwpTap\`)
- `UwpTap.StaticCrt\UwpTap.StaticCrt.vcxproj`
- `UwpTap.StaticCrt.WinUI3\UwpTap.StaticCrt.WinUI3.vcxproj`
- `OneCore.StaticCrt\UwpTap.OneCore.StaticCrt[.WinUI3]\*.vcxproj`
- Build command: `Invoke-Build.ps1 -Project <vcxproj> -Platform x64 -NoProjectReferences`.

**MAUI TAP**
- `MauiTap.csproj` is netstandard2.0, SDK glob (no projitems), built against MAUI 6.0.312 reference DLLs, defines `MAUI_TAP`, and is listed in `Shared\Source\traversal.props`.
- Helpers in TapAgentToolsService.cs: `FindWindow`, `IsEffectivelyVisible`, `GetDoubleProperty`, `InvokeOnDispatcher` (~581).
- `objectIdentityService.GetHandle(object)` and `GetObject(long)` are available.

**Tool parameters**
- `string[]` parameters work in CopilotFunction.
- Avoid object arrays; use strings such as `"Prop=Value"` or `"x,y"`.

**Planned list inputs**
- `get_element_properties` and `get_element_styles`: `elementIds[]`.
- `explain_property_value`: `elementIds[]` × `propertyNames[]`, capped.
- `hit_test`: `elementIds[]` plus optional `points[]`.
- `set_element_property`: `elementIds[]` plus `setters[]` and `resetProperties[]`.

**Function provider** (`XamlDiagnosticsFunctionProvider.cs`)
- Pattern: `[CopilotFunction(name, desc, CopilotConfirmationRequirement.X, Group=ToolGroup)]`.
- Read-only tools use `RunAsync(progressMessage, progress, () => service.X)`; mutating tools use `RunConfirmedAsync(..., broker, title, detail, func, ct)`.
- The `AppDescription` and `ElementIdDescription` constants reference `xaml_list_apps`.
- `xaml_hit_test`'s description says "(WPF)"; change it to all platforms.

**Service** (`XamlAgentService.cs`, approximate lines)
- ListAppsAsync 320
- GetDiagnosticsStatusAsync 374
- GetElementPropertiesAsync 769
- SetElementPropertyAsync 913
- GetElementStylesAsync 1025
- ExplainPropertyValueAsync 1105
- GetElementBoundsAsync 1306 (the batching pattern)
- InteractAsync 1397
- HitTestAsync 1434: gated as WPF-only at ~1470; change it to check `DiagnosticBits.SupportsHitTest` and make the note platform-neutral.
- GetHotReloadStatusAsync 1796
- ApplyHotReloadAsync 1904
- ListWindowsAsync 2087

**Build**
- Recreate `.vs\copilot.proj` (a Traversal project) with RuntimeHostBase, XamlTapContract, WpfCoreTap, WpfTap, Diagnostics and MauiTap.
- Build: `. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`, then check for " 0 Error(s)".

**Encoding**
- `[IO.File]::WriteAllText` strips the BOM; prefer the edit tool.
- XamlAgentService.cs has no BOM and uses CRLF.

**Contract naming**
- XamlJsonData.cs compiles into several assemblies, so new type names must not collide with RuntimeHost types (CS0433).

**Deploy and test**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- `& "$h\Redeploy.ps1"`: closes VS, deploys elevated, patches the System.Drawing.Common redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config`, and relaunches `devenv /rootsuffix Exp`. Wait about 60 s.
- `& "$h\Run-Demo.ps1" -Name X -Tag runN`: output goes to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`. Use `node $h\peek.js events.jsonl` for a timeline.
- Run `KeepAwake.ps1` async during tests.
- If the RDP window is minimized, SendKeys and CopyFromScreen fail.

**Constraints**
- Demo apps are WPF only, so WinUI/UWP/MAUI are only checked by compiling.
- Skill examples use generic names.
- Never push, rebase or amend; offer a single local commit at the end.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`**
  - Native WinUI/UWP TAP: the new HandleElementHitTest (~2445–2820), the registration at 303, and the resource handle fixes (~2112, ~2309).
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.h`**
  - Handler declaration at line 114.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.HitTest.cs`** (new) and **`TapAgentToolsService.cs`** (registration ~67)
  - The MAUI hit test.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs`**
  - The WPF reference implementation.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`** (~637–770)
  - The ElementHitTest contract field names.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
  - Implementation of every tool. Needs list inputs, GetStatusAsync, and the SupportsHitTest gate.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`** (34.6 KB)
  - Tool definitions. Lines 1–200 were viewed; list_apps is ~52, diagnostics_status ~62, hit_test ~200.
- **SKILL.md**, **`references\xaml-authoring.md`**, **`Diagnostics\Documentation\copilot-tools.md`**
  - Docs to update.
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`**
  - Log this round as findings #71+ and new run rows, including the native resource handle-space bug fix.
</important_files>

<next_steps>
1. Read the `nativebuild` shell result for WinUI3. Confirm UwpTap.cpp actually compiled rather than hitting the cache: look for UwpTap.cpp in the logs, or rebuild with `-NoCache` if needed. Fix any errors. Optionally compile the OneCore variants, which have no HWND path.
2. Update SQL: cap-bit, native-hittest and maui-hittest set to done.
3. **host-lists:**
   - add array inputs to properties, styles, explain, hit_test and set_property, returning per-item results and errors;
   - gate HitTestAsync on `DiagnosticBits.SupportsHitTest`, with a fallback message for older TAPs;
   - make the descriptions platform-neutral.
4. **get-status:**
   - add `xaml_get_status(app?)`, combining apps, debugger state, windows, diagnostics issues and hot reload state;
   - remove `xaml_list_apps`, `xaml_get_diagnostics_status`, `xaml_list_windows` and `xaml_get_hot_reload_status`;
   - grep and update every reference to them (hints, AppDescription, ElementIdDescription, SKILL.md, docs, harness prompts.json).
5. **docs-skill:** update the SKILL.md tool table and workflows, copilot-tools.md (564 on all platforms, SupportsHitTest bit, list inputs) and the tool count.
6. **build-deploy:**
   - recreate `.vs\copilot.proj`, including MauiTap;
   - build until 0 errors;
   - check that Redeploy.ps1 deploys what's needed;
   - restore BOMs.
7. **retest:**
   - start KeepAwake and check the desktop is unlocked and rendering;
   - re-run GhostClicks, PrecedenceWars, BindingStorm, A11ySweep, VanishingSave and others;
   - compare tool call counts against earlier runs;
   - log everything in TestPass.md.
8. **Wrap up:**
   - stop KeepAwake and delete `.vs\copilot.proj`;
   - remind the user about UAC, the redirect patch (PR 807376) and the language service assert;
   - offer a single local commit;
   - ask about skill updates;
   - call task_complete.
</next_steps>