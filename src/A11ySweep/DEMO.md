# A11ySweep: accessibility audit and fix in one pass

**Wow moment:** the AI runs the accessibility checker on the live podcast player. It maps each Axe.Windows issue back to an exact XAML element and line, then fixes all of them: names for icon buttons, a keyboard-reachable "Subscribe", a label for search, contrast and list item names. It reruns the checker to show zero errors.

**Why this was hard before:** a model reading XAML can't compute effective contrast through styles, can't tell that a ListBox item's automation name comes out as `A11ySweep.Episode`, and can't map a scanner result like "Button with no name at (34,456)" back to a source line. Doing the audit and fix by hand takes an expert about an hour.

## Setup
Set **A11ySweep** as the startup project and press F5.

## Prompt
> Run an accessibility check on my running app, fix every issue in the XAML, and verify it's clean.

## Expected tool flow
1. `xaml_run_accessibility_check` returns issues with element IDs and source locations.
2. `xaml_get_element_properties` / `xaml_explain_property_value Foreground` on the low-contrast text.
3. `xaml_capture_image` to show the icon-only controls.
4. The AI edits the XAML (AutomationProperties.Name, LabeledBy, a Button instead of a Border, darker colors, an ItemContainerStyle name binding or Episode.ToString).
5. `xaml_apply_hot_reload` → `xaml_run_accessibility_check` again → `xaml_get_accessibility_results`.

## Answer key
- Back, Play, Forward and Shuffle icon buttons, plus the Like ToggleButton: no AutomationProperties.Name.
- CoverArt Image: no name. Mark it decorative or name it.
- SubscribeChip: a clickable Border (MouseLeftButtonUp) that isn't focusable and has no role. Make it a Button.
- SearchBox: the visual "Search" label isn't associated. Use `AutomationProperties.LabeledBy`.
- VolumeSlider: no name.
- Low-contrast text: #C4C4C4, #BDBDBD, #C8C8C8 on white.
- Episode list items are named `A11ySweep.Episode`. Bind AutomationProperties.Name to Title.

## Reset
Restore the folder from source control.
