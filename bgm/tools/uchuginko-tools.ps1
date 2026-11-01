# 宇宙銀行・成功神殿の作業用コマンド
# 使い方は bgm/tools/インストール.txt を見る

$global:UBDesk = "$HOME\Desktop"
$global:UBShinList = "$HOME\Downloads\成功神殿_音源\list.txt"
$global:UBEnc = New-Object System.Text.UTF8Encoding($false)

function _UBDur($p) { [double](ffprobe -v error -show_entries format=duration -of csv=p=0 "$p") }
function _UBLine($p) { "file '" + ($p -replace "'", "'\''") + "'" }
function _UBPath($line, $base) {
  $p = ($line -replace "^file '", "" -replace "'$", "") -replace "'\\''", "'"
  if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $base $p }
  $p
}
function _UBSec($hms) { if ($hms -match '^\d+:\d+$') { $hms = "0:$hms" }; [TimeSpan]::Parse($hms).TotalSeconds }  # 「34:00」のような分:秒も受け付ける

# 成功神殿：list.txt の曲をランダムに並べて、音源とIDチェック用の黒画面動画を作る
# 例）神殿音源 1028        （3時間）
#     神殿音源 1028 03:33:33
function 神殿音源 {
  param([Parameter(Mandatory)][string]$日付, [string]$長さ = "03:00:00")
  if (-not (Test-Path -LiteralPath $UBShinList)) { Write-Host "list.txt が見つかりません：$UBShinList" -ForegroundColor Red; return }
  $W = "$UBDesk\制作\神殿$日付"; New-Item -ItemType Directory -Force $W | Out-Null; Set-Location $W
  $base = Split-Path $UBShinList
  $files = Get-Content $UBShinList -Encoding UTF8 | Where-Object { $_ -match "^file " } | ForEach-Object { _UBPath $_ $base } | Where-Object { Test-Path -LiteralPath $_ }
  Write-Host "曲数：$($files.Count)" -ForegroundColor Cyan
  if ($files.Count -eq 0) { return }
  $order = $files | Get-Random -Count $files.Count
  $list = @(); $tt = @(); $t = 0; $end = _UBSec $長さ
  foreach ($f in $order) {
    $list += _UBLine $f
    $tt += "{0:hh\:mm\:ss}  {1}" -f [TimeSpan]::FromSeconds($t), (Split-Path $f -Leaf)
    $t += _UBDur $f
    if ($t -gt $end) { break }
  }
  [IO.File]::WriteAllLines("$W\order_神殿$日付.txt", $list, $UBEnc)
  [IO.File]::WriteAllLines("$W\時刻表_神殿$日付.txt", $tt, $UBEnc)
  $cut = $end - 0.5
  ffmpeg -hide_banner -loglevel error -stats -f concat -safe 0 -i "order_神殿$日付.txt" -vn -c:a aac -b:a 192k -t $cut -y "音源_神殿$日付.m4a"
  ffmpeg -hide_banner -loglevel error -stats -f lavfi -i color=black:s=1280x720:r=1 -i "音源_神殿$日付.m4a" -c:v libx264 -tune stillimage -c:a copy -shortest -movflags +faststart -y "IDチェック_神殿$日付.mp4"
  Write-Host "できました：$W" -ForegroundColor Green
  Write-Host "次：IDチェック_神殿$日付.mp4 を非公開でアップして、著作権の欄を確認" -ForegroundColor Green
}

# 成功神殿：Filmoraの書き出し（v神殿MMDD.mp4）を、テロップ後ろからくり返して延ばし、音源と合わせる
# 例）神殿完成 1028 95     （テロップが95秒で終わる場合）
function 神殿完成 {
  param([Parameter(Mandatory)][string]$日付, [Parameter(Mandatory)][int]$秒, [string]$長さ = "03:00:00")
  $W = "$UBDesk\制作\神殿$日付"; Set-Location $W
  $v = @("v神殿$日付.mp4", "v神殿$日付.mp4.mp4") | Where-Object { Test-Path -LiteralPath "$W\$_" } | Select-Object -First 1
  if (-not $v) { Write-Host "v神殿$日付.mp4 が $W にありません" -ForegroundColor Red; return }
  $a = "音源_神殿$日付.m4a"
  if (-not (Test-Path -LiteralPath "$W\$a")) { Write-Host "$a がありません（先に 神殿音源 $日付）" -ForegroundColor Red; return }
  $loop = (_UBDur "$W\$v") - $秒
  if ($loop -le 0) { Write-Host "テロップの秒数が動画より長いです" -ForegroundColor Red; return }
  $n = [math]::Ceiling((_UBSec $長さ) / $loop) + 1
  $l = @("file '$v'"); 1..$n | ForEach-Object { $l += "file '$v'"; $l += "inpoint $秒" }
  [IO.File]::WriteAllLines("$W\list_神殿$日付.txt", $l, $UBEnc)
  $cut = (_UBSec $長さ) - 0.5
  ffmpeg -hide_banner -loglevel error -stats -f concat -safe 0 -i "list_神殿$日付.txt" -i $a -map 0:v -map 1:a -c copy -t $cut -movflags +faststart -y "完成_神殿$日付.mp4"
  Write-Host "できました：$W\完成_神殿$日付.mp4" -ForegroundColor Green
}

# 宇宙銀行：IDチェック済み＋IDチェック済み金庫の曲をランダムに並べて、日ごとに音源・時刻表・order・IDチェック動画を作る
# 例）宇宙音源 1103 1104                 （それぞれ3時間33分33秒。日ごとに順番を変える）
#     宇宙音源 1102 1103 1104 -ライブ 1102 （1102は月曜ライブ用＝全曲を1回ずつの長さ）
#     宇宙音源 1107 -長さ 09:00:00          （土曜の9時間）
function 宇宙音源 {
  param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$日付, [string]$ライブ = "", [string]$長さ = "03:33:33")
  $all = @(Get-ChildItem -LiteralPath "$UBDesk\IDチェック済み", "$UBDesk\IDチェック済み金庫" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.(mp3|m4a|wav)$' })
  if ($all.Count -lt 10) { Write-Host "曲が $($all.Count) 曲しかありません。デスクトップの「IDチェック済み」「IDチェック済み金庫」を確認してください" -ForegroundColor Red; return }
  Write-Host "曲の長さを調べています（$($all.Count)曲）…" -ForegroundColor Cyan
  $dur = @{}; foreach ($f in $all) { $dur[$f.FullName] = _UBDur $f.FullName }
  $one = ($dur.Values | Measure-Object -Sum).Sum
  Write-Host ("曲数：{0}　全曲1周：{1:hh\:mm\:ss}" -f $all.Count, [TimeSpan]::FromSeconds($one)) -ForegroundColor Cyan
  foreach ($day in $日付) {
    $live = ($day -eq $ライブ)
    $W = "$UBDesk\制作\$day"; New-Item -ItemType Directory -Force $W | Out-Null; Set-Location $W
    $order = $all | Get-Random -Count $all.Count
    $list = @(); $tt = @(); $t = 0
    if ($live) { $end = $one } else { $end = _UBSec $長さ }
    while ($t -lt $end - 1) {
      foreach ($f in $order) {
        $list += _UBLine $f.FullName
        $tt += "{0:hh\:mm\:ss}  {1}" -f [TimeSpan]::FromSeconds($t), $f.Name
        $t += $dur[$f.FullName]
        if ($t -ge $end - 1) { break }
      }
    }
    [IO.File]::WriteAllLines("$W\order_$day.txt", $list, $UBEnc)
    [IO.File]::WriteAllLines("$W\時刻表_$day.txt", $tt, $UBEnc)
    if ($live) { $cut = $end } else { $cut = $end - 0.5 }
    Write-Host "$day の音源を作っています…" -ForegroundColor Cyan
    ffmpeg -hide_banner -loglevel error -stats -f concat -safe 0 -i "order_$day.txt" -vn -c:a aac -b:a 192k -t $cut -y "音源_$day.m4a"
    ffmpeg -hide_banner -loglevel error -stats -f lavfi -i color=black:s=1280x720:r=1 -i "音源_$day.m4a" -c:v libx264 -tune stillimage -c:a copy -shortest -movflags +faststart -y "IDチェック_$day.mp4"
    $kind = if ($live) { "ライブ用・全曲1周" } else { "長さ $長さ" }
    Write-Host "できました：$W（$kind）音源・時刻表・order・IDチェック動画" -ForegroundColor Green
  }
  Write-Host "次：各フォルダの IDチェック_〇〇.mp4 を非公開でアップして、著作権の欄を確認" -ForegroundColor Green
}

# 宇宙銀行：Filmoraの書き出し（vMMDD.mp4）を、テロップ後ろ（inpoint）からくり返して延ばし、音源と合わせる
# 例）宇宙完成 1101 102                    （inpoint 102秒・3時間33分33秒・音源は 音源_1101*.m4a のいちばん新しいもの）
#     宇宙完成 1101 102 -音源 音源_1101b.m4a  （音源を指定）
#     宇宙完成 1107 120 -長さ 09:00:00        （土曜の9時間）
#     宇宙完成 1102 106 -ライブ                （月曜ライブ用：音源1周の長さで ライブ_1102.mp4 を作る）
function 宇宙完成 {
  param([Parameter(Mandatory)][string]$日付, [Parameter(Mandatory)][int]$秒, [string]$長さ = "03:33:33", [string]$音源 = "", [string]$映像 = "", [switch]$ライブ)
  $W = "$UBDesk\制作\$日付"
  if (-not (Test-Path -LiteralPath $W)) { Write-Host "$W がありません" -ForegroundColor Red; return }
  Set-Location $W
  if ($映像) { $v = $映像 } else { $v = @("v$日付.mp4", "v$日付.mp4.mp4") | Where-Object { Test-Path -LiteralPath "$W\$_" } | Select-Object -First 1 }
  if (-not $v -or -not (Test-Path -LiteralPath "$W\$v")) { Write-Host "v$日付.mp4 が $W にありません（v$日付-1 などの名前なら -映像 v$日付-1.mp4 と付ける）" -ForegroundColor Red; return }
  if ($音源) { $a = $音源 } else { $a = Get-ChildItem -LiteralPath $W -Filter "音源_$日付*.m4a" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name }
  if (-not $a -or -not (Test-Path -LiteralPath "$W\$a")) { Write-Host "音源_$日付.m4a が $W にありません" -ForegroundColor Red; return }
  $out = "完成_$日付.mp4"
  if ($ライブ) { $長さ = "{0:hh\:mm\:ss\.ff}" -f [TimeSpan]::FromSeconds((_UBDur "$W\$a") + 0.5); $out = "ライブ_$日付.mp4" }
  Write-Host "映像：$v ／ 音源：$a ／ inpoint：$秒 秒 ／ 長さ：$長さ" -ForegroundColor Cyan
  $loop = (_UBDur "$W\$v") - $秒
  if ($loop -le 0) { Write-Host "inpointの秒数が映像より長いです" -ForegroundColor Red; return }
  $n = [math]::Ceiling((_UBSec $長さ) / $loop) + 1
  $l = @("file '$v'"); 1..$n | ForEach-Object { $l += "file '$v'"; $l += "inpoint $秒" }
  [IO.File]::WriteAllLines("$W\list$日付.txt", $l, $UBEnc)
  $cut = (_UBSec $長さ) - 0.5
  $fs = @(); if ($cut -le 4 * 3600) { $fs = @("-movflags", "+faststart") }  # 9時間は空き容量が2倍いるので外す
  ffmpeg -hide_banner -loglevel error -stats -f concat -safe 0 -i "list$日付.txt" -i $a -map 0:v -map 1:a -c copy -t $cut @fs -y $out
  Write-Host "できました：$W\$out（非公開でアップして著作権の欄を確認）" -ForegroundColor Green
}

# 申し立ての時刻に流れていた曲を調べる（宇宙銀行・成功神殿どちらでも）
# 例）曲探し 1020 01:25:04 01:26:44
#     曲探し 神殿1028 00:41:10
function 曲探し {
  param([Parameter(Mandatory)][string]$フォルダ, [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$時刻)
  $W = "$UBDesk\制作\$フォルダ"
  $fs = Get-ChildItem -LiteralPath $W -Filter "時刻表*.txt" | Sort-Object Name
  if (-not $fs) { Write-Host "$W に時刻表がありません" -ForegroundColor Red; return }
  # フォルダに時刻表が複数あるときは、全部を調べて表示する
  foreach ($f in $fs) {
    Write-Host "時刻表：$($f.Name)" -ForegroundColor Cyan
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    foreach ($h in $時刻) {
      $s = _UBSec $h; $hit = $null
      foreach ($line in $lines) {
        if ($line -match '^(\d\d:\d\d:\d\d)\s+(.+)$') { if ((_UBSec $matches[1]) -le $s) { $hit = $line } else { break } }
      }
      "  $h → $hit"
    }
  }
}

Write-Host "宇宙銀行ツールを読み込みました（宇宙音源／宇宙完成／神殿音源／神殿完成／曲探し）" -ForegroundColor DarkYellow
