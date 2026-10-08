import json,re,os
src=open(os.path.join(os.path.dirname(__file__),'app_index.html')).read()
arr=src[src.index('const ITEMS=[')+12:src.index('\n];',src.index('const ITEMS=['))+2]
items=json.loads(arr)
cats=[]
for it in items:
    if it[0] not in cats: cats.append(it[0])
F=os.environ.get('FONT_DIR',os.path.abspath('fonts'))
import qrcode,qrcode.image.svg,io
URL='https://kokoro-block.netlify.app/'
_b=io.BytesIO();qrcode.make(URL,image_factory=qrcode.image.svg.SvgPathImage,box_size=10,border=1).save(_b)
QR=_b.getvalue().decode().split('?>',1)[-1]
def qrbox(msg): return f'<div class="qr"><div class="qri">{QR}</div><div><b>アプリでも選べます</b><p>{msg}</p><p class="url">{URL}</p></div></div>'
def iceberg(top,under,w=100):
    return f'''<div class="ice"><svg viewBox="0 0 360 400"><rect width="360" height="120" fill="#fff"/><rect y="120" width="360" height="280" fill="#e9e9e9"/>
<polygon points="132,120 160,80 174,58 192,74 206,96 228,120" fill="#fff" stroke="#333" stroke-width="2"/>
<polygon points="132,120 228,120 286,180 318,262 280,340 196,384 110,360 52,290 60,200" fill="#cfcfcf" stroke="#333" stroke-width="2"/>
<path d="M0 120 Q15 113 30 120 T60 120 T90 120 T120 120 T150 120 T180 120 T210 120 T240 120 T270 120 T300 120 T330 120 T360 120" fill="none" stroke="#333" stroke-width="2"/></svg>
<div class="it">{top}</div><div class="iu">{under}</div><div class="ws">水面</div></div>'''
P=[]
def page(h,cls=''): P.append(f'<section class="pg {cls}">{h}</section>')
# 1 title
page('''<div class="cover"><p class="small">宇宙銀行の</p><h1>心のブロックを<br>書きかえる手帳</h1><p class="sub">口ぐせの奥にある思いこみに気づいて<br>新しい言葉で1週間を過ごす</p><p class="small">日付なし・いつからでも始められます</p><p class="au">ヒュー</p></div>''')
page('<div class="center small">この手帳は、自分の気持ちに気づくためのものです。<br>結果や効果を約束するものではありません。<br><br>借金や支払いが苦しいとき、眠れない・気持ちが沈む日が続くときは、<br>ひとりで抱えずに専門の窓口へ相談してください。<br>お金・借金の相談：「法テラス」で検索<br>こころの相談：「まもろうよ こころ」で検索（厚生労働省）</div>')
page(f'''<h2>はじめに　氷山の一角</h2>
<p>「節約しなきゃ」「借金を返すぞ」「人生をやり直したい」。<br>ふだん心の中でつぶやいている口ぐせは、氷山の一角です。</p>
{iceberg('見えている口ぐせ<br><b>「節約しなきゃ」</b>','水面の下の思いこみ<br><b>いつも足りない</b>')}
<p>水面の下には、もっと大きな思いこみがかくれています。そこに気づいて、新しい言葉に書きかえる。この手帳は、それを1週間ずつ、くり返していくためのものです。</p>''')
page(f'''<h2>この手帳の使い方</h2>
<div class="step"><b>1　月のはじめ（月間ページ）</b><p>今月よく出る口ぐせを書き、巻末の「ことば集」から新しい言葉を選んで書きます。</p></div>
<div class="step"><b>2　毎日（週間ページ）</b><p>予定を書き、「今日ひとつだけ」ができたら□にチェック。ひとことメモも残します。</p></div>
<div class="step"><b>3　週末</b><p>今週うけとったものと、自分へのひとことを書きます。</p></div>
<div class="step"><b>4　月の終わり</b><p>新しい言葉を言えた日に○をつけ、今月の記録を書きます。</p></div>
<div class="note">書けない日があっても大丈夫。日付は入っていないので、空いたら次のページからまた始めましょう。</div>
{qrbox('スマホで読みとると「心のブロック診断」が開きます。口ぐせを選ぶと新しい言葉が出て、TODOをGoogleカレンダーに入れたり、LINEに送ったりもできます。')}
<div class="step"><b>新しい言葉の言い方</b><p>朝と寝る前に、声に出して3回。心がざわついても、言いなれるほど、なじんでいきます。</p></div>''')
page(f'''<h2>今年のわたしの口ぐせ</h2><p>思いつくままに書き出してみましょう。お金・仕事・家族・恋愛・からだ、なんでも。</p>
{''.join('<div class="ln"></div>' for _ in range(10))}
<h3>いちばん書きかえたい口ぐせ</h3>{iceberg('<span class="blank">「　　　　　　　　」</span>','<span class="blank">　　　　　　　　</span>')}''')
# weekly words rotation by category
order=[]
bycat={c:[i for i in items if i[0]==c] for c in cats}
k=0
while len(order)<60:
    c=cats[k%len(cats)];j=k//len(cats)
    if j<len(bycat[c]): order.append(bycat[c][j])
    k+=1
ln=lambda n:''.join('<div class="ln"></div>' for _ in range(n))
def day(d,sun=False): return f'<div class="day"><div class="dd{" sun" if sun else ""}">{d}<span>／</span></div><div class="dc"><div class="dl"></div><div class="dl"></div><div class="chk">□ 今日ひとつだけ　</div></div></div>'
w=0
for m in range(12):
    cal='<div class="cal">'+''.join(f'<div class="h{" sun" if d=="日" else ""}">{d}</div>' for d in "月火水木金土日")+''.join('<div></div>' for _ in range(35))+'</div>'
    page(f'''<div class="ttl"><span>　　　月</span><small>MONTHLY</small></div>
<div class="box"><b>今月の口ぐせ</b><div class="ln"></div></div><div class="box"><b>✦ 今月の新しい言葉</b><div class="ln"></div></div>{cal}''','L')
    page(f'''<div class="ttl"><span>今月の記録</span><small>月末に</small></div>
<div class="box"><b>新しい言葉を言えた日に○</b><div class="nums">{" ".join(str(i) for i in range(1,16))}<br>{" ".join(str(i) for i in range(16,32))}</div></div>
<div class="box"><b>今月うけとったもの</b>{ln(4)}</div><div class="box"><b>気づいたこと・メモ</b>{ln(7)}</div>''','R')
    for _ in range(5):
        it=order[w];w+=1
        page(f'''<div class="ttl"><span>　　月　　日〜</span><small>WEEKLY</small></div>
<div class="box"><b>✦ 今週の新しい言葉</b><div class="ln"></div><div class="hint">迷ったら：「{it[3]}」</div></div>
<div class="days">{day("月")}{day("火")}{day("水")}{day("木")}</div>''','L')
        page(f'''<div class="days">{day("金")}{day("土")}{day("日",True)}</div>
<div class="box"><b>今週うけとったもの</b>{ln(2)}</div><div class="box"><b>今週のわたしへ ひとこと</b>{ln(2)}</div>''','R')
# word collection
P.append(f'<section class="pg"><h2>ことば集　口ぐせ → 新しい言葉</h2><p>今の口ぐせに近いものを探して、右の言葉を月間・週間ページに書きましょう。</p>{qrbox("同じ120の言葉を、アプリでテーマ別に選べます。")}</section>')
rows=[]
for c in cats:
    rows.append(f'<div class="cat">{c}</div>')
    for it in bycat[c]:
        rows.append(f'<div class="wr"><div class="wv">「{it[1]}」<span>{it[2]}</span></div><div class="ww">{it[3]}</div></div>')
P.append('<section class="flow">'+''.join(rows)+'</section>')
for i in range(4):
    page(f'''<h2>わたしの氷山</h2>{iceberg('見えている口ぐせ<br><span class="blank">「　　　　　　　　」</span>','水面の下の思いこみ<br><span class="blank">　　　　　　　　</span>')}
<div class="box"><b>✦ 新しい言葉</b>{ln(2)}</div><div class="box"><b>今日ひとつだけ</b>{ln(1)}</div>''')
css=f'''
@font-face{{font-family:M;src:url(file://{F}/mincho.ttf)}}
@font-face{{font-family:G;src:url(file://{F}/goth.ttf)}}
@font-face{{font-family:G;font-weight:700;src:url(file://{F}/gothb.ttf)}}
@page{{size:148mm 210mm;margin:13mm 12mm 13mm 17mm}}
@page :left{{margin:13mm 17mm 13mm 12mm}}
@page :right{{margin:13mm 12mm 13mm 17mm}}
*{{box-sizing:border-box}}
body{{margin:0;font-family:G;font-size:9.5pt;color:#222;line-height:1.7}}
.pg{{height:184mm;break-after:page;display:flex;flex-direction:column;gap:3mm;overflow:hidden}}
.flow{{break-after:page}}
h1{{font-family:M;font-size:26pt;line-height:1.4;margin:0}}
h2{{font-family:M;font-size:15pt;margin:0;border-bottom:1.5pt solid #222;padding-bottom:1mm}}
h3{{font-family:M;font-size:11pt;margin:2mm 0 0}}
p{{margin:0}}
.cover{{display:flex;flex-direction:column;justify-content:center;gap:6mm;height:100%;text-align:center}}
.sub{{font-family:M;font-size:11pt}} .small{{font-size:9pt}} .au{{font-family:M;font-size:13pt;margin-top:20mm}}
.center{{margin:auto;text-align:center}}
.ice{{position:relative;width:88%;margin:0 auto;aspect-ratio:360/400}}
.ice svg{{position:absolute;inset:0;width:100%;height:100%}}
.it{{position:absolute;top:1%;left:0;right:0;text-align:center;font-size:8.5pt}}
.it b,.iu b{{font-size:11pt;font-family:M}}
.iu{{position:absolute;top:52%;left:20%;right:16%;text-align:center;font-size:8.5pt}}
.ws{{position:absolute;top:31%;right:2%;font-size:7pt}}
.blank{{display:inline-block;border-bottom:.6pt solid #222;min-width:40mm}}
.step b{{font-family:M;font-size:11pt}}
.note{{border:.6pt solid #888;padding:2mm 3mm;border-radius:2mm}}
.ln{{border-bottom:.5pt dashed #999;height:7mm}}
.ttl{{display:flex;justify-content:space-between;align-items:baseline;border-bottom:1.5pt solid #222;font-family:M;font-size:14pt}}
.ttl small{{font-family:G;font-size:7pt;letter-spacing:.2em}}
.box{{border:.6pt solid #888;border-radius:2mm;padding:1.5mm 3mm}}
.box b{{font-size:8pt;letter-spacing:.05em}}
.hint{{font-size:7.5pt;color:#555;margin-top:1mm}}
.nums{{font-size:9pt;letter-spacing:.12em;line-height:2}}
.cal{{display:grid;grid-template-columns:repeat(7,1fr);grid-template-rows:6mm repeat(5,1fr);flex:1;border-top:.6pt solid #888;border-left:.6pt solid #888}}
.cal div{{border-right:.6pt solid #888;border-bottom:.6pt solid #888}}
.cal .h{{text-align:center;font-size:8pt;font-weight:700;background:#eee}}
.days{{display:flex;flex-direction:column;flex:1;border-top:.6pt solid #888}}
.day{{flex:1;display:grid;grid-template-columns:12mm 1fr;border-bottom:.6pt solid #888}}
.dd{{border-right:.6pt solid #888;padding:1mm;font-family:M;font-size:12pt;display:flex;flex-direction:column}}
.dd span{{font-size:7pt;color:#777;margin-top:auto}}
.dc{{padding:1mm 2.5mm;display:flex;flex-direction:column}}
.dl{{border-bottom:.5pt dashed #bbb;flex:1}}
.chk{{font-size:8pt;padding-top:1mm;border-bottom:.5pt dashed #bbb;height:7mm}}
.cat{{font-family:M;font-size:12pt;border-bottom:1pt solid #222;margin:4mm 0 1mm;break-after:avoid}}
.wr{{display:grid;grid-template-columns:1fr 1fr;gap:3mm;padding:1.2mm 0;border-bottom:.4pt dotted #aaa;break-inside:avoid;font-size:8.5pt}}
\n.qr{{display:flex;gap:3mm;align-items:center;border:.6pt solid #888;border-radius:2mm;padding:2mm 3mm}}
.qri{{width:22mm;flex:none}} .qri svg{{width:22mm;height:22mm}} .qr b{{font-size:9pt}} .qr p{{font-size:8pt}} .url{{font-size:7pt;color:#555}}
.wv span{{display:block;font-size:7pt;color:#666}}
.ww{{font-family:M;font-size:9.5pt}}
'''
open(os.environ.get('OUT','techo.html'),'w').write(f'<!doctype html><meta charset="utf-8"><style>{css}</style>'+''.join(P))
print(len(P),'blocks')
