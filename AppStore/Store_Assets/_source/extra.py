from render import *
S = load_screens()

def header_logo():
    W,H=3840,1646
    c=glow_bg((W,H),INK,[(0.5,0.45,0.30,ULTRA,140),(0.85,0.95,0.22,WARM,110),(0.12,0.9,0.20,ULTRA,70)])
    wm=wordmark(560,(255,255,255))
    c.alpha_composite(wm,((W-wm.width)//2,(H-wm.height)//2))
    c.convert('RGB').save(OUT+'/01_Header/ArtistFolio_Header_LogoOnly_3840x1646.png',optimize=True)

def search_small():
    W,H=1920,1280
    c=glow_bg((W,H),PAPER,[(0.15,0.15,0.25,(214,208,255),255),(0.85,0.9,0.25,(255,214,196),255)])
    d=ImageDraw.Draw(c)
    m=96
    ic=app_icon(132); shadow_paste(c,ic,(m,80),blur=14,alpha=60,offset=6)
    text(d,(m+164,90),'ArtistFolio',font('bold',64),INK)
    text(d,(m+166,168),'Discover and collect original art',font('reg',36),(90,90,104))
    panels=[('Discover','Original art from\nindependent artists','search',ULTRA),
            ('See it on your wall','Preview any piece\nin your own space','wall',WARM),
            ('Contact the artist','Ask about size,\nshipping and more','artist',ULTRA)]
    gap=40; pw=(W-2*m-2*gap)//3; top=290; ch=H-top-70; r=44
    for i,(t,s,key,acc) in enumerate(panels):
        px=m+i*(pw+gap)
        card=Image.new('RGBA',(pw,ch),(0,0,0,0))
        ImageDraw.Draw(card).rounded_rectangle((0,0,pw-1,ch-1),r,fill=(255,255,255,235))
        shadow_paste(c,card,(px,top),blur=24,alpha=40,offset=8)
        d=ImageDraw.Draw(c)
        d.ellipse((px+40,top+56,px+56,top+72),fill=acc)
        text(d,(px+70,top+40),t,font('bold',44),INK)
        text(d,(px+40,top+104),s,font('reg',31),(96,96,110),spacing=1.3)
        phw=round(pw*0.66); ph=phone(S[key],phw)
        y0=top+225; vis=ch-(y0-top); ox=(pw-phw)//2
        ph=ph.crop((0,0,phw,vis))
        cm=rr_mask((pw,ch),r).crop((ox,y0-top,ox+phw,y0-top+vis))
        ph.putalpha(ImageChops.multiply(ph.split()[3],cm))
        c.alpha_composite(ph,(px+ox,y0))
    c.convert('RGB').save(OUT+'/02_Search_Results/ArtistFolio_SearchResults_1920x1280.png',optimize=True)

header_logo(); search_small()
