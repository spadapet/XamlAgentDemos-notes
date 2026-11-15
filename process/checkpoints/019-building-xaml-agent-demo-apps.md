<overview>
The user (@spadapet) wants every Visual Studio XAML Diagnostics feature exposed to GitHub Copilot, so AI models can inspect, debug and fix running XAML apps through VS and the TAP. That feature is already implemented as a prototype and committed locally: 22 in-proc `xaml_*` tools, a skill, new TAP messages, and style/resource tools.

The current request is for high "wow factor" demos, backed by sample WPF apps, that show what AI can now do that wasn't possible before. I'm building 7 small net10.0-windows WPF apps in `Q:\source\XamlAgentDemos` (the location the user chose, outside the VS repo, so nothing gets committed there). Each app has bugs planted on purpose and gets a DEMO.md script.

Standing constraint for the VS repo: never push, rebase or amend; only add new local commits.
</overview>

<history>
1. **Earlier segments (summarized):**
   - Planned and implemented the XAML Copilot tools, the skill, TAP handlers for WPF, UwpTap and MAUI, the style and resource tools, tests and docs.
   - Ran a code review and fixed its 4 findings.
   - VS repo commits (local only): `e92845d6d4a8`, `4b38d3e7ed20`, `319232bd8061`, `723bc2667ffa`, `309c315ca805`.

2. **The user asked for "great demo ideas with a big wow factor"**, adding: "You can create sample WPF apps... Make as many as you want."
   - I asked where to put them. The user chose `Q:\source\XamlAgentDemos`, targeting net10.0-windows.
   - Created the shared scaffolding and all 7 apps. Only ThemeBreaker has been built and verified so far.
   - ThemeBreaker snapshots confirmed that dark mode is badly broken, as intended:
     - The header is invisible.
     - Cards stay white, with near-invisible light text.
     - The "Updated..." line and the subtitle keep their light-theme colors.
     - The Export button loses its accent color.
     - The Share button stays light.
</history>

<work_done>
All files are under `Q:\source\XamlAgentDemos`. Output from `--snapshot` runs goes to `out\`, which is scratch output and should be deleted or ignored.

**Shared scaffolding**
- `Directory.Build.props`:
  - Properties: net10.0-windows, WinExe, UseWPF, Nullable, ImplicitUsings.
  - Links `src\Shared\*.cs` into every project.
  - Adds a global `Using Include="XamlAgentDemos"`.
- `src\Shared\ObservableObject.cs`: provides `SetProperty` and `OnPropertyChanged`.
- `src\Shared\RelayCommand.cs`: an `ICommand` that raises CanExecuteChanged via `CommandManager.RequerySuggested`.
- `src\Shared\DemoHost.cs`:
  - `Initialize(app, args)` supports two switches:
    - `--trace-bindings <file>` writes binding errors to a file through a TextWriterTraceListener.
    - `--snapshot <png>` renders the main window's content after 2 seconds, then shuts the app down.
  - Also provides `GetArg` and `SaveSnapshot(element, background, path)`.

**1. ThemeBreaker (built and verified)**
- Files: App.xaml (styles), App.xaml.cs, ThemeManager.cs, Themes\Light.xaml, Themes\Dark.xaml, MainWindow.xaml(.cs).
- Switch: `--dark` turns on dark mode after Loaded.
- ThemeManager swaps `MergedDictionaries[0]` using pack URIs.
- Six planted bugs:
  1. HeaderTitle uses `Foreground="{StaticResource PrimaryText}"`.
  2. TicketsCard has a hard-coded `Background="White"`.
  3. The `SecondaryTextStyle` setter uses `{StaticResource SecondaryText}`.
  4. `Window.Resources` contains a `CardBackground` that shadows the theme's key.
  5. Dark.xaml misspells the key as `AccentBush`, so AccentBrush is missing in dark mode.
  6. The `SecondaryButtonStyle` ControlTemplate hard-codes `Background="#E9ECF1"` instead of using a TemplateBinding.

**2. VanishingSave (not built)**
- Files: App.xaml(.cs), CustomerViewModel.cs, FooterSettings.cs, MainWindow.xaml(.cs).
- Four stacked causes hide SaveButton:
  1. `Visibility="{Binding CanSave, ..., FallbackValue=Collapsed}"`, but the view model property is `IsSaveAvailable`.
  2. `FooterButtonStyle` has a Trigger that sets Opacity=0 when IsEnabled=False. The SaveCommand can only execute when IsDirty.
  3. Code-behind sets `SaveColumn.Width` to 0 in Loaded when `FooterSettings.UseCompactFooter` is true.
  4. A Border, `SyncStatusHost`, sits in the same column (Grid.Column=2) with ZIndex=1 and a White background, covering the button.

**3. BindingStorm (not built)**
- Files: App.xaml(.cs), MainViewModel.cs (records Order, Customer, ReportSummary), MainWindow.xaml(.cs), Views\OrderDetailsWindow.xaml(.cs).
- The details dialog opens with `Show()` and an Owner, not ShowDialog.
- Most failures are latent because tab content and the dialog are only created when visited:
  - **Orders tab:** `OrderTotal` instead of `Total`.
  - **Customers tab:**
    - `ElementName=searchBox`, but the element is named SearchBox.
    - `{Binding Emial}`.
    - `RelativeSource AncestorType=ListView` inside a ListBox.
  - **Reports tab:**
    - `Visibility="{Binding HighPriorityCount}"`, an int bound to Visibility. Not yet verified that this actually produces a failure.
    - `Summary.Revenue` inside a scope whose DataContext is already Summary.
  - **Settings tab:**
    - `ItemsSource="{Binding Regions}"`; the real property is AvailableRegions.
    - `IsChecked="{Binding AutoRefresh}"`; the real property is AutoRefreshEnabled.
  - **Dialog:**
    - `Order.Id`.
    - `ShippingAdress`.

**4. A11ySweep (not built)**
- Files: App.xaml (IconButtonStyle, CoverArt DrawingImage), App.xaml.cs, PlayerViewModel.cs, MainWindow.xaml(.cs).
- Planted issues:
  - Icon-only Path buttons with no names: Back, Play, Forward, Shuffle, plus the LikeButton ToggleButton.
  - The Image has no name.
  - SubscribeChip is a clickable Border handling MouseLeftButtonUp: not focusable and has no role.
  - SearchBox has no label.
  - VolumeSlider has no name.
  - Several low-contrast text colors (#C4C4C4, #BDBDBD, #C8C8C8).
  - Episode ListBox items have no AutomationProperties.Name, so their names come out as the class name, "A11ySweep.Episode".

**5. PixelPerfect (not built)**
- Files: App.xaml (no StartupUri), App.xaml.cs, MainWindow.xaml(.cs).
- App.xaml.cs creates MainWindow itself and supports `--render-xaml <loose.xaml> <out.png>`.
- `design-source\pixelperfect-mockup.xaml` is the loose XAML target, a Grid sized 744x561.
- About 9 planted differences between the app and the mockup:

  | Area | App (current) | Mockup (target) |
  |---|---|---|
  | Background | White | #F2F0F7 |
  | Card padding | 16 | 32 |
  | Card corner radius | 4 | 12 |
  | Card border vs shadow | Border, no shadow | No border, DropShadowEffect |
  | Title | FontSize 20, normal weight | FontSize 28, SemiBold |
  | Field height and spacing | 32, margin 4 | 36, margin 12 |
  | "Forgot password?" link | Left | Right |
  | Sign in button | Left-aligned, Width 100, #2D7FF9 | Stretched, #5B3FD9, rounded |
  | Footer | Left | Centered |

- The `src\PixelPerfect\design\` folder exists, but `mockup.png` has not been generated yet.

**6. GermanReady (not built)**
- Files: App.xaml(.cs), Loc.cs, MainWindow.xaml(.cs).
- Switch: `--lang de|qps`.
- Loc.cs is an indexer-based localization source (en/de/qps pseudo-loc) that raises `Item[]` when the language changes. Language is chosen with RadioButtons: English, Deutsch, Pseudo-loc.
- Planted layout bugs:
  - The header Border has a fixed Height=58 with a wrapping subtitle.
  - The label column is a fixed Width=90.
  - The postal code TextBox is Width=120.
  - The country ComboBox is Width=120.
  - The Apply coupon button is Width=64.
  - The delivery note is in a horizontal StackPanel, so it overflows instead of wrapping.
  - The footer buttons are a fixed Width=96.

**7. BugRepro (not built)**
- Files: App.xaml(.cs), ProfileViewModel.cs, MainWindow.xaml(.cs), bug-report.md.
- Bug: `Cancel()` sets `isReverting = true` and never resets it, so later edits never mark the form dirty. SaveCommand and CancelCommand can only execute when IsDirty.
- Second bug: the Email binding uses the default LostFocus trigger.

**Not yet done**
- [ ] A `.sln` file.
- [ ] Building and verifying apps 2–7.
- [ ] The mockup PNG.
- [ ] A DEMO.md for each app.
- [ ] A top-level README.
- [ ] The ranked summary for the user.
</work_done>

<technical_details>
- **Building:** `dotnet build src\<App> -v q -nologo` works; ThemeBreaker built with 0 warnings. These are standalone apps outside the VS repo, so `dotnet build` is fine.
- **Verifying without VS:**
  - Run `<exe> --snapshot <abs path png>`, then view the PNG.
  - For binding failures, use `--trace-bindings <file>`. Note this only catches failures in UI that has actually been created, so latent tabs won't show up.
  - Use `Start-Process -Wait` to wait for the app to exit.
- **ThemeBreaker:** the StaticResource bugs only show when the theme is toggled at runtime, because StaticResource resolves at load. That's why `--dark` toggles after Loaded rather than at startup. Styles live in App.xaml (not a separate merged dictionary) so that the StaticResource in a Style setter resolves correctly.
- **PixelPerfect mockup:** the loose XAML is kept outside the project so the AI can't read it. The PNG comes from the `--render-xaml` switch, which does XamlReader.Load, then Measure/Arrange, then RenderTargetBitmap.
- **BindingStorm:**
  - TwoWay binding to a read-only property throws an exception in WPF, so I avoided it.
  - The dialog uses `Show()` so it doesn't block `xaml_interact`. The TAP now returns "still running" after 3 seconds anyway.
- **GermanReady:** the XAML `IsChecked="True"` on English fires Checked during InitializeComponent. That's fine.
- **Tool names to reference in the DEMO.md files:**
  - App and status: `xaml_list_apps`, `xaml_get_diagnostics_status`.
  - Tree and properties: `xaml_get_visual_tree`, `xaml_find_elements`, `xaml_get_element_properties`, `xaml_set_element_property`.
  - Styles and resources: `xaml_get_element_styles`, `xaml_explain_property_value`, `xaml_find_resource`, `xaml_get_resource_dictionaries`.
  - Layout and interaction: `xaml_get_element_bounds`, `xaml_interact` (actions: invoke, toggle, select, addToSelection, removeFromSelection, expand, collapse, setValue, focus, scrollIntoView), `xaml_select_element`.
  - Binding failures: `xaml_get_binding_failures`, `xaml_clear_binding_failures`.
  - Hot reload: `xaml_get_hot_reload_status`, `xaml_get_hot_reload_log`, `xaml_apply_hot_reload`.
  - Live Preview: `xaml_list_windows`, `xaml_capture_image` (element capture works on WinUI/UWP only; WPF captures windows).
  - Accessibility: `xaml_run_accessibility_check`, `xaml_get_accessibility_results`.
- **Tool confirmations:** set_element_property, interact, select_element, clear_binding_failures and apply_hot_reload require confirmation, so presenters should click "always allow".
- **Demo prerequisites in VS:**
  - F5 a Debug build; it has source info.
  - XAML Hot Reload enabled.
  - Copilot Agent mode, with the prototype feature built into VS.
- **VS repo git**, if it's ever needed:
  - `core.safecrlf` and `autocrlf` are on, so convert files to CRLF before `git add`.
  - Use `git -C Q:\src\VS_xaml`.
  - Commit trailers:
    - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
    - `Copilot-Session: 3815da22-ae30-4db6-bb02-0ae296cab09b`
</technical_details>

<important_files>
- `Q:\source\XamlAgentDemos\Directory.Build.props`, plus `src\Shared\DemoHost.cs`, `ObservableObject.cs` and `RelayCommand.cs`: the shared infrastructure.
- `Q:\source\XamlAgentDemos\src\ThemeBreaker\*`: demo 1, verified.
- `Q:\source\XamlAgentDemos\src\VanishingSave\MainWindow.xaml`: the footer Grid with SaveButton, SaveColumn and SyncStatusHost is at roughly lines 100–135.
- `Q:\source\XamlAgentDemos\src\BindingStorm\MainWindow.xaml` and `Views\OrderDetailsWindow.xaml`: the binding failures.
- `Q:\source\XamlAgentDemos\src\A11ySweep\MainWindow.xaml`: the accessibility issues.
- `Q:\source\XamlAgentDemos\src\PixelPerfect\MainWindow.xaml` and `design-source\pixelperfect-mockup.xaml`: the app and its target design.
- `Q:\source\XamlAgentDemos\src\GermanReady\MainWindow.xaml` and `Loc.cs`: the fixed-size layout and the localization source.
- `Q:\source\XamlAgentDemos\src\BugRepro\ProfileViewModel.cs` (the `Cancel()` bug) and `bug-report.md`.
- In the VS repo, the feature itself is in `src\Xaml\Diagnostics\Source\Diagnostics\AgentTools\`: `XamlDiagnosticsFunctionProvider.cs` (tool definitions) and `skills\xaml-diagnostics\SKILL.md`.
</important_files>

<next_steps>
1. Build the remaining apps: `dotnet build` each of VanishingSave, BindingStorm, A11ySweep, PixelPerfect, GermanReady and BugRepro, and fix any compile errors.
2. Verify each one with `--snapshot` (and `--trace-bindings` for BindingStorm and VanishingSave):
   - VanishingSave: Save is invisible and a CanSave failure is logged.
   - GermanReady: run with `--lang de` and check the clipping.
   - PixelPerfect: generate the mockup with `PixelPerfect.exe --render-xaml design-source\pixelperfect-mockup.xaml src\PixelPerfect\design\mockup.png`, then view it next to an app snapshot.
   - BindingStorm: check whether the int→Visibility binding really fails. If it converts silently, replace it with a clear conversion error.
3. Create `XamlAgentDemos.sln` with `dotnet new sln` and `dotnet sln add src\*\*.csproj`.
4. Write a DEMO.md for each app covering:
   - setup (F5),
   - the exact prompt to type,
   - the expected tool flow,
   - the "wow moment",
   - why this was hard or impossible before,
   - a full list of the planted bugs with an answer key,
   - how to reset.
5. Write the top-level `README.md`:
   - The demos ranked by wow factor: ThemeBreaker, VanishingSave, PixelPerfect, BindingStorm, GermanReady, A11ySweep, BugRepro.
   - Prerequisites.
   - A "finale" idea: one prompt that makes an app ship-ready by combining binding failures, accessibility, theme and localization.
   - The DemoHost switches.
6. Delete the scratch `out\` folder, or note it in the README.
7. Reply to the user with a concise ranked list of the demos and their wow points, plus the location. There's no VS repo commit, since the demos live outside the repo.
8. Afterwards, consider asking whether any repo skill should be updated with lessons learned.
</next_steps>