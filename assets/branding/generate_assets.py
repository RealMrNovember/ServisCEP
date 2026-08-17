"""
ServisCEP marka varliklarini (PNG ikonlar + favicon.ico) uretir.

v2 - daha detayli/rafine versiyon: bezelli telefon govdesi, ekran
detaylari (hoparlor + home bar), aksan renkli ic-disa dogru soluklasan
senkron dalgalari, arka planda yumusak radial highlight (derinlik).

Kullanim:
    python generate_assets.py
"""

from PIL import Image, ImageDraw, ImageFilter

BG = "#131316"
BEZEL = "#3F3F46"
SCREEN = "#FAFAFA"
SCREEN_DETAIL = "#D4D4D8"
ACCENT = "#3B82F6"
WHITE = "#FFFFFF"

SUPER = 4
BASE = 512
SIZE = BASE * SUPER

def S(*vals):
    return tuple(v * SUPER for v in vals)

def rounded_mask(size, rx):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=rx, fill=255)
    return m

def draw_icon():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # --- arka plan: duz taban + yumusak radial highlight (derinlik) ---
    bg_layer = Image.new("RGBA", (SIZE, SIZE), BG)
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.ellipse(S(-60, -140, 420, 260), fill=(255, 255, 255, 46))
    highlight = highlight.filter(ImageFilter.GaussianBlur(SIZE * 0.05))
    bg_layer = Image.alpha_composite(bg_layer, highlight)

    mask = rounded_mask(SIZE, 112 * SUPER)
    canvas = Image.composite(bg_layer, canvas, mask)

    # --- aksan parlamasi (senkron dalgalarinin arkasinda yumusak isik) ---
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gcx, gcy, gr = 318, 150, 66
    gd.ellipse(S(gcx - gr, gcy - gr, gcx + gr, gcy + gr), fill=(59, 130, 246, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.035))
    canvas = Image.alpha_composite(canvas, Image.composite(glow, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask))

    d = ImageDraw.Draw(canvas)

    # --- telefon govdesi: bezel + ekran (iki katmanli, derinlik icin) ---
    bx, by, bw, bh, brx = 158, 110, 156, 230, 38
    d.rounded_rectangle(S(bx, by, bx + bw, by + bh), radius=brx * SUPER, fill=BEZEL)

    sx, sy, sw, sh, srx = bx + 10, by + 10, bw - 20, bh - 20, 30
    d.rounded_rectangle(S(sx, sy, sx + sw, sy + sh), radius=srx * SUPER, fill=SCREEN)

    screen_cx = sx + sw / 2
    # hoparlor
    d.rounded_rectangle(S(screen_cx - 18, sy + 14, screen_cx + 18, sy + 18), radius=2 * SUPER, fill=BEZEL)
    # home bar
    d.rounded_rectangle(
        S(screen_cx - 22, sy + sh - 16, screen_cx + 22, sy + sh - 12),
        radius=2 * SUPER,
        fill=SCREEN_DETAIL,
    )

    # --- senkron dalgalari: ic (aksan renk) -> dis (beyaz), yuvarlak uclu ---
    cx, cy = 318, 150
    stroke_w = 15
    cap_r = stroke_w / 2
    for r, color in ((46, ACCENT), (82, WHITE)):
        bbox = S(cx - r, cy - r, cx + r, cy + r)
        d.arc(bbox, start=270, end=360, fill=color, width=stroke_w * SUPER)
        start_pt = (cx, cy - r)
        end_pt = (cx + r, cy)
        for px, py in (start_pt, end_pt):
            d.ellipse(S(px - cap_r, py - cap_r, px + cap_r, py + cap_r), fill=color)

    return canvas.resize((BASE, BASE), Image.LANCZOS)

def main():
    master = draw_icon()
    master.save("icon-512.png")

    for size in (192, 180, 128, 64, 32, 16):
        master.resize((size, size), Image.LANCZOS).save(f"icon-{size}.png")

    master.resize((180, 180), Image.LANCZOS).save("apple-touch-icon.png")

    favicon_sizes = [(16, 16), (32, 32), (48, 48)]
    imgs = [master.resize(s, Image.LANCZOS) for s in favicon_sizes]
    imgs[0].save("favicon.ico", format="ICO", sizes=favicon_sizes)

    print("Tamamlandi.")

if __name__ == "__main__":
    main()
