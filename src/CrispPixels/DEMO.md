# CrispPixels: "Why does my app look blurry?"

**Wow moment:** the AI zooms into a capture of the running app and spots the blur. Then it uses **fractional live bounds** (x=12.5), effect and scale properties to find four separate causes. It fixes them and shows before/after captures where the 1-px lines and text are crisp again.

**Why this was hard before:** "it looks a bit fuzzy" is nearly impossible to debug from source. Fractional positions come from margins added together across several parents, and Viewbox scale is computed at runtime. Only the live bounds and render transforms explain it.

## Setup
Set **CrispPixels** as the startup project and press F5. Look at the divider lines, the toolbar icons, the invoice text and the totals card.

## Prompt
> My invoice screen looks blurry, especially the thin lines, the icons and the text. Find every cause in the running app and fix it.

## Expected tool flow
1. `xaml_capture_image` with elementId=InvoiceCard for a close-up.
2. `xaml_get_element_bounds` for CardDivider, ColumnRule, SaveIcon and TotalsCard:
   - Fractional x/y (12.5, 10.5, ...), so 1-px lines straddle pixels.
   - SaveIcon renders at 20×20 from a 16×16 bitmap.
   - TotalsCard renders smaller than its 420 px Width (Viewbox scale < 1).
3. `xaml_get_element_properties`:
   - Window has no `UseLayoutRounding`.
   - InvoiceCard has `Effect=DropShadowEffect` (rasterizes the text in the card).
   - SaveIcon has `Stretch=Fill`, Source 16×16.
   - TotalsViewbox is Height=104.
4. Optional live experiment: `xaml_set_element_property` Window `UseLayoutRounding=True`, then capture to show the lines snap.
5. The AI fixes everything, then hot reload and before/after capture.

## Answer key
| Cause | Fix |
|---|---|
| Fractional margins/padding with no layout rounding | `UseLayoutRounding="True"` on the Window and whole-number margins |
| 16×16 bitmap icons stretched to 20×20 | Use the native size (`Stretch="None"`) or vector icons |
| DropShadowEffect directly on the card that holds text | Put the shadow on a sibling Border behind the content |
| Viewbox scales the totals card down | Remove the Viewbox; let the card size naturally |

## Reset
`git checkout -- src\CrispPixels`
