#!/usr/bin/env python3
"""Pack named 3-up SE/NW sheets into iso_chars masters."""
from PIL import Image, ImageDraw
import numpy as np
from collections import deque
from scipy import ndimage
import os, sys

IMAGINE = "/home/workdir/artifacts/imagine_images"
OUT = "/home/workdir/artifacts/iso_chars"
os.makedirs(os.path.join(OUT,"masters256"), exist_ok=True)
os.makedirs(os.path.join(OUT,"cells128x192"), exist_ok=True)

def load(iid):
    for ext in (".jpg",".png"):
        p=os.path.join(IMAGINE,iid+ext)
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    raise FileNotFoundError(iid)

def is_bg(r,g,b):
    r=r.astype(int); g=g.astype(int); b=b.astype(int)
    hot = (r>=190) & (g<=55) & (b>=80) & ((r-g)>=120)
    dark = (np.maximum(np.maximum(r,g),b) <= 12)
    return hot | dark

def key_flood(arr):
    h,w=arr.shape[:2]
    seed=is_bg(arr[:,:,0],arr[:,:,1],arr[:,:,2])
    vis=np.zeros((h,w),dtype=bool)
    q=deque()
    for x in range(w):
        q.append((x,0)); q.append((x,h-1))
    for y in range(h):
        q.append((0,y)); q.append((w-1,y))
    bg=np.zeros((h,w),dtype=bool)
    while q:
        x,y=q.popleft()
        if x<0 or y<0 or x>=w or y>=h or vis[y,x]: continue
        vis[y,x]=True
        if not seed[y,x]: continue
        bg[y,x]=True
        q.append((x+1,y)); q.append((x-1,y)); q.append((x,y+1)); q.append((x,y-1))
    alpha=~bg
    alpha=ndimage.binary_closing(alpha, structure=np.ones((3,3)))
    arr[:,:,3]=alpha.astype(np.uint8)*255
    return arr

def extract_n(im, n=3):
    arr=np.array(im.convert("RGBA"))
    arr=key_flood(arr)
    lab, nlab = ndimage.label(arr[:,:,3]>0)
    boxes=[]
    for i in range(1,nlab+1):
        ys,xs=np.where(lab==i)
        if xs.size<400: continue
        boxes.append((int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1, int(xs.size), i))
    boxes=sorted(boxes, key=lambda b: b[4], reverse=True)[:n]
    boxes=sorted(boxes, key=lambda b: b[0])
    cells=[]
    for x0,y0,x1,y1,area,i in boxes:
        pad=6
        xa,ya=max(0,x0-pad),max(0,y0-pad)
        xb,yb=min(arr.shape[1],x1+pad),min(arr.shape[0],y1+pad)
        cell=arr[ya:yb,xa:xb].copy()
        sublab=lab[ya:yb,xa:xb]
        mask=(sublab==i) | (ndimage.binary_dilation(sublab==i, iterations=2) & (cell[:,:,3]>0))
        cell[:,:,3]=np.where(mask, cell[:,:,3], 0)
        cells.append(Image.fromarray(cell))
    return cells

def fit(im, W, H, baseline=4):
    im=im.convert("RGBA")
    bbox=im.getbbox()
    if not bbox:
        return Image.new("RGBA",(W,H),(0,0,0,0))
    crop=im.crop(bbox)
    cw,ch=crop.size
    scale=min((W-4)/cw, (H-baseline-2)/ch)
    nw=max(1,int(round(cw*scale))); nh=max(1,int(round(ch*scale)))
    crop=crop.resize((nw,nh), Image.NEAREST)
    canvas=Image.new("RGBA",(W,H),(0,0,0,0))
    canvas.paste(crop, ((W-nw)//2, H-nh-baseline), crop)
    return canvas

def pack_wave(se_id, nw_id, names, nums):
    se_cells=extract_n(load(se_id), len(names))
    nw_cells=extract_n(load(nw_id), len(names))
    print("pack", se_id, nw_id, names, "se", len(se_cells), "nw", len(nw_cells))
    for name,num,se,nw in zip(names,nums,se_cells,nw_cells):
        for facing,src in (("se",se),("nw",nw)):
            m256=fit(src,256,256,4)
            c128=fit(src,128,192,3)
            m256.save(os.path.join(OUT,"masters256",f"BD_iso256_{num:02d}_{name}_{facing}.png"))
            c128.save(os.path.join(OUT,"cells128x192",f"BD_iso128x192_{num:02d}_{name}_{facing}.png"))
            mag=Image.new("RGB",(256,256),(255,0,255))
            mag.paste(m256.convert("RGB"), mask=m256.split()[-1])
            mag.save(os.path.join(OUT,"masters256",f"BD_iso256_{num:02d}_{name}_{facing}_MAGENTA.png"))
        pair=Image.new("RGBA",(512,256),(0,0,0,0))
        s=fit(se,256,256); n=fit(nw,256,256)
        pair.paste(s,(0,0),s); pair.paste(n,(256,0),n)
        pair.save(os.path.join(OUT,f"BD_iso256_{num:02d}_{name}_SE_NW.png"))

if __name__ == "__main__":
    waves = eval(sys.argv[1]) if len(sys.argv)>1 else []
    for w in waves:
        pack_wave(*w)
