using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class Rot {
  [DllImport("ole32.dll")] static extern int GetRunningObjectTable(int r, out IRunningObjectTable p);
  [DllImport("ole32.dll")] static extern int CreateBindCtx(int r, out IBindCtx p);
  public static List<string> Names() { var l=new List<string>(); IRunningObjectTable rot; GetRunningObjectTable(0,out rot); IEnumMoniker e; rot.EnumRunning(out e); var m=new IMoniker[1]; IBindCtx c; CreateBindCtx(0,out c);
    while(e.Next(1,m,IntPtr.Zero)==0){ string n; m[0].GetDisplayName(c,null,out n); l.Add(n);} return l; }
  public static object Get(string name) { IRunningObjectTable rot; GetRunningObjectTable(0,out rot); IEnumMoniker e; rot.EnumRunning(out e); var m=new IMoniker[1]; IBindCtx c; CreateBindCtx(0,out c);
    while(e.Next(1,m,IntPtr.Zero)==0){ string n; m[0].GetDisplayName(c,null,out n); if(n==name){ object o; rot.GetObject(m[0],out o); return o;} } return null; }
}
