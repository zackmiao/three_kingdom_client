# 生成游戏音效与角色语音
# 语音：Windows SAPI 中文语音合成（Huihui） -> assets/audio/voice/*.wav
# 音效：程序合成的 WAV（无版权素材，纯本地生成） -> assets/audio/sfx/*.wav
Add-Type -AssemblyName System.Speech

$root = Join-Path $PSScriptRoot 'assets\audio'
$voiceDir = Join-Path $root 'voice'
$sfxDir = Join-Path $root 'sfx'
New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null
New-Item -ItemType Directory -Force -Path $sfxDir | Out-Null

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice('Microsoft Huihui Desktop')
$synth.Rate = 1
$synth.Volume = 100

$lines = [ordered]@{
  'sha'         = '杀'
  'shan'        = '闪'
  'tao'         = '桃'
  'jiu'         = '酒'
  'wuxie'       = '无懈可击'
  'guohe'       = '过河拆桥'
  'shunshou'    = '顺手牵羊'
  'nanman'      = '南蛮入侵'
  'wanjian'     = '万箭齐发'
  'wugu'        = '五谷丰登'
  'taoyuan'     = '桃园结义'
  'huogong'     = '火攻'
  'juedou'      = '决斗'
  'tiesuo'      = '铁索连环'
  'lebu'        = '乐不思蜀'
  'bingliang'   = '兵粮寸断'
  'shandian'    = '闪电'
  'zhuangbei'   = '装备'
  'panding'     = '判定'
  'shoushang'   = '受伤了'
  'wodehuibe'   = '我的回合'
  'shengli'     = '胜利'
  'shibai'      = '败北'
  'jineng'      = '发动技能'
  'mopai'       = '摸牌'
  'jiuzhu'      = '救命啊'
  'sile'        = '阵亡'
  'chupai'      = '出牌'
}

foreach ($k in $lines.Keys) {
  $path = Join-Path $voiceDir "$k.wav"
  $synth.SetOutputToWaveFile($path)
  $synth.Speak($lines[$k])
  $synth.SetOutputToNull()
}

# 武将出场语音：24 位武将各一句「XX，请赐教」
$heroes = @(
  '刘备','曹操','孙权','周处','谋关羽','谋张辽','谋袁绍','谋吕布','谋华雄','谋张飞',
  '谋赵云','谋甄姬','谋大乔','谋田豫','谋黄忠','谋陈宫','谋曹操','谋周瑜','谋曹仁','谋于禁',
  '谋贾诩','谋马超','谋曹丕','谋张角'
)
foreach ($h in $heroes) {
  $key = ($h -replace '谋', 'mou_')
  $path = Join-Path $voiceDir "hero_$key.wav"
  $synth.SetOutputToWaveFile($path)
  $synth.Speak("$h，请赐教")
  $synth.SetOutputToNull()
}
$synth.Dispose()

# ---------------- 合成音效 ----------------
$rate = 22050
function Write-Wav([string]$path, [double[]]$samples) {
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  $dataLen = $samples.Length * 2
  $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
  $bw.Write([int](36 + $dataLen))
  $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
  $bw.Write([int]16)
  $bw.Write([int16]1)
  $bw.Write([int16]1)
  $bw.Write([int]$rate)
  $bw.Write([int]($rate * 2))
  $bw.Write([int16]2)
  $bw.Write([int16]16)
  $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
  $bw.Write([int]$dataLen)
  foreach ($s in $samples) {
    $v = [Math]::Max(-1.0, [Math]::Min(1.0, $s))
    $bw.Write([int16]($v * 30000))
  }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

$rnd = New-Object System.Random 20241115

# 出牌 / 滑动：短促的气流声
$n = [int]($rate * 0.34)
$buf = New-Object double[] $n
$last = 0.0
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Sin([Math]::PI * [Math]::Pow($t, 0.7))
  $noise = $rnd.NextDouble() * 2 - 1
  $last = $last * 0.72 + $noise * 0.28
  $buf[$i] = $last * $env * 0.85
}
Write-Wav (Join-Path $sfxDir 'play.wav') $buf

# 摸牌：更轻、更短
$n = [int]($rate * 0.22)
$buf = New-Object double[] $n
$last = 0.0
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Pow(1 - $t, 1.6)
  $noise = $rnd.NextDouble() * 2 - 1
  $last = $last * 0.6 + $noise * 0.4
  $buf[$i] = $last * $env * 0.5
}
Write-Wav (Join-Path $sfxDir 'draw.wav') $buf

# 伤害：低频冲击 + 噪声
$n = [int]($rate * 0.42)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Pow(1 - $t, 2.2)
  $tone = [Math]::Sin(2 * [Math]::PI * (150 - 70 * $t) * $i / $rate)
  $noise = ($rnd.NextDouble() * 2 - 1) * 0.35
  $buf[$i] = ($tone * 0.8 + $noise) * $env
}
Write-Wav (Join-Path $sfxDir 'damage.wav') $buf

# 回复：上行两声
$n = [int]($rate * 0.5)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $f = if ($t -lt 0.5) { 523.25 } else { 783.99 }
  $local = if ($t -lt 0.5) { $t * 2 } else { ($t - 0.5) * 2 }
  $env = [Math]::Pow(1 - $local, 1.8) * 0.9
  $buf[$i] = [Math]::Sin(2 * [Math]::PI * $f * $i / $rate) * $env
}
Write-Wav (Join-Path $sfxDir 'heal.wav') $buf

# 护甲：金属脆响
$n = [int]($rate * 0.32)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Pow(1 - $t, 2.6)
  $a = [Math]::Sin(2 * [Math]::PI * 960 * $i / $rate)
  $b = [Math]::Sin(2 * [Math]::PI * 1460 * $i / $rate)
  $buf[$i] = ($a * 0.55 + $b * 0.35) * $env
}
Write-Wav (Join-Path $sfxDir 'shield.wav') $buf

# 判定：上扬的扫频
$n = [int]($rate * 0.45)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Sin([Math]::PI * $t) * 0.8
  $f = 520 + 620 * $t
  $buf[$i] = [Math]::Sin(2 * [Math]::PI * $f * $i / $rate) * $env
}
Write-Wav (Join-Path $sfxDir 'judge.wav') $buf

# 点击
$n = [int]($rate * 0.05)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $buf[$i] = [Math]::Sin(2 * [Math]::PI * 1250 * $i / $rate) * [Math]::Pow(1 - $t, 3) * 0.6
}
Write-Wav (Join-Path $sfxDir 'click.wav') $buf

# 回合开始：低沉锣声
$n = [int]($rate * 0.85)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Pow(1 - $t, 1.7)
  $a = [Math]::Sin(2 * [Math]::PI * 196 * $i / $rate)
  $b = [Math]::Sin(2 * [Math]::PI * 294 * $i / $rate) * 0.4
  $c = [Math]::Sin(2 * [Math]::PI * 392 * $i / $rate) * 0.2
  $buf[$i] = ($a + $b + $c) * $env * 0.7
}
Write-Wav (Join-Path $sfxDir 'turn.wav') $buf

# 胜利：上行琶音
$notes = @(523.25, 659.25, 783.99, 1046.5)
$n = [int]($rate * 0.9)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $seg = [Math]::Min(3, [int]($t * 4))
  $localT = $t * 4 - $seg
  $env = [Math]::Pow(1 - $localT, 1.5) * (1 - 0.15 * $seg)
  $buf[$i] = [Math]::Sin(2 * [Math]::PI * $notes[$seg] * $i / $rate) * $env * 0.7
}
Write-Wav (Join-Path $sfxDir 'win.wav') $buf

# 失败：下行
$n = [int]($rate * 0.9)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Pow(1 - $t, 1.2) * 0.8
  $f = 420 - 220 * $t
  $buf[$i] = [Math]::Sin(2 * [Math]::PI * $f * $i / $rate) * $env
}
Write-Wav (Join-Path $sfxDir 'lose.wav') $buf

# 技能：水晶般的和声
$n = [int]($rate * 0.55)
$buf = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
  $t = $i / $n
  $env = [Math]::Sin([Math]::PI * [Math]::Pow($t, 0.6)) * [Math]::Pow(1 - $t, 0.5)
  $a = [Math]::Sin(2 * [Math]::PI * 880 * $i / $rate)
  $b = [Math]::Sin(2 * [Math]::PI * 1320 * $i / $rate) * 0.5
  $buf[$i] = ($a + $b) * $env * 0.55
}
Write-Wav (Join-Path $sfxDir 'skill.wav') $buf

$voiceCount = (Get-ChildItem $voiceDir -Filter *.wav).Count
$sfxCount = (Get-ChildItem $sfxDir -Filter *.wav).Count
$voiceBytes = (Get-ChildItem $voiceDir -Filter *.wav | Measure-Object -Property Length -Sum).Sum
$sfxBytes = (Get-ChildItem $sfxDir -Filter *.wav | Measure-Object -Property Length -Sum).Sum
"voice=$voiceCount files, $voiceBytes bytes"
"sfx=$sfxCount files, $sfxBytes bytes"
