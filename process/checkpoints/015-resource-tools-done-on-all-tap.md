<overview>
The user (@spadapet) wants Copilot AI to have access to every Visual Studio XAML Diagnostics feature, so models can diagnose, debug and fix running XAML apps through VS and the injected TAP. That covers the Live Visual Tree, Live Property Explorer, Live Preview images, binding failures, the accessibility checker, Hot Reload, app/platform discovery, and why a feature is unavailable.

The approved `plan.md` in the session folder is being built as a prototype:
- in-proc Copilot agent-mode tools (`xaml_*`) plus a built-in skill, all in the Diagnostics DLL;
- new TAP messages that only run when the TAP reports the capability.

The user agreed to add style tools (Tier 1) and resource tools (Tier 2) before the single local commit. Both tiers are now implemented across all TAPs and the host. Docs and the commit remain.
</overview>

<history>
1. **Earlier segments**
   - Planned and implemented:
     - the `xaml_*` tools, the skill and its references, and Copilot registration;
     - the hot reload log buffer;
     - the 560/561 (bounds and interact) contract and the `SupportsAgentTools=0x20` capability bit;
     - 560/561 for WPF, UwpTap (WinUI3 and UWP) and MauiTap;
     - the in-app Copilot re-route;
     - unit tests.
   - Answered the user's questions on availability, the tool inventory, completeness, the legacy toolbar, and the scenarios.
   - The user agreed to the style and resource tools.
   - Tier 1 style tools (`xaml_get_element_styles`, `xaml_explain_property_value`): host-only, done.
   - Tier 2 contract (562/563 plus payloads) and the WPF TAP implementation: done.

2. **This segment: finished Tier 2 resource tools**
   - **MauiTap**
     - Fixed the `IApplication` ambiguity by checking `handle == 0 || handle == Constants.ApplicationHandle` (added `using Microsoft.VisualStudio.DesignTools.TapContract.Utility;`).
     - Made the main `TapAgentToolsService` `sealed partial` and registered the 562/563 observers.
     - `MauiTap.csproj` built successfully.
   - **UwpTap (native)**
     - Added the `HandleFindResource` and `HandleGetResourceDictionaries` declarations in `UwpTap.h`.
     - Registered them after the ElementAutomationAction registration (~line 301).
     - Implemented them in `UwpTap.cpp` before `GetDispatcher`, with an anonymous-namespace helper set:
       - `ResourceScope`, `Truncate`, `FormatColor`, `DescribeResourceKey` (string keys, or `{x:Type Name}` for boxed TypeName)
       - `ResourceKeyMatches`, `DescribeResourceValue` (Style/SolidColorBrush/ResourceDictionary/Color/Thickness/IPropertyValue)
       - `HasResourceContent`, `GetDictionarySource`
       - `GetResourceScopes`: FE.Resources up the Parent()/VisualTreeHelper chain, then Application
       - `GetThemeLookupKeys`, `TryGetThemeDictionary`, `GetResourceOwnerHandle`
       - `ResourceLookupContext`, `DescribeOwner`, `AddSourceInfo`
       - `CollectResourceDefinitions`: own keys → theme dictionary (ActualTheme, then "Default") → merged in reverse
       - `DescribeResourceDictionary`, `GetResourceTheme`
       - a static `TryGetResourceTarget`
     - Fixed two compile errors:
       - `Uri.empty()` became `!= nullptr`.
       - `ResourceContext` was ambiguous with the ABI type, so it was renamed `ResourceLookupContext`.
     - `UwpTap.StaticCrt.WinUI3` and `UwpTap.StaticCrt` (x64) both built successfully. The file is kept without a BOM, matching the original.
   - **Host**
     - `XamlAgentService.cs`: added the Resources section after `InteractAsync` (~1089-1245):
       - `ResourceFallbackHint`, `ResolveResourceScope(host, app, elementId)`, `DescribeResourceOwner`
       - `FindResourceAsync(app, elementId, key, ct)` and `GetResourceDictionariesAsync(app, elementId, includeKeys, maxKeysPerDictionary, ct)`
       - Both are gated by `ThrowIfAgentToolsUnsupported`, switch to the main thread after the TAP reply, map owner handles to element IDs and locations, and resolve SourceInfo through `SourceResolver`. They return hints for not-found and shadowed results.
     - `XamlDiagnosticsFunctionProvider.cs`: added the `xaml_find_resource(key, elementId?, app?)` and `xaml_get_resource_dictionaries(elementId?, app?, includeKeys=false, maxKeysPerDictionary=200)` tools (NotRequired), after `xaml_explain_property_value`. There are now 22 tools.
     - Building Diagnostics with `-NoProjectReferences` failed on the stale contract. Building it with project references (`-NoRestore` only) succeeded.
     - Unit built, and the tests passed: 36/36.
     - SQL todo `resource-tools-tier2` is marked done; no todos remain open.
   - **Started docs**: grep found the places to update (see next_steps).
</history>

<work_done>
**Done and building**
- Diagnostics `AgentTools\*`:
  - `XamlAgentService.cs`, with Tier 1 style and Tier 2 resource methods
  - `XamlDiagnosticsFunctionProvider.cs` (22 tools)
  - the skills provider, log buffer, imaging, exception and in-app extension classes
  - the skill files
- Contract: 560-563 in C# `XamlMessageType.cs`, UwpTap `XamlMessageType.h`, and `XamlJsonData.cs`.
- WPF TAP (WpfTap and WpfCoreTap): 560-563.
- UwpTap (WinUI3 and UWP StaticCrt x64): 560-563.
- MauiTap: 560-563.
- Host capability plumbing, the Copilot-repo registration, and unit tests (`Test\Unit\AgentTools\XamlAgentToolsTests.cs`). All 36 tests pass.

**Remaining**
- [ ] Docs update (in progress).
- [ ] The single local commit.
- [ ] Summarize for the user, then ask about skill updates.
</work_done>

<technical_details>
**Build**
- Command:
  ```
  cd Q:\src\VS_xaml; $env:PSModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"; & src\Shared\Tools\Scripts\Prime-ForCopilot.ps1 *> $null; & src\Shared\Tools\Scripts\Invoke-Build.ps1 -Project <proj> [-NoProjectReferences] [-NoRestore] [-Platform x64] *> .vs\<name>.txt
  ```
- Then `Select-String` the output for `": error |Build succeeded|Build FAILED"`. Don't pipe the build into `Select-Object -First`.
- Diagnostics.csproj needs a build **with** project references after a contract change; otherwise you get a stale XamlTapContract and CS0246 errors.
- Tests:
  ```
  src\Xaml\Scripts\Test-Xaml.ps1 -Suite diagnostics -Filter "XamlAgentTools,DiagnosticPlatform,HostDebugger,InAppCopilot"
  ```

**UwpTap notes**
- `JsonHelper.h` lives at `src\edev\ClientDiagnostics\Source\Common\Utility\inc`. `ToJSON` supports types with a `ToJSONImpl` method and pointers to them.
- `OM::SourceInfo::ToJSONImpl()` returns null when the source info is invalid.
- `ObjectIdentityService::GetHandle(IInspectable)` returns the XamlDiagnostics handle. `GetSourceInfo(DependencyObject)` must run on the UI thread.
- `GetDispatcher(ObjectIdentifier(0))` falls back to the main dispatcher.
- Beware name clashes with ABI types brought in by the file-level `using` directives (for example `ResourceContext`).

**Resource lookup semantics**
- WPF: element → Style.Resources → Template.Resources → parents → App; merged dictionaries searched in reverse; the effective entry is the one `ReferenceEquals` the `TryFindResource` result.
- UWP/WinUI: own keys → theme dictionary → merged in reverse; the first definition is effective.
- MAUI: own keys → the `_mergedInstance` (Source) dictionary → merged in reverse; the first definition is effective.
- Handle 0 means application scope.

**Tool and capability conventions**
- Gating: `ThrowIfAgentToolsUnsupported`. A TAP that doesn't know a message never replies, so the call times out.
- Tools return Newtonsoft JSON with nulls omitted.
- Errors are `{error, message, hint}`.
- Element IDs look like `a1:<handle>`.

**Constraints**
- Never push, rebase or amend. Make one local commit via `git -C Q:\src\VS_xaml` with trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
- Use the dashed copyright header.

**Skill-update candidates to ask the user about at the end**
- the PSModulePath fix
- `Select-Object -First` orphaning MSBuild
- UwpTap link dependencies: build with references
- Test-Xaml filter commas
- the capability-bit pattern
- `FirstPartySkills`
- Diagnostics needing a build with references after a contract change
</technical_details>

<important_files>
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - The host façade.
  - Tier 1 style methods at ~748-960; `ThrowIfAgentToolsUnsupported` ~966; the new Resources section ~1089-1245; `SourceResolver` near the end.
- `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlDiagnosticsFunctionProvider.cs`
  - The tool definitions. Style and resource tools are at ~109-153.
- `src\Xaml\Shared\Source\UwpTap\UwpTap.cpp` / `UwpTap.h`
  - The native 562/563 handlers: registration ~301, helpers and handlers ~1831-2396, header ~112-113.
- `src\Xaml\Shared\Source\MauiTap\AgentTools\TapAgentToolsService.cs` and `TapAgentToolsService.Resources.cs`: MAUI 562/563.
- `src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.Resources.cs`: WPF 562/563.
- `src\Xaml\Shared\Source\XamlTapContract\TapOM\XamlJsonData.cs` (~670-830): the resource payloads.
- Docs to update:
  - `src\Xaml\Diagnostics\Documentation\copilot-tools.md`
    - lines 30-31 say "WPF only" for bounds/interact;
    - line 43 says the capability bit is set for WPF only;
    - the 4 style/resource tools need adding.
  - `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md`
    - lines 29-30 say "(WPF)" for bounds/interact;
    - the 4 new tools and a recipe are needed.
  - `skills\xaml-diagnostics\references\xaml-authoring.md` (Resources section ~29-32) and `enablement-and-troubleshooting.md`: optional mention of `xaml_find_resource`.
- `C:\Users\peterspa\.copilot\session-state\3815da22-ae30-4db6-bb02-0ae296cab09b\plan.md`: the plan with the style and resource addendum.
</important_files>

<next_steps>
1. **Docs**
   - `copilot-tools.md`:
     - change bounds/interact from "WPF only" to WPF, WinUI/UWP and MAUI (MAUI screen positions are approximate);
     - state that the `SupportsAgentTools` bit is set by all three TAPs and covers 560-563;
     - add rows for `xaml_get_element_styles`, `xaml_explain_property_value` (host-only, existing PropertyChain), `xaml_find_resource` and `xaml_get_resource_dictionaries` (new TAP 562/563);
     - list the new messages.
   - `SKILL.md`:
     - update the tool table: drop "(WPF)" and add the 4 tools;
     - add a recipe: "Why isn't my style/setter/resource applying?" → `xaml_find_elements` → `xaml_get_element_styles` → `xaml_explain_property_value` → `xaml_find_resource` (elementId and key) / `xaml_get_resource_dictionaries` → edit XAML → hot reload → capture.
   - Optionally add a line in `xaml-authoring.md` Resources pointing to `xaml_find_resource`.
   - Keep `SKILL.md` under ~500 lines.
2. Run `git -C Q:\src\VS_xaml status`, review the changed and new files, then make the single local commit with the trailers (no push).
3. Give the user a brief summary: the 22 tools, the new TAP messages 560-563 on all platforms, and passing tests.
4. Use `ask_user` to ask whether to update skills with the lessons learned listed in technical_details.
</next_steps>