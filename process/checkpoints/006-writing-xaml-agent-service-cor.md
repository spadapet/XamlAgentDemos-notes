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
   - I asked scope questions, wrote plan.md, and added 12 SQL todos. The plan was approved.

2. **Implementation, earlier segments.**
   - Added the Copilot ProjectReference to Diagnostics.csproj.
   - Got the leaf build working (built the dependencies ToolboxControlsInstaller, then DesignerHost, then Diagnostics). It builds cleanly.
   - Researched all the host, tree, property, RTB, Live Preview, binding, a11y and hot-reload APIs.

3. **Implementation, this segment.**
   - Verified the remaining APIs:
     - SourceNavigator and ISourceInfoResolver
     - the a11y view model and issue interfaces
     - RenderTargetBitmapManager and BitmapDataPayload (internal)
     - the XamlMessageType list (500-559)
     - the IXamlDiagnosticsHost, IXamlHotReloadHost and IDiagnosticHost members
     - IMarkupChangeErrorManager, IMarkupChangeProcessingInformation and MarkupChangeError
     - IBindingFailures and IBindingFailure
     - IXamlUserOptions
     - ElementTreeContainer, IElement and ILiveNode
     - the Endpoint members
     - the property DTOs
     - package Initialized semantics (it fires immediately if the host already exists)
   - Confirmed that Newtonsoft.Json 13.0.4 and System.Text.Json are available in the assets.
   - Chose the folder and namespace **`AgentTools`**. `Copilot` would collide with the existing `ICopilotExtension` area.
   - Created four new files, listed below, and wired the log buffer into the host ctor. **None of the new code has been compiled yet.**
</history>

<work_done>
Files modified:
- `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`, line 148: added `<ProjectReference Include="$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj" Private="false" />`. This builds.
- `src\Xaml\Diagnostics\Source\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs`, ctor (lines ~68-70): the base call now passes `new Lazy<IHotReloadLogger>(() => AgentTools.XamlHotReloadLogBuffer.Wrap(hotReloadLogger.Value))`.

Files created (all in `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`, namespace `Microsoft.VisualStudio.DesignTools.Diagnostics.AgentTools`):
- `XamlHotReloadLogBuffer.cs`
  - `XamlHotReloadLogEntry` DTO.
  - `XamlHotReloadLogBuffer : IHotReloadLogger` decorator with:
    - a static 500-entry ring buffer
    - `Wrap`, `Record`, `GetEntries`, `Clear`
    - `LogAsync`, which records `message.Message`, `ErrorLevel?.ToString()`, `Verbosity` and `ProjectName`, then forwards. These property names are unverified and could fail to compile.
- `XamlAgentException.cs`: the `XamlAgentErrorCodes` constants (NO_APPS, APP_NOT_FOUND, ELEMENT_GONE, INVALID_ARGUMENT, PROPERTY_NOT_FOUND, UNSUPPORTED_PLATFORM, UNSUPPORTED_BY_TAP, TAP_ERROR, TAP_TIMEOUT, NOT_AVAILABLE, WINDOW_NOT_FOUND) and `XamlAgentException(code, message, hint)`.
- `XamlAgentImaging.cs`: a static helper that:
  - provides `GetWindowInfo(hwnd)` (title, rect, DPI, visible, minimized),
  - provides `GetTopLevelWindows(pid)` (EnumWindows, visible, unowned),
  - provides `CaptureWindow(hwnd)`, which uses PrintWindow with PW_RENDERFULLCONTENT=2 and returns a frozen BitmapSource via `Imaging.CreateBitmapSourceFromHBitmap`,
  - provides `EncodePng(source, maxSize, out w, out h)`, which scales with TransformedBitmap and encodes with PngBitmapEncoder,
  - defines `DefaultMaxImageSize` = 1280,
  - contains the P/Invoke NativeMethods.
- `XamlAgentService.cs` (~59 KB): a MEF `[Export(typeof(XamlAgentService))]` Shared, internal sealed class. Methods:
  - `GetHostAsync`: switches to the UI thread, loads the package with VsPackageLoader, and waits for `Initialized`, with a 10 s timeout.
  - Endpoint keys `"a1"`, `"a2"`, … per EndPointId. Element IDs have the form `"{appKey}:{handle}"`.
  - `FindEndpoint` and `FindElement`, which throw structured errors.
  - `SendTapMessageAsync<T>`: timeout plus `TapExceptionSuppressor`.
  - `ListAppsAsync`, `GetDiagnosticsStatusAsync` (an issues list of `{issue, evidence, fix}`), `GetOptions`.
  - `GetVisualTreeAsync(app, rootElementId, depth=4, maxNodes=200, cap 2000)`.
  - `FindElementsAsync(app, type, name, sourceFile, line, maxResults)`.
  - `SelectElementAsync(elementId, goToSource)`: sets `ActiveElementTracker.ActiveElement` and calls `host.NavigateToSource`.
  - `GetElementPropertiesAsync(elementId, nameFilter, includeAll)`: uses PropertyChainRequest with Reset=false and Level=All. Default/overridden properties are hidden unless includeAll is set.
  - `SetElementPropertyAsync(elementId, propertyName, value, reset)`: Object is the element handle; CreateInstanceType is string, except for UWP/WinUI. It re-reads the new value afterwards.
  - `GetBindingFailuresAsync(textFilter, max)` and `ClearBindingFailuresAsync`.
  - `GetHotReloadStatusAsync`: options, .NET HR enabled, isProcessing, the env var `XAML_HOT_RELOAD_ACCURACY_OVER_PERF`, per-app HR state, and RuntimeErrors with line/col computed from the file offset.
  - `GetHotReloadLog(max, errorsOnly, textFilter)` (synchronous).
  - `ApplyHotReloadAsync`: waits while IsProcessing, then returns errors and new log lines.
  - `ListWindowsAsync(app)`: LivePreview RemoteContents plus an EnumWindows fallback, with windowId `"0x{HWND hex}"`.
  - `CaptureImageAsync(app, windowId, elementId, maxSize)`: returns `CaptureResult{Png, Width, Height, Description}`.
    - Windows are captured with PrintWindow; only HWNDs that belong to connected apps are allowed.
    - Elements use RTB only for UWP/WinUI. Other platforms get UNSUPPORTED_BY_TAP.
  - `RunAccessibilityCheckAsync`: owns its own `AccessibilityIssuesViewModel(host)`, clears it, runs `RunAsync`, and waits ≤5 s for SourceInfoReceived.
  - `GetAccessibilityResultsAsync`.
  - Nested `SourceResolver`: `host.GetSourceInfoResolver(endpoint).ResolveRuntimeSourceInfo(si).Path`, cached per call.

SQL todos:
- done: plumbing
- in_progress: function-provider, readonly-tools
- pending: copilot-registration, skill, hot-reload-tools, mutation-tools, tap-wpf, inapp-reroute, tap-winui, tap-maui, docs-tests
</work_done>

<technical_details>
**Build**
- Run these in one PowerShell process from `Q:\src\VS_xaml`:
  ```
  & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null
  & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoProjectReferences -NoRestore
  ```
  It takes about 30-60 s. If CS0006 reports a missing metadata file, leaf-build that dependency first. Don't use the full-reference build: it hits unrelated environment failures.
- For tests, use `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Test` and `Test-Xaml.ps1 -Suite diagnostics -Filter X`.

**Namespaces likely needed (unverified; fix at compile time)**
- The service's current usings include `RuntimeHost.Markup` (a guess for MarkupChangeError), `RuntimeHost.Networking` and `RuntimeHost.TapOM`.
- `DiagnosticBits` may be in `...TapContract.TapOM`, and `SupportedPlatform` may need `Diagnostics.Platform` or `XamlTapContract.TapOM`.
- `RemoteContent` is in `Diagnostics.LivePreview`.
- `LivePreviewKind`, `RenderTargetBitmapRequestInfo` and `RenderTargetBitmapResponseInfo` are in `TapContract.TapOM`. Existing Diagnostics files alias these through `RuntimeHost.TapOM`.
- `BaseValueSource` should be aliased as `using BaseValueSource = Microsoft.VisualStudio.DesignTools.RuntimeHost.TapOM.BaseValueSource;` (from PlatformObjectCache).
- `ElementKind` is in `RuntimeHost.Live`.
- `ElementTreeContainer` and `ElementTree` are in `Diagnostics.UI.LiveVisualTree.Model`.
- `XamlDiagnosticsHost` is in `Diagnostics.Model`.
- `ISourceInfoResolver` and `GetSourceInfoResolver` are in the `Diagnostics` namespace (DiagnosticsBase\Project).
- `Logger` is ambiguous, so avoid using it.
- `KnownUIContexts` comes from Microsoft.VisualStudio.Shell.
- `PropertyRequestLevel` has the values All=0 and Layout=1.

**API facts**
- `XamlDiagnosticsHost`: TreeContainer, ActiveElementTracker, LivePreviewManager, BindingFailuresProvider, UserOptions, DiagnosticNotAvailableReason, IsActive, Endpoints, MarkupChangeErrorManager.RuntimeErrors, HotReloadProcessingInformation.IsProcessing, HotReloadOptions.IsDotNetHotReloadEnabledAsync, `ApplyXamlChangesAsync(ct)`.
- `endpoint.InstanceManager()` is HotReloadInstanceManager, which has `IsEnabled`.
- `SourceNavigatorExtensions` (internal) provides `GetSourceNavigator` and `NavigateToSource(host, endpoint, MarkupLocation)`. `ISourceNavigator.GetFilePath` requires `CacheSourceInfoAsync` to have been called first.
- `AccessibilityIssuesViewModel(IXamlDiagnosticsHost)` (internal):
  - Its constructor must run on the UI thread (it asserts in AddEndpoint).
  - Members: `RunAsync()`, `ClearEntries()`, `Entries` (TableEntryAdapter.AccessibilityIssue), `SourceInfoReceived`, `Dispose`.
  - `IAccessibilityIssue`: Rule, HowToFix, Description, AutomationId, ProcessId, ScanData (with SourceNavigator), ElementInfo (RuntimeId, ClassName, ElementName, Rectangle, SourceInfo).
- RTB: `RenderTargetBitmapRequestInfo{InstanceHandle, RenderFlags=0, MaxWidth, MaxHeight}`. Then `new BitmapDataPayload(response).GenerateImageSource()` produces a WriteableBitmap; `payload.Result.Ok` and `ReturnCode` give the status. Only UwpTap implements RTB.
- `GetElementSnapData` (533) is UwpTap-only (SnapLineService), so it can't be used to get WPF bounds.
- `ThreadHelperBase` (Utility): Factory, ReentrantFactory, ThrowIfNotOnUIThread, RunOnUIThread.

**Copilot API, for the next file**
- Provider:
  - `[ExportBrokeredService(Name,"0.1",Audience=ServiceAudience.Local)] sealed class : CopilotFunctionHandler, IExportedBrokeredService`
  - `Moniker = new ServiceMoniker(Name, new Version("0.1"))`, `Descriptor = CopilotDescriptors.CreateDescriptor(Moniker)`, `InitializeAsync` returns CompletedTask
  - `[ImportingConstructor]` can be private
- Tool methods:
  - `[CopilotFunction(name, desc, CopilotConfirmationRequirement.X)] public async Task<string|CopilotContext> M([CopilotDescription] string progressMessage, CopilotRequest originalRequest, IProgress<CopilotProgress> progress, CancellationToken ct, [CopilotDescription] optional params)`
  - Required-confirmation tools must also take `CopilotFunctionInvocationContext` or `ICopilotFunctionBroker`.
  - May need `#pragma warning disable VSCOPILOT_API`.
- Image context:
  ```
  new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", correlationId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext{Data, MimeType="image/png", Width, Height, FilePath=null!}){CanReduce=false}
  ```
  `CreateImageContext` is in Copilot.Core and can't be referenced.
- Skills: `[CopilotSkillsProvider(@"relative\skills", uiContextGuid)]` on an `ICopilotSkillsProvider` export; it may need the `VSCOPILOT_BACKEND` pragma.
- UIContext: `GuidList.UICONTEXT_DiagnosticToolWindowsAvailable`.
- JSON output: use Newtonsoft `JsonConvert.SerializeObject(obj, new JsonSerializerSettings{NullValueHandling=Ignore})`. Catch `XamlAgentException` and return `{error=code, message, hint}`.

**Constraints**
- Never push, rebase, or amend. Make a single commit at the end with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- At the end, ask the user whether to update a skill. Candidates: the leaf-build dependency trick, and the fact that the Copilot.Core helpers aren't public.

**Open questions**
- One skill or two.
- Which API submits a prompt into Agent mode for the in-app re-route.
- How the Debugger agent includes the tools (DebuggerSdkAgent proxy).
- New TAP messages would be 560 (`GetElementBoundsRequest`) and 561 (`ElementAutomationActionRequest`), synced with `UwpTap\XamlMessageType.h`. A new DiagnosticBits capability bit would be 0x20, synced with `UwpTap DiagnosticBits.h`.
</technical_details>

<important_files>
- **plan.md** (session folder): the approved plan and source of truth.
- **`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**: the core façade. Newly written and not yet compiled.
- **`...\AgentTools\XamlAgentImaging.cs`**, **`XamlAgentException.cs`**, **`XamlHotReloadLogBuffer.cs`**: newly written helpers.
- **`...\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs`**: the logger wrap in the ctor (lines 62-71).
- **`...\Diagnostics\Diagnostics.csproj`**: the Copilot reference (line 148). The skill Content items still need adding; see the existing Content example near line 143.
- **`...\Diagnostics\Tool\Model\XamlDiagnosticsHost.cs`**: host members (lines 84-105).
- **`...\AccessibilityChecker\ToolWindow\AccessibilityIssuesViewModel.cs`**: the a11y run.
- **`...\Tool\Model\ElementProperty.cs`** (lines 137-170): the reference for set-property.
- **`src\Copilot\src\Copilot.Vsix\Debugging\DebuggerUIFunctionProvider.cs`**: the template for the function provider.
- **`src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`** and **`DebuggerSdkAgent.cs`** (lines 66-79): where the tools get registered.
</important_files>

<next_steps>
Immediate next steps:
1. Build Diagnostics with the leaf-build command and fix the compile errors in AgentTools: namespaces, the HotReloadLogMessage property names, BitmapDataPayload, the `is not` pattern and C# language version, and anything else the compiler reports.
2. Create `AgentTools\XamlDiagnosticsFunctionProvider.cs` with these tools:

   | Tool | Confirmation |
   |---|---|
   | `xaml_list_apps` | NotRequired |
   | `xaml_get_diagnostics_status` | NotRequired |
   | `xaml_get_visual_tree` | NotRequired |
   | `xaml_find_elements` | NotRequired |
   | `xaml_get_element_properties` | NotRequired |
   | `xaml_get_binding_failures` | NotRequired |
   | `xaml_get_hot_reload_status` | NotRequired |
   | `xaml_get_hot_reload_log` | NotRequired |
   | `xaml_list_windows` | NotRequired |
   | `xaml_capture_image` | NotRequired (returns an image CopilotContext plus a text description) |
   | `xaml_run_accessibility_check` | NotRequired |
   | `xaml_get_accessibility_results` | NotRequired |
   | `xaml_select_element` | Required |
   | `xaml_set_element_property` | Required |
   | `xaml_clear_binding_failures` | Required |
   | `xaml_apply_hot_reload` | Required |

   It should import `XamlAgentService` via MEF (or `[Import]` in the brokered-service ctor), serialize results to JSON, and map exceptions to error JSON.
3. Create `AgentTools\XamlDiagnosticsSkillsProvider.cs` plus the skill content: `AgentTools\skills\xaml-diagnostics\SKILL.md` and `references\*.md` covering enablement, troubleshooting, tool workflows, and XAML authoring for the designer and hot reload. Add them as Content items with CopyToOutputDirectory and VSIX inclusion.
4. Build after each step.

Remaining work, in order:
- the Copilot-repo registration (FirstPartyToolsProvider `AllFromProviderTool` plus FirstPartySkills; DebuggerSdkAgent inclusion)
- the WPF TAP messages 560/561 with a capability bit (bounds, interact)
- the in-app ICopilotExtension re-route
- WinUI and MAUI TAP support
- unit tests in `src\Xaml\Diagnostics\Test\Unit`, and docs (README, `Documentation\copilot-tools.md`)
- final build and test, a single commit with the trailers, no push, and ask the user about updating a skill
- keep the SQL todo statuses updated as I go
</next_steps>