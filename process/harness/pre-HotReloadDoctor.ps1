param($appPid)
# Simulates the presenter's three edits in the VS editor (saved, so XAML Hot Reload applies them).
$s='Q:\source\XamlAgentDemos\src\HotReloadDoctor'
$dte=Get-Dte
function Edit-InVs([string]$path,[string]$find,[string]$replace){
  $w=Invoke-Dte { $dte.ItemOperations.OpenFile($path) }
  Start-Sleep 2
  $doc=Invoke-Dte { $dte.ActiveDocument }
  $td=Invoke-Dte { $doc.Object('TextDocument') }
  $ep=Invoke-Dte { $td.StartPoint.CreateEditPoint() }
  $text=Invoke-Dte { $ep.GetText($td.EndPoint) }
  $ok=$text.Contains($find)
  if($ok){ $new=$text.Replace($find,$replace); Invoke-Dte { $ep.Delete($td.EndPoint) } | Out-Null; Invoke-Dte { $ep.Insert($new) } | Out-Null }
  Invoke-Dte { $doc.Save() } | Out-Null
  Write-Host "edited $path ($find -> $replace): $ok"
  Start-Sleep 4
}
Edit-InVs "$s\MainWindow.xaml" 'Foreground="#1F2937"' 'Foreground="DarkGreen"'
Edit-InVs "$s\MainWindow.xaml" '<TextBlock FontWeight="SemiBold" Text="{Binding Title}" />' '<TextBlock FontWeight="Bold" Text="{Binding Title}" />'
Edit-InVs "$s\Skins\Skin.xaml" 'Color="#F5F3FF"' 'Color="#FFF7ED"'

