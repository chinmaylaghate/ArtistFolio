from render import *
from stories import STORIES, names
S = load_screens()
W,H = 1206,2622
OUTD = OUT+'/06_Screenshots_Portrait_1206x2622'; os.makedirs(OUTD, exist_ok=True)
SUBS = ['Original paintings and photos\nfrom independent artists.',
        'Search by style, medium or price.',
        'Use your camera to preview\nany piece in your room.',
        'Reach artists by email, Instagram,\nor their website.',
        'Publish your work in minutes.\nNo fees, no middleman.']
for st,nm,sub in zip(STORIES,names,SUBS):
    n,eb,title,_,keys,a1,a2 = st
    c = glow_bg((W,H),INK,[(0.75,0.12,0.45,a1,150),(0.1,0.95,0.45,a2,110),(0.9,0.8,0.3,a1,70)])
    d = ImageDraw.Draw(c)
    y = 150
    fe = font('semi',38)
    tw = d.textlength(eb.upper(),font=fe)+56
    w,h = pill(c,(round((W-tw)/2),y),eb.upper(),fe,(255,255,255),a1+(255,),28,16)
    d = ImageDraw.Draw(c)
    y += h+46
    ft = font('bold',112)
    for i,ln in enumerate(title.split('\n')):
        d.text((W//2,y+i*120),ln,font=ft,fill=(255,255,255),anchor='ma')
    y += 120*len(title.split('\n'))+30
    fs = font('reg',46)
    for i,ln in enumerate(sub.split('\n')):
        d.text((W//2,y+i*62),ln,font=fs,fill=(200,200,214),anchor='ma')
    y += 62*len(sub.split('\n'))+80
    ph = phone(S[keys[0]],880)
    shadow_paste(c,ph,((W-880)//2,y),alpha=190)
    c.convert('RGB').save(f'{OUTD}/{n}_{nm}_1206x2622.png',optimize=True)
