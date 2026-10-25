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

Write-Host "宇宙銀行ツールを読み込みました（神殿音源／神殿完成／曲探し）" -ForegroundColor DarkYellow
