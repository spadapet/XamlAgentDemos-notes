# XAML Agent Demos

Small WPF (net10.0-windows) apps with bugs planted on purpose. They show what Copilot can do once it can see and drive a **running** XAML app through Visual Studio's XAML Diagnostics (`xaml_*` tools and the `xaml-diagnostics` skill).

The rankings and tool names below are historical. See [the process journal](process/Journal.md) and [unimplemented demo ideas](process/demo-ideas.md) for later findings, including the source-only baselines and their limitations.

Each app has a `DEMO.md` with the setup, the exact prompt, the expected tool flow, the "wow moment" and an answer key.

## Demos, ranked by wow factor

| # | App | One-line pitch | Key capabilities |
|---|---|---|---|
| 1 | [ThemeBreaker](src/ThemeBreaker/DEMO.md) | "Fix dark mode": 6 bugs with 6 different resource/precedence root causes | explain_property_value, find_resource, resource dictionaries, styles, hot reload, capture |
| 2 | [VanishingSave](src/VanishingSave/DEMO.md) | "Where's my Save button?": 4 stacked causes | bounds, z-order, style triggers, binding failures, live set-property experiments |
| 3 | [PixelPerfect](src/PixelPerfect/DEMO.md) | "Make it match this mockup PNG" with a visual edit→reload→capture loop | capture_image, bounds, hot reload |
| 4 | [BindingStorm](src/BindingStorm/DEMO.md) | The AI drives every tab and dialog to surface *latent* binding failures, then fixes all 10 | interact, binding failures, hot reload |
| 5 | [GermanReady](src/GermanReady/DEMO.md) | The AI switches to German/pseudo-loc and finds and fixes every clipped control | interact, bounds, explain_property_value |
| 6 | [A11ySweep](src/A11ySweep/DEMO.md) | Accessibility audit mapped to XAML lines, fixed, then re-verified | accessibility check, properties, hot reload |
| 7 | [BugRepro](src/BugRepro/DEMO.md) | Bug report → live repro → root cause → fix → replay | interact, element properties |
| 8 | [LostWindows](src/LostWindows/DEMO.md) | "The buttons open nothing": 3 windows that are open but invisible (off-screen, minimized without a taskbar button, 0 px) | list_windows, capture (per window), set property |
| 9 | [GhostClicks](src/GhostClicks/DEMO.md) | Buttons that ignore clicks; the AI proves the handlers work and finds the invisible overlays | interact, bounds, z-order, properties, set property |
| 10 | [SlowScroll](src/SlowScroll/DEMO.md) | 3,000 realized items → ~25: three stacked virtualization killers fixed and *measured* one at a time | find_elements counts, bounds, tree, hot reload |
| 11 | [HotReloadDoctor](src/HotReloadDoctor/DEMO.md) | "Hot reload is broken!" (it isn't): overridden in code, template swapped, XamlReader skin; plus rude edits | hot reload status/log, explain_property_value, resource dictionaries |
| 12 | [PrecedenceWars](src/PrecedenceWars/DEMO.md) | "I set it but it won't change": animation, local value, wiped binding, style setter, parent coercion | explain_property_value, interact, properties |
| 13 | [ResponsiveDashboard](src/ResponsiveDashboard/DEMO.md) | The AI resizes the live window to 1024/800, finds every overflow and fixes the layout | set property (Window.Width), capture, bounds |
| 14 | [TemplateDetective](src/TemplateDetective/DEMO.md) | Every feed item uses the fallback DataTemplate; 4 template-matching failures | visual tree, properties, resource dictionaries, find_resource |
| 15 | [StyleMaze](src/StyleMaze/DEMO.md) | 5 places ignore the brand style: ToolBar, merge order, subclass, local scope, template boundary | element styles, find_resource, resource dictionaries |
| 16 | [DesignPolish](src/DesignPolish/DEMO.md) | Live design-token audit, plus "try 3 hero designs live" with runtime-only experiments | tree + properties at scale, set property, capture |
| 17 | [CrispPixels](src/CrispPixels/DEMO.md) | "Why is it blurry?": fractional bounds, stretched bitmaps, effects, Viewbox scaling | bounds, properties, capture, set property |

### Scenario demos (no special app needed)
Use any app above:
- **Attach without source info:** start the app outside VS, then Debug > Attach. Ask *"Why doesn't the Live Visual Tree show XAML file locations?"* The AI uses `xaml_get_diagnostics_status` and explains `ENABLE_XAML_DIAGNOSTICS_SOURCE_INFO=1` and F5 vs attach.
- **Release build / hot reload off:** run a Release build, or disable WPF in Tools > Options > Debugging > XAML Hot Reload. Ask *"Why isn't hot reload working?"* The status tools name the exact reason and the fix.
- **Two apps at once:** set multiple startup projects (e.g., ThemeBreaker + StyleMaze). Ask *"Compare the accent color and button styles across both running apps."* The AI uses `xaml_list_apps` and per-app `xaml_find_resource`.
- **Onboarding, "which XAML renders this?":** ask *"Which XAML file and line renders the Export button, and what's its DataContext?"* The AI uses `xaml_find_elements` + `xaml_select_element goToSource=true`, which highlights it in the app and opens the source.

## Tool coverage

| Tool | Demos |
|---|---|
| `xaml_list_apps`, `xaml_get_diagnostics_status` | All; scenario demos |
| `xaml_get_visual_tree`, `xaml_find_elements` | SlowScroll, TemplateDetective, DesignPolish, ThemeBreaker, onboarding |
| `xaml_get_element_properties` | GhostClicks, PrecedenceWars, CrispPixels, DesignPolish, TemplateDetective |
| `xaml_explain_property_value` | PrecedenceWars, ThemeBreaker, HotReloadDoctor, GermanReady |
| `xaml_get_element_styles` | StyleMaze, ThemeBreaker |
| `xaml_find_resource`, `xaml_get_resource_dictionaries` | StyleMaze, ThemeBreaker, TemplateDetective, HotReloadDoctor |
| `xaml_set_element_property` | DesignPolish (variants), ResponsiveDashboard, GhostClicks, LostWindows, CrispPixels |
| `xaml_get_element_bounds` | GhostClicks, CrispPixels, ResponsiveDashboard, SlowScroll, VanishingSave |
| `xaml_interact` | BindingStorm, BugRepro, GhostClicks, PrecedenceWars |
| `xaml_select_element` | Onboarding scenario |
| `xaml_list_windows`, `xaml_capture_image` | LostWindows, ResponsiveDashboard, PixelPerfect, everything else |
| `xaml_get_binding_failures`, `xaml_clear_binding_failures` | BindingStorm, VanishingSave |
| `xaml_run_accessibility_check`, `xaml_get_accessibility_results` | A11ySweep |
| `xaml_get_hot_reload_status`, `xaml_get_hot_reload_log`, `xaml_apply_hot_reload` | HotReloadDoctor, SlowScroll, all fix loops |

### Finale: "Make it ship-ready"
On any app (BindingStorm or GermanReady work best):
> Make this running app ship-ready: exercise all the UI, fix every binding failure, every accessibility issue, any dark-mode or localization layout problem, and show me before/after screenshots.

## Prerequisites
- A Visual Studio build that includes the XAML Diagnostics Copilot tools and skill, with the feature flag on.
- Copilot Chat in **Agent mode**. Choose "Always allow" for the mutating tools (set property, interact, select, clear binding failures, apply hot reload) to keep the demo flowing.
- F5 a **Debug** build so XAML source info is available. Keep XAML Hot Reload enabled (the default).
- Before each demo, restore the original sources (e.g. `git init` and commit this folder once, then `git checkout -- .`).

## Building
```
dotnet build XamlAgentDemos.sln
.\Render-Mockup.ps1        # regenerates src\PixelPerfect\design\mockup.png
```

## Command-line switches (src\Shared\DemoHost.cs)
- `--snapshot <png>`: render the main window to a PNG after 2 seconds, then exit. Used to verify the bugs without VS.
- `--trace-bindings <file>`: write WPF binding errors to a file.
- `--width <n>` / `--height <n>`: start the main window at a specific size (e.g., ResponsiveDashboard at 800).
- App-specific: ThemeBreaker `--dark`; GermanReady `--lang de|qps`; PixelPerfect `--render-xaml <xaml> <png>`.

`New-DemoApp.ps1 <Name>` scaffolds a new demo app and adds it to the solution.

## Process logs
See [process/Journal.md](process/Journal.md) for the chronological design → implementation → deployment → testing → iteration history, with links to checkpoints, the plan, the full session transcript, the harness, and the analysis scripts.

