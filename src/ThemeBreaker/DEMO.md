# ThemeBreaker: "Fix dark mode" in one prompt

**Wow moment:** the user flips the app to dark mode and it looks broken. One prompt later the AI has explained six root causes, each with a different mechanism: a frozen StaticResource, a local value, a style setter, a shadowed key, a typo'd key in Dark.xaml and a hard-coded template brush. It fixes them in source and the app re-themes live through hot reload.

**Why this was hard before:** the XAML source looks right. Every bug is about *which resource actually won at runtime*. A model reading files can't tell that `PrimaryText` was resolved once at load, that `Window.Resources` shadows the theme key, or that a template ignores `Background`. The answers only exist in the running app's property precedence and resource lookup chain.

## Setup
1. Open `XamlAgentDemos.sln` and set **ThemeBreaker** as the startup project.
2. F5 (Debug). Click **Dark mode** in the app, or start it with `--dark`.

## Prompt
> Dark mode in my running app looks broken. Use the live app to find every element that didn't switch theme, explain why each one didn't, and fix the source.

## Expected tool flow
1. `xaml_list_apps`, then `xaml_capture_image` to see the broken dark window.
2. `xaml_find_elements` / `xaml_get_visual_tree` to locate HeaderTitle, TicketsCard, the cards, the buttons and the subtitle text.
3. `xaml_explain_property_value` on Foreground and Background. It shows *Local value* (TicketsCard), *Style setter* (SecondaryTextStyle) and *StaticResource frozen at load* (HeaderTitle).
4. `xaml_find_resource CardBackground` shows that Window.Resources shadows the theme dictionary.
5. `xaml_get_resource_dictionaries` shows that Dark.xaml defines `AccentBush`, not `AccentBrush`.
6. `xaml_get_element_styles` on the Share button shows the template's hard-coded `#E9ECF1`.
7. The AI edits the XAML, then runs `xaml_apply_hot_reload` → `xaml_capture_image` to compare before and after.

## Answer key
| # | Element | Root cause | Fix |
|---|---|---|---|
| 1 | HeaderTitle | `Foreground="{StaticResource PrimaryText}"` resolved once | DynamicResource |
| 2 | TicketsCard | Local `Background="White"` | Remove it (or use DynamicResource CardBackground) |
| 3 | Subtitle and "Updated…" text | `SecondaryTextStyle` setter uses StaticResource | DynamicResource in the setter |
| 4 | All cards | `Window.Resources` redefines `CardBackground` | Delete the shadowing resource |
| 5 | Export button | Dark.xaml key typo `AccentBush` | Rename it to `AccentBrush` |
| 6 | Share button | The `SecondaryButtonStyle` template hard-codes `#E9ECF1` | `{TemplateBinding Background}` plus a themed setter |

## Reset
`git checkout -- src\ThemeBreaker` (or keep a zip of the original folder).
