# Windows Scancode Mapping

As explained in
<https://docs.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers#scan-code-mapper-for-keyboards>,
a registry value can be created under
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout`, called
`Scancode Map`, to remap key presses to other key presses.

This can be set in a `.reg` script file. This is the Control/Caps Lock switch
example in the above link turned into a script, adapted from
<https://superuser.com/a/1264295>:

```reg
Windows Registry Editor Version 5.00

; The hex data is in five groups of four bytes:
;   00,00,00,00,\    header version (always 00000000)
;   00,00,00,00,\    header flags (always 00000000)
;   03,00,00,00,\    # of entries (2 in this case) plus a NULL terminator line.
;                    Entries are in 2-byte pairs: Key code to send & keyboard key to send it.
;                    Each entry is in "least significant byte, most significant byte" order,
;                    e.g. 0x1234 becomes `34,12`
;   1d,00,3a,00,\    Send LEFT CTRL (0x001d) code when user presses the CAPS LOCK key (0x003a) 
;   3a,00,1d,00,\    Send CAPS LOCK (0x003a) code when user presses the LEFT CTRL key (0x001d) 
;   00,00,00,00      NULL terminator

; Scan codes are from the "Scan 1 make" in the table here:
; https://docs.microsoft.com/en-us/windows/win32/inputdev/about-keyboard-input#scan-codes

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout]
"Scancode Map"=hex:00,00,00,00,\
                   00,00,00,00,\
                   03,00,00,00,\
                   1d,00,3a,00,\
                   3a,00,1d,00,\
                   00,00,00,00
```

The `\`-prefixed line breaks can be removed, but help with visual grouping.

Only the administrator can edit the registry. To run the script, open an administrator terminal (PowerShell or CMD) and run

```powershell
regedt32 "C:\path\to\swap_reset.reg"
```

To find the scan codes, either reference the table at this link:
<https://docs.microsoft.com/en-us/windows/win32/inputdev/about-keyboard-input#scan-codes>.

Or they can also be found by running a monstrous script in PowerShell that's
basically a C# script (adapted from: <https://stackoverflow.com/a/54237188>):

```powershell
Add-Type -TypeDefinition '
using System;
using System.IO;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace KeyLogger {
  public static class Program {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;

    private static HookProc hookProc = HookCallback;
    private static IntPtr hookId = IntPtr.Zero;
    private static int keyCode = 0;

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static int WaitForKey() {
      hookId = SetHook(hookProc);
      Application.Run();
      UnhookWindowsHookEx(hookId);
      return keyCode;
    }

    private static IntPtr SetHook(HookProc hookProc) {
      IntPtr moduleHandle = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
      return SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, moduleHandle, 0);
    }

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
      if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
        keyCode = Marshal.ReadInt32(lParam);
        Application.Exit();
      }
      return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
  }
}
' -ReferencedAssemblies System.Windows.Forms

[System.Convert]::ToString(([System.Windows.Forms.Keys][KeyLogger.Program]::WaitForKey()).value__,16)
```
