<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to Copilot AI, so models can diagnose, debug, and fix running XAML apps through VS and the injected TAP. That covers:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images
- binding failures
- the accessibility checker
- Hot Reload
- app and platform discovery
- explanations of why a feature is unavailable

The plan (in plan.md in the session folder) is approved and is being implemented as a prototype ("whatever works most easily"). The approach is in-proc Copilot agent-mode tools plus a built-in skill, all in the Diagnostics DLL, with a few capability-gated new TAP messages. WPF is done first, then WinUI/UWP, then MAUI. The user has now asked to implement **both** the WinUI/UWP and MAUI TAP support before committing.
</overview>

<history>
1. **Earlier segments**:
   - Planned and got approval.
   - Implemented the plumbing, 18 `xaml_*` tools, the skill plus references, the Copilot registration (FirstPartyToolsProvider, not compiled locally), and the hot reload log buffer.
   - Phase 3 contract: message types 560/561, payloads, and the `SupportsAgentTools` bit.
   - WPF TAP handler `TapAgentToolsService` and the host-side `GetElementBoundsAsync`/`InteractAsync`.
   - Everything builds.
2. **This segment**:
   - Implemented the **in-app Copilot re-route**: `AgentTools\XamlInAppCopilotExtension.cs`. Fixed the build errors:
     - `IVsFeatureFlags` lives in `Microsoft.Internal.VisualStudio.Shell.Interop`.
     - `Package` is ambiguous; use `Shell.Package`.
     - The ISB001 analyzer requires the `using` to wrap the proxy before the null check.
   - Diagnostics builds.
   - Added unit tests in `Test\Unit\AgentTools\XamlAgentToolsTests.cs`. Building them first failed because the msrustup restore broke. Fixed that by resetting PSModulePath, then built with project references (~9 min). **All 4 tests pass.**
   - Added `Documentation\copilot-tools.md` and a README link.
   - Marked the SQL todos `inapp-reroute` and `docs-tests` done.
   - Asked the user about the next step; they chose **"both"**: implement the WinUI/UWP and MAUI TAP support, then commit.
   - Started UwpTap research. Message registration is in `UwpTap.cpp` around lines 275-288, for example:
     - `m_protocolHandler.RegisterWithoutErrorHandling(XamlMessageType::RenderTargetBitmapRequest, bind(&WindowsXamlDiagnosticsTap::HandleRenderTargetBitmapRequest, this, _1));`
     - `m_protocolHandler.Register(XamlMessageType::MapAccessibilityErrorsRequest, this, &WindowsXamlDiagnosticsTap::HandleMapAccessibilityErrors);`

     Handler declarations are in `UwpTap.h` (~line 100), and `HandleRenderTargetBitmapRequest` is at `UwpTap.cpp:792`. Message IDs are in `UwpTap\XamlMessageType.h`; 560/561 were already added there.
</history>

<work_done>
All paths are under `Q:\src\VS_xaml`.

Done and building (Diagnostics, RuntimeHostBase, DiagnosticsBase, WpfTap, WpfCoreTap, and the Unit tests):

- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`: `XamlAgentService.cs`, `XamlDiagnosticsFunctionProvider.cs` (18 tools), `XamlAgentImaging.cs`, `XamlAgentException.cs`, `XamlHotReloadLogBuffer.cs`, `XamlDiagnosticsSkillsProvider.cs`, the skills (SKILL.md plus 2 references), and the **new** `XamlInAppCopilotExtension.cs`.
- **New** `XamlInAppCopilotExtension.cs`:
  - `[Export(typeof(ICopilotExtension))]`.
  - Feature flag `Xaml.Diagnostics.InAppCopilotChat`, default true.
  - `IsCopilotAvailable` = flag && signed-in UIContext `87453937-35de-4ecd-9aec-ff07d343d777`.
  - `StartSession`/`EndSession` ref-count a UIContextChanged subscription that raises `SessionChanged(StatusChanged)`.
  - `SendCopilotRequestAsync` gets `ICopilotService` via `SVsBrokeredServiceContainer`.
    - Backend mode: `CreateSessionAsync`, then `SendRequestAsync`. Images become `CopilotImageAttachment`; existing paths become `CopilotFileAttachment`. `DisplayPrompt` is the user's text.
    - Legacy mode: `StartThreadAsync` plus a `CopilotRequest` markdown prompt, with no images.
    - Returns a TAP `CopilotResponse` (Success/Failure).
  - `internal static BuildModelPrompt(prompt, paths)`.
  - Reject and feedback are no-ops.
- **New** `src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: 4 tests covering the log ring buffer cap, GetHotReloadLog filtering/limit, the empty hint, and BuildModelPrompt. All pass.
- **New** `src\Xaml\Diagnostics\Documentation\copilot-tools.md`. `README.md` links to it (after the MAUI startup diagnostics line).
- Earlier items:
  - Diagnostics.csproj Content glob and files.swr.
  - `VisualStudioXamlDiagnosticsHost.cs` logger wrap.
  - FirstPartyToolsProvider (Copilot repo).
  - Contract changes: `XamlMessageType.cs`/`.h` (560/561), `DiagnosticBits.cs` (`SupportsAgentTools = 0x20`), `DiagnosticBits.h` comment, `WpfDiagnosticPlatform.cs` bit, and the `XamlJsonData.cs` ElementBounds*/ElementAutomationAction* DataContracts.
  - WpfTap: `AgentTools\TapAgentToolsService.cs`, projitems, and the `DiagnosticVisualTreeService` wiring.

SQL todos:
- All done except `tap-winui` (now starting) and `tap-maui` (pending).

Not done:
- WinUI/UWP and MAUI TAP handlers.
- Runtime/E2E testing.
- The final commit.
</work_done>

<technical_details>
**Build**
- Leaf build:
  ```
  cd Q:\src\VS_xaml; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> -NoProjectReferences [-NoRestore]
  ```
  Filter output with `Select-String`.
- **Don't use `Select-Object -First N` on build output.** It ends the pipeline while MSBuild keeps running in the background and locks the `.err` log, which caused an MSB4104 error on the next build. Use `-Last` or no limit instead.
- **msrustup restore failure fix**: before building, set
  ```
  $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"
  ```
  The cause is that pwsh 7's Archive module leaks into the powershell.exe 5.1 `Expand-Archive` (MethodCountCouldNotFindBest). This likely also fixes the Copilot.Vsix restore.
- Unit tests:
  - The output exe is `out\tests\x86chk\DesignTools.Tests.Unit.XamlDiagnostics\DesignTools.Tests.Unit.XamlDiagnostics.exe`.
  - Run with `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter <name>`.
  - Tests use `[Test]` from `DesignTools.Tests.Foundation`, derive from `UnitTestClass`, and use FluentAssertions with xUnit v3.
  - Anonymous result objects are read via reflection.
- Build order: RuntimeHostBase → DiagnosticsBase → WpfTap → WpfCoreTap → Diagnostics. WpfTap/WpfCoreTap need a restore.

**Native builds (from the building-locally skill)**
- Compile the owning vcxproj/nativeproj with `-NoProjectReferences -NoRestore`, then filter the .err file to your own changed files. IntelliSense isn't a compile gate.
- The `IfFail*` macros need `HRESULT hr;` declared.

**TAP facts**
- An unknown message gets no reply. That's why the `SupportsAgentTools` capability bit plus the 10 s timeout are needed.
- Host-side DiagnosticBits 0x4+ are hard-coded per platform on the host (e.g., `WpfDiagnosticPlatform.cs`). WinUI/UWP and MAUI platform classes need the bit added once their TAP supports the messages.
- `XamlAgentService.ThrowIfAgentToolsUnsupported` checks the bit.

**Payloads (`XamlJsonData.cs`)**
- `GetElementBoundsRequest {handles[]}` → per element: handle, isVisible, screen rect (physical px), window-relative rect (DIPs), window handle, dpiScale, error.
- `ElementAutomationActionRequest {handle, action, value}` → success/error.
- Check the exact field names in `XamlJsonData.cs` and `WpfTap\AgentTools\TapAgentToolsService.cs` before implementing C++/MAUI. The UwpTap C++ JSON uses `value request` (cpprest/json-like) parsing.

**WPF implementation reference**
- Bounds: TransformToAncestor, PointToScreen, and `TransformToDevice` for DPI.
- Actions go through AutomationPeer patterns: invoke, toggle, select, add/removeSelection, expand, collapse, setValue/setText, focus, scrollIntoView.
- It runs on the element's dispatcher.
- WinUI equivalents:
  - Bounds: `TransformToVisual(nullptr)`, `XamlRoot.RasterizationScale`, and the window HWND.
  - Actions: `FrameworkElementAutomationPeer::FromElement`, then `GetPattern(PatternInterface::Invoke…)`.
  - Run on the element's DispatcherQueue/Dispatcher.

**Other**
- Copilot type name collisions: alias `TapCopilotResponse`/`TapCopilotResponseStatus`/`TapCopilotEventKind` from `Microsoft.VisualStudio.DesignTools.RuntimeHost.TapOM`.
- Pragmas needed: `VSDIAG_API`, `VSCOPILOT_API`, `VSCOPILOT_BACKEND`.

**Constraints**
- Never push, rebase, or amend. Make a single local commit at the end with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C Q:\src\VS_xaml`.
- Use the dashed Copyright header style.
- At the end, ask the user whether to update a skill. Candidates:
  - The PSModulePath fix for msrustup.
  - `Select-Object -First` orphaning MSBuild.
  - WpfTap leaf builds need a restore.
  - A Required confirmation needs `ICopilotFunctionBroker` plus `AskConfirmationAsync`.
  - `IncludeBuiltInContributions` makes first-party tools flow into SDK agents.
  - Backend `CreateSessionAsync`/`SendRequestAsync` is how to submit a prompt plus images to chat.
</technical_details>

<important_files>
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp` / `UwpTap.h`: the native WinUI/UWP TAP. Handler registration is at ~275-288, the RTB handler pattern at ~792, and declarations in the .h at ~100. **Next to modify.**
- `src\Xaml\Shared\Source\UwpTap\XamlMessageType.h`: 560/561 are already added. `UwpTap\DiagnosticBits.h` has a comment only.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: the WPF reference implementation to port.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`: the payload DataContracts (field names to match in C++ and MAUI).
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`: the host façade. Bounds/interact are at ~697-823, and `ThrowIfAgentToolsUnsupported` is at ~702.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`: the tool descriptions say "Supported for WPF apps" (~127-139). Update them once WinUI/MAUI are supported. The same applies to SKILL.md and copilot-tools.md.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlInAppCopilotExtension.cs`: the in-app re-route (new).
- `src\Xaml\Diagnostics\Test\Unit\AgentTools\XamlAgentToolsTests.cs`: the new tests.
- `src\Xaml\Diagnostics\Documentation\copilot-tools.md`: the new docs, including the TAP messages section to update.
- The host platform classes that set DiagnosticBits (find the WinUI/UWP/MAUI equivalents of `WpfDiagnosticPlatform.cs`).
</important_files>

<next_steps>
**Immediate: `tap-winui`.** Mark it in_progress in SQL.
1. Read `UwpTap.cpp`/`.h` to learn the handler patterns:
   - JSON parsing and building the response (look at `HandleMapAccessibilityErrors` and `HandleRenderTargetBitmapRequest`)
   - how a handle maps to an element
   - UI-thread dispatch
   - WinUI vs UWP abstractions (the TAP probably supports both via a shared code path and wrappers)
2. Add the `HandleGetElementBounds` and `HandleElementAutomationAction` handlers and register them for 560 and 561.
3. Bounds: `TransformToVisual(root)`, `XamlRoot` scale, the HWND, visibility.
4. Actions: use automation peer patterns, matching the WPF action names.
5. Find the host-side UWP/WinUI platform class and add `SupportsAgentTools` to its DiagnosticBits. Be careful: an older remote TAP would then hang until the timeout. Consider a TAP-side version or capability check if one exists.
6. Find the UwpTap vcxproj/nativeproj and compile it in isolation.

**Then: `tap-maui`.**
- Find MauiTap (`src\Xaml\...\MauiTap`). Note the existing build error: `Microsoft.Maui.Controls.HotReload.Forms.dll` was missing for Unit.Maui, which means MauiTap isn't built locally.
- Implement bounds via MAUI `VisualElement` bounds and platform views, and actions via `Button.SendClicked`, `IsToggled`, `Text`, `Focus`, etc.
- Register the messages and set the host MAUI platform bit.
- Build.

**Finally**
- Update the tool descriptions, SKILL.md, and copilot-tools.md to reflect platform support.
- Rebuild the Diagnostics and Unit tests.
- Make the single local commit with the trailers (no push).
- Ask the user about updating skills.
</next_steps>