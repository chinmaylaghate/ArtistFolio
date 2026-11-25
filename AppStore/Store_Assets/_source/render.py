import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps, ImageChops

SRC = '/mnt/user-data/uploads/ArtistFolio_ClaudeCode/AppStore/screenshots'
LOGO = '/mnt/user-data/uploads/ArtistFolio_ClaudeCode/AppStore/ArtistFolio_Logo_icon.png'
OUT = '/home/claude/af/out'
F = '/usr/share/fonts/opentype/inter/'

INK = (14, 14, 19)
ULTRA = (59, 43, 240)
ULTRA_L = (139, 127, 255)
WARM = (226, 78, 32)
PAPER = (246, 244, 239)


def font(w, size):
    return ImageFont.truetype(F + {'black': 'InterDisplay-Black.otf', 'bold': 'InterDisplay-Bold.otf',
                                   'semi': 'InterDisplay-SemiBold.otf', 'med': 'Inter-Medium.otf',
                                   'reg': 'Inter-Regular.otf', 'light': 'InterDisplay-Light.otf'}[w], size)


# ---------- screens ----------
def crop_comp(name, top):
    im = Image.open(os.path.join(SRC, name)).convert('RGB')
    return im.crop((172, top + 2, 1118, top + 2 + 2061))

def load_screens():
    s = {}
    s['home'] = crop_comp('01-where-art-finds-its-home.png', 510)
    s['search'] = crop_comp('02-discover-original-art.png', 454)
    s['detail'] = crop_comp('03-your-personal-art-feed.png', 454)
    s['artist'] = crop_comp('04-follow-and-contact-artists.png', 454)
    s['wall'] = crop_comp('05-contact-the-artist.png', 454)
    s['studio'] = Image.open(os.path.join(SRC, '04_studio.png')).convert('RGB')
    s['profile'] = Image.open(os.path.join(SRC, '05_profile.png')).convert('RGB')
    s['home_raw'] = Image.open(os.path.join(SRC, '01_home.png')).convert('RGB')
    return s


def rr_mask(size, r, ss=4):
    w, h = size
    m = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), r * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def phone(screen, width):
    """Return RGBA phone mockup (bezel + screen) of given outer width."""
    bez = round(width * 0.032)
    sw = width - 2 * bez
    sh = round(sw * screen.height / screen.width)
    h = sh + 2 * bez
    outer_r = round(width * 0.155)
    inner_r = outer_r - bez
    ph = Image.new('RGBA', (width, h), (0, 0, 0, 0))
    body = Image.new('RGBA', (width, h), (22, 22, 26, 255))
    ph.paste(body, (0, 0), rr_mask((width, h), outer_r))
    # thin metal edge highlight
    edge = Image.new('RGBA', (width, h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, width - 2, h - 2), outer_r, outline=(92, 92, 104, 255), width=max(2, width // 260))
    ph = Image.alpha_composite(ph, edge)
    scr = screen.resize((sw, sh), Image.LANCZOS).convert('RGBA')
    ph.paste(scr, (bez, bez), rr_mask((sw, sh), inner_r))
    return ph


def shadow_paste(canvas, img, xy, blur=None, alpha=150, offset=None):
    w, h = img.size
    blur = blur or max(8, w // 14)
    offset = offset if offset is not None else w // 28
    pad = blur * 3
    sh = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    a = img.split()[3].point(lambda v: v * alpha // 255)
    sh.paste(Image.new('RGBA', (w, h), (0, 0, 0, 255)), (pad, pad), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (xy[0] - pad, xy[1] - pad + offset))
    canvas.alpha_composite(img, xy)


def glow_bg(size, base, blobs):
    """blobs: list of (cx, cy, radius, color, alpha) in relative units."""
    W, H = size
    small = (max(64, W // 8), max(32, H // 8))
    bg = Image.new('RGBA', small, base + (255,))
    for cx, cy, r, col, al in blobs:
        layer = Image.new('RGBA', small, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        rr = r * small[0]
        x, y = cx * small[0], cy * small[1]
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col + (al,))
        layer = layer.filter(ImageFilter.GaussianBlur(rr * 0.6))
        bg = Image.alpha_composite(bg, layer)
    return bg.resize(size, Image.BICUBIC)


def wordmark(height, color):
    lg = Image.open(LOGO).convert('L')
    inv = ImageOps.invert(lg)
    box = inv.point(lambda v: 255 if v > 30 else 0).getbbox()
    inv = inv.crop(box)
    w = round(inv.width * height / inv.height)
    a = inv.resize((w, height), Image.LANCZOS)
    out = Image.new('RGBA', (w, height), color + (0,))
    out.putalpha(a)
    return out


def app_icon(size):
    ic = Image.open(LOGO).convert('RGBA').resize((size, size), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(ic, (0, 0), rr_mask((size, size), round(size * 0.2237)))
    return out


def text(d, xy, s, f, fill, spacing=1.12, anchor='la', align='left'):
    lines = s.split('\n')
    x, y = xy
    lh = round(f.size * spacing)
    for i, ln in enumerate(lines):
        d.text((x, y + i * lh), ln, font=f, fill=fill, anchor=anchor)
    return y + len(lines) * lh


def pill(canvas, xy, label, f, fg, bg, padx, pady, dot=None):
    d = ImageDraw.Draw(canvas)
    tw = d.textlength(label, font=f)
    asc, desc = f.getmetrics()
    th = asc
    dotw = 0
    if dot:
        dotw = round(th * 0.55) + round(padx * 0.5)
    w = round(tw + 2 * padx + dotw)
    h = round(th + 2 * pady)
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((xy[0], xy[1], xy[0] + w, xy[1] + h), h // 2, fill=bg)
    if dot:
        r = round(th * 0.275)
        cx = xy[0] + padx + r
        cy = xy[1] + h // 2
        ld.ellipse((cx - r, cy - r, cx + r, cy + r), fill=dot)
    canvas.alpha_composite(layer)
    d = ImageDraw.Draw(canvas)
    d.text((xy[0] + padx + dotw, xy[1] + h // 2), label, font=f, fill=fg, anchor='lm')
    return w, h
