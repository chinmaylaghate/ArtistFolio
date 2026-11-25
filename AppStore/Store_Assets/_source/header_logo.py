import numpy as np
from PIL import Image
from render import wordmark, INK, ULTRA, WARM
W,H=3840,1646
y,x=np.mgrid[0:H,0:W].astype(np.float32)
img=np.zeros((H,W,3),np.float32)+np.array(INK,np.float32)
def blob(cx,cy,r,col,a):
    global img
    d=np.sqrt((x-cx*W)**2+(y-cy*H)**2)/(r*W)
    w=(np.exp(-d**2*2.2)*a)[...,None]
    img=img*(1-w)+np.array(col,np.float32)*w
blob(0.5,0.45,0.38,ULTRA,0.55); blob(0.88,0.98,0.28,WARM,0.45); blob(0.1,0.95,0.22,ULTRA,0.25)
img+=np.random.default_rng(2).normal(0,1.0,(H,W))[...,None]
bg=Image.fromarray(np.clip(img,0,255).astype('uint8')).convert('RGBA')
wm=wordmark(560,(255,255,255))
bg.alpha_composite(wm,((W-wm.width)//2,(H-wm.height)//2))
p='out/01_Header/ArtistFolio_Header_LogoOnly_3840x1646.png'
bg.convert('RGB').save(p,optimize=True)
im=Image.open(p); print(im.size)
im.resize((960,411)).save('p_hl.png'); im.crop((1300,400,2300,1000)).resize((800,480)).save('p_hl_zoom.png')
