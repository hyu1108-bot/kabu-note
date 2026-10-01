# 3時間33分33秒にループする手順（PowerShell＋ffmpeg）

2026-10-01（金曜分）で成功した手順。書き出しは1本だけ（テロップ入り）。

1. Filmoraでテロップ入りの30〜40分版を書き出し、デスクトップに置く
2. テロップが消える時刻をメモ（例：1:33）
3. PowerShellを開いて、下を1行ずつ（または全部）貼り付け。`00:01:33` と ファイル名の一部（`1001金曜日用`）だけ毎回変える

```powershell
cd ([Environment]::GetFolderPath("Desktop"))
Copy-Item "*1001金曜日用.mp4" kin.mp4
$lines = @("file 'kin.mp4'") + (1..8 | ForEach-Object { "file 'kin.mp4'"; "inpoint 00:01:33" })
[IO.File]::WriteAllLines("$PWD\list.txt", $lines)
ffmpeg -f concat -safe 0 -i list.txt -t 03:33:33 -c copy kin_3h.mp4
```

4. できた kin_3h.mp4 の名前を変える（例：最新1002金曜日用_3時間33分33秒）。kin.mp4 と list.txt は削除してよい

## つまずいたところ
- PowerShellが `C:\WINDOWS\system32` で開くと「パスが存在しない」「アクセス拒否」になる → 1行目の cd でデスクトップに移動する
- 出力ファイル名に全角文字を使うと、貼り付け時に別のコマンドがくっついて失敗しやすい → 出力は英数字（kin_3h.mp4）にして、あとで名前を変える
- 「Non-monotonic DTS」の黄色い警告がつなぎ目ごとに出るが、完成はする。つなぎ目（2周目の始まりなど）を少し再生して確認する
- かかる時間は約40秒（再エンコードしないため）
