# GermanReady: "Is my UI ready for German?"

**Wow moment:** the AI switches the live app to German and then to pseudo-loc by clicking the language radio buttons itself. It screenshots each one and uses element bounds to find every clipped control (desired size > actual size). Then it replaces fixed sizes with content-driven layout and verifies all three languages again.

**Why this was hard before:** clipping only exists at runtime with real localized strings. A model reading XAML sees `Width="96"` but can't know that "Zahlungspflichtig bestellen" needs 190px. Finding these issues takes a localization test pass that is usually done weeks later by another team.

## Setup
Set **GermanReady** as the startup project and press F5. It starts in English and looks fine.

## Prompt
> Test my running checkout page in German and pseudo-localization. Find every place text is clipped or truncated and fix the layout so it works in all languages.

## Expected tool flow
1. `xaml_find_elements type=RadioButton`, then `xaml_interact select` Deutsch.
2. `xaml_capture_image`, then `xaml_get_visual_tree includeBounds` to compare TextBlock/Button bounds with their parents and find clipping.
3. `xaml_explain_property_value Width` on each clipped control shows a local fixed Width.
4. The same for Pseudo-loc.
5. The AI edits the XAML (Auto/MinWidth, a wrapping TextBlock, `*` columns), then `xaml_apply_hot_reload` → re-check each language.

## Answer key
- The header Border has a fixed `Height=58`, so the subtitle wraps and gets cut off.
- The label column has a fixed `Width=90`.
- The postal code TextBox is `Width=120` (fine), and the country ComboBox is `Width=120`, which truncates "Vereinigte Staaten".
- The Apply coupon button is `Width=64`.
- The delivery note is in a horizontal StackPanel, so it can't wrap.
- The footer buttons are a fixed `Width=96`.

Start the app with `--lang de` or `--lang qps` to skip the clicking.

## Reset
Restore the folder from source control.
