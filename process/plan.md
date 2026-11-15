# XAML Diagnostics for Copilot — Feature Plan (prototype)

## 1. Problem

VS has rich XAML runtime diagnostics, but Copilot can't see or use any of them:
- Live Visual Tree (LVT)
- Live Property Explorer (LPE)
- Live Preview
- Binding Failures
- Accessibility Checker
- XAML Hot Reload (XHR)

All of these talk to the running app through the injected **TAP** DLL over `ProtocolHandler`. The goal is to let Copilot do these things while the user is debugging, or using MAUI design-time preview:
- discover the XAML apps,
- inspect the tree, properties, layout, images, binding failures, a11y issues and hot reload state,
- change things (set properties, interact, trigger hot reload),
- explain why something is unavailable, then fix XAML/code in the solution.

## 2. Decisions (confirmed with user)

| Topic | Decision |
|---|---|
| Surfaces | **In-proc agent-mode tools** plus a **built-in skill**. There's **no dedicated XAML agent**. Tools must work in normal **Agent mode** and in the **Debugger agent**. |
| Assembly | Put everything in the existing **`Microsoft.VisualStudio.DesignTools.Diagnostics.dll`** (`src\Xaml\Diagnostics\Source\Diagnostics`). Add a `ProjectReference` to `$(INETROOT)\src\Copilot\src\Copilot\Copilot.csproj`, the same pattern CMake uses (`src\vc\projbld\CMake\Package\...csproj:368`). |
| Skill content | General knowledge about how XAML Diagnostics/XHR work (enablement, requirements, troubleshooting, tool workflows), **plus XAML-authoring guidance so the XAML works well with the XAML designer** (and hot reload / diagnostics). |
| Mutations | `CopilotConfirmationRequirement.Required`. The user can "always allow" per session. |
| TAP | New TAP messages are allowed **only** where no existing message provides the info or action. All new messages are capability-negotiated. |
| Platform rollout for new TAP capabilities | WPF → WinUI/UWP (native UwpTap) → MAUI. |
| In-app Copilot prototype | **Re-route** it through the new implementation: the in-app prompt goes to Copilot chat with XAML context, and the new tools become available. |
| MAUI design-time sessions | **Included** wherever the endpoint supports it. |
| Prototype mindset | Pick what's easiest and works. Keep it behind a feature flag. |

## 3. Architecture

```
 Copilot Chat (Agent mode / Debugger agent)
        │ tool calls (brokered service, Audience=Local)
        ▼
 XamlDiagnosticsFunctionProvider  ([CopilotFunction] methods)         ┐
        │                                                             │  Diagnostics.dll
 XamlAgentService  (pure C#, testable; DTOs, paging, handle registry) │  (new folder: Copilot\)
        │                                                             │
 IXamlDiagnosticsHost / ElementTreeContainer / PropertyExplorer /     │
 BindingFailuresProvider / AccessibilityChecker / LivePreviewManager /│
 RenderTargetBitmapManager / IXamlUserOptions / HotReload logger tee  ┘
        │ ProtocolHandler.SendMessageAsync (existing + few new messages)
        ▼
 TAP in app: WpfTap │ UwpTap (UWP+WinUI) │ MauiTap
```

### 3.1 Components (all in Diagnostics.dll, folder `Copilot\`)

1. **`XamlAgentService`** (MEF `[Export]`, internal). This is the single façade over the host model. It:
   - resolves endpoints,
   - assigns stable **agent element IDs** (`"{endpointShortId}:{instanceHandle}"`),
   - does paging and limits,
   - converts model objects to JSON-friendly DTOs,
   - owns the "why unavailable" diagnostics.

   All tools call it, and so does the in-app Copilot re-route. It's unit-testable with existing mocks (Unit/Component test projects).
2. **`XamlDiagnosticsFunctionProvider`**, which implements `ICopilotFunctionProvider` via `[CopilotFunction]` attributes. It is exported with `[ExportBrokeredService("Microsoft.VisualStudio.Xaml.Diagnostics.CopilotFunctions", "0.1", Audience = ServiceAudience.Local)]`. The pattern is in `DebuggerUIFunctionProvider.cs:27-28` and CMake's provider. Images are returned as `CopilotContext` image contexts (`CreateImageContext`), as in `DebuggerUIFunctionProvider.cs:168-226`.
3. **New UIContext `XamlDiagnosticsActive`**. It's active when ≥1 XAML endpoint is connected (debug or MAUI design-time). It's set from `IXamlHotReloadHost.EndpointChanged`. This controls tool registration and skill activation. Tools stay callable when no endpoint exists, but `list_xaml_apps` must then explain *why* nothing is connected. So the plan registers the provider under **DebuggingMode OR XamlDiagnosticsActive**. The final choice is made during implementation, and the open question is in §9.
4. **Registration in the Copilot repo** (`src\Copilot\src\Copilot.Vsix\AgentMode\FirstPartyToolsProvider.cs`): add one `AllFromProviderTool(moniker, uiContext)` entry with a comment block (Description/Repo/Project) per file convention. This needs Copilot team approval/CI gates.
5. **Debugger agent inclusion**: `DebuggerSdkAgent.cs:66-79` builds a fixed `CopilotFunctionAggregator`. Add a source that proxies the XAML brokered provider so the tools also appear in the Debugger agent. This is a small Copilot-repo change. Alternative: a brokered-proxy `CopilotFunctionProviderSource`.
6. **Built-in skill** via `[CopilotSkillsProvider("Copilot\\skills", XamlDiagnosticsActive or DebuggingMode guid)]`. It is exported on a trivial `ICopilotSkillsProvider` class in Diagnostics.dll (`src\Copilot\src\Copilot\AgentSkills\CopilotSkillsProviderAttribute.cs`, consumed by `MefAgentSkillsPaths.cs`).
   - Ship `Copilot\skills\xaml-diagnostics\SKILL.md` (+ `references\*.md`) as VSIX content next to the DLL.
   - Add the skill name to `FirstPartyToolsProvider.FirstPartySkills` so it's enabled by default (Copilot-repo change).
   - Two skills might be better than one (`xaml-diagnostics`, `xaml-authoring`) so the authoring guidance also loads at design time with no debuggee. Decided in implementation; the authoring skill's UIContext would then be "XAML file open/solution has XAML".
7. **Hot Reload log tee**. This is a ring buffer (last N=500 entries) of XAML hot-reload log messages. It wraps the existing `IHotReloadLogger` usage in Diagnostics, logs the TAP `LogMessage` and `UpdatesApplied`, and records apply results and errors from `IMarkupChangeErrorManager`. No scraping of the output pane is needed.
8. **Feature flag**: `XamlDiagnostics.CopilotTools` (a VS feature flag) plus an option for disabling. Copilot also has per-tool user toggles.

### 3.2 Element identity & lifetime
- The ID is `endpointKey:handle`. `endpointKey` is a short stable index per `Endpoint.EndPointId` for the session. `handle` is the TAP instance handle already used by `PlatformObjectCache`/`ElementTreeContainer`.
- If an element no longer exists (tree mutation), tools return the structured error `ELEMENT_GONE` plus a hint to re-query.
- Results always include `endpointKey`, `platform`, and the element `type`/`name` so the model doesn't confuse apps.

### 3.3 Output limits / perf
- Tree tools default to `depth=3` and `maxNodes=200`, with continuation tokens (`childrenOf`) and a hard cap of 2000 nodes per call.
- Property lists are filtered by default to *local/set* values with a `category`/`nameFilter` parameter, and support an `includeAll` flag.
- Images default to ≤1280px on the long edge (the RTB max is 2048), as PNG.
- All tools are cancellable, use JTF correctly, never block the UI thread on TAP round-trips, and have a per-call timeout (e.g., 10 s) that returns `TAP_TIMEOUT`.

## 4. Tool catalog

Legend: **R** = read-only (NotRequired), **M** = mutating (Required). "New TAP" = needs new message (only where existing ones can't do it).

### Discovery & setup
| Tool | Kind | Description / data source |
|---|---|---|
| `xaml_list_apps` | R | Every endpoint: `endpointKey`, display name, OS PID (map `Endpoint.ProcessId` GUID to the debugger process if possible), platform (`SupportedPlatform`: WPF .NET FW / WPF .NET / UWP / WinUI / MAUI / Web), remote?, design-time vs debug, root windows, DiagnosticBits capabilities, source-info available?, JMX on?, hot reload enabled for platform? |
| `xaml_get_diagnostics_status` | R | Explains why LVT/XHR/source info are not available. Inputs: `XamlDiagnosticsHost.DiagnosticNotAvailableReason`, options (`debugging.xamlHotReload.*`), NotFirstProcess, attach vs F5, elevated process, platform disabled in options, `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO` not set or source info missing, project build properties (`XamlDebuggingInformation`, `DisableXbfLineInfo`, Debug config), unsupported platform/remote. Returns a list of `{issue, evidence, fix}` objects. |

### Live Visual Tree
| Tool | Kind | Description |
|---|---|---|
| `xaml_get_visual_tree` | R | Tree from a root (an app, window, or element ID), with depth/maxNodes paging and a `justMyXaml` flag (default = user option). Each node has: id, type, name, childCount, source location (file/line/col if known), visibility, and optionally bounds. |
| `xaml_find_elements` | R | Searches by type / x:Name / property value / text content / source file+line. Returns IDs and paths. Uses `GetNamedElements` + tree walk in `XamlAgentService`. |
| `xaml_get_element_bounds` | R | Pixel bounds (screen + window-relative + DPI scale) for one or more elements. **Needs a new TAP message, `GetElementBoundsRequest`** (no generic bounds message exists). WPF reuses the `TryGetElementRect` logic from `TapAccessibilityCheckerService.cs`. `get_visual_tree(includeBounds=true)` batches it. |
| `xaml_select_element` | M* | Selects in the LVT and highlights it in the app (existing `HostSelectionChange` / layout adorner). Marked Required only because it changes the IDE/app UI. It could be NotRequired. |
| `xaml_go_to_source` | R | Opens/returns the XAML source location of an element (existing source info / `DocumentViewManager`). |

### Live Property Explorer
| Tool | Kind | Description |
|---|---|---|
| `xaml_get_element_properties` | R | Properties with value, value source (local, style, template, inherited, default, binding…), type, and whether each is editable. Includes bindings/resources in the value chain. Existing `PropertyChainRequest`, `CollectionRequest`, `EnumsRequest`. |
| `xaml_get_property_value_details` | R | Expanded detail for one property: binding expression and resolved value, style setter origin, resource key, collection items. |
| `xaml_set_element_property` | M | Sets a property value (string → converted by TAP), or resets to default. Existing `SetPropertyRequest` (same path as `PropertyExplorerViewModel.SetValueAsync`). The result reminds the model that this is a *runtime-only* change and that source must be edited to persist. |

### Visual / Live Preview
| Tool | Kind | Description |
|---|---|---|
| `xaml_list_windows` | R | Top-level windows per app: title, HWND, size, DPI, RTL. From the Live Preview root registration data (`TapLivePreviewService` / `LivePreviewManager`). |
| `xaml_capture_image` | R | Image of a window or of an element subtree, returned as an image context. Strategy: **element** → `RenderTargetBitmapManager.RequestRenderTargetBitmap` (existing). **window** → the latest Live Preview frame if streaming, else RTB of the window root. **Fallback** → the debugger `debugger_screenshot` (UIA desktop capture), documented in the skill. An optional `annotateIds` flag overlays element ID boxes (draw-on-host using bounds) so the model can correlate. |

### Interaction
| Tool | Kind | Description |
|---|---|---|
| `xaml_interact` | M | Actions: `invoke` (button/click), `toggle`, `select`, `expand/collapse`, `setText`, `focus`, `scrollIntoView`. **Needs new TAP message `ElementAutomationActionRequest`**, which runs the element's AutomationPeer pattern in-proc. This avoids fragile coordinate clicks and works by element ID. Fallback when unsupported: the skill tells the model to use `debugger_ui_interact` (UIA) with the AutomationId/Name we return. |
| `xaml_go_to_state` / storyboard | M | (Optional, later) Existing `GoToState`, `StoryboardAction`. |

### Binding failures
| Tool | Kind | Description |
|---|---|---|
| `xaml_get_binding_failures` | R | All `IBindingFailure` entries: severity, count, binding path, target element/property/type, data context type/name, description, error code, original output text, **XAML source document/line/col**, project. Filter by endpoint/text, with paging. |
| `xaml_clear_binding_failures` | M | `IBindingFailures.ClearEntries()`. Useful before a "reproduce → re-check" loop. |

### Accessibility
| Tool | Kind | Description |
|---|---|---|
| `xaml_run_accessibility_check` | R† | Runs Axe.Windows (`AccessibilityChecker.Run()` path used by `AccessibilityToolWindow`) on an app's windows. Returns issues: rule, description, how-to-fix, element (automationId/name/type), element ID + XAML source when `MapAccessibilityErrorsRequest` can map it. †Not a mutation, but it can be slow and shows a tool window, so NotRequired with progress. Supported on WPF and WinUI desktop. Other platforms return `UNSUPPORTED_PLATFORM`. |
| `xaml_get_accessibility_results` | R | The last results without rescanning. |

### Hot Reload
| Tool | Kind | Description |
|---|---|---|
| `xaml_get_hot_reload_status` | R | Per app: enabled, platform supported, all `debugging.xamlHotReload.*` options (applyOnSave, JMX, previewSelected, in-app toolbar, per-platform enables), env-var options (e.g., `XAML_HOT_RELOAD_ACCURACY_OVER_PERF`), pending (unapplied) edits, current rude edits/errors (`IMarkupChangeErrorManager`), last apply result. |
| `xaml_get_hot_reload_log` | R | Recent XAML Hot Reload log entries from the ring buffer (§3.1-7), with severity filter and paging. |
| `xaml_apply_hot_reload` | M | `IXamlHotReloadHost.ApplyXamlChangesAsync`. Optionally waits for `UpdatesApplied` and returns the result plus errors. Typical workflow: the agent edits a .xaml file (normal edit tool), saves, calls apply, then calls `xaml_capture_image` to verify. |
| `xaml_set_hot_reload_option` | M | (Optional) Toggles an XHR option, e.g., JMX or applyOnSave. Low priority. |

## 5. New TAP messages (minimum set)

Add them to `XamlMessageType.cs`, with payloads in `XamlJsonData.cs`. Gate each on a new **DiagnosticBits capability flag** that the TAP advertises, so old TAPs (remote debugger, older installs) report `UNSUPPORTED_BY_TAP` cleanly.

| Message | Why existing isn't enough | WPF | WinUI/UWP | MAUI |
|---|---|---|---|---|
| `GetElementBoundsRequest {handles[]} → {handle, screenRect, rootRelativeRect, rootHwnd, dpiScale, isVisible}[]` | There's no generic bounds query. The a11y and layout-adorner code computes rects only internally. | Phase 1 | Phase 2 | Phase 3 |
| `ElementAutomationActionRequest {handle, action, value?} → {success, error}` | There's no generic invoke/input message. `InAppMenuCommand`/`ExecuteXamlActions` are unrelated. | Phase 1 | Phase 2 | Phase 3 (platform-view mapping) |
| (Maybe) `CaptureWindowImageRequest` | Only if RTB-of-window-root + Live Preview frames prove insufficient (e.g., popups, HwndHost, WinUI). Try existing first. | — | Evaluate | Evaluate |

Before adding any of these, verify again that `HitTest`, `RenderTargetBitmapRequest`, `TrackFocusElementRequest`, and the Live Preview selection messages can't be reused.

## 6. Built-in skill content (SKILL.md + references)

`xaml-diagnostics` (and possibly a separate `xaml-authoring`):
- **What it is and how it attaches**: TAP injection, which platforms are supported, VS options locations, the F5 vs Attach difference, NotFirstProcess / multi-process, remote, and MAUI design-time preview (17.14+).
- **Enablement checklist**:
  - Tools > Options > Debugging > XAML Hot Reload settings and their effects.
  - Source info requirements: Debug build, WPF `XamlDebuggingInformation=True`, UWP/WinUI `DisableXbfLineInfo=False`, `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1` (the injector sets it on F5; on Attach the user must set it), not elevated.
  - Hot reload limits per platform, and `XAML_HOT_RELOAD_ACCURACY_OVER_PERF`.
  - This content comes from the public docs and the troubleshooting page.
- **Tool workflows** (recipes):
  1. "Fix binding failures": get_binding_failures → open source → fix path/DataContext → apply_hot_reload → clear → re-check.
  2. "Why does X look wrong": find_elements → capture_image(element) → get_element_properties (value source) → set_element_property experiment → edit XAML → hot reload → capture again.
  3. "Fix accessibility": run_accessibility_check → map to source → fix AutomationProperties/contrast/etc.
  4. "Hot reload didn't apply": get_hot_reload_status → get_hot_reload_log → explain rude edits / unsupported changes.
  5. "LVT empty / no source info": get_diagnostics_status → fix.
- **Interpreting data**: value sources, JMX, element ID lifetime, runtime-only edits vs persisted edits.
- **XAML authoring for designer/hot-reload friendliness**:
  - design-time data (`d:DataContext`, `d:DesignInstance`, `d:` properties, `mc:Ignorable`),
  - avoid heavy constructor logic / service calls in controls (designer and XHR re-instantiate),
  - parameterless constructors, `DesignerProperties.GetIsInDesignMode` guards,
  - resource placement (App.xaml merged dictionaries, StaticResource ordering),
  - `x:Name` usage, avoiding code-behind tree walking,
  - `{Binding}` with explicit paths / `x:DataType` (MAUI compiled bindings, WinUI `x:Bind`),
  - hot-reload-safe vs rude edits (e.g., adding event handlers, x:Class changes),
  - keep styles and templates in XAML,
  - AutomationProperties for accessibility.

  Per-platform notes go in `references\`.
- The skill must stay within ~500 lines in SKILL.md and route details to `references\*.md`. Follow the repo's `writing-skills` guidance when authoring.

## 7. In-app Copilot re-route (prototype integration)

Today: TAP `CopilotRequest` (prompt + ink/comment images + sources) → `InAppUICopilotManager` → MEF `ICopilotExtension`. There's no product implementation in-repo.

New: implement `ICopilotExtension` in Diagnostics.dll (`XamlInAppCopilotExtension`). It:
- Opens or focuses Copilot Chat in **Agent mode** and submits the user's in-app prompt. Attached to it: the app image(s) from the request, selected element IDs and source files as context, and a short preamble telling the model which `endpointKey` it is and to use the `xaml_*` tools. Use the chat-submission API available to first-party components (to confirm: `ICopilotChatService`/`IVsCopilot...` "send prompt" API used by other features).
- Streams status back to the TAP through the existing correlation-ID reply path (`SessionChanged`, reject, feedback) so the in-app pane shows "sent to Copilot Chat" and completion.
- Keeps `IsInAppCopilotEnabled` as the user gate. The existing `WpfInAppCopilotTests` / `InAppUICopilotManagerTests` are updated.

## 8. Cross-cutting

- **Threading**: tools run off the UI thread. Hop to the UI thread only where the host model requires it (e.g., `RegisterEndpoint`, `MarkupDocumentManager`). Use the Diagnostics JTF.
- **Errors**: use a structured error code enum (`NO_APPS`, `ENDPOINT_GONE`, `ELEMENT_GONE`, `UNSUPPORTED_PLATFORM`, `UNSUPPORTED_BY_TAP`, `TAP_TIMEOUT`, `NOT_DEBUGGING`, `FEATURE_DISABLED`) with a human-readable hint.
- **Privacy**: property values/images can contain user data. That's the same exposure as the screenshot debugger tools, and it stays in-session. Telemetry records tool name, platform, success/error code, and duration only (no values). Telemetry event names get GDPR classification (`telemetry.json`).
- **Localization**: tool descriptions are model-facing English constants (same as other providers). User-visible progress strings go in resx.
- **Docs**: update `src\Xaml\Diagnostics\README.md`, add `Documentation\copilot-tools.md`, and update `accessibility-checker-tool.md`.
- **Tests**:
  - Unit tests for `XamlAgentService` (DTO mapping, paging, IDs, status reasons) with existing mocks.
  - Component tests using the WPF test app harness (like `WpfInAppCopilotTests`) for the new TAP messages, plus property set and capture.
  - Copilot-repo unit test for the FirstPartyToolsProvider entry.
  - Optional APEX smoke test (F5 WPF app → call tools via the function provider).

## 9. Open questions (resolve during implementation)

1. UIContext for tools: register under `DebuggingMode` (so status/why-unavailable works early) vs. only `XamlDiagnosticsActive`. Leaning toward a new combined context.
2. One skill vs two (diagnostics vs authoring), and how to activate authoring guidance without a debug session.
3. Exact first-party API to submit a prompt into Agent mode from the in-app re-route.
4. Whether Debugger-agent inclusion is done by proxy source in `DebuggerSdkAgent` or by a generic "first-party tools also in subagents" mechanism the Copilot team prefers.
5. Mapping `Endpoint.ProcessId` (GUID) to an OS PID for correlation with debugger tools.

## 10. Phasing

- **Phase 0 – Plumbing**:
  - Copilot reference
  - UIContext
  - feature flag
  - `XamlAgentService` skeleton
  - function provider export
  - FirstPartyToolsProvider + DebuggerSdkAgent registration
  - skill provider + first SKILL.md draft
- **Phase 1 – Read-only, all platforms (host-side only)**:
  - list_apps, diagnostics_status
  - visual_tree, find_elements, go_to_source
  - element_properties, property details
  - binding_failures
  - hot_reload_status, log tee, hot_reload_log
  - list_windows, capture_image (RTB / Live Preview)
  - a11y check/results
- **Phase 2 – Mutations**: set_element_property, select_element, apply_hot_reload, clear_binding_failures.
- **Phase 3 – New TAP (WPF)**: bounds + automation action (`xaml_get_element_bounds`, `xaml_interact`, annotated captures).
- **Phase 4 – In-app Copilot re-route.**
- **Phase 5 – New TAP for WinUI/UWP (UwpTap, native)**, then **Phase 6 – MAUI** (incl. design-time sessions).
- **Phase 7 – Docs, telemetry classification, tests, APEX smoke.**

(Todos are tracked in the session SQL `todos` table.)

## Addendum: style and resource tools (after the UwpTap/MAUI work, before the commit)

Tier 1, host-only (uses the existing PropertyChain sources):
- `xaml_get_element_styles(elementId)`: the applied styles in precedence order. For each: kind (explicit, implicit, theme default, template, trigger), key or target type, file/line, and the properties it sets with won/overridden-by.
- `xaml_explain_property_value(elementId, propertyName)`: the full precedence chain for one property, with each source's value, kind, name and file/line, and the winner.

Tier 2, new TAP messages (562 FindResource, 563 GetResourceDictionaries), gated on SupportsAgentTools; WPF, UwpTap and MauiTap:
- `xaml_find_resource(elementId, key)`: the runtime lookup (element → ancestors → merged dictionaries → Application → theme dictionaries). Returns the value and its type, the winning dictionary and file/line, shadowed definitions, and the WinUI theme dictionary used.
- `xaml_get_resource_dictionaries(app|elementId)`: the merged/theme dictionary structure with source URIs, files and keys.
- Optional: StaticResource/DynamicResource reference info on property values.

## Next phase: automated demo test pass (prepared, not started)
Loop per demo (17, from Q:\source\XamlAgentDemos-notes\src\*\DEMO.md as the hidden grading rubric):
1. Drive the running fastmain VS via DTE (COM ROT, `VisualStudio.DTE.18.0`): open the .sln/.csproj, build, Debugger.Go, wait for app + TAP.
2. Send the prompt through UI Automation: focus the Copilot Chat input, paste, Enter. Use realistic user prompts with no hints.
3. Wait for the turn to finish by watching `%LOCALAPPDATA%\Microsoft\VisualStudio\CopilotCli\session-state\<id>\events.jsonl`.
4. Ask follow-ups such as "what did you verify", "what blocked you", "which tools were confusing".
5. Copy events.jsonl, render a transcript, and grade it against DEMO.md.
6. Fix SKILL.md or the tools. A tool change means rebuilding Diagnostics and redeploying, which needs VS restarted plus an elevated deploy.
7. Stop debugging, start a new chat, `git -C Q:\source\XamlAgentDemos checkout -- . ; git clean -fd`.
8. Log findings and changes to Q:\source\XamlAgentDemos-notes\TestPass.md.
Risks to probe first: whether chat input accepts UIA/SendKeys (needs an unlocked desktop), new-chat command, modal dialogs, and the turn-complete event type.
