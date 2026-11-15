<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to GitHub Copilot, so AI models can inspect, debug and fix running XAML apps through VS and the TAP. That feature is already implemented as a prototype and committed locally in the VS repo: 22 `xaml_*` tools, a skill, TAP messages, and style/resource tools.

The current work is a set of high "wow factor" demo WPF apps (net10.0-windows) in `Q:\source\XamlAgentDemos`. That folder is outside the VS repo and is its own small git repo. Each app has bugs planted on purpose plus a DEMO.md script.

The user's latest request: "come up with more ideas to make sure all of the new functionality gets an amazing 'wow' demo... Live Preview or Live Visual Tree can help debug subtle issues... Feel free to add more sample projects... I just want a lot to try out."

Standing constraint for the VS repo: never push, rebase or amend; only add new local commits.
</overview>

<history>
1. **Earlier segments (summarized):**
   - Planned and implemented the XAML Copilot tools, skill, TAP handlers, style/resource tools, tests and docs.
   - Ran a code review and fixed its findings.
   - VS repo commits (local only): `e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`, `723bc2667ffa`, `309c315ca805`.

2. **User asked for wow demo ideas and sample WPF apps.**
   - Built 7 apps in `Q:\source\XamlAgentDemos`: ThemeBreaker, VanishingSave, BindingStorm, A11ySweep, PixelPerfect, GermanReady, BugRepro.
   - Created `XamlAgentDemos.sln`. All apps build, and each was verified with snapshots and binding traces.
   - Fixed PixelPerfect's `x:Name="Title"` (renamed to `TitleText`, CS0108).
   - Fixed a `--` inside an XML comment in the mockup XAML.
   - Added `Render-Mockup.ps1` and generated `src\PixelPerfect\design\mockup.png`.
   - Wrote a DEMO.md for each app, the top-level README.md (ranked list, finale prompt, prerequisites, switches) and `.gitignore` (bin, obj, out, .vs, *.user).
   - Deleted `out\`, ran `git init`, and made baseline commit `d4ddfb1` "XAML agent demo apps (baseline with planted bugs)".
   - Reported the ranked list to the user.

3. **User asked for many more demos and sample projects (current request).**
   - Checked the skill and tool signatures in the VS repo to ground the demos (see technical details).
   - Added `--width`/`--height` to DemoHost and created the `New-DemoApp.ps1` scaffolder.
   - Scaffolded 10 new apps, all added to the sln: PrecedenceWars, StyleMaze, GhostClicks, LostWindows, SlowScroll, TemplateDetective, ResponsiveDashboard, CrispPixels, HotReloadDoctor, DesignPolish.
   - Wrote the code for 8 of them.
   - Built and snapshot-verified PrecedenceWars and StyleMaze; both show their planted bugs.
   - The rest are not built yet. I was in the middle of writing CrispPixels (finished) when the context was compacted.
</history>

<work_done>
**Shared infrastructure** (root `Q:\source\XamlAgentDemos`):
- `Directory.Build.props`: net10.0-windows, WinExe, UseWPF, Nullable, ImplicitUsings; links `src\Shared\*.cs`; global `Using XamlAgentDemos`.
- `src\Shared\DemoHost.cs` switches:
  - `--trace-bindings <file>`
  - `--snapshot <png>`: renders main window content after 2 s, then exits.
  - `--width`/`--height <n>`: new; sets the size at Loaded priority and SizeToContent=Manual.
- `ObservableObject.cs` and `RelayCommand.cs`.
- `New-DemoApp.ps1 <Name>`: creates csproj, App.xaml (StartupUri=MainWindow.xaml) and App.xaml.cs (calls DemoHost.Initialize), then adds the project to the sln.
- `Render-Mockup.ps1`, `README.md`, `.gitignore`, and baseline commit `d4ddfb1`. The new apps are not committed yet.

**New apps:**

1. **PrecedenceWars** — built and verified. Files: MainWindow.xaml(.cs), StoreViewModel.cs. Five cards, each with a property that won't change:
   - (a) The WelcomeBanner Opacity is held by a Loaded storyboard (To=0.15, default HoldEnd), so the ShowBannerButton code that sets Opacity=1 has no effect.
   - (b) HoverButton has a local `Background="#F3F4F6"`, which beats the style's IsMouseOver trigger. HoverButtonOk is the working comparison.
   - (c) OnResetClick sets `CountText.Text` locally, which replaces the OneWay binding, so Add item no longer updates the count.
   - (d) ReleaseNotesText uses BodyTextStyle, whose FontSize=13 setter beats the inherited Window FontSize bound to TextSizeSlider.
   - (e) ToolbarPanel has `IsEnabled="{Binding IsIdle}"`, and IsBusy stays true because SyncCatalog's catch block returns before `IsBusy=false`. So ExportButton is disabled even though its CanExecute is true.

2. **StyleMaze** — built and verified. Files: App.xaml merges Themes/Brand.xaml then Themes/LegacyReports.xaml; DangerButton.cs; MainWindow.xaml(.cs) with a `Project` record. Five style mysteries:
   - (a) The ToolBar buttons (NewButton, OpenButton, ShareButton) get the ToolBar.ButtonStyleKey style instead of the implicit brand style.
   - (b) LegacyReports.xaml redefines `AccentBrush` as orange and is merged last, so it wins and UpgradeButton is orange.
   - (c) DangerButton (a Button subclass) doesn't get the implicit Button style, so it looks like a plain red-background button.
   - (d) SecondaryActions' StackPanel.Resources has an implicit Button style without BasedOn, so those buttons fall back to the default look.
   - (e) The Window-level implicit TextBlock style (#2B1F73, 15) doesn't apply inside the RecentProjects DataTemplate.

3. **GhostClicks** — not built. MainWindow.xaml(.cs) with a `Message` record; StatusText shows "Last action: ...". Four ways clicks get lost:
   - (a) HeaderBand has `IsHitTestVisible="False"`, so SettingsButton inside it can't be clicked.
   - (b) MessageRow Borders have no Background, so only the text is clickable.
   - (c) PageIndicator (Width=200, Margin right 150, Transparent background) overlays the left ~38 px of PreviousButton.
   - (d) ToastHost (Grid.Row=3, Transparent background) covers the ActionBar (Reply, Forward, Archive). Its child Toast fades to Opacity 0 after 1 s, but the host stays.
   - `xaml_interact invoke` still works on these buttons, which proves the handlers are fine and hit-testing is the problem.

4. **LostWindows** — not built. Files: MainWindow, SettingsWindow, NotificationsWindow, InspectorWindow XAML; ToolWindows.xaml.cs (the three partial classes); WindowLayout.cs, which reads layout.json via System.Text.Json; layout.json (CopyToOutput set in the csproj). Three windows that open without being seen:
   - Settings is restored to -32000,-32000.
   - Notifications is restored Minimized with ShowInTaskbar=False.
   - Inspector uses SizeToContent with its content collapsed (HasSelection=false), so it shrinks to a sliver.
   - All are owned by the main window and opened from its buttons.

5. **SlowScroll** — not built. MainWindow.xaml(.cs). A log viewer with 3000 LogEntry records and three stacked virtualization killers:
   - (1) LogList sits inside ScrollViewer > StackPanel, so it gets infinite height.
   - (2) `ScrollViewer.CanContentScroll="False"`.
   - (3) Grouping through a CollectionViewSource without `VirtualizingPanel.IsVirtualizingWhenGrouping`.
   - PerfText shows first render time, realized ListBoxItem count and list height, refreshed every second.

6. **TemplateDetective** — not built. Files: Models\FeedItems.cs (records FeedItem base, Comment, Commit, Deployment, SecurityAlert : IAlert, Mention), Legacy\Comment.cs, MainWindow.xaml(.cs). A base `models:FeedItem` template ("X mentioned you") catches every item whose specific template fails:
   - (a) The Comment template is typed `legacy:Comment` (wrong namespace).
   - (b) The Commit template has an `x:Key`, so it isn't implicit.
   - (c) The IAlert template uses an interface DataType, which WPF won't match implicitly.
   - (d) The Deployment template lives in SidebarPanel.Resources, so it's out of scope for the Feed list but renders correctly in the sidebar ContentControl.
   - Not yet verified that an interface DataType doesn't throw.

7. **ResponsiveDashboard** — not built. Looks fine at 1280x760 and is planned to break at 1024 and 800:
   - The header is a Canvas: SearchBox is absolutely positioned at Canvas.Left=420, Width=360; UserArea uses Canvas.Right.
   - NavPanel Width=220 and ActivityPanel Width=280 are fixed.
   - KpiTiles has 4 fixed 170-px columns.
   - ChartCard holds a 660-px Polyline.
   - The footer is a horizontal StackPanel with long text.

8. **CrispPixels** — written, not built. Four blur causes:
   - Fractional margins (`12.5,10.5`; toolbar padding 8.5) with no UseLayoutRounding, which blurs the 1-px CardDivider and ColumnRule.
   - 16x16 RenderTargetBitmap icons (SaveIcon, PrintIcon) stretched to 20x20.
   - A DropShadowEffect directly on InvoiceCard, which blurs its text.
   - TotalsViewbox (Height=118) scales the 420-wide TotalsCard down.

9. **HotReloadDoctor** — scaffold only; a `Skins\` folder exists.

10. **DesignPolish** — scaffold only.
</work_done>

<technical_details>
- **Build and verify without VS:**
  - `dotnet build src\<App> -v q -nologo`.
  - Then `Start-Process "src\<n>\bin\Debug\net10.0-windows\<n>.exe" -ArgumentList '--snapshot',"$PWD\out\<n>.png",'--trace-bindings',"$PWD\out\<n>.bind.txt" -Wait`, and view the PNG.
  - Delete `out\` before committing.
- **Creating files:** the create tool fails if the parent directory doesn't exist, or if the file already exists. Delete or edit instead.
- **Avoid the CS0162 unreachable-code warning** by making a throw conditional (for example `IsOffline()` in PrecedenceWars).
- **Tool facts confirmed in the VS repo** (`XamlDiagnosticsFunctionProvider.cs` and `XamlAgentService.cs`):
  - `xaml_get_visual_tree(app, rootElementId, depth=4, maxNodes=200 up to 2000)`; nodes include `childCount`.
  - `xaml_find_elements(app, type, name, sourceFile, line, maxResults=50)` returns `count` and `truncated`.
  - `xaml_get_element_properties(elementId, nameFilter, includeAll)`.
  - `xaml_get_element_styles(elementId)`.
  - `xaml_explain_property_value(elementId, propertyName)`.
  - `xaml_find_resource(key, elementId, app)`.
  - `xaml_get_resource_dictionaries(elementId, app, includeKeys, maxKeysPerDictionary)`.
  - `xaml_set_element_property(elementId, propertyName, value, reset)`.
  - `xaml_get_element_bounds(elementIds[])`.
  - `xaml_interact(elementId, action, value)`.
  - `xaml_select_element(elementId, goToSource=true)`.
  - `xaml_get_binding_failures(textFilter, maxResults)`.
  - `xaml_get_hot_reload_log(maxEntries, errorsOnly, textFilter)`.
  - `xaml_list_windows(app)` returns windowId, app, title, bounds (x, y, width, height), dpiScale, visible, minimized. This is the key to the LostWindows demo.
  - `xaml_capture_image(app, windowId, elementId — WinUI/UWP only, maxSize=1280)`.
  - `xaml_run_accessibility_check(maxResults)` and `xaml_get_accessibility_results`.
- **Skill guidance:**
  - The hot reload workflow uses `xaml_get_hot_reload_status`, then the log with `errorsOnly`. Common causes: unsaved file, platform disabled, parse error, unsupported edits (x:Class, new event handlers, new types).
  - For no source info: F5 instead of attach, a Debug build, and `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1` for attach scenarios.
- **Mutating tools need confirmation** (set property, interact, select, clear binding failures, apply hot reload). Presenters should choose "Always allow".
- **WPF behaviors the demos rely on:**
  - Implicit styles from Window.Resources don't cross template boundaries for non-Controls (verified in StyleMaze).
  - ToolBar overrides the Button style.
  - Implicit styles need an exact type match.
  - The last merged dictionary wins.
  - A local value beats a style trigger.
  - A HoldEnd animation beats a local value.
  - Setting a local value on a OneWay-bound target removes the binding.
  - IsEnabled is coerced by its parent.
  - An implicit DataTemplate matches base types but not interfaces.
- **VS repo git**, if ever needed: `git -C Q:\src\VS_xaml`; convert files to CRLF; commit trailers:
  - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
  - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
</technical_details>

<important_files>
- `Q:\source\XamlAgentDemos\src\Shared\DemoHost.cs`: verification switches; `--width`/`--height` just added.
- `Q:\source\XamlAgentDemos\New-DemoApp.ps1`: scaffolder for new apps.
- `Q:\source\XamlAgentDemos\README.md`: ranked demo table, prerequisites, finale prompt and switches. Needs the 10 new demos added.
- `src\<App>\MainWindow.xaml` for each new app: holds the planted bugs listed above.
- `src\PrecedenceWars\StoreViewModel.cs`: the stuck IsBusy bug.
- `src\LostWindows\layout.json` and `WindowLayout.cs`: the bad saved window placements.
- `src\TemplateDetective\Models\FeedItems.cs` and `Legacy\Comment.cs`: the template-matching traps.
- Existing DEMO.md files (for example `src\ThemeBreaker\DEMO.md`): the format to follow. Sections: title, wow moment, why it was hard before, setup, prompt, expected tool flow, answer key, reset.
- In the VS repo: `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\skills\xaml-diagnostics\SKILL.md` and `XamlDiagnosticsFunctionProvider.cs` (lines ~55–350), which hold the tool definitions.
</important_files>

<next_steps>
1. Write **HotReloadDoctor**: "my XAML edits don't show up."
   - WelcomeTitle Foreground is set in code-behind on Loaded, so XAML edits are overridden; `xaml_explain_property_value` shows the local value.
   - `Skins\Skin.xaml` is a loose file (CopyToOutput) loaded through XamlReader at startup, so it never hot reloads; `xaml_get_resource_dictionaries` shows it has no pack Source.
   - Scripted presenter edits: add `Click="OnNew"`, which needs a rebuild; introduce a XAML typo, which produces an error with a line number. The AI uses hot reload status and log.
2. Write **DesignPolish**:
   - Inconsistent spacing (7/9/13 margins, off the 4-px grid), font sizes (13/13.5/14/15) and near-duplicate colors (#333333/#343434/#2F2F2F). The AI audits the live LVT values and consolidates them into resources.
   - A second "live design variants" demo: the AI tries 3 hero-section variants with `xaml_set_element_property`, captures each, the user picks one, and the AI writes it to source.
3. Build all new apps and fix errors. Snapshot each:
   - ResponsiveDashboard at `--width 1024` and `--width 800`.
   - GhostClicks after more than 2 s.
   - SlowScroll: check the PerfText count.
   - TemplateDetective: confirm the interface DataType doesn't throw and every item shows "mentioned you".
   - CrispPixels: check the blur.
   - Use `--trace-bindings` to catch any unintended binding failures.
4. Write a DEMO.md for each of the 10 new apps, same format as before. Expected flows:
   - **PrecedenceWars:** `xaml_explain_property_value`; reproduce the counter bug with `xaml_interact`.
   - **StyleMaze:** `xaml_get_element_styles` and `xaml_find_resource AccentBrush`.
   - **GhostClicks:** bounds and z-order; invoke works, which proves the problem is hit-testing.
   - **LostWindows:** `xaml_list_windows` shows the bounds and minimized state; the fix is to clamp placement to the virtual screen.
   - **SlowScroll:** `xaml_find_elements type=ListBoxItem maxResults=2000` returns truncated, and the bounds show a huge list height; fix the three causes one at a time, measuring after each hot reload.
   - **TemplateDetective:** the LVT shows which template each ContentPresenter used.
   - **ResponsiveDashboard:** `xaml_set_element_property` on the Window Width, then capture at each size.
   - **CrispPixels:** bounds show fractional x values; check properties for Effect and Viewbox scale.
5. Add scenario-only demos that need no new app to the README:
   - Attach-to-process with no source info (`xaml_get_diagnostics_status` explains ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO).
   - Two apps debugged at once (multiple startup projects): use `xaml_list_apps` and compare branding across apps.
   - "Explain this screen / which XAML file renders this panel" onboarding: `xaml_find_elements` plus `xaml_select_element` to go to source.
   - Release build or hot reload disabled, explained by the status tools.
6. Update README.md with all 17 apps ranked, plus a feature-coverage matrix showing which tool each demo exercises.
7. Delete `out\`, then `git add -A` and commit in `Q:\source\XamlAgentDemos` (a separate repo, so a normal commit is fine).
8. Reply concisely to the user with the new demo list and wow points. Afterwards, consider asking whether any repo skill should be updated with lessons learned.
</next_steps>