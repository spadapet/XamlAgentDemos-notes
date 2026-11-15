<overview>
The user (@spadapet) wants every Visual Studio "XAML Diagnostics" feature exposed to Copilot AI, so the model can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers:
- Live Visual Tree (LVT) and Live Property Explorer (LPE)
- Live Preview images and the list of windows
- binding failures
- the accessibility checker
- hot reload: state, errors, log, and triggering an apply
- the list of apps being debugged and their platforms
- explanations of why a feature is unavailable

The plan was approved and implementation is underway. It's a prototype: the user wants whatever works most easily. The design is in-proc Copilot agent-mode tools (a brokered `CopilotFunctionHandler` subclass) plus a built-in skill, all inside the existing Diagnostics DLL, with no dedicated agent.
</overview>

<history>
1. **Plan mode** (earlier).
   - I researched the Copilot extensibility points, the XAML Diagnostics host, the TAP protocol, and the in-app Copilot prototype.
   - I asked six scope questions, wrote plan.md, and added 12 SQL todos. The plan was approved.

2. **Implementation, first segments.**
   - Read the Copilot contracts and loaded the building-locally skill.
   - Researched the host, tree, property, RTB, Live Preview, binding, a11y and hot-reload APIs.
   - The first baseline builds failed for environment reasons:
     - MC1000 errors from missing reference binaries.
     - A full `build2` (with references) failed on unrelated items: the L3 cache was unavailable, `FileHashGenerator` and `Revision` were missing their project.assets.json, and the msrustup install failed.

3. **Implementation, this segment.**
   - Reflected `IHotReloadLogger` from the Debugger.Contracts package. Its only member is `ValueTask LogAsync(HotReloadLogMessage, CancellationToken)`. `LogMessageAsync` is an extension method in `Diagnostics\HotReload\Maui\LoggerExtensions.cs`.
   - Added the Copilot ProjectReference to Diagnostics.csproj.
   - Got the leaf build working by leaf-building the missing dependencies in order: ToolboxControlsInstaller, then DesignerHost, then Diagnostics. **Diagnostics now builds successfully with the Copilot reference** (binlog `.vs\logs\src_Xaml_Diagnostics_Source_Diagnostics_Diagnostics_20261111_144941_634.binlog`).
   - Found that the `CreateStringContext` and `CreateImageContext` helpers live in Copilot.Core (not referenceable), so I'll build the contexts manually.
   - Read the XAML-local build skill and instructions (`src\Xaml\copilot-instructions.md`, `src\Xaml\.copilot\skills\xaml-build-test-deploy\SKILL.md`).
   - Gathered the remaining model APIs (see technical details). No tool code has been written yet.
</history>

<work_done>
Files modified:
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`: added this as the first item of the ProjectReference ItemGroup (line 148):
  `<ProjectReference Include="$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj" Private="false" /> <!-- For Copilot agent-mode tools and skills -->`
  It builds cleanly.

SQL todos:
- done: `plumbing`
- in_progress: `function-provider`, `readonly-tools`
- pending: copilot-registration, skill, hot-reload-tools, mutation-tools, tap-wpf, inapp-reroute, tap-winui, tap-maui, docs-tests

Dependencies: function-provider and skill depend on plumbing. copilot-registration, readonly-tools and hot-reload-tools depend on function-provider. mutation-tools, tap-wpf and inapp-reroute depend on readonly-tools. tap-winui and tap-maui depend on tap-wpf. docs-tests depends on mutation-tools and tap-wpf.

plan.md in the session folder is the approved plan and the source of truth.
</work_done>

<technical_details>
**Build**
- Working command (run in one PowerShell process, from `Q:\src\VS_xaml`):
  ```
  & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null
  & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoProjectReferences [-NoRestore]
  ```
  It takes about 30-60 s. If CS0006 reports a missing metadata file, leaf-build that project first.
- Don't use the full-reference build: it hits unrelated environment failures (Rust, FileHashGenerator).
- The Xaml docs say to prefer `src\Xaml\Scripts\Build-Xaml.ps1`, which needs the Modeling SDK. For tests, build the whole `Diagnostics\Test\dirs.proj` (via `Build-Xaml.ps1 -Component Diagnostics -Scope Test`), not individual leaf projects. Run tests with `src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter X`.
- Other Copilot.csproj consumers (e.g. CommonIDE) use `Private="false"`.

**Copilot API**
- Base class pattern (from DebuggerUIFunctionProvider):
  - `[ExportBrokeredService(Name, "0.1", Audience=ServiceAudience.Local)] public sealed class X : CopilotFunctionHandler, IExportedBrokeredService`
  - `public static readonly ServiceMoniker Moniker = new(Name, new Version("0.1"));`
  - `ServiceDescriptor = CopilotDescriptors.CreateDescriptor(Moniker)`
  - `public override ServiceRpcDescriptor Descriptor => ServiceDescriptor;`
  - `public Task InitializeAsync(CancellationToken) => Task.CompletedTask;`
  - The `[ImportingConstructor]` can be private.
- Tool methods:
  - Signature: `[CopilotFunction(name, description, CopilotConfirmationRequirement.X)] public async Task<string|CopilotContext|CopilotContext[]> M([CopilotDescription(...)] string progressMessage, CopilotRequest originalRequest, IProgress<CopilotProgress> progress, CancellationToken ct, [CopilotDescription(...)] optional params...)`.
  - Required-confirmation functions MUST take an `ICopilotFunctionBroker` or a `CopilotFunctionInvocationContext` parameter.
  - Progress: `progress.Report(msg)` and `progress.Report(msg, CopilotProgressStatus.Error)`. This extension is in Copilot.dll `CopilotActiveResponseExtensions` (namespace Microsoft.VisualStudio.Copilot).
  - Might need `#pragma warning disable VSCOPILOT_API`.
- Text results: return `Task<string>` for text tools; the handler converts them.
- Image results: build the context manually:
  ```
  new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", correlationId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext { Data = bytes, MimeType = "image/png", Width = 0, Height = 0, FilePath = null! }) { CanReduce = false }
  ```
  - `CopilotImageContext` is a public record in Copilot.dll.
  - The `CopilotContext(ServiceMoniker, string member, CopilotCorrelationId, CopilotTypeName, object)` constructor is public.
- Text context alternative: `new CopilotContext(new ServiceMoniker("Microsoft.VisualStudio.Copilot.MiscellaneousContextProvider", new Version(CopilotDescriptors.CurrentContextProviderVersion)), new CopilotContextDescriptor("miscellaneous","Miscellaneous context as plain text", CopilotDefaultTypes.StringName), correlationId, text)`.
- Skills provider: `[CopilotSkillsProvider(@"Content\skills", uiContextGuid)]` (see the Copilot.Vsix.Tests MefAgentSkillsPathsTests.cs:239). No product usage exists yet. It's consumed by `MefAgentSkillsPaths`; the folder is relative to the assembly and likely needs `VSCOPILOT_BACKEND` pragma.
- The UIContext for tools and the skill is `GuidList.UICONTEXT_DiagnosticToolWindowsAvailable` (Debugging | DiagnosticConnectionActive).

**Host acquisition**
- Load the package with `new VsPackageLoader(ServiceProvider.GlobalProvider, GuidList.GuidXamlDiagnosticsPkg).LoadPackageAsync(ct)`, cast it to `IXamlDiagnosticsPackage`, subscribe to `Initialized` (it fires immediately if the host already exists), then read `pkg.XamlDiagnosticsHost`. The pattern is in XamlDiagnosticsTestContract.cs:47-135.
- Alternative: MEF-import `VisualStudioXamlDiagnosticsHost`, though it requires the package's `InitializeServices`.

**Host members (XamlDiagnosticsHost)**
- PropertyExplorerViewModel (IPropertyExplorerViewModel, `SetValueAsync(SetPropertyRequestInfo, IElementValueBase)`)
- LivePreviewManager (ILivePreviewManager: RemoteContents, IsSupportedOS)
- UserOptions (IXamlUserOptions)
- ActiveElementTracker (`ActiveElement` settable)
- TreeContainer (ElementTreeContainer)
- BindingFailuresProvider
- DocumentViewManager
- CopilotExtension
- DiagnosticNotAvailableReason
- HotReloadLogger (`Lazy<IHotReloadLogger>`)

The session objects are created in OnSessionStarted (line ~157) and nulled in OnSessionStopped (line ~233).

**From XamlHotReloadHost / IXamlHotReloadHost / IDiagnosticHost**
- `Endpoints` (ICollection<Endpoint>) and the `EndpointChanged` event
- `MarkupChangeErrorManager.RuntimeErrors`
- `HotReloadProcessingInformation` (IsProcessing, ProcessingStartTime, Changed)
- `HotReloadOptions` (IHotReloadOptions: `IsDotNetHotReloadEnabledAsync`)
- `ApplyXamlChangesAsync(ct)`
- `endpoint.InstanceManager()` returns IInstanceManager; a HotReloadInstanceManager has `IsEnabled`.

**Endpoint** members: Platform (IDiagnosticPlatform: Platform SupportedPlatform, DiagnosticBits), ProtocolHandler, DisplayName, ProcessId (Guid), IsRemote, EndPointId (Guid), `GetProperty<T>(key, default)`, and `TapExceptionSuppressor()` extension (EndpointExtensions.cs:74, used as `using (endpoint.TapExceptionSuppressor()?.Suppress())`).

**ContractStrings keys**: WindowsProcessId ("XamlHotReload.WindowsProcessId"), NoDebugMode, AppTargetFramework, AppEntryAssemblyName, AppTargetPlatform, XamlHotReloadEnabled, HotReloadCapabilities, SourceNavigatorId, SourceInfoResolverId, EmulatorProcessId.

**Enums**
- `DiagnosticBits`: None, SourceInfoNotAvailable=1, HotReloadNotSupported=2, SupportsSharedResourceDictionaries=4, SupportsLivePropertyExplorer=8, SupportsInAppMenu=0x10. This must stay in sync with UwpTap DiagnosticBits.h; new capability bits would start at 0x20.
- `SupportedPlatform`: Invalid, WindowsUIXaml (UWP), WpfFramework, WpfCore, Unused, WinUI, Maui, DotNetWeb.
- `ElementKind`: Visual, Application, ResourceDictionary.

**Tree**
- `ElementTreeContainer`: RootNode (Element), `GetElementTree(endpoint)` returns ElementTree (LiveNodeTreeBase<IElement>: RootNode, GetElement(handle), GetNamedElements(name)), `GetElement(endpoint, handle)`, `GetNamedElements(name)`.
  - RootNode children are process roots (Type="Process", grouped by DisplayName). Their children are IElements, filtered by `.Endpoint`.
- `IElement : ILiveNodeWithChildren`, with Location (MarkupLocation) and Endpoint.
- `ILiveNodeWithChildren`: IsRoot, Name, ChildIndex, Children, Parent, IsInTree.
- `ILiveNode`: Handle, SourceInfo, ParentHandle, TypeFullName, Kind.
- `SourceInfo`: FileName (a runtime URI), LineNumber, ColumnNumber, MarkupHandle, IsEmpty.
- Source navigation: `host.GetSourceNavigator(endpoint)` (SourceNavigation\SourceNavigatorExtensions.cs:13) returns ISourceNavigator. There's also `ISourceInfoResolver` (DiagnosticsBase\Project). Read the tree on the UI thread.

**Properties**
- Request: `endpoint.ProtocolHandler.SendMessageAsync<PropertyValuesHolder>(XamlMessageType.PropertyChainRequest, new PropertiesRequestInfo{Object=handle, Reset=false})`.
  - Use Reset=false so LPE's cache isn't disturbed.
  - Usings: `Microsoft.VisualStudio.DesignTools.RuntimeHost.Networking` and `.RuntimeHost.TapOM`.
- Holder: Error, Sources (TapPropertySource: Handle, TargetType, Name, Source as BaseValueSource, SourceInfo), and Properties (TapPropertyValue).
  - TapPropertyValue fields: Index, Type, DeclaringType, PropertyName, PropertyChainIndex (an index into Sources), IsAttached, Value, ValueType, Handle, SourceInfo, ReadOnly, IsCollection, IsValueBindingExpression, Overridden.
- Set: `SetPropertyRequestInfo{Object, Index, CreateInstanceType, Value}` returns ResponseWithError. CreateInstanceType is `typeof(string).FullName` for WPF/MAUI and `prop.Type` for UWP/WinUI. See `ElementProperty.CreateEditRequest` (Tool\Model\ElementProperty.cs:137-170) for the exact logic.

**Images**
- RTB: `RenderTargetBitmapManager.RequestRenderTargetBitmap(protocolHandler, handle, renderFlags)` (Tool\Managers\RenderTargetBitmapManager.cs:31) returns RenderTargetResult. **Only UwpTap implements RTB, not WPF.**
- Window capture plan: do it host-side with `PrintWindow(hwnd, hdc, 2)`, using HWNDs from `LivePreviewManager.RemoteContents`. RemoteContent fields: Id, Endpoint, Handle, HandleKind, Name, Size, IsMinimized, IsRightToLeft, UnitsPerPixel, Frame. Fall back to EnumWindows by the WindowsProcessId property.

**Bindings**: `host.BindingFailuresProvider.BindingFailures`.
- `IBindingFailures`: Entries, CountedEntries, HasEntries, ClearEntries, EntriesChanged.
- `IBindingFailure`: ErrorSeverity (TraceEventType), SourceInfo, Count, BindingPath, DataContextName, DataContextType, Description, DocumentName, ErrorCode, ExpandedDetails, OriginalError, ProjectName, Target, TargetName, TargetPropertyType.

**A11y**: `internal sealed AccessibilityIssuesViewModel` (AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs:38), with `RunAsync()` (line 90) and `SourceInfoReceived` (fired at line 279). The tool window wraps it (AccessibilityIssuesToolWindow.cs:68,125).

**IXamlUserOptions**: IsHotReloadEnabled, IsWpfEnabled, IsUwpEnabled, IsWinUIEnabled, IsMauiEnabled, IsHotReloadOnSaveEnabled, IsPreviewSelectedEnabled, IsInAppMenuEnabled, IsJustMyXamlEnabled, IsInAppSelectionEnabled, IsLayoutAdornersEnabled, IsTrackFocusedElementEnabled, IsBindingFailuresVisible, IsCompatibilityModeEnabled, and others.

**Hot reload log tee**
- Wrap the logger in the `VisualStudioXamlDiagnosticsHost` ctor (line ~67): `base(..., new Lazy<IHotReloadLogger>(() => XamlHotReloadLogBuffer.Wrap(hotReloadLogger.Value)), ...)`. The decorator implements `LogAsync`, records `HotReloadLogMessage` (Verbosity, InstanceId, Message, ErrorLevel?, ProjectName, Variant, Category) into a 500-entry ring buffer, then forwards.
- This covers HotReloadInstanceManager, MarkupChangeErrorManager and XamlDiagnosticsHost. The MAUI session manager imports its own logger, which is acceptable for the prototype.
- `MarkupChangeError` fields: Message, ErrorType, ErrorCode, Severity, Category, Offset, Length, DocumentLocator (Path, RelativePath, ProjectName), ProjectName.

**Protocol**: XamlMessageType goes up to 559; new messages would start at 560 (`GetElementBoundsRequest`=560, `ElementAutomationActionRequest`=561). They must stay in sync with `UwpTap\XamlMessageType.h`.

**Constraints**
- Never push, rebase, or amend. Make a single commit with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- At the end, ask the user whether to update a skill. Possible candidate: the leaf-build dependency-chain trick, and the fact that the Copilot.Core context helpers aren't public.

**Open questions**: one skill or two; which API submits a prompt into Agent mode for the in-app re-route; how the Debugger agent includes the tools (DebuggerSdkAgent proxy).
</technical_details>

<important_files>
- **plan.md** (session folder): the approved plan.
- **`src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`**: Copilot ProjectReference added at line 148. Content items for the skill still need adding (existing Content example at ~line 143: `VS\XamlHotReloadSettings.registration.json` with CopyToOutputDirectory).
- **`...\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs`**: MEF exports at lines 44-46; the ctor (lines 62-89) is where the hot reload logger will be wrapped.
- **`...\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs`**: members (84-105), OnSessionStarted (157), OnEndpointChanged (175-230), OnSessionStopped (233).
- **`...\Diagnostics\XamlDiagnosticsPackage.cs`** and **`XamlDiagnosticsTestContract.cs`** (47-135): host acquisition.
- **`...\Diagnostics\ElementTree\ElementTreeContainer.cs`**: tree API.
- **`...\Tool\UI\LivePropertyExplorer\Model\PlatformObjectCache.cs`** (130-185): the property request pattern.
- **`...\Tool\Model\ElementProperty.cs`** (137-170): the set-property request.
- **`...\Tool\Managers\RenderTargetBitmapManager.cs`**: RTB.
- **`...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`**: a11y run.
- **`...\SourceNavigation\SourceNavigatorExtensions.cs`**: source navigation.
- **`src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs`**: the function provider template.
- **`src\Copilot\src\Copilot.Core\Debugging\CopilotExtensions.cs`** (60-95): context helpers to replicate.
- **`src\Xaml\copilot-instructions.md`** and **`src\Xaml\.copilot\skills\xaml-build-test-deploy\SKILL.md`**: XAML build/test guidance.
</important_files>

<next_steps>
Immediate next steps: create the files in `src\Xaml\Diagnostics\Source\Diagnostics\Copilot\` (the SDK-style csproj auto-includes .cs files):
1. **`XamlHotReloadLogBuffer.cs`**: the IHotReloadLogger decorator plus a static 500-entry ring buffer. Wire it into the VisualStudioXamlDiagnosticsHost ctor.
2. **`XamlAgentService.cs`**: a MEF `[Export]` façade that:
   - acquires the host via the package,
   - maps endpoint keys (short index per EndPointId),
   - parses element IDs (`"{key}:{handle}"`),
   - reads the tree on the UI thread (depth/maxNodes),
   - finds elements,
   - gets and sets properties,
   - reads and clears binding failures,
   - reports hot reload status, log and apply,
   - lists windows from RemoteContents,
   - captures images (PrintWindow for windows; RTB for elements on UWP/WinUI; UNSUPPORTED_BY_TAP for WPF elements),
   - runs a11y,
   - builds diagnostics-status reasons.

   It produces JSON output (check whether Newtonsoft or System.Text.Json is already available transitively, otherwise use DataContractJsonSerializer or a hand-built string), with timeouts and error codes.
3. **`XamlDiagnosticsFunctionProvider.cs`**: the `xaml_*` tools. Required-confirmation tools take a `CopilotFunctionInvocationContext` parameter.
4. **`XamlDiagnosticsSkillsProvider.cs`** plus `Copilot\skills\xaml-diagnostics\SKILL.md` and `references\*.md` as Content (CopyToOutputDirectory, and include them in the VSIX).
5. Build after each step with the leaf-build command.

Then do the rest, in order:
- the Copilot-repo registration (FirstPartyToolsProvider AllFromProviderTool and FirstPartySkills; DebuggerSdkAgent)
- the mutation tools
- the WPF TAP messages (560/561, with a new DiagnosticBits capability)
- the in-app ICopilotExtension re-route
- WinUI and MAUI TAP support
- unit tests in `src\Xaml\Diagnostics\Test\Unit`, and docs (README, `Documentation\copilot-tools.md`)
- build and test, make a single commit with the trailers, don't push, and ask the user about updating a skill
</next_steps>