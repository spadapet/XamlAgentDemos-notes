<overview>
The user (@spadapet) wants a full feature plan, made in PLAN mode, for exposing every "XAML Diagnostics" capability in Visual Studio to Copilot AI. The capabilities are Live Visual Tree, Live Property Explorer, Live Preview images, binding failures, the accessibility checker, XAML Hot Reload state/errors/output/triggering, and the list of debugged XAML apps and their platforms. The goal is for AI to diagnose, debug, and fix running XAML apps through VS, which talks to the injected TAP DLL. The approach so far is to research the codebase and the VS Copilot extensibility, then write plan.md in the session folder, put the todos into SQL, ask clarifying questions with ask_user, and present the plan with exit_plan_mode. Nothing gets implemented until the user approves.
</overview>

<history>
1. The user asked, in [[PLAN]] mode, for a thorough implementation plan. Notes from the request:
   - The user is open to MCP, skills, or a custom agent, whichever works best.
   - The helpers must know how diagnostics and hot reload are enabled.
   - LVT should give pixel positions and properties, allow interaction and setting properties, and explain why LVT or source info is unavailable (for example, the env var is not set).
   - Preview should provide app images and the list of top-level windows.
   - Binding failures should be returned with their source locations.
   - AI should be able to run the accessibility checker.
   - Hot reload should expose errors, all option states, the ability to trigger a reload, and the Hot Reload output pane.
   - AI should see all debugged XAML apps and their platforms.
   - Docs URLs were provided.
   - Actions taken:
     - Loaded the `xaml` skill (mostly WPF UI authoring guidance, only relevant if we add VS UI) and the `repo-index` skill.
     - Shell scripts (`Get-CopilotInstructions.ps1`, `Search-FeatureIndex.ps1`) are blocked in plan mode, so features.json was read directly instead.
     - Read the Diagnostics docs (README, initialization.md, multiple-process-ui-diagnostics.md) and `src\Xaml\copilot-instructions.md`.
     - Fetched the public docs: LVT/LPE, binding failures, Live Preview, hot reload, and hot reload troubleshooting.
     - Ran 3 background explore agents (Copilot tool infra, Diagnostics host model, TAP protocol/features). All three finished and their results were read.
     - Discovered the existing in-app Copilot integration and the RenderTargetBitmapManager.
     - Was viewing the external tool-contribution examples (CMake, CppBuildInsights SDK agent, FirstPartyToolsProvider) when compaction occurred.
</history>

<work_done>
No files created or modified yet. plan.md has not been written, and no SQL todos have been inserted.

Research completed:
- [x] VS Copilot tool/agent/skill extensibility
- [x] XAML Diagnostics host model (endpoints, LVT, LPE, options, hot reload)
- [x] TAP protocol message map and per-feature data models
- [x] Existing in-app Copilot feature and render bitmap
- [ ] Optional: confirm a bounds API, accessibility checker run path, and UWP/WinUI/MAUI handler coverage. These could also be listed as plan work items instead.
- [ ] Ask the user clarifying questions with ask_user
- [ ] Write plan.md, insert todos and deps into SQL, call exit_plan_mode
</work_done>

<technical_details>
**Copilot extensibility in VS (in-repo `src\Copilot`, contracts assembly `Microsoft.VisualStudio.Copilot`)**
- Tool contract:
  - `ICopilotFunctionProvider` (src\Copilot\src\Copilot\Functions\ICopilotFunctionProvider.cs:5-28).
  - `CopilotFunctionDescriptor` (CopilotFunctionDescriptor.cs:20-141): name, description, confirmation, args, return type, and user-toggle/default-on settings (lines 91-115).
  - `[CopilotFunction]` attribute, with JSON schema generated from types (CopilotLocalFunctionDescriptorHelpers.cs:44-91).
  - Confirmation levels: NotRequired, Required, AlwaysConfirm.
  - Results are CopilotFunctionResult/ValueResult.
- Providers are usually exported as brokered services. Example: `[ExportBrokeredService(...)]` on DebuggerFunctionProvider.cs:27-47.
- Gating: `FirstPartyToolsProvider` (src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs) is a central registry.
  - `FirstPartyTools` contains NamedTool, AllFromProviderTool, and McpServerTool entries. Each has a brokered-service moniker, a tool name, an activating UIContext GUID, and an ApplicableHost.
  - `FirstPartySdkAgents` lists debugger, Reviews, and profiler.
  - `FirstPartySkills` is an empty set of "built-in skill names approved default-on". This suggests built-in skills are a supported concept.
  - `Candidates` holds HandoffAgentDescriptor entries (modernization, profiler, BuildPerfCpp, debugger, msbuild): a handoff agent with a description, responder moniker, and UIContext.
  - Changes to this file require the Copilot team's CI gates/approval.
  - `AllFromProviderTool` (the SSMS example) lets a provider own its whole tool list without VS-repo edits each time.
- External team examples:
  - src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs (24KB; not yet read).
  - src\vc\projbld\CppBuildInsights\...\BuildPerformanceSdkAgent.cs: a `[CopilotSdkAgent(name, DisplayName, Description)]` MEF class implementing `ICopilotSdkAgent` + `CopilotSdkAgentHooks`, with GetSystemPromptAsync and GetToolsAsync (fetches ICopilotFunctionProvider via brokered-service proxy). Uses `#pragma warning disable VSCOPILOT_BACKEND` because the API is experimental.
  - BuildPerformanceAgentProvider.cs (responder provider).
  - DiagnosticsHub ProfilerSdkAgent (external repo).
- Debugger UI tools: src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs.
  - Screenshot tool at lines 168-226 returns the image as **CopilotContext** (image context), not as a function result value.
  - UI tree tool at line 251 and interact tool at line 431 (UIA-based). These overlap with what XAML tools could do and are a reuse pattern for images and interaction.
- Other tool examples:
  - Debugger state: Copilot.Core\Debugging\DebuggerFunctionProvider.cs (expression eval uses AlwaysConfirm).
  - TestExplorerFunctionHandler.cs.
  - Context providers: `ICopilotContextProvider` (Copilot\Context\ICopilotContextProvider.cs:8-67) and DebuggerContextProvider.cs:22-46.
- Skills and custom agents are loaded from workspace/user files:
  - CopilotAgentSkillsLoader.cs:155-187 and CopilotAgentSkillsPaths.cs:71-90 (`.github/skills/*/SKILL.md`).
  - CopilotCustomAgentsLoader.cs; instructions come from `.github/copilot-instructions.md` and `.github/instructions`.
  - No evidence found that a component can register a built-in skill file, apart from the `FirstPartySkills` name set.
- MCP:
  - VS consumes MCP servers (ModelContextProtocol 1.0.0.0, GitHub.Copilot.SDK 1.0.26 in src\ConfigData\Packages\Copilot.props).
  - The MCP Server Manager UI lives in the extensionManager.
  - There is an in-proc loopback MCP server, `AhpVsToolMcpServer.cs`, that projects VS tools to the Agent Host Protocol client only. No general external VS MCP server was found.
  - A separate standalone "Debugger MCP Server" exists (Concord repo, src/vsdbg/mcp-debug-server; tools debugger_ui_tree, debugger_screenshot, debugger_ui_interact). It's a possible pattern or integration point for external agents such as Copilot CLI.
- Copilot team instructions (src\Copilot\.github\instructions): XML docs on public APIs; options go in ConversationsOptions + copilot.registration.json; unit tests are in src\Copilot\test; APEX tests are in src\Tests\Copilot.

**XAML Diagnostics host**
- Getting the host: load package `8291C340-36B8-4C91-8C40-CCE75398FF75`, then query `IXamlHotReloadHost` from the service provider. VS exports the implementation (VisualStudioXamlDiagnosticsHost.cs:44) as IXamlHotReloadHost via MEF. `IXamlDiagnosticsHost` (Diagnostics\Source\Diagnostics\Tool\Model\IXamlDiagnosticsHost.cs:17) extends it.
- `IXamlHotReloadHost` (DiagnosticsBase\Host\IXamlHotReloadHost.cs:14) exposes:
  - `Endpoints`, `EndpointChanged` (EndpointEventArgs IsAdded/Endpoint).
  - `ApplyXamlChangesAsync(ct)` (VS impl → MarkupDocumentManager.ApplyGenericHotReload() on the UI thread when the debugger is running).
  - `HotReloadLogger` (IHotReloadLogger, line 65), IMarkupChangeErrorManager, MarkupDocumentManager.
  - RegisterEndpoint must run on the UI thread.
- `Endpoint` (Endpoint.cs:16) exposes Platform (IDiagnosticPlatform, DiagnosticBits such as SupportsInAppMenu), ProtocolHandler, DisplayName, ProcessId (a Guid, not the OS PID), IsRemote, EndPointId. `EndpointExtensions.InstanceManager(endpoint)` is at line 71.
- `SupportedPlatform` (Shared\Source\XamlTapContract\TapOM\SupportedPlatform.cs:12) values: Invalid, WindowsUIXaml(UWP), WpfFramework, WpfCore, Unused, WinUI, Maui, DotNetWeb.
- `XamlDiagnosticsHost` (Tool\Model\XamlDiagnosticsHost.cs) exposes:
  - TreeContainer (ElementTreeContainer), BindingFailuresProvider, DocumentViewManager.
  - `DiagnosticNotAvailableReason` string (~line 99): useful for "why LVT unavailable".
  - CopilotExtension (lines 48, 69-74, 97, 169-172), LivePreviewManager, InAppUIManager, PropertyExplorerViewModel, userOptions, IHotReloadStatusReporter.
- LVT:
  - ElementTreeContainer (Diagnostics\ElementTree\ElementTreeContainer.cs:26) provides LiveNodesChanged, GetElementTree(endpoint), GetElement(endpoint, handle), GetNamedElements, RootNode.
  - IElement has Location (source) and Endpoint.
  - ElementViewModel creates children lazily (GenerateChildren).
  - Just My XAML filtering happens in the view model layer.
  - **No host-side bounds/position API exists.**
- LPE:
  - PropertyExplorerViewModel has SetValueAsync(SetPropertyRequestInfo, IElementValueBase) and uses PlatformObjectCache.GetElementOrPropertyObjectAsync(handle).
  - Edits are sent as the SetPropertyRequest TAP message.
- Options use the `debugging.xamlHotReload.` prefix (OptionNames.cs:9; XamlHotReloadSettings.registration.json): enableXamlHotReload, enableWpf/enableUwp/enableWinui/enableMaui, applyOnSave, justMyXaml, previewSelected, inAppSelectionAutoOff, inAppToolbar. The runtime interface is IXamlUserOptions/VisualStudioXamlUserOptions.
- Telemetry `DebuggingStartedWithoutVisualDiagnostics` with reasons such as NotFirstProcess (TelemetryEvents.cs:13, TelemetryValues.cs:70). There's no public reasons enum.
- Hot reload output: `IHotReloadLogger` is a brokered service owned by the .NET Hot Reload team and backs the "Hot Reload" output pane. It's used across Diagnostics, MAUI, and CodeAnalysisDiagnostics (ServiceBrokerWrapper). For AI access, we either tee XAML log messages into an in-memory ring buffer or read the pane text.
- Binding failures:
  - IBindingFailure (Diagnostics\Bindings\IBindingFailure.cs:12) fields: severity, SourceInfo, count, binding path, data context name/type, description, document/project, error code/details, original error, target name/property/type.
  - BindingFailuresProvider.cs:22; IBindingFailures.ClearEntries() (IBindingFailures.cs:31).
  - Sources: the TAP `BindingFailedEvent` (WPF) plus output parsers for WPF/UWP/MAUI (BindingFailuresFromOutput reads GUID_OutWindowDebugPane).
- Accessibility:
  - Uses Axe.Windows, triggered from the LVT/AccessibilityToolWindow via `AccessibilityChecker.Run()`.
  - IAccessibilityIssue (Diagnostics\AccessibilityChecker\IAccessibilityIssue.cs:10): rule, how-to-fix, description, automationId, processId, scan data, element info. Model in Axe\AxeAccessibilityIssue.cs.
  - TAP messages MapAccessibilityErrorsRequest, SetAccessibilitySelection, and Clear map issues to elements/source and highlight them (WpfTap\AccessibilityChecker\TapAccessibilityCheckerService.cs:40; TryGetElementRect ~195 converts screen pixels to root-relative coordinates).
  - Supported only on WPF and WinUI desktop. Doc: Diagnostics\Documentation\accessibility-checker-tool.md.
- XamlDiagnosticsTestContract (Diagnostics\XamlDiagnosticsTestContract.cs) is the existing automation surface: WaitForElementAsync, SelectElementInLiveVisualTree, Get/SetSelectedElementPropertyValue, GetSelectedElementProperties, ClearBindingFailures, RefreshLivePropertyExplorer, and more. Good reference for a programmatic API.

**TAP protocol**
- ProtocolHandler.SendMessageAsync<TReply>(int, obj) and RegisterMessageObserver / RegisterAsyncMessageObserver (Shared\Source\TapContract\Networking\ProtocolHandler.cs:142, IProtocolHandler.cs:55,76).
- IDs live in MessageType.cs:21 and XamlMessageType.cs:16. Host commands:
  - Properties: PropertyChainRequest, SetPropertyRequest, CollectionRequest, GetDefaultValue, EnumsRequest.
  - Selection/in-app UI: HostSelectionChange, SetInAppSelectionStateRequest, SetLayoutAdornerStateRequest, SetJustMyXamlModeRequest, TrackFocusElementRequest, InAppMenuStateRequest/Command.
  - Rendering/hit-testing: RenderTargetBitmapRequest, HitTest (designer WpfSurface only).
  - Actions: ExecuteXamlActions, GoToState, StoryboardAction, GetDictionaryEntryValue, EvaluateStaticExtension.
  - Hot reload: FullPageHotReloadRequest, ResetResourceProvider.
  - Other: SetBindingFailuresCount, accessibility messages, CopilotEvent/CopilotRequest.
  - TAP→host: VisualTreeMutation, LivePreviewMutation, LivePreviewFrame, DisplayInfo, LogMessage, UpdatesApplied, BindingFailedEvent.
- TAPs live at Shared\Source\WpfTap, UwpTap (UWP and WinUI, native C++), MauiTap, and WebTap. MAUI implements fewer features; UWP handler coverage is unverified.
- Live Preview:
  - LivePreviewManager (Tool\UI\LivePreview\Model\LivePreviewManager.cs).
  - WPF TapLivePreviewService.cs:45-219 registers root HWNDs (title, UnitsPerPixel DPI, RTL) and handles selection by HWND + screen coordinates (hit-test in TAP).
  - Frames are streamed asynchronously (LivePreviewStreamingRequest, LivePreviewFrame). There's no on-demand PNG request; it could be built by grabbing a frame or by using RenderTargetBitmap.
- RenderTargetBitmapManager (Diagnostics\Source\Diagnostics\Tool\Managers\RenderTargetBitmapManager.cs): RequestRenderTargetBitmap(protocolHandler, instanceHandle, renderFlags), max 2048x2048, Pbgra32. This can produce a per-element or per-window image for AI.
- No generic element-bounds request and no generic "click/invoke" TAP command exist. Both would need new TAP messages, or reuse of UIA via the debugger's ui_interact tool.
- Source info: WPF uses VisualDiagnostics.GetXamlSourceInfo (WpfVisualDiagnostics.cs:123) and requires ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1. The injector sets it at WpfTapBootstrap\Injector.cpp:27; the check is in VisualTreeService.cs:165; UwpTap.cpp:1334; MauiVisualDiagnostics.cs:120.
- Per the docs, source info also needs a Debug build (WPF `XamlDebuggingInformation=True`; UWP `DisableXbfLineInfo=False`), F5 rather than Attach, and a non-elevated app. Hot reload isn't supported for elevated apps. `XAML_HOT_RELOAD_ACCURACY_OVER_PERF` is an env var option. MAUI Live Preview and Hot Reload also work at design time (17.14+), not only while debugging.

**Existing in-app Copilot (experimental)**
- InAppUICopilotManager (Diagnostics\Source\Diagnostics\Tool\Managers\InAppUICopilotManager.cs): the TAP sends a CopilotRequest (prompt, ContextImages, ContextSources), and VS forwards it to `ICopilotExtension` (Diagnostics\ICopilotExtension.cs, `[Experimental]`).
  - SendCopilotRequestAsync(correlationId, prompt, images, paths), plus reject, feedback, and SessionChanged.
  - The ICopilotExtension is obtained from MEF via GetExportedValueOrDefault.
- **No in-repo product implementation of ICopilotExtension** was found (only tests/mocks); it's likely in another repo or unshipped.
- The WPF TAP has Copilot UI: WpfTap\WpfVisualTreeService\Copilot\TapCopilotService.cs, CopilotCommentsPane, InkCommentStroke (ink annotations). The user option is IsInAppCopilotEnabled.
- Tests: WpfInAppCopilotTests.cs, InAppUICopilotManagerTests.cs.

**Constraints and preferences**
- Never push, rebase, or amend the user's commits; add a single new commit and stop for review (user memory).
- Build with src\Xaml\Scripts\Build-Xaml.ps1 / Test-Xaml.ps1 (needs a VS dev shell and the Modeling SDK). Don't use dotnet build.
- The plan must not include time estimates.
- Plan mode blocks shell scripts that write outside the session folder.

**Draft design direction (not yet confirmed with the user)**
- Primary: in-proc VS Copilot function provider(s) in the XAML Diagnostics package, exported as a brokered service. Register through FirstPartyToolsProvider with an `AllFromProviderTool` gated on a new UIContext such as "XAML diagnostics endpoint active". Optionally add a `[CopilotSdkAgent]` "XAML" agent with a system prompt that holds the enablement/troubleshooting knowledge, plus a handoff descriptor and a built-in skill name in FirstPartySkills.
- Secondary/optional: an MCP projection for external agents (Copilot CLI), possibly through the Debugger MCP server or a VS-hosted MCP. Needs a decision.
- Tool set:
  - list_xaml_apps (endpoints/platform/status/why unavailable)
  - get_visual_tree (paged, depth, filter, JMX, source info)
  - find_elements
  - get_element_properties
  - set_element_property (confirm)
  - get_element_bounds (new TAP message)
  - capture_screenshot (window or element via RenderTargetBitmap/LivePreview frame, returned as image context)
  - list_windows
  - select/highlight element
  - interact (new TAP message or UIA; confirm)
  - get_binding_failures / clear
  - run_accessibility_check / get results
  - get_hot_reload_status / options / errors
  - get_hot_reload_output
  - apply_hot_reload (confirm)
  - get_diagnostics_setup_help
- Needs new TAP messages for bounds and input across WPF, UWP/WinUI (native), and MAUI, and versioning/back-compat for old TAPs. Use DiagnosticBits capability flags.
</technical_details>

<important_files>
- Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs: central first-party tool, agent, skill, and handoff registry where XAML tools and the agent must be registered.
- Q:\src\VS_xaml\src\Copilot\src\Copilot\Functions\ICopilotFunctionProvider.cs, CopilotFunctionDescriptor.cs, CopilotConfirmationRequirement.cs: the tool contract.
- Q:\src\VS_xaml\src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs (168-226 screenshot as image context, 251 ui tree, 431 interact): pattern for images and UI interaction.
- Q:\src\VS_xaml\src\vc\projbld\CppBuildInsights\CppBuildInsightsCollector\BuildPerformanceResponder\BuildPerformanceSdkAgent.cs and BuildPerformanceAgentProvider.cs: external-team SDK agent pattern. Also src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs (not yet read).
- Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs and IXamlDiagnosticsHost.cs; DiagnosticsBase\Host\IXamlHotReloadHost.cs, Endpoint.cs: the host API the tools will call.
- Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Tool\Managers\InAppUICopilotManager.cs, ICopilotExtension.cs: the existing experimental in-app Copilot path.
- Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Tool\Managers\RenderTargetBitmapManager.cs: per-element image capture.
- Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\Networking\XamlMessageType.cs, TapOM\XamlJsonData.cs: TAP message IDs and payloads, where new messages would be added.
- Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\XamlDiagnosticsTestContract.cs: existing programmatic automation surface.
- Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Bindings\IBindingFailure.cs, BindingFailuresProvider.cs; AccessibilityChecker\IAccessibilityIssue.cs; VS\OptionNames.cs; ElementTree\ElementTreeContainer.cs; Tool\UI\LivePreview\Model\LivePreviewManager.cs; Tool\UI\LivePropertyExplorer\ViewModel\PropertyExplorerViewModel.cs.
- Q:\src\VS_xaml\src\Xaml\Diagnostics\README.md and Documentation\*.md (initialization, multiple-process, binding-failures-tool, accessibility-checker-tool, WpfVisualTreeRoots): docs to update later.
</important_files>

<next_steps>
Immediate next steps, still in plan mode:
1. Optionally skim CMakeCopilotFunctionProvider.cs (how a non-Copilot package exports a brokered function provider and registers via an AllFromProviderTool/NamedTool) and accessibility-checker-tool.md. Also confirm where VS-side DTOs could live and whether the XAML Diagnostics package can reference Microsoft.VisualStudio.Copilot contracts.
2. Use ask_user to confirm:
   - Exposure surface: in-VS Copilot tools + built-in XAML agent/skill only, or also an MCP server for external agents such as Copilot CLI or VS Code.
   - Platform scope for new TAP features: WPF first vs. WPF+WinUI+UWP+MAUI.
   - Whether AI may mutate the app (set properties, simulate clicks, trigger hot reload, edit XAML) and the confirmation policy.
   - Whether to build on or replace the experimental in-app Copilot (ICopilotExtension).
   - Image strategy: on-demand screenshot vs. LivePreview frames.
   - Whether to include design-time MAUI preview.
3. Write C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md. Contents:
   - Problem and approach.
   - Architecture: XamlDiagnosticsCopilotService in the Diagnostics package, a brokered function provider, a context provider, an SDK agent with a knowledge-rich system prompt, FirstPartyToolsProvider registration, UIContext gating, and an optional MCP projection.
   - Full tool catalog with parameters, results, confirmation, and platform support.
   - New TAP messages (element bounds, window screenshot on demand, input/invoke, possibly tree snapshot batch) with capability bits and back-compat.
   - Hot reload output ring buffer.
   - Unavailability diagnostics, covering the env var, Debug build properties, attach vs. F5, elevation, options disabled, NotFirstProcess, and platform unsupported.
   - Telemetry, privacy/PII, perf limits (paging, depth, image size), threading, testing (unit, component tests like WpfInAppCopilotTests, APEX), docs, and phasing.
   - Todos with dependencies. No time estimates.
4. Insert the todos and todo_deps into SQL, then call exit_plan_mode with a bullet summary.
</next_steps>