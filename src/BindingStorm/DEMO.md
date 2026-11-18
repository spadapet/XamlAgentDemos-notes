# BindingStorm: "Find and fix every binding failure, even the ones that aren't hit yet from the other tabs."

**Wow moment:** at startup the Binding Failures window shows only a few entries. The AI *drives the app itself*: it switches every tab and opens the details dialog with `xaml_interact`, which surfaces latent failures. Then it fixes all 10 failures and verifies that the list is empty.

**Why this was hard before:** WPF only reports binding errors for UI that has actually been created. Most of these live in unvisited tabs and an unopened dialog. Several also need runtime context to fix: the actual DataContext type, a mismatched `ElementName` casing, a `RelativeSource` searching for a type that isn't an ancestor, an int bound to Visibility, and a doubled `Summary.` path inside a scope that is already Summary.

## Setup
Set **BindingStorm** as the startup project and press F5.

## Prompt
> Exercise every tab and dialog in my running app, collect all binding failures, fix them all in source, and prove the list is clean.

## Expected tool flow
1. `xaml_clear_binding_failures`, then `xaml_get_binding_failures` to get the baseline.
2. `xaml_find_elements type=TabItem`, then `xaml_interact select` on each tab.
3. On the Orders tab, select an order and `xaml_interact invoke OrderDetailsButton`, which opens OrderDetailsWindow.
4. `xaml_get_binding_failures` now has the full list, with XAML file and line for each entry.
5. `xaml_get_element_properties` / `xaml_explain_property_value DataContext` to learn the real source types.
6. The AI edits both XAML files, then runs `xaml_apply_hot_reload`, `xaml_clear_binding_failures`, re-exercises the UI and checks with `xaml_get_binding_failures` again, which returns 0.

## Answer key
| Location | Bad | Fix |
|---|---|---|
| Orders tab | `OrderTotal` | `Total` |
| Customers tab | `ElementName=searchBox` | `SearchBox` |
| Customers tab | `Emial` | `Email` |
| Customers tab | `AncestorType=ListView` | `ListBox` |
| Reports tab | `Visibility="{Binding HighPriorityCount}"` (int) | Bind a bool or use a converter |
| Reports tab | `Summary.Revenue` inside the Summary scope | `Revenue` |
| Settings tab | `Regions` | `AvailableRegions` |
| Settings tab | `AutoRefresh` | `AutoRefreshEnabled` |
| Details dialog | `Order.Id` | `Id` |
| Details dialog | `ShippingAdress` | `ShippingAddress` |

## Reset
Restore the folder from source control.
