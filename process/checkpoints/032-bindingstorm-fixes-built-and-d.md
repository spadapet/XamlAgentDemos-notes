<overview>
The user is exposing Visual Studio XAML Diagnostics to Copilot through 22 `xaml_*` tools in Diagnostics.dll and a deployed `xaml-diagnostics` skill, demonstrated with 17 WPF demo apps. Most recently they asked me to implement every fix I recommended after analyzing a BindingStorm Copilot Chat log. All fixes are implemented, the changed projects build, and they're deployed to `c:\vs\fastmain`. Next, the user retests.
</overview>

<history>
1. **Earlier work, summarized from prior checkpoints**
   - Planned and implemented the 22 tools, the skill and the Copilot integration. The prototype commit in the VS repo is `c15a32e78cc0`.
   - Created 17 WPF demo apps in `Q:\source\XamlAgentDemos`.
   - Changed `DeployToVs.ps1` so it deploys the SKILL.md files.
   - Added `XamlDiagnosticsCopilotRegistration.cs`, which registers the tool provider.
   - Added `Group = "XAML Diagnostics"` to the tools.
   - Fixed UI-thread asserts by switching to the main thread in the provider's `RunAsync`/`CaptureImageAsync`.
   - Moved the demo notes to `Q:\source\XamlAgentDemos-notes` and reinitialized both repos with a single commit each.
   - Analyzed the BindingStorm log at `Q:\cabs\foo.md`.

2. **User: "Make all of those fixes", with three comments**
   - Hot reload only updates elements in the live tree, so newly shown UI can log old binding failures.
   - XAML-only edits should use XAML hot reload, and code edits can use C# Hot Reload, so no temp build is needed.
   - Bindings built in code have no XAML source and matter less.

   What I did:
   - **WpfTap:** `select` now works on item containers through the item peer from the parent ItemsControl, with a fallback to `Selector.IsSelectedProperty`.
   - **UwpTap:** `select` falls back to `SelectorItem.IsSelected`.
   - **`XamlAgentService`:**
     - `source` is null when there's no XAML file, and `line`/`column` are null when 0 or less.
     - `notAvailableReason` is cleared once the app is connected.
     - New `ShortenTypeName` shortens type names in the output.
     - `nameFilter` hides overridden entries but keeps bindings.
     - The binding failures result has a cumulative-log `note` and lists entries with a XAML file first.
     - `ApplyHotReloadAsync` has a new `includeCodeChanges` option; `PostCodeHotReloadCommand` posts the VS Hot Reload command.
   - **Provider:** updated tool descriptions and added the new parameter.
   - **SKILL.md:**
     - Rewrote the "Fix binding failures" workflow: the list is a cumulative log, check views that haven't been shown, and verify after a clear plus a revisit, with a note about hot reload and the live tree.
     - Added an "Apply a fix to the running app" section: don't build while debugging, XAML edits use hot reload, code edits use `includeCodeChanges=true`.
     - `xaml_find_elements` plus `rootElementId` is now preferred over reading the whole tree.
     - The `select` advice now targets TabItem, ListBoxItem and ComboBoxItem.
     - Updated the Tools table and Rules.
   - **`copilot-tools.md`:** the `xaml_apply_hot_reload` row now mentions `includeCodeChanges`.
   - **Build:**
     - These projects built cleanly: WpfCoreTap, WpfTap, and the UwpTap.StaticCrt and WinUI3 projects.
     - Diagnostics had 4 errors, which I fixed:
       - `Package` was ambiguous; I used the fully qualified `Microsoft.VisualStudio.Shell.Package.GetGlobalService`.
       - `SourceInfo.LineNumber`/`ColumnNumber` are `uint`, so the null-conditional values use `(uint?)` casts.
     - The rebuild succeeded. I removed a UTF-8 BOM I had accidentally added to `XamlAgentService.cs`; the original file has no BOM.
   - **Deploy:** ran `DeployToVs.ps1 -VSInstallPath c:\vs\fastmain -Diagnostics -NonInteractive` elevated. It copied 42 files, skipped 4 (probably x86 outputs that weren't built) and had 0 failures. That includes Diagnostics.dll, SKILL.md and all the TAP DLLs.
   - Gave the user a summary and told them to reset the demo with `git -C Q:\source\XamlAgentDemos checkout -- .`. Nothing is committed.
</history>

<work_done>
Uncommitted changes in `Q:\src\VS_xaml`:

- **`src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`**
  - `RunAction` builds a peer list (the item peer first, then the element's own peer).
  - New `GetItemPeer`, `FindPattern`/`GetPattern` and `SetSelected`.
- **`src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`**
  - The `select`, `addToSelection` and `removeFromSelection` branch uses the SelectionItem pattern, then falls back to `SelectorItem.IsSelected`.
- **`src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`**: all the service fixes above.
- **`XamlDiagnosticsFunctionProvider.cs`**: tool descriptions and the `includeCodeChanges` parameter.
- **`skills\xaml-diagnostics\SKILL.md`**: workflow rewrites.
- **`src\Xaml\Diagnostics\Documentation\copilot-tools.md`**
- **Earlier uncommitted changes:**
  - `DeployToVs.ps1`
  - `XamlDiagnosticsCopilotRegistration.cs`
  - `XamlDiagnosticsPackage.cs`
  - The thread fixes

Status:
- [x] All BindingStorm fixes implemented
- [x] Built
- [x] Deployed to fastmain
- [ ] The user retests in VS. Nothing has been verified at runtime.
</work_done>

<technical_details>
- **Build:**
  1. `cd Q:\src\VS_xaml`
  2. Run `& src\Shared\Tools\Scripts\Prime-ForCopilot.ps1` in the same process as the build.
  3. `msbuild <proj> /restore /m /v:m /nologo /clp:ErrorsOnly`
  - Project paths:
    - `src\Xaml\Shared\Source\WpfTap\Core\WpfCoreTap.csproj`
    - `src\Xaml\Shared\Source\WpfTap\Framework\WpfTap.csproj`
    - `src\Xaml\Diagnostics\Source\Diagnostics\Diagnostics.csproj`, which takes about 3–5 minutes
    - `src\Xaml\Shared\Source\UwpTap\UwpTap.StaticCrt\UwpTap.StaticCrt.vcxproj`
    - `src\Xaml\Shared\Source\UwpTap\UwpTap.StaticCrt.WinUI3\UwpTap.StaticCrt.WinUI3.vcxproj`
  - WpfTap sources come in through `WpfTapItems.projitems`.
- **Deploy:** `Q:\src\Xaml\Scripts\DeployToVs.ps1` (full path `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`) must run elevated: `Start-Process pwsh -Verb RunAs -Wait`, with output redirected to a log. `-Diagnostics` deploys the TAP DLLs and SKILL.md.
- **Code quirks:**
  - In `XamlAgentService.cs`, `Package` resolves to the `Microsoft.VisualStudio.DesignTools.Package` namespace, so use the fully qualified Shell `Package`.
  - The file has no BOM; preserve that.
- **Unverified at runtime:**
  - Which Hot Reload command QueryStatus reports as enabled: `0xF017`, `0xF024` or `0x0105` in `guidVSDebugCommand`.
  - `includeCodeChanges` posts the command asynchronously, so the tool can't report whether the code change applied. Only the Hot Reload output pane shows that.
- **User preference:** never push, rebase or amend. Commit only if asked, and stop for review.
</technical_details>

<important_files>
- `Q:\src\VS_xaml\src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\XamlAgentService.cs`
  - Changed: `ListAppsAsync` (~212), `GetDiagnosticsStatusAsync` (~277), `GetElementPropertiesAsync` (~579), `ShortenTypeName` (~642), `GetBindingFailuresAsync` (~1310), `ApplyHotReloadAsync`/`PostCodeHotReloadCommand` (~1472–1540), `SourceResolver.Resolve` (~1830).
- `...\AgentTools\XamlDiagnosticsFunctionProvider.cs`: the tool definitions.
- `...\AgentTools\skills\xaml-diagnostics\SKILL.md`: the skill. The workflows start around line 46; the Rules are around line 107.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\WpfTap\AgentTools\TapAgentToolsService.cs`: the WPF interact/select fix.
- `Q:\src\VS_xaml\src\Xaml\Shared\Source\UwpTap\UwpTap.cpp`: the UWP/WinUI select fallback (~1752–1782).
- `Q:\src\VS_xaml\src\Xaml\Scripts\DeployToVs.ps1`: deployment.
</important_files>

<next_steps>
- Wait for the user's retest of BindingStorm, after they reset the demo XAML, and address any issues it finds.
- At the end of the session, per the custom instructions, consider asking the user whether to update a skill using `writing-skills`. Learnings so far:
  - The `Package` name ambiguity in the Diagnostics project.
  - The build and deploy commands above.
</next_steps>