<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers LVT, LPE, Live Preview images, binding failures, the a11y checker, Hot Reload, app/platform discovery, and explanations of why a feature is unavailable.

The approved plan (plan.md in the session folder) is being implemented as a prototype ("whatever works most easily"):
- in-proc Copilot agent-mode tools plus a built-in skill, all in the Diagnostics DLL;
- a few capability-gated new TAP messages (560 GetElementBounds, 561 ElementAutomationAction).

WPF is done. The user asked for **both** WinUI/UWP and MAUI TAP support to be implemented before the single local commit.
</overview>

<history>
1. **Earlier segments**
   - Planned the feature and got approval.
   - Implemented the plumbing, 18 `xaml_*` tools, the skill and its references, the Copilot registration, the hot reload log buffer, and the contract (560/561, payloads, `SupportsAgentTools=0x20`).
   - Implemented the WPF TAP handler `TapAgentToolsService`.
   - Implemented the in-app Copilot re-route `XamlInAppCopilotExtension.cs`.
   - Added unit tests (4 pass), `Documentation\copilot-tools.md`, and a README link.
   - The user chose "both" (WinUI/UWP + MAUI TAP), then commit.

2. **This segment: started `tap-winui`**
   - **Design change on capability negotiation.** Previously the host hard-coded `SupportsAgentTools` for WPF. It now comes from the TAP's `TapInitialized` Status bits, so older or remote TAPs never get messages they don't understand.
     - `SupportsAgentTools` moved outside the `#if !XAML_DESIGN_TOOLS_TAP_CONTRACT_DLL` block in `TapContract\TapOM\DiagnosticBits.cs`, so TAPs can report it.
     - Added the matching line (sorted) to `TapContract\PublicAPI\PublicAPI.Unshipped.txt`.
     - Host platform constructors gained an optional `DiagnosticBits tapStatus = None` parameter and OR in `(tapStatus & SupportsAgentTools)`:
       - `WpfDiagnosticPlatform` (it no longer hard-codes the bit)
       - `WinRTDiagnosticPlatform`
       - `DiagnosticsMobile\Platform\DiagnosticPlatform`
       - `DiagnosticPlatformFactory.GetPlatform(..., tapStatus)`
       - `HostDebuggerExtension.CreateMobilePlatform(..., tapStatus)`
     - Callers now pass the TAP status: `HostDebuggerExtension.OnTapInitialized` passes `payload.Status`, and `NonDebugProcessManager.RegisterEndpoint` passes `connection.DiagnosticBits`.
     - The WPF TAP (`WpfVisualTreeService\VisualTreeService.cs` ~line 86) now posts `Status = SupportsAgentTools | (HasSourceInfo ? None : SourceInfoNotAvailable)`.
   - **Native UwpTap, partly done:**
     - `UwpTap\DiagnosticBits.h`: added `SupportsAgentTools = 0x20` and updated the comment.
     - `UwpTap.h` (~110-112): declared `value HandleGetElementBounds(value)`, `value HandleElementAutomationAction(value)` and `HWND GetRootWindowHandle(const xaml_winrt::UIElement&)`.
     - `UwpTap.cpp`:
       - Registered both handlers (~290-291) with `m_protocolHandler.Register(XamlMessageType::GetElementBoundsRequest/ElementAutomationActionRequest, this, &...)`.
       - The initial status is now `DiagnosticBits::SupportsAgentTools` (~301).
     - **The handler implementations are NOT written yet**, so the build will fail until they are added.
</history>

<work_done>
Done and building in earlier segments:
- Diagnostics `AgentTools\*`: tools, service, skill, in-app re-route, log buffer.
- Unit tests.
- Docs.
- Contract.
- WPF TAP.

Modified this segment, not yet built:
- `src\Xaml\Shared\Source\TapContract\TapOM\DiagnosticBits.cs`
- `src\Xaml\Shared\Source\TapContract\PublicAPI\PublicAPI.Unshipped.txt`
- `src\Xaml\Shared\Source\WpfTap\WpfVisualTreeService\VisualTreeService.cs`
- `src\Xaml\Diagnostics\Source\Diagnostics\Tool\Platform\Wpf\WpfDiagnosticPlatform.cs`
- `src\Xaml\Diagnostics\Source\Diagnostics\Tool\Platform\Uwp\WinRTDiagnosticPlatform.cs`
- `src\Xaml\Diagnostics\Source\Diagnostics\Tool\Platform\DiagnosticPlatformFactory.cs`
- `src\Xaml\Diagnostics\Source\DiagnosticsMobile\Platform\DiagnosticPlatform.cs`
- `src\Xaml\Diagnostics\Source\Diagnostics\HostDebuggerExtension.cs` (~958, 962, 1022-1024)
- `src\Xaml\Diagnostics\Source\Diagnostics\NonDebug\NonDebugProcessManager.cs` (~283, 287)
- `src\Xaml\Shared\Source\UwpTap\DiagnosticBits.h`, `UwpTap.h`, `UwpTap.cpp`

SQL todos:
- `tap-winui` is in progress. Mark it in_progress in SQL if it isn't already.
- `tap-maui` is pending.
</work_done>

<technical_details>
**Build**
- Command:
  ```
  cd Q:\src\VS_xaml; $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> -NoProjectReferences [-NoRestore]
  ```
  The PSModulePath fix avoids the msrustup restore failure.
- Don't pipe build output to `Select-Object -First`: it orphans MSBuild and causes MSB4104 on the next build.
- Build order: RuntimeHostBase → DiagnosticsBase → TapContract/XamlTapContract → WpfTap → WpfCoreTap → DiagnosticsMobile → Diagnostics. WpfTap needs a restore.
- Unit tests: run `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter <name>`. The output exe is `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\...`.
- Native: compile the UwpTap vcxproj in isolation. The projects are:
  - `UwpTap\UwpTap.StaticCrt\UwpTap.StaticCrt.vcxproj`
  - `UwpTap\UwpTap.StaticCrt.WinUI3\UwpTap.StaticCrt.WinUI3.vcxproj`
  - the OneCore variants under `UwpTap\OneCore.StaticCrt\`

  Use `-NoRestore -NoProjectReferences`, probably also `-Platform x64`, then filter `.vs\logs\<proj>.err` for `UwpTap.cpp`. `IfFail*` macros need `HRESULT hr;`.

**Capability negotiation**
- The TAP reports bits in `TapInitialized.Status`. The host keeps only `SupportsAgentTools` from it.
- `XamlAgentService.ThrowIfAgentToolsUnsupported` (~702) checks `endpoint.Platform.DiagnosticBits`.
- An unknown message gets no reply, which is why the gate is needed.
- Possible test impact: `HostDebuggerDataBridgeTests.TapInitialized_RegistersReportedCapabilities` and the platform tests should still pass, since the new parameters are optional.

**UwpTap patterns**
- JSON is cpprest `web::json::value`. Use `request.at(L"X")`, `.as_array()`, `.as_string()`, `ToJSON(...)`, `FromJSON<ObjectIdentifier>(v)` and `value::object()`.
- Handles: `ObjectIdentifier(int64)`, `m_identityService->TryGetObject<winrt::UIElement>(id)` (returns null if missing), `GetDispatcher(id)` gives a `DispatcherHelper`, then `WinrtRunOnUIThread(dispatcher, DispatcherPriority::Normal, lambda)` returns the lambda's result.
- `Register` wraps handler exceptions into an error reply.
- `xaml_winrt` is a namespace alias: `Microsoft::UI::Xaml` when `WINUI3`, else `Windows::UI::Xaml`. `XAML_RUNTIME_CLASS(cl)` is available.
- `m_factoryProvider->GetWinrt<T>(L"RuntimeClassName")` gets activation factories/statics.
- `ROOT_MUTATIONS` (WinUI3) means `m_roots` (`unordered_map<int64, shared_ptr<UILayerManager>>`) is keyed by the XamlRoot id. `GetRootId(IUnknown*)` returns `m_identityService->GetId(element.XamlRoot(), m_identityScope).GetId()`, or 0 on non-ROOT_MUTATIONS builds.
- `UILayerManager::GetLivePreviewHwnd()` returns the top-level HWND.
- `GetDpiForWnd(HWND)` lives in `WindowsUtility.h`. Guard HWND/user32 code with `#ifndef ONECORE_BUILD`.
- Accessing XAML objects from the wrong thread throws.

**Planned WinUI/UWP implementation**
- Includes, conditional on `WINUI3`: `winrt\Microsoft.UI.Xaml.Automation.Peers.h`, `...Automation.Provider.h` and `...Media.h`, or the `Windows.UI.Xaml` equivalents.
- **Bounds:**
  - Get the peer via `FrameworkElementAutomationPeer` statics (`FromElement`/`CreatePeerForElement`; use the C++/WinRT static call or the factory provider).
  - Screen rect comes from `peer.GetBoundingRectangle()` (physical px); `IsVisible` = non-empty && `!peer.IsOffscreen()`.
  - Root rect comes from `element.TransformToVisual(nullptr).TransformBounds({0,0,ActualWidth,ActualHeight})`.
  - HWND via `GetRootWindowHandle`: WinUI3 uses `m_roots.find(GetRootId(element))`; UWP uses the single root. Fall back to 0.
  - `DpiScale` = `GetDpiForWnd(hwnd)/96`, else screen/root width ratio, else 1.
  - Per-element try/catch fills `Error`. Cap at 2000 handles.
- **Response JSON:** `{"Bounds":[{Handle, Found, IsVisible, RootWindowHandle, DpiScale, ScreenX, ScreenY, ScreenWidth, ScreenHeight, RootX, RootY, RootWidth, RootHeight, Error}]}`.
- **Action request:** `{Handle, Action, Value}`. Response: `{Error?, SupportedPatterns:[...], Result}`.
  - Actions (case-insensitive) and their providers:
    - `invoke`/`click` → `IInvokeProvider`
    - `toggle` → `IToggleProvider`, reporting `ToggleState`
    - `select`/`addToSelection`/`removeFromSelection` → `ISelectionItemProvider`
    - `expand`/`collapse` → `IExpandCollapseProvider`
    - `setValue`/`setText` → `IRangeValueProvider` when there's no Value pattern and the value is numeric, else `IValueProvider`
    - `focus` → `Control.Focus(FocusState::Programmatic)`
    - `scrollIntoView` → `IScrollItemProvider`, else `StartBringIntoView` if available
  - Get each provider with `peer.GetPattern(PatternInterface::X).try_as<...>()`.
  - Report supported patterns from a fixed list: Invoke, Toggle, SelectionItem, Selection, ExpandCollapse, Value, RangeValue, ScrollItem, Scroll, Text.
  - Run on the element's dispatcher. Mirror the error messages in WPF `TapAgentToolsService.cs`.

**MAUI notes**
- MauiTap is at `src\Xaml\Shared\Source\MauiTap`. It posts `TapInitializedEvent` in `BaseMauiAgent.cs` ~88-98 and `VisualTreeService\VisualTreeService.cs` ~85-92.
- MauiTap likely isn't buildable locally: `Microsoft.Maui.Controls.HotReload.Forms.dll` is missing.
- Host-side MAUI may come through `DiagnosticsMobile.DiagnosticPlatform`, or through `WinRTDiagnosticPlatform` for WinUI-hosted MAUI via `GetPlatform`. Both now honor `tapStatus`.

**Other gotchas from before**
- Copilot type aliases: `TapCopilotResponse` etc.
- Pragmas: `VSDIAG_API`, `VSCOPILOT_API`, `VSCOPILOT_BACKEND`.
- `IVsFeatureFlags` lives in `Microsoft.Internal.VisualStudio.Shell.Interop`.
- Use `Shell.Package` (the bare `Package` name is ambiguous).
- The ISB001 analyzer requires the `using` to wrap the proxy before the null check.

**Constraints**
- Never push, rebase or amend. Make one local commit at the end, using `git -C Q:\src\VS_xaml`, with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use the dashed copyright header.
- Afterwards, ask the user about skill updates. Candidates:
  - the PSModulePath fix for msrustup
  - `Select-Object -First` orphaning MSBuild
  - WpfTap needs a restore
  - `ICopilotFunctionBroker.AskConfirmationAsync`
  - `IncludeBuiltInContributions`
  - backend `CreateSessionAsync`/`SendRequestAsync`
  - the TAP-reported capability-bit pattern
</technical_details>

<important_files>
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`
  - Native WinUI/UWP TAP.
  - Registration at ~275-292; status at ~301.
  - Handler examples: `HandleSetPropertyRequest` ~510, `HandleRenderTargetBitmapRequest` ~795, `HandleMapAccessibilityErrors` ~1000.
  - `GetRootId` ~1370, `HighlightElement` ~1420, `GetDispatcher` ~1477.
  - **Add the three function implementations and the includes here next.**
- `src\Xaml\Shared\Source\UwpTap\UwpTap.h`: declarations added at ~110-112.
- `src\Xaml\Shared\Source\UwpTap\DiagnosticBits.h`: `SupportsAgentTools` added.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: the reference behavior and messages to port to C++ and MAUI.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` ~570-668: payload field names.
- `src\Xaml\Shared\Source\TapContract\TapOM\DiagnosticBits.cs` and `PublicAPI.Unshipped.txt`: the bit is now visible to TAPs.
- Host platform files (all now take `tapStatus`):
  - `WpfDiagnosticPlatform.cs`
  - `WinRTDiagnosticPlatform.cs`
  - `DiagnosticPlatformFactory.cs`
  - `DiagnosticsMobile\Platform\DiagnosticPlatform.cs`
  - `HostDebuggerExtension.cs`
  - `NonDebugProcessManager.cs`
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs` ~127-139: the "Supported for WPF apps" text needs updating. The same goes for SKILL.md and `Documentation\copilot-tools.md`.
- `src\Xaml\Shared\Source\MauiTap\` (`BaseMauiAgent.cs`, `VisualTreeService\VisualTreeService.cs`): the next TAP to modify.
</important_files>

<next_steps>
1. **Finish UwpTap.**
   - Add the automation/media includes, then implement `HandleGetElementBounds`, `HandleElementAutomationAction` and `GetRootWindowHandle` in `UwpTap.cpp` as planned in technical_details.
   - Build `UwpTap.StaticCrt.vcxproj` and `UwpTap.StaticCrt.WinUI3.vcxproj` (and OneCore if feasible) with `-NoProjectReferences -NoRestore`.
   - Filter the `.err` logs for `UwpTap.cpp`, and fix errors iteratively.
2. **Rebuild the managed projects** touched this segment: TapContract, WpfTap/WpfCoreTap, DiagnosticsMobile, Diagnostics. Rerun the unit tests, including the platform and HostDebuggerDataBridge tests if feasible.
3. **`tap-maui`.**
   - Add a handler service in MauiTap for 560/561:
     - bounds from `VisualElement` bounds plus the platform view;
     - actions via `Button.SendClicked`/Command, `Switch.IsToggled`/`CheckBox.IsChecked`, `Entry.Text`, `Focus`, `ScrollTo`, and so on.
   - Register it with the protocol handler.
   - Add `SupportsAgentTools` to the MauiTap `TapInitializedEvent.Status`, checking which DiagnosticBits enum MauiTap compiles against.
   - Build if possible; note the missing HotReload.Forms dependency.
4. **Update docs and descriptions.** Change the tool descriptions, SKILL.md and copilot-tools.md to cover WPF/WinUI/UWP/MAUI support and the TAP-reported capability bit.
5. **Wrap up.**
   - Mark the SQL todos done.
   - Make the single local commit with the trailers (no push).
   - Ask the user about skill updates.
</next_steps>