# 金色のキラキラが降る背景動画（つなぎ目なしでループ）を作る
# 使い方: python gold_particles.py [秒数] [出力ファイル名]
import sys, subprocess, numpy as np
W, H, FPS = 1920, 1080, 25
SEC = int(sys.argv[1]) if len(sys.argv) > 1 else 20
OUT = sys.argv[2] if len(sys.argv) > 2 else "gold_particles.mp4"
N = SEC * FPS
rng = np.random.default_rng(8)

def sprite(r, soft):
    s = int(r * 3) + 2
    y, x = np.mgrid[-s:s + 1, -s:s + 1]
    d = np.sqrt(x * x + y * y) / r
    a = np.clip(1 - d, 0, 1) ** soft if soft else np.exp(-d * d * 2)
    return a.astype(np.float32)

PAL = np.array([[1.0, .78, .30], [1.0, .62, .18], [1.0, .90, .55], [1.0, .97, .85],
                [.30, .45, 1.0], [.35, .85, .95]], np.float32)
PW = np.array([.32, .24, .2, .14, .06, .04])

def make(n, rmin, rmax, soft, bright, laps):
    p = []
    for _ in range(n):
        r = rng.uniform(rmin, rmax)
        p.append(dict(spr=sprite(r, soft), x=rng.uniform(0, W), y=rng.uniform(0, H),
                      lap=rng.choice(laps), col=PAL[rng.choice(6, p=PW)] * bright * rng.uniform(.5, 1),
                      tw=rng.integers(1, 4), ph=rng.uniform(0, 6.283), sway=rng.uniform(0, 18)))
    return p

layers = (make(4500, 1.0, 2.6, 0, 1.6, [1, 2]) +          # 細かいキラキラ
          make(700, 5, 14, 1.5, .9, [1]) +            # ぼけた光の玉
          make(60, 20, 38, 2, .35, [1]))               # 大きなぼけ
img = np.zeros((H, W, 3), np.float32)
ff = subprocess.Popen(["ffmpeg", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                       "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
                       "-pix_fmt", "yuv420p", OUT], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
for f in range(N):
    t = f / N
    img[:] = 0
    # 上のほうをほんのり金色に
    img[:H // 3] += (np.linspace(.35, 0, H // 3)[:, None, None] * PAL[0])
    for q in layers:
        s = q["spr"]; h = s.shape[0] // 2
        y = int((q["y"] + t * q["lap"] * (H + 2 * h)) % (H + 2 * h)) - h
        x = int(q["x"] + q["sway"] * np.sin(6.283 * t + q["ph"])) % W
        k = (.55 + .45 * np.sin(6.283 * q["tw"] * t + q["ph"])) * (2.2 - 1.7 * min(max(y, 0) / H, 1))  # 上ほど明るく
        y0, y1, x0, x1 = max(y - h, 0), min(y + h + 1, H), max(x - h, 0), min(x + h + 1, W)
        if y0 >= y1 or x0 >= x1: continue
        img[y0:y1, x0:x1] += s[y0 - y + h:y1 - y + h, x0 - x + h:x1 - x + h, None] * q["col"] * k
    ff.stdin.write((np.clip(img, 0, 1) * 255).astype(np.uint8).tobytes())
ff.stdin.close(); ff.wait()
print("できました:", OUT)
