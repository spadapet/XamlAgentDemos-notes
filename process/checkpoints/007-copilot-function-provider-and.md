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
   - I wrote plan.md and added SQL todos. The user approved the plan.

2. **Implementation, earlier segments.**
   - Added the Copilot ProjectReference to Diagnostics.csproj.
   - Got the leaf build working.
   - Researched all the host APIs.
   - Created AgentTools: `XamlAgentService`, `XamlAgentImaging`, `XamlAgentException` and `XamlHotReloadLogBuffer`.
   - Wired the log buffer into the host ctor.

3. **This segment.**
   - Built Diagnostics and fixed the compile errors:
     - added `using Microsoft.VisualStudio.DesignTools.Diagnostics.TapOM;` (for `DiagnosticBits` and `LivePreviewKind`)
     - added `using Microsoft.VisualStudio.Threading;` (for `await TaskScheduler.Default`)
     - fixed the `uint`/`int?` conditionals by using `(int?)x : null`
     - fully qualified `System.Windows.Interop.Imaging.CreateBitmapSourceFromHBitmap`
   - **The build now succeeds.**
   - Created `XamlDiagnosticsFunctionProvider.cs`, which has 16 tools. **The build succeeds.**
   - Investigated packaging (setup files.swr), the skills provider attribute, and FirstPartyToolsProvider.
   - Edited the Copilot repo's FirstPartyToolsProvider to register the tools and the skill. **This hasn't been compiled yet.**
   - Started looking at DebuggerSdkAgent (`src\Copilot\src\Copilot.Vsix\Agents\Sdk\DebuggerSdkAgent.cs`) to add the XAML tools to the Debugger agent.
</history>

<work_done>
Files created or modified (all under `Q:\src\VS_xaml`):

- `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`, line ~148: Copilot ProjectReference (`Private="false"`).
- `src\Xaml\Diagnostics\Source\Diagnostics\VS\VisualStudioXamlDiagnosticsHost.cs`: the ctor wraps the hot reload logger with `AgentTools.XamlHotReloadLogBuffer.Wrap(...)`.
- `...\Diagnostics\AgentTools\XamlAgentService.cs`: the MEF `[Export]` façade. It compiles. Public methods:
  - `ListAppsAsync`, `GetDiagnosticsStatusAsync`
  - `GetVisualTreeAsync(app, rootElementId, depth, maxNodes, ct)`
  - `FindElementsAsync(app, type, name, sourceFile, line, maxResults, ct)`
  - `SelectElementAsync(elementId, goToSource, ct)`
  - `GetElementPropertiesAsync(elementId, nameFilter, includeAll, ct)`
  - `SetElementPropertyAsync(elementId, propertyName, value, reset, ct)`
  - `GetBindingFailuresAsync(textFilter, max, ct)`, `ClearBindingFailuresAsync`
  - `GetHotReloadStatusAsync`, `GetHotReloadLog(max, errorsOnly, textFilter)` (synchronous), `ApplyHotReloadAsync`
  - `ListWindowsAsync(app, ct)`
  - `CaptureImageAsync(app, windowId, elementId, maxSize, ct)`, which returns `CaptureResult{Png, Width, Height, Description}`
  - `RunAccessibilityCheckAsync(max, ct)`, `GetAccessibilityResultsAsync(max, ct)`
  - All the others return `Task<object>`.
- `...\AgentTools\XamlAgentImaging.cs`: PrintWindow capture, PNG encoding, window enumeration. It compiles.
- `...\AgentTools\XamlAgentException.cs`: `XamlAgentErrorCodes` plus `XamlAgentException(code, message, hint)` with `Code` and `Hint` properties.
- `...\AgentTools\XamlHotReloadLogBuffer.cs`: a ring buffer decorator over `IHotReloadLogger`. It compiles.
- **NEW** `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`. **It compiles.**
  - `internal sealed class : CopilotFunctionHandler, IExportedBrokeredService`, with `[ExportBrokeredService("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions","0.1",Audience=Local)]` and a private `[ImportingConstructor](XamlAgentService)`.
  - Tools:

    | Tool | Confirmation |
    |---|---|
    | `xaml_list_apps` | NotRequired |
    | `xaml_get_diagnostics_status` | NotRequired |
    | `xaml_get_visual_tree` | NotRequired |
    | `xaml_find_elements` | NotRequired |
    | `xaml_get_element_properties` | NotRequired |
    | `xaml_set_element_property` | Required |
    | `xaml_select_element` | Required |
    | `xaml_get_binding_failures` | NotRequired |
    | `xaml_clear_binding_failures` | Required |
    | `xaml_get_hot_reload_status` | NotRequired |
    | `xaml_get_hot_reload_log` | NotRequired |
    | `xaml_apply_hot_reload` | Required |
    | `xaml_list_windows` | NotRequired |
    | `xaml_capture_image` | NotRequired; returns `CopilotContext[]`: an image context plus a string context |
    | `xaml_run_accessibility_check` | NotRequired |
    | `xaml_get_accessibility_results` | NotRequired |

  - Required tools take `ICopilotFunctionBroker`. They call `broker.AskConfirmationAsync(new CopilotConfirmationRequestOptions(title, desc){PermissionScope="XamlDiagnostics.Mutation"})` and return `USER_DECLINED` JSON if the user declines.
  - Results are serialized with Newtonsoft (NullValueHandling.Ignore). Errors become `{error, message, hint}`.
  - Progress is reported as `new CopilotProgress(status){Description=msg}`.
  - It uses `#pragma warning disable VSCOPILOT_API`.
- **MODIFIED (Copilot repo, not compiled yet)** `src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`:
  - `FirstPartySkills` now contains `XamlDiagnosticsSkillName` = "xaml-diagnostics" (a private const).
  - Added `internal static readonly Guid XamlDiagnosticsToolsUIContext = new("5C69788A-62F3-42C8-880A-1A4CE40C6671")`, declared before FirstPartyTools so static init order is fine.
  - Added this entry, with a Description/Repo/Project comment block, at the end of the `FirstPartyTools` array:
    ```
    new AllFromProviderTool(moniker: new("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions", new("0.1")), uiContext: XamlDiagnosticsToolsUIContext) { ApplicableHost = FirstPartyToolHost.VisualStudio }
    ```

SQL todo status:
- done: plumbing
- in_progress: function-provider (nearly done), readonly-tools, copilot-registration
- pending: skill, hot-reload-tools, mutation-tools, tap-wpf, inapp-reroute, tap-winui, tap-maui, docs-tests

hot-reload-tools and mutation-tools are effectively implemented in the service and provider.
</work_done>

<technical_details>
**Build**
- Run these in one PowerShell call from `Q:\src\VS_xaml`:
  ```
  & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null
  & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj -NoProjectReferences -NoRestore
  ```
  It takes about 30-60 s.
- C# collection expressions (`[a, b]`) compile in Diagnostics.
- The Copilot.Vsix project hasn't been built yet. Find its csproj under `src\Copilot\src\Copilot.Vsix\` and leaf-build it the same way. Leaf-build any missing dependencies (CS0006) first.

**Copilot API facts (verified)**
- `CopilotFunctionHandler` discovers `[CopilotFunction]` methods by reflection (public and non-public), so an internal class works. CMake's provider is also internal.
- No pkgdef is needed for `ExportBrokeredService` MEF exports. Diagnostics.dll is already a MefComponent in its source.extension.vsixmanifest.
- `CopilotConfirmationRequirement.Required` requires an `ICopilotFunctionBroker` or `CopilotFunctionInvocationContext` parameter; otherwise the descriptor throws. The function itself must call `AskConfirmationAsync`. `CopilotConfirmationStatus` values are Unknown, Accepted and Rejected.
- `CopilotProgressStatus` values are Pending, Completed and Error.
- Image context:
  ```
  new CopilotContext(CopilotDescriptors.Context.Image.Moniker, "image", corrId, CopilotDefaultTypes.ImageContextName, new CopilotImageContext{...}){CanReduce=false}
  ```
- String context: `new CopilotContext(new ServiceMoniker("Microsoft.VisualStudio.Copilot.MiscellaneousContextProvider", new Version(CopilotDescriptors.CurrentContextProviderVersion)), "miscellaneous", corrId, CopilotDefaultTypes.StringName, text)`.
- Skills:
  - Use `[CopilotSkillsProvider(directory, uiContextString)]` on a class implementing the empty `ICopilotSkillsProvider` interface. The attribute is `[Experimental(ExperimentalFeatures.Backend)]`, so it needs `#pragma warning disable VSCOPILOT_BACKEND`.
  - The directory is relative to the provider's assembly. The deepest folder must be named `skills`, and each child folder needs a `SKILL.md`.
  - The provider is never instantiated.
- UIContext: use `GuidList.UICONTEXT_DiagnosticToolWindowsAvailable` = "5C69788A-62F3-42C8-880A-1A4CE40C6671" (Guids.cs:63). It's the rule "Debugging | DiagnosticConnectionActive" from XamlDiagnosticsPackage.cs:69. This resolves open question 1, including MAUI design-time sessions.
- Debugger agent: `src\Copilot\src\Copilot.Vsix\Agents\Sdk\DebuggerSdkAgent.cs` (not under AgentMode).
  - It builds `CopilotFunctionAggregator([...CopilotFunctionProviderSource(provider)...])` from MEF-imported providers.
  - `CopilotFunctionProviderSource` is a record `(ICopilotFunctionProvider Provider, Func<...>? Selector)` in Copilot.Core/Functions/CopilotFunctionAggregator.cs.
  - The XAML provider is a brokered service in another assembly. Including it needs a proxy `ICopilotFunctionProvider` obtained via `serviceBroker.GetProxyAsync<ICopilotFunctionProvider>(descriptor)`, or a lazy wrapper. The agent already has `[Import(typeof(SVsFullAccessServiceBroker))] IServiceBroker serviceBroker`.
  - The legacy `DebuggerAgentResponderProvider` (Copilot.Core/Debugging) has a similar sources list (lines ~124-134).

**Setup**
- `src\SetupPackages\Xaml\Diagnostics\core\files.swr` installs Diagnostics.dll to `InstallDir:\Common7\IDE\CommonExtensions\Microsoft\XamlDiagnostics`. Its source is `!(bindpath.binaries.x86)\bin\netsdk\xaml\Diagnostics\$(VSDefaultTFM)\`.
- Skill files need `folder "AgentTools"` / `folder "skills"` / `folder "xaml-diagnostics"` entries there, following the existing `folder "Settings"` pattern.
- In the csproj, add Content items with CopyToOutputDirectory, following the existing pattern for `VS\XamlHotReloadSettings.registration.json`.

**Constraints**
- Never push, rebase, or amend. Make a single commit at the end with these trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use `git -C`.
- File header style in AgentTools is the dashed `// ---...` Copyright header.
- At the end, ask the user whether to update a skill. Candidates:
  - the leaf-build dependency trick
  - Copilot.Core helpers (CreateImageContext/CreateStringContext) aren't public
  - Required confirmation needs a broker parameter and an explicit AskConfirmationAsync

**Open questions**
- Which API submits a prompt into Agent mode for the in-app re-route.
- New TAP messages would be 560/561 with DiagnosticBits capability 0x20 (deferred phase).
</technical_details>

<important_files>
- **plan.md** (session folder): the approved plan.
- **`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`**: the Copilot tools. Done and compiles.
- **`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**: the core façade. Compiles.
- **`src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`**: tool and skill registration (lines ~54-64, ~251-260). Edited but not built.
- **`src\Copilot\src\Copilot.Vsix\Agents\Sdk\DebuggerSdkAgent.cs`**: the aggregator at lines ~48-80. The XAML proxy source needs adding here.
- **`src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`**: the skill Content items still need adding (near line 143).
- **`src\SetupPackages\Xaml\Diagnostics\core\files.swr`**: the skill files still need adding.
- **`src\Xaml\Diagnostics\Source\Diagnostics\XamlDiagnosticsPackage.cs`** (lines 64-73): UIContext rules.
</important_files>

<next_steps>
Immediate next steps:
1. **Debugger agent inclusion.** In DebuggerSdkAgent, add a source for the XAML brokered provider. Write a small lazy proxy `ICopilotFunctionProvider` that calls `serviceBroker.GetProxyAsync<ICopilotFunctionProvider>(CopilotDescriptors.CreateDescriptor(new ServiceMoniker("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions", new Version("0.1"))))` and returns an empty list if it's unavailable. Alternatively, check whether a helper for brokered function providers already exists in Copilot.Core. Then build Copilot.Vsix (leaf) to verify both Copilot-repo edits.
2. **Skills provider and content.**
   - Create `AgentTools\XamlDiagnosticsSkillsProvider.cs` with `[CopilotSkillsProvider(@"AgentTools\skills", GuidList.UICONTEXT_DiagnosticToolWindowsAvailable)]`, an internal sealed class implementing `ICopilotSkillsProvider`, and the `VSCOPILOT_BACKEND` pragma.
   - Create `AgentTools\skills\xaml-diagnostics\SKILL.md`. It needs frontmatter with name and description, should stay at about 500 lines or fewer, and covers the tool catalog, workflows, enablement and the "why unavailable" checklist.
   - Create `references\` files: `enablement-and-troubleshooting.md`, `hot-reload.md`, `xaml-authoring.md` (designer and hot-reload friendly XAML, design-time data, etc.), and `platform-notes.md`.
   - Add csproj Content items (CopyToOutputDirectory PreserveNewest) and files.swr entries.
   - Load the `writing-skills` skill before authoring.
   - Build.
3. Update the SQL todos: function-provider, copilot-registration, skill, hot-reload-tools and mutation-tools become done.

Remaining work:
- WPF TAP messages 560 (GetElementBounds) and 561 (ElementAutomationAction) with a capability bit, plus the `xaml_get_element_bounds` and `xaml_interact` tools.
- The in-app ICopilotExtension re-route.
- WinUI and MAUI TAP support.
- Unit tests for XamlAgentService and the provider in `src\Xaml\Diagnostics\Test\Unit`. Use `src\Xaml\Scripts\Build-Xaml.ps1 -Component Diagnostics -Scope Test` and `Test-Xaml.ps1 -Suite diagnostics -Filter X`.
- Docs: `src\Xaml\Diagnostics\README.md` and `Documentation\copilot-tools.md`.
- Final build, then a single commit with the trailers and no push.
- Ask the user about updating a skill.
</next_steps>