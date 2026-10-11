# 宇宙銀行ツールをデスクトップに作る（最初の1回だけ貼ってEnter）
$T = "$HOME\Desktop\宇宙銀行ツール"
New-Item -ItemType Directory -Force -Path $T | Out-Null

@'
# ライブ1：IDチェック済みの曲で3時間の音を作る
$Dir = "$HOME\Desktop\IDチェック済み"
$Out = "$HOME\Desktop\ライブ音源_3h_$(Get-Date -Format MMdd).mp3"
$Goal = 10800
$songs = Get-ChildItem -LiteralPath $Dir -File | Where-Object { $_.Extension -match '^\.(mp3|wav|m4a)$' } | Sort-Object Name
$dur = @{}; foreach ($s in $songs) { $dur[$s.FullName] = [double](ffprobe -v error -show_entries format=duration -of csv=p=0 $s.FullName) }
$order = @(); $total = 0; $round = 0
while ($total -lt $Goal) {
  $set = if ($round % 2 -eq 0) { $songs } else { $songs[($songs.Count-1)..0] }
  foreach ($s in $set) { if ($total -ge $Goal) { break }; $order += $s; $total += $dur[$s.FullName] }
  $round++
}
$list = Join-Path $env:TEMP "live_list.txt"
$lines = $order | ForEach-Object { "file '" + ($_.FullName -replace "'", "'\''") + "'" }
[IO.File]::WriteAllLines($list, $lines, (New-Object Text.UTF8Encoding $false))
"$($songs.Count) 曲で3時間の音を作ります..."
ffmpeg -hide_banner -loglevel error -stats -y -f concat -safe 0 -i $list -t $Goal `
  -af "afade=t=in:d=2,afade=t=out:st=$($Goal-3):d=3" -c:a libmp3lame -b:a 320k $Out
"できました: $Out"
Read-Host "Enterで閉じます"
'@ | Out-File "$T\ライブ1_音を作る.ps1" -Encoding utf8

@'
# ライブ2：デスクトップの「ライブ画像」フォルダの画像で映像を作る（1枚1分・2秒フェード）
$ImgDir = "$HOME\Desktop\ライブ画像"
$Seg    = Join-Path $env:TEMP "live_seg.mp4"
$D = 60; $F = 2
$imgs = Get-ChildItem -LiteralPath $ImgDir -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' } | Sort-Object Name
$a = @("-hide_banner","-loglevel","error","-stats","-y")
foreach ($im in $imgs) { $a += "-loop","1","-t",($D+$F),"-i",$im.FullName }
$fc = ""
for ($i=0; $i -lt $imgs.Count; $i++) { $fc += "[$($i):v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,fps=24,format=yuv420p[v$i];" }
$prev = "v0"
for ($i=1; $i -lt $imgs.Count; $i++) { $fc += "[$prev][v$i]xfade=transition=fade:duration=$($F):offset=$($i*$D)[x$i];"; $prev = "x$i" }
$a += "-filter_complex",$fc.TrimEnd(';'),"-map","[$prev]","-c:v","libx264","-preset","veryfast","-crf","23",$Seg
"$($imgs.Count) 枚で映像を作ります...（10〜20分）"
& ffmpeg @a
"映像ができました。次は ライブ3 です"
Read-Host "Enterで閉じます"
'@ | Out-File "$T\ライブ2_映像を作る.ps1" -Encoding utf8

@'
# ライブ3：テロップを入れて、音をのせて3時間に仕上げる（月曜はおみくじ案内、それ以外は眠る日の言葉）
$T1 = "ようこそ、宇宙銀行へ`n今夜も、朝まで11時間"
$T2 = "不安は、消さなくていい`n預けるだけで大丈夫"
if ((Get-Date).DayOfWeek -eq 'Monday') { $T3 = "おみくじ：チャットに`nおみくじ とだけ書いてね" }
else { $T3 = "今夜は何もしなくて大丈夫です`nゆっくりおやすみください" }

$Seg   = Join-Path $env:TEMP "live_seg.mp4"
$SegT  = Join-Path $env:TEMP "live_seg_telop.mp4"
$Audio = (Get-ChildItem "$HOME\Desktop\ライブ音源_3h_*.mp3" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
$Out   = "$HOME\Desktop\ライブ素材_テロップ付き_$(Get-Date -Format MMdd).mp4"
$font  = if (Test-Path "C:\Windows\Fonts\YuGothB.ttc") { "C\:/Windows/Fonts/YuGothB.ttc" } else { "C\:/Windows/Fonts/meiryob.ttc" }
$utf8  = New-Object Text.UTF8Encoding $false
"使う音: $Audio"

$times = @(@(2,15), @(14,27), @(26,39))
$texts = @($T1, $T2, $T3)
$parts = @()
for ($i=0; $i -lt 3; $i++) {
  $tf = Join-Path $env:TEMP "telop$i.txt"
  [IO.File]::WriteAllText($tf, $texts[$i], $utf8)
  $tfp = ($tf -replace '\\','/') -replace ':','\:'
  $s = $times[$i][0]; $e = $times[$i][1]
  $alpha = "if(lt(t,$s),0,if(lt(t,$s+1),t-$s,if(lt(t,$e-1),1,if(lt(t,$e),$e-t,0))))"
  $parts += "drawtext=fontfile='$font':textfile='$tfp':fontsize=72:fontcolor=0xF5D78E:line_spacing=28:shadowcolor=black@0.8:shadowx=4:shadowy=4:x=(w-text_w)/2:y=(h-text_h)/2:alpha='$alpha'"
}
$fcFile = Join-Path $env:TEMP "telop_filter.txt"
[IO.File]::WriteAllText($fcFile, "[0:v]" + ($parts -join ",") + "[v]", $utf8)

"テロップを入れています..."
ffmpeg -hide_banner -loglevel error -stats -y -i $Seg -/filter_complex $fcFile -map "[v]" `
  -c:v libx264 -preset veryfast -crf 23 -r 24 -pix_fmt yuv420p $SegT

$list = Join-Path $env:TEMP "telop_list.txt"
$lines = @("file '$SegT'") + (1..12 | ForEach-Object { "file '$Seg'" })
[IO.File]::WriteAllLines($list, $lines, $utf8)
"3時間にして音をのせます..."
ffmpeg -hide_banner -loglevel error -stats -y -f concat -safe 0 -i $list -i $Audio `
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -t 10800 $Out
"できました: $Out"
Read-Host "Enterで閉じます"
'@ | Out-File "$T\ライブ3_テロップと仕上げ.ps1" -Encoding utf8

@'
# IDチェック1：未チェックの新しい曲から30曲を「チェック中」へ移し、時刻表を作る
$Lib  = "$HOME\Desktop\素材ライブラリ\音源"
$From = "$Lib\未チェック"; $To = "$Lib\チェック中"
New-Item -ItemType Directory -Force -Path $To | Out-Null
if (Get-ChildItem -LiteralPath $To -File | Where-Object { $_.Extension -match '^\.(mp3|wav|m4a)$' }) {
  "「チェック中」に前の曲が残っています。結果に合わせて IDチェック済み か NG へ移してから実行してください"
  Read-Host "Enterで閉じます"; return
}
$t = [TimeSpan]::Zero; $k = 0; $list = @()
Get-ChildItem -LiteralPath $From -File | Sort-Object Name -Descending | Select-Object -First 30 | ForEach-Object {
  $k++
  $len = [TimeSpan]::FromSeconds([double](ffprobe -v error -show_entries format=duration -of csv=p=0 $_.FullName))
  $list += "{0:D2}  {1:hh\:mm\:ss} から  {2}" -f $k, $t, $_.Name
  $t += $len
  Move-Item -LiteralPath $_.FullName -Destination (Join-Path $To ("{0:D2}_{1}" -f $k, $_.Name))
}
$list += "合計 {0:hh\:mm\:ss}" -f $t
$list | Out-File "$To\時刻表.txt" -Encoding utf8
$list
Read-Host "Enterで閉じます"
'@ | Out-File "$T\IDチェック1_30曲を選ぶ.ps1" -Encoding utf8

@'
# IDチェック2：「チェック中」の曲を番号順につないだ黒画面の動画を作る（非公開でアップして著作権欄を見る）
$Dir = "$HOME\Desktop\素材ライブラリ\音源\チェック中"
$Out = "$HOME\Desktop\IDチェック用_$(Get-Date -Format MMdd_HHmm).mp4"
$list = Join-Path $env:TEMP "idcheck_list.txt"
$lines = Get-ChildItem -LiteralPath $Dir -File | Where-Object { $_.Extension -match '^\.(mp3|wav|m4a)$' } |
  Sort-Object Name | ForEach-Object { "file '" + ($_.FullName -replace "'", "'\''") + "'" }
[IO.File]::WriteAllLines($list, $lines, (New-Object Text.UTF8Encoding $false))
"$($lines.Count) 曲をつなぎます..."
ffmpeg -hide_banner -loglevel error -stats -y -f lavfi -i "color=c=black:s=640x360:r=1" `
  -f concat -safe 0 -i $list -map 0:v -map 1:a -shortest `
  -c:v libx264 -tune stillimage -c:a aac -b:a 192k $Out
"できました: $Out"
Read-Host "Enterで閉じます"
'@ | Out-File "$T\IDチェック2_動画を作る.ps1" -Encoding utf8

@'
【宇宙銀行ツール】右クリック →「PowerShell で実行」で動きます

■ ライブ素材を作る（この順番で）
 1. ライブ1_音を作る        … IDチェック済みの曲で3時間の音
 2. （デスクトップの「ライブ画像」に画像を20枚入れる。最初に出したい画像は名前を 00_ から）
 3. ライブ2_映像を作る      … 1枚1分の映像（10〜20分）
 4. ライブ3_テロップと仕上げ … テロップ＋音で3時間の完成品（月曜はおみくじ案内が自動で入る）
    → デスクトップに「ライブ素材_テロップ付き_日付.mp4」

■ 曲のIDチェック
 1. IDチェック1_30曲を選ぶ … 新しい曲30曲を「チェック中」へ＋時刻表
 2. IDチェック2_動画を作る … 黒画面の動画 → YouTubeに非公開でアップ → 著作権欄を見る
 3. 問題なし → チェック中の曲を「IDチェック済み」へ／引っかかった曲 → 「NG」へ
'@ | Out-File "$T\使い方.txt" -Encoding utf8

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
"宇宙銀行ツールを作りました"
explorer $T
