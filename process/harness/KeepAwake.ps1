Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Nudge {
 [DllImport("user32.dll")] static extern void mouse_event(uint f,int dx,int dy,uint d,UIntPtr e);
 [DllImport("user32.dll")] static extern void keybd_event(byte vk,byte sc,uint f,UIntPtr e);
 [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint s);
 [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII p);
 [StructLayout(LayoutKind.Sequential)] struct LII { public uint cb; public uint t; }
 public static uint LastInput(){ var l=new LII(); l.cb=8; GetLastInputInfo(ref l); return l.t; }
 public static void Go(){ mouse_event(1,1,0,0,UIntPtr.Zero); mouse_event(1,-1,0,0,UIntPtr.Zero); keybd_event(0x7E,0,0,UIntPtr.Zero); keybd_event(0x7E,0,2,UIntPtr.Zero); }
}
"@
[Nudge]::SetThreadExecutionState([uint32]2147483651) | Out-Null
while($true){ [Nudge]::Go(); Start-Sleep 30 }

