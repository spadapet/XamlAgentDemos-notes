<overview>
The user is building Copilot "XAML Diagnostics" agent tools for Visual Studio:
- `xaml_*` functions in Diagnostics.dll;
- new TAP messages handled inside the running app;
- a built-in skill, SKILL.md.

All 17 WPF demo apps were tested autonomously in the fastmain Exp hive, and every run is logged in the notes repo.

Current request, in autopilot (decide without asking, verify, then task_complete):
- add list (batch) inputs to the tools;
- fold the four status tools into one `xaml_get_status`;
- do NOT merge the binding or accessibility tools yet;
- implement the new WPF TAP functionality (hit test, null background) for WinUI, UWP and MAUI where possible;
- keep demo apps WPF only, update them if needed, re-run the tests, and log the results.
</overview>

<history>
1. **Earlier segments:** planned and implemented the tools, the skill and a test harness. Ran all 17 demos. Findings #1–62 are in `Q:\source\XamlAgentDemos-notes\TestPass.md`.

2. **"New test cases, more robust tools, SKILL.md XAML authoring guidance":**
   - Implemented:
     - `xaml_hit_test` (WPF, TAP message 564, types `ElementHitTest*`);
     - find_elements wildcards and `namedOnly`;
     - a note on `xaml_interact` that automation invoke bypasses hit testing;
     - the `nullBackground` flag on hit-test results;
     - `lastHotReloadUpdate` tracking. The host subscribes once to `IMarkupChangeProcessingInformation.Changed` (fully qualified as `RuntimeHost.Pipeline.IMarkupChangeProcessingInformation`) in `GetHostAsync` and reports the time in apply_hot_reload's noChange result and in get_hot_reload_status;
     - the skill and authoring reference additions.
   - Build: 0 errors, deployed.
   - GhostClicks run3 passed and verified the fixes live with hit_test. Run4 aborted because the RDP session stopped rendering (SendKeys and CopyFromScreen failed).
   - Logged in TestPass.md: run3 and run4 rows, findings #63–70, and a "Proposed new test cases" section.
   - Updated copilot-tools.md and SKILL.md for nullBackground and lastHotReloadUpdate.
   - Stopped KeepAwake and deleted `.vs\copilot.proj`. Called task_complete.

3. **User asked whether tools can be combined, and whether the TAP changes reached all platforms.**
   - Answered:
     - there are 23 tools;
     - proposed batching and consolidation;
     - hit test (564) is WPF only;
     - element capture works on WinUI/UWP but not WPF or MAUI.

4. **User asked whether merging would hurt tool selection.**
   - Answered: batching is safe; merging behind mode parameters hides capabilities.
   - Recommended:
     - list inputs on the existing tools;
     - fold the four status tools into one;
     - keep distinct tools with question-first descriptions;
     - about 18 tools in total.

5. **Current request:** implement list inputs, `xaml_get_status`, no binding/accessibility merge, WinUI/UWP/MAUI parity, update test apps, re-run tests.
   - Created SQL todos:
     - cap-bit
     - native-hittest
     - maui-hittest
     - host-lists
     - get-status
     - docs-skill
     - build-deploy
     - retest
   - Dependencies: native and maui depend on cap-bit; build-deploy depends on everything; retest depends on build-deploy.
   - Added the `SupportsHitTest = 0x40` capability bit everywhere (details below). Restored UTF-8 BOMs that `[IO.File]::WriteAllText` had stripped.
   - Started researching the native hit test. Found that `UwpTap\Designer\HitTestService.cpp` already uses `VisualTreeHelper::FindElementsInHostCoordinates(point, root, includeAllElements)`. Also found `InAppUI\HitTestHelper.cpp` (GetParent, clipping logic near lines 166–190), and UwpTap.cpp bounds code (~1583) to use as a template.
</history>

<work_done>
All changes are uncommitted in `Q:\src\VS_xaml`.

From the previous round (built and deployed):
- `XamlAgentService.cs`
- `XamlDiagnosticsFunctionProvider.cs`
- `TapAgentToolsService.HitTest.cs` (new)
- `TapAgentToolsService.cs` (WPF)
- `WpfTapItems.projitems`
- `XamlMessageType.cs` (564)
- `XamlJsonData.cs` (ElementHitTest* types, NullBackground)
- `SKILL.md`
- `references\xaml-authoring.md`
- `copilot-tools.md`

This round (not built yet):
- `Shared\Source\TapContract\TapOM\DiagnosticBits.cs`: added `SupportsHitTest = 0x40` with a doc comment (outside the `#if`).
- `Shared\Source\UwpTap\DiagnosticBits.h`: `SupportsHitTest = 0x40`.
- `Shared\Source\UwpTap\XamlMessageType.h`: `ElementHitTestRequest = 564`.
- `Shared\Source\UwpTap\UwpTap.cpp` ~line 312: status now `SupportsAgentTools | SupportsHitTest`. **The 564 handler is NOT written yet**, so the flag is set without a handler. Must add the handler or revert before building.
- `MauiTap\VisualTreeService\VisualTreeService.cs` ~line 90: sets SupportsHitTest. **The MAUI handler is NOT written yet.**
- `WpfTap\WpfVisualTreeService\VisualTreeService.cs` ~line 86: sets SupportsHitTest.
- `XamlTapContract\Networking\XamlMessageType.cs`: 564 comment now says "Only send when the platform has DiagnosticBits.SupportsHitTest." BOM restored.

Todo status:
- [x] cap-bit, done in files (SQL status not yet updated)
- [ ] native-hittest
- [ ] maui-hittest
- [ ] host-lists
- [ ] get-status
- [ ] docs-skill
- [ ] build-deploy
- [ ] retest
</work_done>

<technical_details>
**Tool parameters**
- `string[]` parameters work in CopilotFunction (as in `xaml_get_element_bounds`'s `elementIds`).
- Object-array parameter support is unverified. Avoid it: use `string[]` such as `setters: ["Background=Red"]` or `points: ["10,5"]`.
- Planned list inputs:
  - `get_element_properties`, `get_element_styles`: `elementIds[]`.
  - `explain_property_value`: `elementIds[]` × `propertyNames[]`, capped.
  - `hit_test`: `elementIds[]` plus optional `points[]`; each point is relative to each element.
  - `set_element_property`: `elementIds[]` plus `setters[]` ("Prop=Value") and `resetProperties[]`.
  - `xaml_interact` stays single, or optionally gets steps.

**Function provider** (`XamlDiagnosticsFunctionProvider.cs`, 450 lines)
- Each tool is a `[CopilotFunction(name, desc, CopilotConfirmationRequirement.X, Group=ToolGroup)]` method.
- Read-only tools use `RunAsync(progressMessage, progress, () => service.X)`.
- Mutating tools use `RunConfirmedAsync(..., broker, title, detail, func, ct)`.
- `AppDescription` refers to xaml_list_apps; update it when folding into xaml_get_status.

**Service methods** (XamlAgentService.cs line numbers):
- ListAppsAsync 320
- GetDiagnosticsStatusAsync 374
- GetElementPropertiesAsync(elementId, nameFilter, includeAll) 769
- SetElementPropertyAsync 913
- GetElementStylesAsync 1025
- ExplainPropertyValueAsync 1105
- GetElementBoundsAsync 1306, which shows the batching pattern: group by endpoint, per-item errors
- InteractAsync 1397
- HitTestAsync 1434
  - WPF-gated at ~1470 with `endpoint.Platform.Platform is not (WpfFramework or WpfCore)`;
  - change this to check `DiagnosticBits.SupportsHitTest`;
  - note text mentions "WPF InputHitTest".
- GetHotReloadStatusAsync 1796
- ApplyHotReloadAsync 1904
- ListWindowsAsync 2087

**Native TAP (UwpTap.cpp, 2655 lines)**
- Handlers are registered at ~285–302 with `m_protocolHandler.Register(XamlMessageType::X, this, &WindowsXamlDiagnosticsTap::HandleX)`. Each handler is a member `value HandleX(value request)` and must be declared in the header (find the `HandleGetElementBounds` declaration in UwpTap.h).
- Pattern for running work on the element's UI thread:
  - `ObjectIdentifier id(handle); auto dispatcher = GetDispatcher(id); WinrtRunOnUIThread(dispatcher, DispatcherPriority::Normal, [&]{...})`;
  - inside, `m_identityService->TryGetObject<xaml_winrt::UIElement>(id)`;
  - JSON via `ToJSON` and `info[L"Field"]`;
  - errors via `CurrentExceptionMessage()`;
  - namespace alias `xaml_winrt` (WinUI3 vs UWP via `#ifdef WINUI3`).
- Helpers in the anonymous namespace ~1490: `FormatDouble` and `CreateAutomationPeer`.
- `winrt::VisualTreeHelper::GetParent` is used at ~2068.
- For handles of hit elements, need the identity service's "get handle for object". Look at how other code gets a handle (for example the resource owner code ~2330+).
- Plan for the native hit test:
  - Point: `element.TransformToVisual(nullptr).TransformPoint(local)`.
  - InputTarget: the first result of `FindElementsInHostCoordinates(pt, rootContent, false)`.
  - Stack: the same results (max 15).
  - Blockers: walk parents for Visibility, IsHitTestVisible, `Control.IsEnabled`, Opacity 0.
  - NullBackground: Panel, Border or Control Background == nullptr.
  - VisibleFraction: approximate through ancestor RenderSize/Clip intersection, as in InAppUI HitTestHelper ~166–190.
  - TemplatedParent: walk to a Control ancestor; this may be omitted.
- Response field names must match the C# `ElementHitTestResponse` DataMembers: RootX, RootY, ScreenX, ScreenY, PointInsideElement, InputTarget{Handle,TypeName,Name,TemplatedParent,Property,Value}, ElementReceivesInput, Stack, IsVisible, IsHitTestVisible, IsEnabled, EffectiveOpacity, NullBackground, Blockers, VisibleFraction, ClippedBy, Error.
- Request fields: Handle, UsePoint, X, Y.

**MAUI TAP** (`MauiTap\AgentTools\TapAgentToolsService.cs`, 594 lines)
- Register via `this.cookies.Add(this.protocolHandler.RegisterMessageObserver<Req, Resp>(XamlMessageType.X, this.HandleX))` (~55–65).
- `InvokeOnDispatcher(target, action)` ~581.
- `objectIdentityService.GetObject(handle)`; targets are `BindableObject` / `VisualElement`.
- Plan:
  - blockers from IsVisible, InputTransparent, IsEnabled, Opacity;
  - NullBackground from Layout/Border Background/BackgroundColor null;
  - stack from `VisualTreeElementExtensions.GetVisualTreeElements(window, x, y)` if available;
  - screen coordinates approximate.
- New file `TapAgentToolsService.HitTest.cs` in MauiTap/AgentTools. Check whether MauiTap uses a projitems or a glob.

**Build**
- Run from `Q:\src\VS_xaml`; success shows " 0 Error(s)" in `.vs\diag.txt`:
  `. src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project .vs\copilot.proj -NoRestore -NoProjectReferences *> .vs\diag.txt`
- `.vs\copilot.proj` was deleted and must be recreated. It is a Traversal project with RuntimeHostBase, XamlTapContract, WpfCoreTap, WpfTap (Framework) and Diagnostics. Add the UwpTap/WinUI TAP native projects and the MauiTap project; find their project files first.
- In PowerShell, set `[Environment]::CurrentDirectory` or use absolute paths with `[IO.File]`.
- Don't name a helper function `R` (it's an alias for Invoke-History).

**Encoding**
- `[IO.File]::WriteAllText` strips the BOM. Prefer the edit tool, or restore the BOM afterwards; a restore loop compared against `git show HEAD:<file>`.
- XamlAgentService.cs: no BOM, CRLF.

**Contract naming**
- XamlJsonData.cs compiles into RuntimeHostBase, XamlTapContract and WpfTap.
- New type names must not collide with RuntimeHost types (CS0433 earlier with HitTestRequest).

**Deploy and test**
- `$h = C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\files\harness`
- Deploy: `& "$h\Redeploy.ps1"`. It:
  - closes VS;
  - deploys elevated;
  - patches the System.Drawing.Common redirect to 10.0.0.0 in `C:\vs\fastmain\Common7\IDE\devenv.exe.config` (temporary until PR 807376);
  - relaunches `devenv /rootsuffix Exp`.

  Wait about 60 s afterwards. Redeploy may need updating to include the native and MAUI TAP DLLs (check what it copies).
- Run: `& "$h\Run-Demo.ps1" -Name X -Tag runN`. It sends the prompt from prompts.json plus 7 follow-up questions, and writes output to `Q:\source\XamlAgentDemos-notes\test-runs\<Name>\<Tag>`. Use `node $h\peek.js events.jsonl` for a timeline.
- `prompts.json` and the harness may reference old tool names.
- KeepAwake: `& "$h\KeepAwake.ps1"`, run async; stop it at the end.
- Lock and render checks:
  - lock: `OpenInputDesktop`;
  - rendering: CopyFromScreen "handle is invalid" means the RDP window is minimized, which makes SendKeys fail. It can't be fixed from inside the session; the user must restore the RDP window.

**Other constraints**
- Demo apps are WPF only (user decision), so WinUI/UWP/MAUI are only checked by compiling.
- Skill examples must use generic names, not demo names.
- Git: never push, rebase or amend. Offer a single local commit at the end.
</technical_details>

<important_files>
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**
  - Implementation of every tool.
  - Needs: list-input versions of the methods; a new GetStatusAsync combining ListApps, DiagnosticsStatus, ListWindows and HotReloadStatus; HitTestAsync gated on SupportsHitTest instead of WPF; hints that reference old tool names updated.
  - Lines listed above.
- **`Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**
  - Tool definitions.
  - Needs: removing list_apps, get_diagnostics_status, list_windows and get_hot_reload_status in favor of xaml_get_status; array parameters; question-first descriptions.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`** (and its header)
  - Native WinUI/UWP TAP. Add `HandleElementHitTest` and register it near line 302.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\Designer\HitTestService.cpp`** (~226–256) and **`InAppUI\HitTestHelper.cpp`** (~166–190, 275)
  - Reference code for native hit testing and clipping.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.cs`**
  - MAUI TAP. Register the 564 handler; add a HitTest partial file.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.HitTest.cs`**
  - Reference WPF implementation to mirror.
- **`Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`** (~637–770)
  - ElementHitTest contract.
- **`TapContract\TapOM\DiagnosticBits.cs`** and **`UwpTap\DiagnosticBits.h`**
  - The new SupportsHitTest bit.
- **`SKILL.md`**, **`references\xaml-authoring.md`**, **`Diagnostics\Documentation\copilot-tools.md`**
  - Must reflect xaml_get_status, list inputs, and hit test on all platforms.
- **`Q:\source\XamlAgentDemos-notes\TestPass.md`** (152 lines)
  - Results table, findings #1–70, proposed test cases.
  - Log this round as findings #71+ and new run rows.
</important_files>

<next_steps>
1. Update SQL: set `cap-bit` to done.
2. **native-hittest:** write `HandleElementHitTest` in UwpTap.cpp, declare it in the header and register it. Check the WinUI3 TAP project compiles the same file.
3. **maui-hittest:** add the MAUI handler and register it. Check whether a projitems entry is needed.
4. **host-lists:**
   - convert the service and provider methods to array inputs, with per-item results and errors;
   - group TAP calls by endpoint where possible;
   - change the HitTestAsync gate to `DiagnosticBits.SupportsHitTest`, with a fallback message for older TAPs;
   - change the note wording to be platform-neutral.
5. **get-status:**
   - add `xaml_get_status` with optional `app`;
   - return apps, debuggerState, windows per app, diagnostics issues and fixes, and hot reload state (options, errors, lastHotReloadUpdate);
   - remove the four old functions;
   - grep for every "xaml_list_apps", "xaml_get_diagnostics_status", "xaml_list_windows" and "xaml_get_hot_reload_status" reference (hints, AppDescription, SKILL.md, docs, harness prompts) and update them.
6. **docs-skill:** update the SKILL.md tool table and workflows, copilot-tools.md (564 now on all platforms, SupportsHitTest bit), and the tool count.
7. **build-deploy:**
   - recreate `.vs\copilot.proj`, adding the native TAP (UWP and WinUI3) and MauiTap projects;
   - build until 0 errors;
   - check Redeploy.ps1 deploys the changed TAP binaries;
   - restore BOMs on edited files.
8. **retest:**
   - start KeepAwake and check the desktop is unlocked and rendering;
   - re-run GhostClicks, PrecedenceWars, BindingStorm, A11ySweep and VanishingSave paused2, plus others if time allows;
   - compare tool call counts against earlier runs;
   - update demo apps or prompts if needed (WPF only);
   - log everything in TestPass.md.
9. Wrap up:
   - stop KeepAwake and delete `.vs\copilot.proj`;
   - remind the user about UAC, the redirect patch (PR 807376) and the language service assert;
   - offer a single local commit;
   - ask about skill updates;
   - call task_complete with a summary.
</next_steps>