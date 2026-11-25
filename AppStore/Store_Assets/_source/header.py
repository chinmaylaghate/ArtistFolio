from render import *
S = load_screens()
os.makedirs(OUT+'/01_Header', exist_ok=True)
os.makedirs(OUT+'/02_Search_Results', exist_ok=True)

def header():
    W,H=5244,2950
    c=glow_bg((W,H),INK,[(0.72,0.30,0.30,ULTRA,150),(0.92,0.85,0.22,WARM,120),(0.10,0.95,0.20,ULTRA,70)])
    # phones
    side=1000; mid=1090
    p1=phone(S['home'],side); p3=phone(S['artist'],side); p2=phone(S['detail'],mid)
    shadow_paste(c,p1,(2470,(H-p1.height)//2+190),alpha=170)
    shadow_paste(c,p3,(4060,(H-p3.height)//2+190),alpha=170)
    shadow_paste(c,p2,(3240,(H-p2.height)//2),alpha=200)
    d=ImageDraw.Draw(c)
    x=300
    wm=wordmark(300,(255,255,255)); c.alpha_composite(wm,(x,520))
    y=520+300+200
    y=text(d,(x,y),'Where art finds\nits home',font('bold',250),(255,255,255),spacing=1.08)
    y+=70
    y=text(d,(x,y),'Discover and collect original art\nfrom independent artists.',font('reg',104),(196,196,210),spacing=1.35)
    y+=110
    f=font('med',72); px=x
    for lab,dot in [('See art on your wall',ULTRA_L),('Contact artists directly',WARM),('Artists keep 100%',(255,255,255))]:
        w,h=pill(c,(px,y),lab,f,(255,255,255),(255,255,255,26),56,38,dot=dot)
        px+=w+36
        if lab.startswith('Contact'): px=x; y+=h+36
    c.convert('RGB').save(OUT+'/01_Header/ArtistFolio_Header_5244x2950.png',optimize=True)

def search_results():
    W,H=5244,2950
    c=glow_bg((W,H),PAPER,[(0.15,0.15,0.25,(214,208,255),255),(0.85,0.9,0.25,(255,214,196),255)])
    d=ImageDraw.Draw(c)
    # top brand row
    ic=app_icon(300)
    shadow_paste(c,ic,(300,230),blur=30,alpha=60,offset=12)
    text(d,(660,262),'ArtistFolio',font('bold',150),INK)
    text(d,(664,440),'Discover and collect original art',font('reg',86),(90,90,104))
    # 3 panels
    panels=[('Discover','Original art from\nindependent artists','search',ULTRA),
            ('See it on your wall','Preview any piece\nin your own space','wall',WARM),
            ('Contact the artist','Ask about size,\nshipping and more','artist',ULTRA)]
    pw=1500; gap=(W-600-3*pw)//2; top=700
    for i,(t,s,key,acc) in enumerate(panels):
        px=300+i*(pw+gap)
        card=Image.new('RGBA',(pw,H-top-170),(0,0,0,0))
        cd=ImageDraw.Draw(card)
        cd.rounded_rectangle((0,0,pw-1,card.height-1),110,fill=(255,255,255,235))
        shadow_paste(c,card,(px,top),blur=60,alpha=40,offset=20)
        d=ImageDraw.Draw(c)
        d.ellipse((px+110,top+138,px+150,top+178),fill=acc)
        text(d,(px+180,top+110),t,font('bold',112),INK)
        text(d,(px+110,top+270),s,font('reg',78),(96,96,110),spacing=1.3)
        ph=phone(S[key],980)
        # clip phone to card bottom
        y0=top+560
        visible=card.height-(y0-top)
        ph=ph.crop((0,0,ph.width,visible))
        m=Image.new('L',ph.size,255)
        # fade nothing; mask with card rounded bottom
        cm=rr_mask((pw,card.height),110).crop((260,y0-top,260+ph.width,y0-top+visible))
        a=ImageChops.multiply(ph.split()[3],cm); ph.putalpha(a)
        c.alpha_composite(ph,(px+260,y0))
    c.convert('RGB').save(OUT+'/02_Search_Results/ArtistFolio_SearchResults_5244x2950.png',optimize=True)

header()
