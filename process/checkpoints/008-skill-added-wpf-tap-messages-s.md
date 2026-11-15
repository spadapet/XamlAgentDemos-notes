<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. The features are:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images and windows
- binding failures
- the accessibility checker
- Hot Reload: status, log, and apply
- the list of apps and their platforms
- explanations of why a feature is unavailable

The plan is approved and implementation is underway. It's a prototype: "whatever works most easily". The design is in-proc Copilot agent-mode tools (a brokered `CopilotFunctionHandler`) plus a built-in skill, all in the existing Diagnostics DLL, with no dedicated agent. A few new TAP messages are added (WPF first) for element bounds and interaction.
</overview>

<history>
1. **Plan mode** (earlier): researched the codebase, wrote plan.md and SQL todos. The user approved the plan.
2. **Earlier implementation segments**:
   - Added the Copilot ProjectReference.
   - Created AgentTools (`XamlAgentService`, Imaging, Exception, HotReloadLogBuffer) and `XamlDiagnosticsFunctionProvider` (16 tools). All compile.
   - Edited FirstPartyToolsProvider in the Copilot repo.
3. **This segment**:
   - Found that `DebuggerSdkAgent` has `IncludeBuiltInContributions = true`, so the Debugger agent already gets first-party tools. **No DebuggerSdkAgent change is needed.**
   - Created the skills provider, SKILL.md, and two reference files. Added the csproj Content glob and files.swr entries.
   - Built Diagnostics: it **succeeded**, and the skill files are copied to the output under `AgentTools\skills\xaml-diagnostics\...`.
   - Tried to build Copilot.Vsix:
     - With `-NoRestore`, it failed because the assets file is missing.
     - With restore, it failed in the unrelated Rust tooling (`msrustup.proj`, Expand-Archive).
     - Instead, I hand-verified the FirstPartyToolsProvider edit: syntax matches the other entries, static init order is fine, and the existing tests in `FirstPartyToolsProviderTests.cs` aren't affected.
   - Marked SQL todos done: function-provider, readonly-tools, copilot-registration, skill, hot-reload-tools, mutation-tools.
   - Started Phase 3 (WPF TAP).
     - Confirmed that HitTest and GetElementSnapData exist only in the designer surface, not in the runtime WpfTap, so new messages are justified.
     - Added the contract pieces (message types, payloads, capability bit).
     - Was creating `WpfTap\AgentTools\TapAgentToolsService.cs`. The create failed because the directory doesn't exist.
</history>

<work_done>
All paths are under `Q:\src\VS_xaml`.

**Done and compiling (Diagnostics build succeeded before the Phase 3 contract edits):**
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`:
  - `XamlAgentService.cs`
  - `XamlAgentImaging.cs`
  - `XamlAgentException.cs`
  - `XamlHotReloadLogBuffer.cs`
  - `XamlDiagnosticsFunctionProvider.cs` (16 tools)
- **NEW** `AgentTools\XamlDiagnosticsSkillsProvider.cs`: `[CopilotSkillsProvider(@"AgentTools\skills", GuidList.UICONTEXT_DiagnosticToolWindowsAvailable)] internal sealed class : ICopilotSkillsProvider`, with `#pragma warning disable VSCOPILOT_BACKEND`.
- **NEW** `AgentTools\skills\xaml-diagnostics\SKILL.md`: frontmatter (name, description), Start here, tools table, workflows (binding failures, looks wrong, accessibility, hot reload didn't apply, LVT empty), and Rules.
- **NEW** `AgentTools\skills\xaml-diagnostics\references\enablement-and-troubleshooting.md`: how it connects, options, source info, causes of no connection, hot reload, binding failures, a11y.
- **NEW** `AgentTools\skills\xaml-diagnostics\references\xaml-authoring.md`: design-time data, bindings, hot-reload/designer-friendly code, resources, accessibility.
  - The plan's `hot-reload.md` and `platform-notes.md` weren't created. Their content was folded into enablement-and-troubleshooting.md.
- `Diagnostics.csproj` (~line 146): added `<Content Include="AgentTools\skills\**\*.md"><CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory></Content>`.
- `src\SetupPackages\Xaml\Diagnostics\core\files.swr` (after `folder "Settings"`): added `folder "AgentTools\skills\xaml-diagnostics"` with SKILL.md and a nested `folder "references"` containing the 2 md files.
- `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`:
  - `FirstPartySkills` includes "xaml-diagnostics".
  - Added the `XamlDiagnosticsToolsUIContext` Guid (line 62).
  - Added an `AllFromProviderTool` entry (~lines 259-269).
  - Hand-verified only; it can't be built because restore fails in the Rust tooling.
- `VisualStudioXamlDiagnosticsHost.cs`: the ctor wraps the hot reload logger.

**Phase 3 contract edits (not built yet):**
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs`: `GetElementBoundsRequest = 560` and `ElementAutomationActionRequest = 561`.
- `src\Xaml\Shared\Source\UwpTap\XamlMessageType.h`: the same constants, commented "Not implemented by UwpTap yet".
- `src\Xaml\Shared\Source\TapContract\TapOM\DiagnosticBits.cs`: host-only `SupportsAgentTools = 0x20` (inside `#if !XAML_DESIGN_TOOLS_TAP_CONTRACT_DLL`).
- `src\Xaml\Shared\Source\UwpTap\DiagnosticBits.h`: comment noting that the host-side bits 0x8/0x10/0x20 must not be used by the TAP.
- `src\Xaml\Diagnostics\Source\Diagnostics\Tool\Platform\Wpf\WpfDiagnosticPlatform.cs`: adds `DiagnosticBits.SupportsAgentTools`.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (after `MapAccessibilityErrorsResponse`, ~line 569) adds these DataContracts:

  | Class | Members |
  |---|---|
  | `ElementBoundsRequest` | `List<long> Handles` |
  | `ElementBoundsInfo` | Handle, Found, IsVisible, RootWindowHandle, DpiScale, ScreenX/Y/Width/Height (physical px), RootX/Y/Width/Height (DIPs relative to root), Error |
  | `ElementBoundsResponse : ResponseWithError` | `List<ElementBoundsInfo> Bounds` |
  | `ElementAutomationActionRequest` | Handle, Action, Value |
  | `ElementAutomationActionResponse : ResponseWithError` | `List<string> SupportedPatterns`, `string Result` |

**In progress:**
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`. The directory must be created first (`New-Item -ItemType Directory`), then the file created again. The full content was drafted:
  - namespace `Microsoft.VisualStudio.DesignTools.WpfTap.AgentTools`; `internal sealed class TapAgentToolsService : IDisposable`
  - ctor `(IProtocolHandler, IObjectIdentityService)` registers `RegisterMessageObserver<ElementBoundsRequest, ElementBoundsResponse>(XamlMessageType.GetElementBoundsRequest, ...)` and the equivalent for the automation action. Dispose unregisters the cookies.
  - Bounds: `objectIdentityService.GetObject(handle) is Visual`. On the element's dispatcher it gets:
    - `PresentationSource.FromVisual`
    - `TransformToAncestor(source.RootVisual)` with `RenderSize`
    - `PointToScreen` for (0,0) and the bottom-right corner
    - `CompositionTarget.TransformToDevice.M11` as the DPI scale
    - the HWND from `HwndSource`
    - `IsVisible`
    - It caps each request at 2000 handles.
  - Action: creates a peer via `UIElementAutomationPeer.CreatePeerForElement` or `ContentElementAutomationPeer.CreatePeerForElement`, and lists supported patterns by enumerating `PatternInterface`. Supported actions:

    | Action | Implementation |
    |---|---|
    | invoke / click | `IInvokeProvider` |
    | toggle | `IToggleProvider` |
    | select / addToSelection / removeFromSelection | `ISelectionItemProvider` |
    | expand / collapse | `IExpandCollapseProvider` |
    | setValue / setText | `IValueProvider`, or `IRangeValueProvider` with an invariant double |
    | focus | `UIElement.Focus()` or `ContentElement.Focus()` |
    | scrollIntoView | `IScrollItemProvider`, or `FrameworkElement.BringIntoView` |

    A missing pattern throws `InvalidOperationException`, which is caught into `response.Error`. It uses the `Dispatcher.Invoke` helper.
  - Usings: `System.Windows.Automation`, `.Peers`, `.Provider`, `System.Windows.Interop`, `System.Windows.Media`, `System.Windows.Threading`, `TapContract.Networking`, `WpfTap.WpfVisualTreeService`, `XamlTapContract.Networking`, `XamlTapContract.TapOM`.

SQL todos:
- done: plumbing, function-provider, readonly-tools, copilot-registration, skill, hot-reload-tools, mutation-tools
- pending: tap-wpf (in progress), inapp-reroute, tap-winui, tap-maui, docs-tests
</work_done>

<technical_details>
**Build**
- Run these in one PowerShell call from `Q:\src\VS_xaml`:
  ```
  & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null
  & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <csproj> -NoProjectReferences -NoRestore
  ```
  Pipe the output through `Select-String "error|Build succeeded|-> "`.
- Diagnostics output: `out\binaries\x86chk\bin\netsdk\Xaml\Diagnostics\net472\`.
- WpfTap projects:
  - `src\Xaml\Shared\Source\WpfTap\Framework\WpfTap.csproj`
  - `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj`
  - the shared items file `WpfTapItems.projitems`, which uses `<Compile Include="$(TapRoot)AccessibilityChecker\TapAccessibilityCheckerService.cs" />` (line 28). The new file needs `<Compile Include="$(TapRoot)AgentTools\TapAgentToolsService.cs" />` there.
- Contract changes also affect the XamlTapContract/TapContract projects (netstandard2.0) and DiagnosticsBase. Leaf-build those that are touched; restore may be needed.
- Copilot.Vsix can't be restored locally (msrustup failure).

**TAP facts**
- `IProtocolHandler.RegisterMessageObserver<TReq,TResp>(type, Func)` replies synchronously.
  - `RegisterAsyncMessageObserver` exists only on the concrete ProtocolHandler, not the interface.
  - An unknown message gets no reply, so the host would hang. That's why the capability bit plus the 10 s timeout in `XamlAgentService.SendTapMessageAsync` (which throws `TapTimeout`) matter.
- Host DiagnosticBits 0x4+ are hard-coded per platform host-side (WpfDiagnosticPlatform, WinRTDiagnosticPlatform, DiagnosticsMobile DiagnosticPlatform). They aren't advertised by the TAP. The TAP only sends 0x1/0x2 in TapInitializedEvent.
- The WPF TAP wiring point is `DiagnosticVisualTreeService.Initialize` (`WpfTap\WpfVisualTreeService\DiagnosticVisualTreeService.cs`):
  - It creates `TapAccessibilityCheckerService(protocolHandler, objectIdentityService, rootFinder, adornerProvider)` and disposes it in `Dispose(bool)`.
  - Add `this.agentToolsService = new TapAgentToolsService(protocolHandler, objectIdentityService);` and dispose it the same way.
- `IObjectIdentityService.GetObject(Int64)` and `GetHandle(object)`. PropertyService resolves on the TAP thread, then calls `Dispatcher.Invoke`.
- Payload namespace: when compiled in the TAP contract DLL it's `XamlTapContract.TapOM`, otherwise `RuntimeHost.TapOM` on the host. `ResponseWithError` has `HResult` and `Error`.
- XamlAgentService helpers:
  - `FindElement(host, elementId)` returns `(endpoint, element)`, with `element.Handle`. It's UI-thread only.
  - `SendTapMessageAsync<T>(endpoint, type, payload, ct)`
  - `GetElementId`
  - `endpoint.Platform.DiagnosticBits`
  - Error codes are in `XamlAgentErrorCodes` (include `UnsupportedPlatform` / `UnsupportedByTap` if they exist; check the file).

**Copilot API facts**
- `CopilotFunctionHandler` reflects `[CopilotFunction]` methods.
- A `Required` confirmation needs an `ICopilotFunctionBroker` parameter plus an explicit `AskConfirmationAsync` call.
- The image context uses `CopilotDescriptors.Context.Image.Moniker`.
- The skills attribute directory is relative to the assembly, and its deepest folder must be named `skills`.
- UIContext 5C69788A-62F3-42C8-880A-1A4CE40C6671 = "Debugging | DiagnosticConnectionActive".

**Constraints**
- Never push, rebase, or amend. Make a single commit at the end with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- Use the dashed Copyright header style.
- At the end, ask the user whether to update a skill. Candidates:
  - the leaf-build trick and the Copilot.Vsix restore failing on msrustup
  - Required confirmation needs a broker parameter
  - Copilot.Core context helpers aren't public
  - `IncludeBuiltInContributions` makes first-party tools flow into SDK agents

**Open questions**
- Which first-party API submits a prompt to Agent mode for the in-app re-route.
- Mapping `Endpoint.ProcessId` to an OS PID is partially solved (ContractStrings.WindowsProcessId is used).
</technical_details>

<important_files>
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: the new WPF TAP handler. Next to create, after creating the directory.
- `src\Xaml\Shared\Source\WpfTap\WpfTapItems.projitems`: add a Compile item for the new file (pattern at line 28).
- `src\Xaml\Shared\Source\WpfTap\WpfVisualTreeService\DiagnosticVisualTreeService.cs`: wire the new service in `Initialize` (~line 51) and in `Dispose`.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (~569-668): the new payloads.
- `src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs` (end): 560/561.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: the façade. Add `GetElementBoundsAsync` and `InteractAsync`. Helpers are at lines ~95-190.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`: add the `xaml_get_element_bounds` (NotRequired) and `xaml_interact` (Required, confirmation) tools.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: update the tools table and workflows for the bounds and interact tools.
- `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`: registration (not compiled locally).
- plan.md (session folder): the approved plan.
</important_files>

<next_steps>
Immediate next steps:
1. Run `New-Item -ItemType Directory Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools`, then create `TapAgentToolsService.cs` with the drafted content.
2. Add the Compile item to `WpfTapItems.projitems`. Wire the service in `DiagnosticVisualTreeService` (field, Initialize, Dispose).
3. Host side, in `XamlAgentService`:
   - `GetElementBoundsAsync(elementIds[], ct)` and `InteractAsync(elementId, action, value, ct)`.
   - Check `DiagnosticBits.SupportsAgentTools`; otherwise throw an unsupported error with a hint to use the debugger's `debugger_ui_interact` / `debugger_screenshot`.
   - Group IDs by endpoint, send via `SendTapMessageAsync`, and map to DTOs (include the elementId).
   - Optionally add `includeBounds` to `GetVisualTreeAsync`.
4. Add the provider tools `xaml_get_element_bounds` (R) and `xaml_interact` (M, `AskConfirmationAsync`), and update SKILL.md.
5. Build the TapContract/XamlTapContract (if separate), WpfTap Framework + Core, and Diagnostics. Fix errors.

Remaining work after that:
- In-app ICopilotExtension re-route.
- WinUI/UWP (native UwpTap) and MAUI TAP support for 560/561.
- Unit tests for XamlAgentService and the provider (`src\Xaml\Diagnostics\Test\Unit`; `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Test`, `Test-Xaml.ps1 -Suite diagnostics -Filter X`).
- Docs: `src\Xaml\Diagnostics\README.md` and `Documentation\copilot-tools.md`.
- Final builds, then a single commit with the trailers and no push.
- Ask the user about updating a skill.
</next_steps>