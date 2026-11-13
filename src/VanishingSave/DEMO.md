# VanishingSave: "Where is my Save button?"

**Wow moment:** the Save button is defined in XAML but nobody can see it. The AI walks the live tree and finds that the button is hidden by **four independent, stacked causes**. It proves each one at runtime by setting properties live and taking screenshots, then fixes all four.

**Why this was hard before:** each layer hides the next. Fixing the first cause, the binding, still leaves the button invisible, and a human usually gives up or adds hacks. Seeing the causes takes runtime bounds (a 0-width column), z-order (a Border covering the button), style triggers (Opacity=0 when disabled) and binding failures together. Reading the code alone, nobody notices that `UseCompactFooter` collapses the column in code-behind.

## Setup
1. Set **VanishingSave** as the startup project and press F5.
2. Optionally type in a field so the form is dirty.

## Prompt
> There should be a Save button in the footer of my running app, but I can't see it. Find out every reason it's not visible and fix them.

## Expected tool flow
1. `xaml_find_elements name=SaveButton`, then `xaml_get_element_bounds` shows a width of 0 and Visibility=Collapsed.
2. `xaml_get_binding_failures` shows `CanSave` not found on CustomerViewModel; the real property is `IsSaveAvailable`.
3. `xaml_explain_property_value Visibility` shows the binding falling back to `FallbackValue=Collapsed`.
4. `xaml_get_element_bounds` on SaveColumn's Grid shows column 2 has width 0. The AI traces this to `MainWindow.xaml.cs` (UseCompactFooter).
5. `xaml_get_visual_tree includeBounds` shows SyncStatusHost in the same cell with ZIndex=1 and a white background.
6. `xaml_get_element_styles` shows the FooterButtonStyle trigger IsEnabled=False → Opacity=0.
7. The AI uses `xaml_set_element_property` to prove each cause live (Visibility=Visible, Opacity=1, …) and `xaml_capture_image` after each step.
8. It fixes the source, hot reloads, captures again, then uses `xaml_interact invoke SaveButton` to show that Save works.

## Answer key
1. The binding path `CanSave` should be `IsSaveAvailable`.
2. FooterButtonStyle sets Opacity=0 when disabled, and Save is disabled until the form is dirty. Use 0.4 instead.
3. `FooterSettings.UseCompactFooter` makes code-behind set `SaveColumn.Width = 0`.
4. `SyncStatusHost` (Grid.Column=2, ZIndex=1, White) covers the button. Move it to column 0/1 or remove the background.

## Reset
Restore the folder from source control.
