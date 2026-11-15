param(
  [string]$Exe = 'G:\desk\Three_Kingdom_Client\build\windows\x64\runner\Release\three_kingdom_client.exe',
  [switch]$Maximize
)
# 诊断：把主窗口 + 所有子窗口的矩形打印出来，
# 判断 Flutter 子窗口是否真的铺满了客户区（"画面缩在左上角/右下黑边"的根因）。
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W32D {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
'@
# 注意：PowerShell here-string 的结束标记 '@ 必须独占行首，写成 }'@ 会让整个 C# 块被当成 PowerShell 解析。
$p = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 7
$hwnd = $p.MainWindowHandle
for ($i = 0; $i -lt 20 -and $hwnd -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 500; $p.Refresh(); $hwnd = $p.MainWindowHandle }
if ($hwnd -eq [IntPtr]::Zero) { throw "window not found" }
if ($Maximize) { [W32D]::ShowWindow($hwnd, 3) | Out-Null; Start-Sleep -Seconds 2 }

function Dump($h, $indent) {
  $wr = New-Object W32D+RECT; [W32D]::GetWindowRect($h, [ref]$wr) | Out-Null
  $cr = New-Object W32D+RECT; [W32D]::GetClientRect($h, [ref]$cr) | Out-Null
  $sb = New-Object System.Text.StringBuilder 256
  [W32D]::GetClassName($h, $sb, 256) | Out-Null
  $vis = [W32D]::IsWindowVisible($h)
  Write-Host ("{0}hwnd={1} class={2} visible={3} windowRect=({4},{5})-({6},{7}) client={8}x{9}" -f $indent, $h, $sb.ToString(), $vis, $wr.Left, $wr.Top, $wr.Right, $wr.Bottom, ($cr.Right-$cr.Left), ($cr.Bottom-$cr.Top))
}
Dump $hwnd ''
$child = [W32D]::FindWindowEx($hwnd, [IntPtr]::Zero, $null, $null)
while ($child -ne [IntPtr]::Zero) {
  Dump $child '  '
  $child = [W32D]::FindWindowEx($hwnd, $child, $null, $null)
}
Stop-Process -Id $p.Id -Force
