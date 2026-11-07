"""Preview: re-outline frames (edge pixels -> the standing pose's outline colour).

    python3 -I tools/pixellab/preview/outline_preview.py <export.zip> <out.png> <take>:<direction> [...]
"""
import sys,zipfile,io,collections
from PIL import Image, ImageDraw, ImageFont
zp,out=sys.argv[1],sys.argv[2]; rows=sys.argv[3:]
font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",15)
z=zipfile.ZipFile(zp); N=z.namelist()
def edge(im):
    w,h=im.size; p=im.load(); e=[]
    for y in range(h):
        for x in range(w):
            if p[x,y][3]<128: continue
            if any(not(0<=x+dx<w and 0<=y+dy<h) or p[x+dx,y+dy][3]<128 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))): e.append((x,y))
    return e
def outline_colour(st):
    p=st.load(); c=collections.Counter(p[x,y][:3] for x,y in edge(st)); return c.most_common(1)[0][0]
def fix(im,col):
    im=im.copy(); p=im.load()
    for x,y in edge(im):
        r,g,b,a=p[x,y]
        if 0.3*r+0.59*g+0.11*b>=40: p[x,y]=(col[0],col[1],col[2],255)
    return im
k=4; C=80*k; L=[]
for spec in rows:
    folder,d=spec.split(':')
    st=Image.open(io.BytesIO(z.read([n for n in N if n.endswith(f'Idle/rotations/{d}.png')][0]))).convert('RGBA'); col=outline_colour(st)
    fr=[Image.open(io.BytesIO(z.read(n))).convert('RGBA') for n in sorted(x for x in N if f"/animations/{folder}/{d}/" in x and x.endswith('.png'))]
    L.append((f"{folder[:18]} {d[:7]} BEFORE",st,fr)); L.append(("AFTER (re-outlined)",st,[fix(i,col) for i in fr]))
    print(spec,'outline colour',col)
def put(o,im,x,y):
    bb=im.getbbox(); im=im.crop(bb).resize(((bb[2]-bb[0])*k,(bb[3]-bb[1])*k),Image.NEAREST)
    o.alpha_composite(im,(x+(C-im.width)//2,y+C-im.height))
n=max(len(f) for _,_,f in L)
o=Image.new('RGBA',(330+(n+1)*C,len(L)*(C+12)),(16,13,28,255)); d=ImageDraw.Draw(o)
for i,(lab,st,fr) in enumerate(L):
    y=i*(C+12); d.text((6,y+C//2),lab,fill=(90,255,240) if 'AFTER' in lab else (230,230,240),font=font)
    o.alpha_composite(Image.new('RGBA',(C,C),(40,34,70,255)),(330,y)); put(o,st,330,y)
    for j,im in enumerate(fr): put(o,im,330+(j+1)*C,y)
o.save(out); print(o.size)
