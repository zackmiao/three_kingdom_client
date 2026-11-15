param(
  [string]$Exe = 'G:\desk\Three_Kingdom_Client\build\windows\x64\runner\Release\three_kingdom_client.exe',
  [string]$Out = 'G:\desk\Three_Kingdom_Client\shot_client.png',
  [switch]$Maximize
)
# 抓取 Flutter 窗口的“客户区”：
#  - 用 physical 像素的窗口矩形做缓冲，PrintWindow(FULLCONTENT=2) 渲染整窗
#  - 再用 ClientToScreen 求出客户区在窗口内的偏移，程序化裁剪出来
Add-Type -AssemblyName System.Drawing
if (-not ('W32B' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class W32B {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
}
$p = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 7
$hwnd = $p.MainWindowHandle
for ($i = 0; $i -lt 20 -and $hwnd -eq [IntPtr]::Zero; $i++) {
  Start-Sleep -Milliseconds 500; $p.Refresh(); $hwnd = $p.MainWindowHandle
}
if ($hwnd -eq [IntPtr]::Zero) { throw "window not found" }

if ($Maximize) { [W32B]::ShowWindow($hwnd, 3) | Out-Null; Start-Sleep -Seconds 2 }
[W32B]::SetWindowPos($hwnd, [IntPtr](-1), 0,0,0,0, 0x0001 -bor 0x0002) | Out-Null  # HWND_TOPMOST, NOSIZE|NOMOVE
[W32B]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

$wr = New-Object W32B+RECT; [W32B]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$cr = New-Object W32B+RECT; [W32B]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$pt = New-Object W32B+POINT; $pt.X = 0; $pt.Y = 0
[W32B]::ClientToScreen($hwnd, [ref]$pt) | Out-Null
$winW = $wr.Right - $wr.Left; $winH = $wr.Bottom - $wr.Top
$cw = $cr.Right - $cr.Left;     $ch = $cr.Bottom - $cr.Top
$ox = $pt.X - $wr.Left;         $oy = $pt.Y - $wr.Top
Write-Host "window ${winW}x${winH} client ${cw}x${ch} clientOffset (${ox},${oy})"

$full = New-Object System.Drawing.Bitmap($winW, $winH)
$g = [System.Drawing.Graphics]::FromImage($full)
$hdc = $g.GetHdc()
$ok = [W32B]::PrintWindow($hwnd, $hdc, 2)
$g.ReleaseHdc($hdc); $g.Dispose()
Write-Host "PrintWindow(full) ok=$ok"

$crop = New-Object System.Drawing.Rectangle($ox, $oy, $cw, $ch)
$client = $full.Clone($crop, $full.PixelFormat)
$client.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "saved $Out ($($client.Width)x$($client.Height))"
$client.Dispose(); $full.Dispose()

# 简易质量检查：分行统计亮像素比例，确认底部手牌区确实有牌面
$b = [System.Drawing.Bitmap]::FromFile($Out)
$W = $b.Width; $H = $b.Height
for ($y = 0; $y -lt $H; $y += 60) {
  $bright = 0; $n = 0
  for ($x = 0; $x -lt $W; $x += 7) {
    for ($yy = $y; $yy -lt [math]::Min($H, $y+60); $yy += 7) {
      $c = $b.GetPixel($x, $yy); $v = (0.299*$c.R + 0.587*$c.G + 0.114*$c.B); $n++
      if ($v -gt 150) { $bright++ }
    }
  }
  Write-Host ("band y={0,4} bright%={1,5}" -f $y, [math]::Round(100*$bright/[math]::Max(1,$n),1))
}
$b.Dispose()
