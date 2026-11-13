# LostWindows: "The buttons open nothing"

**Wow moment:** the user clicks Settings, Notifications and Inspector, and nothing appears. The AI lists **every top-level window the app has**, including three the user can't see. It reports their real bounds and state (one at -32000,-32000, one minimized with no taskbar button, one 0 px wide) and traces each back to `layout.json` and `SizeToContent`.

**Why this was hard before:** the windows *are* open; they just aren't visible. No exception, no log. Screenshots show nothing. A model reading code sees `window.Show()` and concludes it works. Only the live window list with bounds and minimized state shows the truth.

## Setup
1. Set **LostWindows** as the startup project and press F5.
2. Click **Settings…**, **Notifications** and **Inspector**. Nothing visible happens.

## Prompt
> When I click Settings, Notifications or Inspector in my running app, nothing shows up. Find out what's happening and fix it so it can never happen again.

## Expected tool flow
1. `xaml_list_windows` returns 4 windows:
   - SettingsWindow at x=-32000, y=-32000 (off every monitor).
   - NotificationsWindow with `minimized=true`. `xaml_get_element_properties` shows ShowInTaskbar=False.
   - InspectorWindow with width/height near 0.
2. `xaml_get_element_properties InspectorWindow` shows SizeToContent=WidthAndHeight. `xaml_get_visual_tree` shows InspectorContent Collapsed (HasSelection=false).
3. `xaml_capture_image windowId=<Settings>` proves the window renders fine. It's just off-screen.
4. The AI reads `WindowLayout.cs` and `layout.json`: the saved placement came from a minimized window (-32000 is Windows' minimized position) and was restored without validation.
5. Fix: clamp the restored placement to the virtual screen, never restore Minimized, and give Inspector a MinWidth/MinHeight and empty-state content. Optionally `xaml_set_element_property` on the window Left/Top to bring it back live first.

## Answer key
| Window | Root cause | Fix |
|---|---|---|
| Settings | Restored to -32000,-32000 | Validate against `SystemParameters.VirtualScreen*`; fall back to CenterOwner |
| Notifications | Restored `Minimized` with `ShowInTaskbar=False` | Don't restore Minimized; show it in the taskbar or restore Normal |
| Inspector | `SizeToContent` with collapsed content gives ~0 size | MinWidth/MinHeight plus an empty-state message |

## Reset
`git checkout -- src\LostWindows`
