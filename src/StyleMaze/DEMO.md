# StyleMaze: "Why don't my buttons use our brand style?"

**Wow moment:** the app has a brand style, but five places ignore it, and each for a different reason. For each element the AI shows exactly *which style applied and where it came from*, including a resource key that was silently overridden by a dictionary merged later.

**Why this was hard before:** the XAML for every button looks identical. The answer depends on implicit-style lookup rules, which differ for ToolBar, subclasses, local style scopes, template boundaries and merge order. Reading files can't tell you which dictionary won at runtime.

## Setup
Set **StyleMaze** as the startup project and press F5.

## Prompt
> We have a brand style in Themes/Brand.xaml, but a lot of my running app doesn't use it. Find every element that isn't branded, explain why, and fix it.

## Expected tool flow
1. `xaml_capture_image` to spot the unbranded buttons and text.
2. `xaml_get_element_styles` on NewButton shows the **ToolBar.ButtonStyleKey** style, not the implicit Button style.
3. `xaml_find_resource AccentBrush` with elementId=UpgradeButton shows the winner is **LegacyReports.xaml**, which shadows Brand.xaml.
4. `xaml_get_resource_dictionaries` shows the merge order in App.xaml.
5. `xaml_get_element_styles` on DeleteButton: **DangerButton** gets no implicit style because implicit styles need an exact type match.
6. `xaml_get_element_styles` on InviteButton shows the local implicit style in SecondaryActions with no BasedOn.
7. `xaml_explain_property_value Foreground` on a TextBlock inside RecentProjects shows the Window-level implicit TextBlock style doesn't cross the DataTemplate boundary.
8. The AI fixes the source, then hot reload and capture.

## Answer key
| Element | Root cause | Fix |
|---|---|---|
| New/Open/Share | ToolBar applies `ToolBar.ButtonStyleKey` | `<Style x:Key="{x:Static ToolBar.ButtonStyleKey}" BasedOn="{StaticResource {x:Type Button}}" .../>` |
| UpgradeButton (orange) | LegacyReports.xaml redefines `AccentBrush` and is merged last | Rename the legacy key or reorder the merge |
| DeleteButton | `DangerButton` subclass doesn't match the implicit Button style | Implicit style for DangerButton `BasedOn` the Button style, or set `DefaultStyleKey` |
| Invite/Archive/Export | Local implicit style without `BasedOn` | `BasedOn="{StaticResource {x:Type Button}}"` |
| RecentProjects text | Implicit TextBlock style doesn't cross the template boundary | Move the style to App.xaml or set it inside the template |

## Reset
`git checkout -- src\StyleMaze`
