# PrecedenceWars: "I set it, but it won't change"

**Wow moment:** five properties ignore the code that sets them. For each one the AI shows the *runtime precedence chain* and the exact winner: a held animation, a local value beating a trigger, a binding wiped out by a local value, a style setter beating inheritance, and a parent coercing `IsEnabled`. Then it fixes all five.

**Why this was hard before:** every line of code that "sets" these values is correct on its own. The bug is the WPF dependency-property precedence order at runtime: animation > local > template/style trigger > style setter > inherited > default. Only the live app knows which layer won. Debugging this today means guessing and breakpoint-hopping.

## Setup
1. Set **PrecedenceWars** as the startup project and press F5.
2. Optionally click the broken buttons first so the audience sees nothing happen: Show banner, Add item after Reset, the text-size slider and Export.

## Prompt
> Each card in my running app has a property that refuses to change. Figure out why for every card using the live app, prove it, and fix the source.

## Expected tool flow
1. `xaml_capture_image`, then `xaml_find_elements` for WelcomeBanner, HoverButton, CountText, ReleaseNotesText and ExportButton.
2. `xaml_explain_property_value`:
   - WelcomeBanner.Opacity is held by an **Animation** (Loaded storyboard, HoldEnd).
   - HoverButton.Background is a **Local** value that beats the IsMouseOver **style trigger**. Compare with HoverButtonOk.
   - ReleaseNotesText.FontSize comes from a **Style setter** (BodyTextStyle), so the inherited Window FontSize loses.
   - ExportButton.IsEnabled is **coerced** to false by its parent ToolbarPanel.
3. Reproduce the counter bug: `xaml_interact invoke` on ResetButton, then AddButton twice. `xaml_get_element_properties CountText` shows a local value and no binding left.
4. `xaml_get_element_properties ToolbarPanel` shows `IsEnabled` bound to `IsIdle`. The AI reads `StoreViewModel.cs` and finds that `IsBusy` never resets after the catch block in `SyncCatalog`.
5. The AI makes the fixes and verifies with hot reload, `xaml_interact` and capture.

## Answer key
| Card | Root cause | Fix |
|---|---|---|
| Banner | Storyboard `FillBehavior=HoldEnd` holds Opacity | `FillBehavior="Stop"`, or animate back, or `BeginAnimation(OpacityProperty, null)` |
| Hover | Local `Background` beats the style trigger | Move the background into a style setter |
| Counter | `CountText.Text = ...` in OnResetClick replaces the binding | Reset the view model property instead |
| Release notes | BodyTextStyle `FontSize=13` setter beats inheritance | Remove the setter or bind it |
| Export | `IsBusy` stuck true, so the parent disables children | `try/finally { IsBusy = false; }` |

## Reset
`git checkout -- src\PrecedenceWars`
