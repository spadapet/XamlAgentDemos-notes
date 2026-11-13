# HotReloadDoctor: "XAML Hot Reload is broken!"

**Wow moment:** the user edits XAML and "nothing happens", three times, for three different reasons. The AI checks hot reload status and the log, sees each edit *was* applied, and finds the real cause each time: code-behind overwrote the value, the template was swapped at runtime, and the skin is loaded with XamlReader so it can't hot reload. Then the user makes two unsupported edits, and the AI explains exactly which ones need a rebuild and why.

**Why this was hard before:** "hot reload doesn't work" is one of the most common XAML complaints, and usually hot reload is working. The model needs hot reload state, the log, the value source of the property, and the resource dictionary's origin to tell "didn't apply" apart from "applied but overridden".

## Setup
Set **HotReloadDoctor** as the startup project and press F5.

## Script (presenter edits, then asks the AI)
1. In MainWindow.xaml change WelcomeTitle `Foreground="#1F2937"` to `"DarkGreen"` and save. The title stays purple.
2. In the `TipTemplate` DataTemplate, change the title FontWeight to Bold and save. The tips don't change.
3. In `Skins\Skin.xaml` change `PageBackground` to `#FFF7ED` and save. The background doesn't change.

## Prompt
> XAML Hot Reload is broken in my running app. I made three edits (title color, tip template, page background in Skin.xaml) and none of them show up. Figure out what's going on.

## Expected tool flow
1. `xaml_get_hot_reload_status`: enabled, platform supported, no pending errors. `xaml_get_hot_reload_log` shows MainWindow.xaml updates **were applied**.
2. `xaml_explain_property_value WelcomeTitle Foreground` shows a **Local** value set in code. `OnLoaded` in MainWindow.xaml.cs overwrites it.
3. `xaml_get_element_properties TipsList` shows ItemTemplate is `CompactTipTemplate` (set in OnLoaded), so TipTemplate edits aren't visible.
4. `xaml_get_resource_dictionaries` shows the Skin dictionary has **no Source URI**. It was created by `XamlReader.Load` from a loose file, so hot reload has nothing to map it to.
5. The AI fixes all three (move the accent to a resource/style, use a DataTemplateSelector or trigger instead of swapping in code, and compile Skin.xaml as a Page merged via pack URI), then verifies with hot reload and capture.

## Part 2: unsupported edits
1. Add `Click="OnGetStarted"` to GetStartedButton (with no handler), and save.
2. Break the XAML (for example delete a closing `>`) and save.
3. Ask: *"Did hot reload apply my last edits?"*
4. The AI uses `xaml_get_hot_reload_status` + `xaml_get_hot_reload_log errorsOnly=true`: the event handler needs a rebuild (new code), and the parse error has a file and line. It fixes the typo and tells the user to rebuild for the handler.

## Answer key
| Symptom | Real cause | Fix |
|---|---|---|
| Title color | `OnLoaded` sets Foreground in code (local value wins) | Remove the code; use a resource or style |
| Tip template | `OnLoaded` swaps in CompactTipTemplate | Use the intended template or a selector/trigger |
| Page background | Skin.xaml loaded via `XamlReader.Load` (no hot reload) | Build Skin.xaml as a Page and merge it via pack URI |
| Click handler | New event handlers are not hot-reloadable | Rebuild / restart |
| Typo | XAML parse error blocks the update | Fix the line in the log |

## Reset
`git checkout -- src\HotReloadDoctor`
