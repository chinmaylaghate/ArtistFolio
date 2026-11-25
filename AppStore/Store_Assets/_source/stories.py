from render import *
S = load_screens()
STORIES = [
 ('01','Discover','Where art\nfinds its home','Original paintings and photos\nfrom independent artists.',['home','detail'],ULTRA,WARM),
 ('02','Browse','Find art\nyou love','Search by style, medium\nor price.',['search','home_raw'],ULTRA,(30,140,200)),
 ('03','AR Preview','See it on\nyour wall','Use your camera to preview\nany piece in your room.',['wall','detail'],WARM,ULTRA),
 ('04','Connect','Follow and\ncontact artists','Reach artists by email,\nInstagram, or their website.',['artist','home_raw'],(30,140,200),ULTRA),
 ('05','For Artists','Share your art.\nKeep 100%.','Publish your work in minutes.\nNo fees, no middleman.',['studio','profile'],ULTRA,WARM),
]

def story(W,H,dark,st,folder,fname,scale):
    n,eb,title,sub,keys,a1,a2=st
    if dark:
        c=glow_bg((W,H),INK,[(0.78,0.25,0.32,a1,150),(0.98,0.95,0.25,a2,110),(0.05,1.0,0.18,a1,60)])
        tc=(255,255,255); sc=(196,196,210)
    else:
        lt=lambda col:tuple(int(v*0.42+255*0.58) for v in col)
        c=glow_bg((W,H),PAPER,[(0.75,0.25,0.35,lt(a1),255),(0.98,0.95,0.28,lt(a2),255)])
        tc=INK; sc=(84,84,98)
    d=ImageDraw.Draw(c)
    x=round(W*0.065)
    # phones on right
    pw=round(H*(0.48 if dark else 0.47))
    pA=phone(S[keys[0]],pw); pB=phone(S[keys[1]],pw)
    topA=round(H*0.085)
    xb=W-round(W*0.06)-pw; xa=xb-pw-round(W*0.025)
    shadow_paste(c,pB,(xb,topA+round(H*0.13)),alpha=150 if dark else 70)
    shadow_paste(c,pA,(xa,topA),alpha=190 if dark else 90)
    # text block, vertically centered
    fe=font('semi',round(36*scale)); ft=font('bold',round(96*scale)); fs=font('reg',round(40*scale))
    block=round(36*scale)*1+round(40*scale)+round(96*scale)*1.06*2+round(44*scale)+round(40*scale)*1.35*2
    y=round((H-block)/2)
    # eyebrow pill
    w,h=pill(c,(x,y),eb.upper(),fe,(255,255,255),a1+(255,),round(26*scale),round(14*scale))
    d=ImageDraw.Draw(c)
    y+=h+round(40*scale)
    y=text(d,(x,y),title,ft,tc,spacing=1.06)
    y+=round(36*scale)
    text(d,(x,y),sub,fs,sc,spacing=1.35)
    # small wordmark bottom left
    wm=wordmark(round(54*scale),tc)
    c.alpha_composite(wm,(x,H-round(H*0.07)-wm.height))
    os.makedirs(OUT+'/'+folder,exist_ok=True)
    c.convert('RGB').save(OUT+'/'+folder+'/'+fname,optimize=True)

names=['where-art-finds-its-home','find-art-you-love','see-it-on-your-wall','follow-and-contact-artists','share-your-art']
if __name__=="__main__":
  for st,nm in zip(STORIES,names):
      story(1920,886,True,st,'03_App_Previews',f'{st[0]}_{nm}_1920x886.png',1.0)
      story(2556,1179,False,st,'04_Screenshots',f'{st[0]}_{nm}_2556x1179.png',1.33)
