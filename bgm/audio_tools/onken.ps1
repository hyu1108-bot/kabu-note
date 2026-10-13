# 宇宙銀行 音源づくりスクリプト（Windows PowerShell 用）
#
# 使い方（フォルダの中で右クリック →「ターミナルで開く」→ 下を貼り付け）
#
#   ① IDチェック用：フォルダの曲を番号順に1本につなぎ、黒い画面の動画を作る
#      powershell -ExecutionPolicy Bypass -File onken.ps1 check "D:\SUNO\1007_チャリン"
#
#   ② 3時間マスター：「IDチェック済み」フォルダの曲を番号順につなぎ、3時間までくり返す
#      powershell -ExecutionPolicy Bypass -File onken.ps1 master "D:\SUNO\IDチェック済み" 1015_木曜
#
# どちらも、曲ごとの開始時刻を書いた「_曲の順番.txt」を一緒に作る。
# 申し立てが付いたら、検出時刻をこの表と見比べれば、どの曲かすぐ分かる。
#
# 必要なもの：ffmpeg（コマンドプロンプトで ffmpeg -version と打って動けばOK）

param(
    [Parameter(Mandatory = $true)][ValidateSet('check', 'master')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$Folder,
    [string]$Name = ''
)

$ErrorActionPreference = 'Stop'
$Hours = 3

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host 'ffmpeg が見つかりません。インストールしてから、もう一度実行してください。' -ForegroundColor Red
    exit 1
}

# 「1007_チャリン (2)」が「(10)」より前に来るよう、数字を桁そろえして並べる
$files = Get-ChildItem -LiteralPath $Folder -File |
    Where-Object { $_.Extension -match '^\.(mp3|wav|m4a)$' } |
    Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(6, '0') }) }

if ($files.Count -eq 0) {
    Write-Host "曲が見つかりません：$Folder" -ForegroundColor Red
    exit 1
}

if ($Name -eq '') { $Name = Split-Path $Folder -Leaf }
$outDir = Join-Path $Folder '_書き出し'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Format-Time([double]$sec) {
    $t = [TimeSpan]::FromSeconds([math]::Floor($sec))
    '{0}:{1:00}:{2:00}' -f [int]$t.TotalHours, $t.Minutes, $t.Seconds
}

# 曲の順番と開始時刻の表を作る
$list = New-Object System.Collections.Generic.List[string]
$table = New-Object System.Collections.Generic.List[string]
$table.Add("番号`t開始`t長さ`t曲名")
$pos = 0.0
$i = 1
foreach ($f in $files) {
    $dur = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 -- $f.FullName)
    $table.Add(("{0}`t{1}`t{2}`t{3}" -f $i, (Format-Time $pos), (Format-Time $dur), $f.Name))
    $list.Add("file '" + ($f.FullName -replace "'", "'\''") + "'")
    $pos += $dur
    $i++
}
$loopLen = $pos
$table.Add('')
$table.Add("1周の長さ（ループ長）：$(Format-Time $loopLen)")
$table.Add('検出時刻からの逆算：検出時刻 − ループ長 × 周回数 → この表の開始時刻と見比べる')

$utf8 = New-Object System.Text.UTF8Encoding($false)
$listPath = Join-Path $outDir '_list.txt'
[IO.File]::WriteAllLines($listPath, $list, $utf8)
[IO.File]::WriteAllLines((Join-Path $outDir "${Name}_曲の順番.txt"), $table, $utf8)

$joined = Join-Path $outDir "${Name}_つなぎ.m4a"
Write-Host "$($files.Count) 曲をつないでいます（1周 $(Format-Time $loopLen)）..."
& ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i $listPath -vn -c:a aac -b:a 256k -ar 48000 $joined

if ($Mode -eq 'check') {
    $video = Join-Path $outDir "${Name}_IDチェック用.mp4"
    Write-Host 'IDチェック用の動画を作っています...'
    & ffmpeg -y -hide_banner -loglevel error -f lavfi -i color=c=black:s=1280x720:r=1 -i $joined `
        -c:v libx264 -tune stillimage -pix_fmt yuv420p -c:a copy -shortest $video
    Write-Host "できました：$video" -ForegroundColor Green
    Write-Host '→ YouTubeに「非公開」でアップして、著作権の欄を確認してください。'
}
else {
    $master = Join-Path $outDir "${Name}_3時間.m4a"
    Write-Host '3時間マスターを作っています...'
    # 最後は長いフェードアウトにしない（ライブのループで無音→急に鳴るのを避ける）
    & ffmpeg -y -hide_banner -loglevel error -stream_loop -1 -i $joined -t ($Hours * 3600) `
        -af 'afade=t=out:st=10797:d=3' -c:a aac -b:a 256k $master
    Write-Host "できました：$master" -ForegroundColor Green
    Write-Host '→ 動画編集ソフトに読み込んで、画像・テロップと合わせてください。'
}

Write-Host "曲の順番と開始時刻：$(Join-Path $outDir "${Name}_曲の順番.txt")"
