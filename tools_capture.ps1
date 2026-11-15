param(
  [string]$Exe = 'G:\desk\Three_Kingdom_Client\build\windows\x64\runner\Release\three_kingdom_client.exe',
  [string]$Out = 'G:\desk\Three_Kingdom_Client\shot_max.png',
  [switch]$Maximize
)

Add-Type -AssemblyName System.Drawing

if (-not ('W32' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class W32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int cx, int cy, bool repaint);
  [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
}
'@
}

$p = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 6

$hwnd = $p.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) {
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $p.MainWindowHandle; break }
  }
}
if ($hwnd -eq [IntPtr]::Zero) { throw "window not found" }

if ($Maximize) {
  [W32]::ShowWindow($hwnd, 3) | Out-Null   # SW_MAXIMIZE
  Start-Sleep -Seconds 2
}

[W32]::SetForegroundWindow($hwnd) | Out-Null
$wr = New-Object W32+RECT
[W32]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$pl = New-Object W32+RECT
[W32]::GetWindowRect($hwnd, [ref]$pl) | Out-Null
$cr = New-Object W32+RECT
[W32]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$cw = $cr.Right - $cr.Left
$ch = $cr.Bottom - $cr.Top
if ($cw -le 0 -or $ch -le 0) {
  $cw = $wr.Right - $wr.Left
  $ch = $wr.Bottom - $wr.Top
}
Write-Host ("window rect: {0}x{1} at ({2},{3}); client: {4}x{5}" -f ($wr.Right-$wr.Left), ($wr.Bottom-$wr.Top), $wr.Left, $wr.Top, $cw, $ch)

# 只抓客户区（PW_CLIENTONLY=1），避免把标题栏/多余缓冲算进图里
$bmp = New-Object System.Drawing.Bitmap($cw, $ch)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [W32]::PrintWindow($hwnd, $hdc, 1)
$g.ReleaseHdc($hdc)
$g.Dispose()
Write-Host "PrintWindow(clientonly) ok=$ok size=${cw}x${ch}"

$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# 边缘亮度分析：中心 vs 右 30 列 / 下 30 行
$b = [System.Drawing.Bitmap]::FromFile($Out)
function Region-Stat($bmp2, $x0, $y0, $x1, $y1) {
  $sum = 0.0; $n = 0
  for ($y = $y0; $y -lt $y1; $y += 7) {
    for ($x = $x0; $x -lt $x1; $x += 7) {
      $c = $bmp2.GetPixel($x, $y)
      $sum += (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B); $n++
    }
  }
  return [math]::Round($sum / [math]::Max(1, $n), 1)
}
$cw = $b.Width; $ch = $b.Height
$center = Region-Stat $b ([int]($cw*0.4)) ([int]($ch*0.42)) ([int]($cw*0.6)) ([int]($ch*0.58))
$left = Region-Stat $b 0 ([int]($ch*0.4)) 30 ([int]($ch*0.6))
$right = Region-Stat $b ($cw-30) ([int]($ch*0.4)) $cw ([int]($ch*0.6))
$top = Region-Stat $b ([int]($cw*0.4)) 0 ([int]($cw*0.6)) 24
$bottom = Region-Stat $b ([int]($cw*0.4)) ($ch-30) ([int]($cw*0.6)) $ch
Write-Host ("brightness center={0} left={1} right={2} top={3} bottom={4}" -f $center, $left, $right, $top, $bottom)
$b.Dispose()
