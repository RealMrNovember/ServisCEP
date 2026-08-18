"""
Play Store "feature graphic" (1024x500) uretir — marka kimligine uygun,
icon.svg/generate_assets.py ile ayni gorsel dilde (koyu zemin + bezelli
telefon + aksan renkli senkron dalgalari).

Kullanim:
    python generate_feature_graphic.py
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG = "#131316"
BEZEL = "#3F3F46"
SCREEN = "#FAFAFA"
SCREEN_DETAIL = "#D4D4D8"
ACCENT = "#3B82F6"
WHITE = "#FFFFFF"
MUTED = "#9CA3AF"

SUPER = 4
W, H = 1024, 500
SIZE_W, SIZE_H = W * SUPER, H * SUPER

FONT_DIR = "C:/Windows/Fonts"


def S(*vals):
    return tuple(v * SUPER for v in vals)


def draw_phone_icon(canvas, cx_base, cy_base, scale=1.0):
    # Orijinal icon.svg/generate_assets.py ile AYNI oranlar (bx=158,by=110,
    # bw=156,bh=230, arc-merkezi=318,150) — sadece cx_base/cy_base etrafında
    # yeniden konumlandirilip olceklenir. Senkron dalgalari kasitli olarak
    # telefonun sag-ust kosesinden disariya tasar (orijinal tasarim niyeti).
    d = ImageDraw.Draw(canvas, "RGBA")

    bw, bh, brx = 156 * scale, 230 * scale, 38 * scale
    bx, by = cx_base - bw / 2, cy_base - bh / 2
    d.rounded_rectangle(S(bx, by, bx + bw, by + bh), radius=brx * SUPER, fill=BEZEL)

    pad = 10 * scale
    sw, sh, srx = bw - pad * 2, bh - pad * 2, 30 * scale
    sx, sy = bx + pad, by + pad
    d.rounded_rectangle(S(sx, sy, sx + sw, sy + sh), radius=srx * SUPER, fill=SCREEN)

    screen_cx = sx + sw / 2
    d.rounded_rectangle(
        S(screen_cx - 18 * scale, sy + 14 * scale, screen_cx + 18 * scale, sy + 18 * scale),
        radius=2 * scale * SUPER,
        fill=BEZEL,
    )
    d.rounded_rectangle(
        S(screen_cx - 22 * scale, sy + sh - 16 * scale, screen_cx + 22 * scale, sy + sh - 12 * scale),
        radius=2 * scale * SUPER,
        fill=SCREEN_DETAIL,
    )

    cx = bx + bw * (160 / 156)
    cy = by + bh * (40 / 230)
    stroke_w = 15 * scale
    cap_r = stroke_w / 2
    for r_ratio, color in ((46 / 156, ACCENT), (82 / 156, WHITE)):
        r = bw * r_ratio
        bbox = S(cx - r, cy - r, cx + r, cy + r)
        d.arc(bbox, start=270, end=360, fill=color, width=int(stroke_w * SUPER))
        for px, py in ((cx, cy - r), (cx + r, cy)):
            d.ellipse(S(px - cap_r, py - cap_r, px + cap_r, py + cap_r), fill=color)


def main():
    canvas = Image.new("RGBA", (SIZE_W, SIZE_H), BG)

    # yumusak radial highlight — sol ust
    highlight = Image.new("RGBA", (SIZE_W, SIZE_H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.ellipse(S(-200, -260, 500, 320), fill=(255, 255, 255, 30))
    highlight = highlight.filter(ImageFilter.GaussianBlur(SIZE_W * 0.03))
    canvas = Image.alpha_composite(canvas, highlight)

    # aksan glow — telefon ikonunun arkasinda
    glow = Image.new("RGBA", (SIZE_W, SIZE_H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gcx, gcy, gr = 850, 210, 150
    gd.ellipse(S(gcx - gr, gcy - gr, gcx + gr, gcy + gr), fill=(59, 130, 246, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(SIZE_W * 0.02))
    canvas = Image.alpha_composite(canvas, glow)

    draw_phone_icon(canvas, 785, 250, scale=1.15)

    d = ImageDraw.Draw(canvas, "RGBA")
    title_font = ImageFont.truetype(f"{FONT_DIR}/segoeuib.ttf", 92 * SUPER)
    tagline_font = ImageFont.truetype(f"{FONT_DIR}/segoeui.ttf", 34 * SUPER)

    tx = 70 * SUPER
    d.text((tx, 178 * SUPER), "ServisCEP", font=title_font, fill=WHITE)
    d.text(
        (tx, 292 * SUPER),
        "Saha teknik servis işletmeleri için",
        font=tagline_font,
        fill=MUTED,
    )
    d.text(
        (tx, 336 * SUPER),
        "mobil-first, offline-first yönetim platformu",
        font=tagline_font,
        fill=MUTED,
    )

    canvas = canvas.resize((W, H), Image.LANCZOS)
    canvas.convert("RGB").save("feature_graphic.png")
    print("Tamamlandi: feature_graphic.png")


if __name__ == "__main__":
    main()
