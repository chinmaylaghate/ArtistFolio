import subprocess, sys, os, numpy as np
from render import *
S = load_screens()
W,H,FPS = 886,1920,30
OUTD = OUT+'/05_App_Previews_Video'; os.makedirs(OUTD, exist_ok=True)

def ease(x): return x*x*(3-2*x)

def prep(key):
    im = S[key]
    sc = im.resize((W, round(W*im.height/im.width)), Image.LANCZOS)
    return sc.crop((0, round(sc.height*0.045), W, sc.height))  # drop status bar

def caption_layer(txt):
    lay = Image.new('RGBA',(W,H),(0,0,0,0))
    g = np.zeros((H,W,4),np.uint8); g[...,:3]=INK
    BAND=430
    a = np.where(np.arange(H)<BAND,255,np.clip(1-(np.arange(H)-BAND)/40,0,1)*255)
    g[...,3]=a[:,None].astype(np.uint8)
    lay = Image.fromarray(g,'RGBA')
    d = ImageDraw.Draw(lay)
    text(d,(64,120),txt,font('bold',84),(255,255,255),spacing=1.08)
    return lay

def endcard(tag):
    c = glow_bg((W,H),INK,[(0.5,0.4,0.5,ULTRA,150),(0.9,1.0,0.4,WARM,110)])
    wm = wordmark(230,(255,255,255)); c.alpha_composite(wm,((W-wm.width)//2,760))
    d = ImageDraw.Draw(c)
    d.text((W//2,1080),tag,font=font('reg',44),fill=(205,205,218),anchor='ma')
    return c.convert('RGB')

def frame_of(src, t, dur, pan):
    BAND=430
    vis = H-BAND
    p = ease(min(max((t-0.8)/(dur-1.6),0),1))
    hidden = max(src.height-vis,0)
    y = pan*hidden*p
    out = Image.new('RGB',(W,H),INK)
    out.paste(src.resize((W,vis), Image.BILINEAR, box=(0,y,W,y+vis)),(0,BAND))
    return out


def render(name, scenes, tag):
    """scenes: list of (key, caption, seconds, pan)"""
    XF = 0.5; END = 2.5
    srcs = [(prep(k), caption_layer(c), d, pan) for k,c,d,pan in scenes]
    ec = endcard(tag)
    total = sum(s[2] for s in srcs) + END
    tmp = f'{OUTD}/{name}.tmp.mp4'
    cmd = ['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-',
           '-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=44100',
           '-shortest','-c:v','libx264','-profile:v','high','-level','4.0','-pix_fmt','yuv420p','-crf','18','-preset','veryfast',
           '-c:a','aac','-b:a','128k','-movflags','+faststart',tmp]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    starts = np.cumsum([0]+[s[2] for s in srcs])
    n = round(total*FPS)
    def scene_img(i,t):
        src,cap,d,pan = srcs[i]
        f = frame_of(src, min(max(t,0),d), d, pan).convert('RGBA')
        f.alpha_composite(cap); return f.convert('RGB')
    for fi in range(n):
        t = fi/FPS
        i = int(np.searchsorted(starts, t, side='right')-1)
        if i >= len(srcs):
            img = ec
            lt = t-starts[-1]
            if lt < XF:  # crossfade from last scene
                img = Image.blend(scene_img(len(srcs)-1, srcs[-1][2]), ec, ease(lt/XF))
        else:
            lt = t-starts[i]
            img = scene_img(i, lt)
            if i>0 and lt < XF:
                img = Image.blend(scene_img(i-1, srcs[i-1][2]+lt), img, ease(lt/XF))
        if fi < 8: img = Image.blend(Image.new('RGB',(W,H),INK), img, fi/8)
        pr.stdin.write(img.tobytes())
    pr.stdin.close(); assert pr.wait()==0
    os.replace(tmp, f'{OUTD}/{name}.mp4')

VIDEOS = {
 '01_discover-original-art_886x1920': ([
    ('home','Where art\nfinds its home',6,1.0),
    ('search','Browse by style,\nmedium and price',6,1.0),
    ('detail','Every detail\nin one place',6,1.0)], 'Discover and collect original art'),
 '03_for-artists_886x1920': ([
    ('studio','Share your art\nin minutes',6,0.0),
    ('profile','Build your\nartist profile',6,0.6),
    ('home_raw','Get found by\ncollectors',6,1.0)], 'Artists keep 100% of every sale'),
}
if __name__=='__main__':
    which = sys.argv[1:] or list(VIDEOS)
    for k in which:
        sc,tag = VIDEOS[k]; render(k, sc, tag); print('done',k)
