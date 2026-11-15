<overview>
The user (@spadapet) wants every Visual Studio "XAML Diagnostics" feature exposed to Copilot AI, so the model can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images and the list of top-level windows
- binding failures
- the accessibility checker
- hot reload: state, errors, log, and triggering an apply
- the list of apps being debugged and their platforms
- explanations of why a feature is unavailable

The plan was approved and implementation is now underway. It's a prototype: the user wants whatever works most easily. The design is in-proc Copilot agent-mode tools (a brokered `CopilotFunctionHandler`) plus a built-in skill, all inside the existing Diagnostics DLL, with no dedicated agent.
</overview>

<history>
1. **Plan mode.** The user asked for a full feature plan.
   - I researched the Copilot extensibility points, the XAML Diagnostics host model, the TAP protocol, and the existing in-app Copilot prototype.
   - I asked six scope questions with ask_user and got answers (see the plan decisions).
   - I wrote plan.md and added 12 SQL todos. exit_plan_mode was approved.

2. **Implementation (current).**
   - Read Copilot contracts. `CopilotDescriptors.Context.Image` is public. `CopilotImageContext` is a public MessagePack record with `required init` properties: Data, MimeType, Width, Height, FilePath. `CopilotContext` has public constructors `(ServiceMoniker, string member, CopilotCorrelationId, string copilotTypeName, object value)` and `(ServiceMoniker, CopilotContextDescriptor, CopilotCorrelationId, object)`. The constant `CopilotDescriptorConstants.ImageContextProvider` = "Microsoft.VisualStudio.Copilot.ImageContextProvider".
   - Loaded the building-locally skill.
   - **Baseline build attempt 1:** primed with `Prime-ForCopilot.ps1`, then `Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoProjectReferences`. It failed with only MC1000 XAML errors, because referenced binaries are missing (Microsoft.VisualStudio.Shell.15.0.dll under `out\binaries\x86chk\bin\netsdk\env\...`, plus DiagnosticsBase.dll and Utility.dll). These are environment failures, not code errors.
   - **Build attempt 2:** started async (shellId `build2`), the same command without `-NoProjectReferences`, so the reference closure gets built. Its result is not yet read.
   - Meanwhile I studied the host APIs listed in the technical details.
</history>

<work_done>
Files created:
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the approved plan, which is the source of truth.

No repository files have been modified yet. No code has been written.

SQL todos are all still pending (`plumbing` should be marked in_progress). Dependencies:

| Todo | Depends on |
|---|---|
| function-provider | plumbing |
| copilot-registration | function-provider |
| skill | plumbing |
| readonly-tools | function-provider |
| hot-reload-tools | function-provider |
| mutation-tools | readonly-tools |
| tap-wpf | readonly-tools |
| inapp-reroute | readonly-tools |
| tap-winui | tap-wpf |
| tap-maui | tap-wpf |
| docs-tests | mutation-tools, tap-wpf |

The async build `build2` is running or finished; check it with `read_powershell build2`.
</work_done>

<technical_details>
**Architecture (approved).** New folder `src\Xaml\Diagnostics\Source\Diagnostics\Copilot\` containing:

- **`XamlAgentService`**: MEF `[Export]` façade.
  - Element IDs have the form `"{endpointKey}:{handle}"`.
  - Paging defaults: depth 3, 200 nodes, hard cap 2000. Images ≤1280px. Per-call timeout 10s.
  - Error codes: NO_APPS, ENDPOINT_GONE, ELEMENT_GONE, UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_TIMEOUT, NOT_DEBUGGING, FEATURE_DISABLED.
- **`XamlDiagnosticsFunctionProvider`**:
  - Subclass `CopilotFunctionHandler` and export with `[ExportBrokeredService("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions","0.1",Audience=ServiceAudience.Local)]` + `IExportedBrokeredService`.
  - Expose a static `Moniker` and `ServiceDescriptor = CopilotDescriptors.CreateDescriptor(Moniker)`, override `Descriptor`, implement `InitializeAsync`.
  - Method signature: `(string progressMessage, CopilotRequest originalRequest, IProgress<CopilotProgress> progress, CancellationToken ct, [CopilotDescription] args...)`.
  - Pattern sources: `src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs` and `src\vc\projbld\CMake\Package\Copilot\CMakeCopilotFunctionProvider.cs`.
- **Tool names:**
  - `xaml_list_apps`, `xaml_get_diagnostics_status`
  - `xaml_get_visual_tree`, `xaml_find_elements`, `xaml_get_element_bounds`, `xaml_select_element`, `xaml_go_to_source`
  - `xaml_get_element_properties`, `xaml_get_property_value_details`, `xaml_set_element_property`
  - `xaml_list_windows`, `xaml_capture_image`
  - `xaml_interact`
  - `xaml_get_binding_failures`, `xaml_clear_binding_failures`
  - `xaml_run_accessibility_check`, `xaml_get_accessibility_results`
  - `xaml_get_hot_reload_status`, `xaml_get_hot_reload_log`, `xaml_apply_hot_reload`
- **Mutations** use `CopilotConfirmationRequirement.Required`.
- **Skill:**
  - `[CopilotSkillsProvider("Copilot\\skills", uiContextGuid)]` on an `ICopilotSkillsProvider` class. It needs `#pragma warning disable VSCOPILOT_BACKEND`.
  - Content goes in `Copilot\skills\xaml-diagnostics\SKILL.md` + `references\` as VSIX Content items.
  - Add the skill name to `FirstPartyToolsProvider.FirstPartySkills`.
- **Copilot-repo edits:** an `AllFromProviderTool(moniker, uiContext)` entry in `FirstPartyTools` (`src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs` ~205-245), and the DebuggerSdkAgent aggregator (`Agents\Sdk\DebuggerSdkAgent.cs` 50-80).
- **Other components:** a new UIContext `XamlDiagnosticsActive` set from EndpointChanged, a feature flag `XamlDiagnostics.CopilotTools`, and a ring buffer of 500 hot-reload log entries.

**Project setup.**
- Diagnostics.csproj is SDK-style, net472, VSIX.
- Add `<ProjectReference Include="$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj" />` (ProjectReferences ~147-163). Watch for MessagePack/StreamJsonRpc conflicts, and don't ship Copilot.dll in the VSIX.
- Content items go ~line 128.

**Building context objects.**
- Image: `new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", correlationId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext{Data,MimeType="image/png",Width,Height,FilePath=null!}){CanReduce=false}`.
- Alternatively, tools can just return strings or JSON.

**Host model APIs** (namespace `Microsoft.VisualStudio.DesignTools.Diagnostics[.Model]`):
- **Getting the host:**
  - Load the package with `new VsPackageLoader(ServiceProvider.GlobalProvider, GuidList.GuidXamlDiagnosticsPkg).LoadPackageAsync`.
  - Cast to `IXamlDiagnosticsPackage`; it has `.XamlDiagnosticsHost` and an `Initialized` event. `host.IsActive` plus PropertyChanged tells you when a session is active.
  - See `XamlDiagnosticsTestContract.cs` lines 47-135, which is MEF `[Export]`ed.
- **`IXamlDiagnosticsHost` (extends IXamlHotReloadHost → IDiagnosticHost):**
  - Members: PropertyExplorerViewModel, LivePreviewManager, ElementTreeContainerViewModel, ActiveElementTracker, UserOptions, ErrorReporting, DocumentViewManager, BindingFailuresProvider, CopilotExtension, `DiagnosticNotAvailableReason`, ActivateHost, ShowWindow(XamlDiagnosticsWindow), `GetSourceNavigator(endpoint)`, `MarkupDocumentManager.NormalizeSourceInfo`, TelemetryLogger.
  - `TreeContainer` (ElementTreeContainer) exists only on the concrete `XamlDiagnosticsHost` class, so cast to it.
  - Session objects are null when no session is active.
- **`IDiagnosticHost`:** `Endpoints` (ICollection<Endpoint>), `EndpointChanged` (EndpointEventArgs: IsAdded, Endpoint), `IsActive`, `CancellationToken`.
- **`IXamlHotReloadHost`:** MarkupDocumentManager, `MarkupChangeErrorManager.RuntimeErrors` (IEnumerable<MarkupChangeError>), HotReloadProcessingInformation, HotReloadOptions (`IsDotNetHotReloadEnabledAsync`), HotReloadLogger, `ApplyXamlChangesAsync(ct)`.
- **`Endpoint`:**
  - Members: EndPointId (Guid), Platform (`IDiagnosticPlatform`: `.Platform` SupportedPlatform, `.DiagnosticBits`), ProtocolHandler, DisplayName, ProcessId (Guid), IsRemote, `GetProperty<T>(key)`.
  - The OS PID comes from `endpoint.GetProperty<int>(ContractStrings.WindowsProcessId)`.
  - `endpoint.InstanceManager()` and `endpoint.TapExceptionSuppressor()?.Suppress()` are also available.
- **`DiagnosticBits`:** None, SourceInfoNotAvailable=1, HotReloadNotSupported=2, SupportsSharedResourceDictionaries=4, SupportsLivePropertyExplorer=8, SupportsInAppMenu=0x10. New capability bits would go here (`Shared\Source\TapContract\TapOM\DiagnosticBits.cs`).
- **`ElementTreeContainer`:**
  - `GetElementTree(endpoint)`, `GetElement(endpoint, handle)`, `GetNamedElements(name)`.
  - `RootNode` → process nodes (Type "Process") → element children.
  - `Element : LiveNodeWithChildren, IElement` has Endpoint and `Location` (MarkupLocation.SourceInfo).
  - The `ILiveNodeWithChildren` side has Handle, SourceInfo, TypeFullName, Kind, Name, IsRoot, Children, Parent, ChildIndex.
  - `SourceInfo` has FileName, LineNumber, ColumnNumber, MarkupHandle; `SourceInfo.IsValidFileInfo(si)` checks validity.
- **Properties (LPE):**
  - Request: send `XamlMessageType.PropertyChainRequest` with `new PropertiesRequestInfo{Object=handle, Reset=false}`. Use Reset=false so the LPE's cache isn't reset.
  - Response is `PropertyValuesHolder{Error, Sources: List<TapPropertySource>, Properties: List<TapPropertyValue>}`.
  - `TapPropertySource`: Handle, TargetType, Name, Source (BaseValueSource), SourceInfo.
  - `TapPropertyValue : ValueBase`: Index, Type, DeclaringType, ItemType, Overridden, PropertyName, PropertyChainIndex, plus Value, ValueType, Handle, MetadataBits, SourceInfo, ReadOnly, IsCollection, IsValueBindingExpression.
  - `PropertyHelper.ApplyAllFilters(props)` is used by PlatformObjectCache.
  - Collections: `CollectionRequest` with `CollectionRequestInfo{Object, StartIndex, ElementCount}` returns `CollectionResponse`.
- **Setting a property:**
  - Send `XamlMessageType.SetPropertyRequest` with `SetPropertyRequestInfo{Object=elementHandle (set locally), Index=(int)tapPropertyValue.Index, CreateInstanceType, Value}` (Value=null clears).
  - `CreateInstanceType` is `typeof(string).FullName` for WPF/MAUI, and `tapPropertyValue.Type` for UWP (WindowsUIXaml)/WinUI.
  - The response is `ResponseWithError` (Error may be a numeric HRESULT).
  - Reference: `ElementProperty.CreateEditRequest`, and `PropertyExplorerViewModel.SetValueAsync` line 264.
- **Binding failures:**
  - Access via `host.BindingFailuresProvider.BindingFailures` (`IBindingFailures`): Entries, CountedEntries, ClearEntries().
  - `IBindingFailure` fields: ErrorSeverity, SourceInfo, Count, BindingPath, DataContextName, DataContextType, Description, DocumentName, ErrorCode, ExpandedDetails, OriginalError, ProjectName, Target, TargetName, TargetPropertyType.
- **UserOptions (`IXamlUserOptions`):** IsHotReloadEnabled, IsWpfEnabled, IsUwpEnabled, IsWinUIEnabled, IsMauiEnabled, IsHotReloadOnSaveEnabled, IsPreviewSelectedEnabled, IsInAppMenuEnabled, IsCompatibilityModeEnabled, IsInAppSelectionEnabled, IsLayoutAdornersEnabled, IsTrackFocusedElementEnabled, IsJustMyXamlEnabled, IsBindingFailuresVisible, BindingFailuresCount, and others.
- **Live Preview:**
  - `ILivePreviewManager.RemoteContents` is a list of `RemoteContent`: Id, Endpoint, Handle (HWND IntPtr), HandleKind (`LivePreviewKind.WindowHandle`), Name, UnitsPerPixel, Size (SizeD), IsRightToLeft, IsMinimized, Frame (LivePreviewFrame), FrameCaptureKind.
  - It also has a `RemoteContentsChanged` event and `StartLivePreview(endpoint, hwnd)`.
- **Images:**
  - `RenderTargetBitmapManager.RequestRenderTargetBitmap(protocolHandler, handle, flags)` returns a `RenderTargetResult` with Ok, ReturnCode, RenderedBitmapDescription (Width, Height, PixelFormat, OpacityMode), and ImageSource (a WriteableBitmap in Pbgra32).
  - Encode it with `PngBitmapEncoder` on the UI thread. Max size is 2048. It uses `ThreadHelperBase.ReentrantFactory`.
- **Accessibility:**
  - The internal `AccessibilityIssuesViewModel(IXamlDiagnosticsHost)` has `RunAsync()`, `Entries` (ObservableCollection<TableEntryAdapter> with `.AccessibilityIssue`), and a `SourceInfoReceived` event (raised after `MapAccessibilityErrorsResponse`). It expects the UI thread (`UIThreadDispatcher`).
  - `IAccessibilityIssue` fields: Rule, HowToFix, Description, AutomationId, ProcessId, ScanData (SourceNavigator.GetFilePath/GetProjectName(SourceInfo)), and ElementInfo (RuntimeId, SourceInfo).
  - `AccessibilityChecker.GetTargetProcesses(host)` excludes remote and MAUI (MAUI uses the native endpoint).
  - Plan: keep a dedicated view-model instance in the service, run it on the UI thread, then wait briefly for SourceInfoReceived.
- **Hot reload log tee point:** `XamlDiagnosticsHost.OnEndpointChanged` → `HotReloadLogger.Value.LogMessageAsync(message,"XAML")`.

**Build and environment:**
- Use `Invoke-Build.ps1` after `Prime-ForCopilot.ps1` in the same process. Never `dotnet build`.
- `-NoProjectReferences` fails on a cold tree because reference outputs are missing, so build with references. Alternatively use `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Source -BuildReferences` (needs the Modeling SDK).
- Binlogs go to `Q:\src\VS_xaml\.vs\logs\`.

**Constraints:**
- Never push, rebase, or amend. Make a single new commit with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- At the end, ask the user whether to update a skill.

**Open questions:**
- Which UIContext gates the tools (DebuggingMode vs. XamlDiagnosticsActive).
- One skill or two.
- Which API submits a prompt into Agent mode for the in-app re-route.
- Whether Debugger-agent inclusion is by proxy or by MEF.
</technical_details>

<important_files>
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the approved plan.
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`: needs the Copilot ProjectReference and the skill Content items.
- `...\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs` and `IXamlDiagnosticsHost.cs`: the host façade target. Session start/stop is ~143-260.
- `...\Diagnostics\XamlDiagnosticsTestContract.cs`: the host-acquisition pattern (lines 47-135) and automation helpers.
- `...\Diagnostics\ElementTree\ElementTreeContainer.cs`, `Element.cs`, `IElement.cs`: tree access.
- `...\Diagnostics\Tool\UI\LivePropertyExplorer\Model\PlatformObjectCache.cs` (lines 130-200), `Tool\Model\ElementProperty.cs`, `Tool\UI\LivePropertyExplorer\ViewModel\PropertyExplorerViewModel.cs:264`: property get/set protocol.
- `...\Diagnostics\Bindings\IBindingFailure*.cs`: binding failure data.
- `...\Diagnostics\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`, `AccessibilityChecker.cs`, `Table\TableEntryAdapter.cs`: running the a11y check and mapping results.
- `...\Diagnostics\Tool\Managers\RenderTargetBitmapManager.cs`, `RenderTargetResult.cs`, `BitmapDataPayload.cs`: element capture.
- `...\Diagnostics\Tool\UI\LivePreview\Model\ILivePreviewManager.cs`, `RemoteContent.cs`: window list.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs`, `TapPropertyValue.cs`, `TapPropertySource.cs`, `SourceInfo.cs`; `Shared\Source\TapContract\TapOM\DiagnosticBits.cs`: TAP contracts.
- Copilot: `src\Copilot\src\Copilot\Functions\CopilotFunctionHandler.cs`, `Context\CopilotImageContext.cs`, `CopilotDescriptors.cs` (Context.Image at line 194), `Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs`, `Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`, `Copilot.Vsix\Agents\Sdk\DebuggerSdkAgent.cs`, `Copilot\AgentSkills\CopilotSkillsProviderAttribute.cs`.
</important_files>

<next_steps>
Immediate:
1. Run `read_powershell build2` for the baseline build with references. If it fails for environment reasons, try `Build-Xaml.ps1 -Component Diagnostics -Scope Source -BuildReferences`, or report the problem.
2. Mark SQL todo `plumbing` in_progress.
3. Add the Copilot ProjectReference to Diagnostics.csproj and rebuild to check for conflicts.
4. Create the `Copilot\` folder files:
   - `XamlAgentService.cs` (host acquisition via package loader / test-contract pattern, endpoint keys, tree/props/bindings/a11y/images/hot reload)
   - DTOs and errors
   - `XamlHotReloadLogBuffer.cs`
   - `XamlDiagnosticsFunctionProvider.cs` (all the `[CopilotFunction]` tools, returning JSON strings plus image contexts)
   - `XamlDiagnosticsSkillsProvider.cs`
   - `skills\xaml-diagnostics\SKILL.md` + `references\*.md` (enablement/troubleshooting, tool workflows, designer- and hot-reload-friendly XAML authoring)
   - the UIContext
5. Then work in this order:
   - the Copilot-repo registration (FirstPartyTools, FirstPartySkills, DebuggerSdkAgent)
   - the mutation tools
   - the WPF TAP messages `GetElementBoundsRequest` and `ElementAutomationActionRequest`, capability-gated (reuse `TryGetElementRect` from `TapAccessibilityCheckerService.cs`)
   - the in-app `ICopilotExtension` re-route
   - WinUI and MAUI TAP support
   - unit tests in `src\Xaml\Diagnostics\Test\Unit` and docs
6. Build and test, make a single commit with trailers, don't push, and ask about a skill update.
</next_steps>