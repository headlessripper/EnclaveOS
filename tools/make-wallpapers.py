"""Usage: python tools/make-wallpapers.py arch/branding/wallpapers

Generate the Enclave Ember wallpapers ("Ember Horizon"): dark, light and login.

Pure SVG Tiny-friendly shapes and gradients (Qt SVG has no filters/blur), so
the shell renders them crisply at any size. Deterministic star field.
"""
import random
import sys

W, H = 3840, 2160
OUT = sys.argv[1]

PALETTE = {
    "dark": dict(sky0="#06070A", sky1="#0D0E12", sky2="#1A120C", haze="#FF7A1A", hazeOp=0.20,
                 cool="#5A6B8C", coolOp=0.10, planet0="#16110E", planet1="#0B0B0D",
                 rim="#FF7A1A", rimOp=0.85, rim2="#FFD0A6", ring="#FFAC55", ringOp=0.16,
                 star="#F5F3EF", stars=150, vign=0.35),
    "light": dict(sky0="#FBFAF7", sky1="#F7F6F3", sky2="#FFE6D1", haze="#FF7A1A", hazeOp=0.22,
                  cool="#C9D3E6", coolOp=0.35, planet0="#FFF4EA", planet1="#F3E6DA",
                  rim="#E95B16", rimOp=0.70, rim2="#FFAC55", ring="#E95B16", ringOp=0.16,
                  star="#E95B16", stars=0, vign=0.0),
    "login": dict(sky0="#050608", sky1="#0A0B0E", sky2="#140F0B", haze="#FF7A1A", hazeOp=0.12,
                  cool="#5A6B8C", coolOp=0.08, planet0="#120E0B", planet1="#09090B",
                  rim="#FF7A1A", rimOp=0.55, rim2="#FFD0A6", ring="#FFAC55", ringOp=0.10,
                  star="#F5F3EF", stars=110, vign=0.45),
}


def make(kind):
    p = PALETTE[kind]
    rnd = random.Random(7)
    # planet: a vast sphere rising from the lower right
    cx, cy, r = 2600, 4300, 2700          # top of the planet at y = 1600
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
           f'<!-- Enclave Ember wallpaper "Ember Horizon" ({kind}). Generated; see docs. -->',
           "<defs>",
           f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
           f'<stop offset="0" stop-color="{p["sky0"]}"/><stop offset="0.6" stop-color="{p["sky1"]}"/>'
           f'<stop offset="1" stop-color="{p["sky2"]}"/></linearGradient>',
           # warm haze hugging the horizon
           f'<radialGradient id="haze" cx="{cx}" cy="{cy - r}" r="2300" gradientUnits="userSpaceOnUse" '
           f'gradientTransform="translate({cx} {cy - r}) scale(1.6 0.55) translate({-cx} {-(cy - r)})">'
           f'<stop offset="0" stop-color="{p["haze"]}" stop-opacity="{p["hazeOp"]}"/>'
           f'<stop offset="0.45" stop-color="{p["haze"]}" stop-opacity="{p["hazeOp"] * 0.35:.3f}"/>'
           f'<stop offset="1" stop-color="{p["haze"]}" stop-opacity="0"/></radialGradient>',
           # cool depth, upper left
           f'<radialGradient id="cool" cx="700" cy="300" r="1900" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0" stop-color="{p["cool"]}" stop-opacity="{p["coolOp"]}"/>'
           f'<stop offset="1" stop-color="{p["cool"]}" stop-opacity="0"/></radialGradient>',
           # the planet body, lit from the top
           f'<radialGradient id="planet" cx="{cx}" cy="{cy - r * 0.55}" r="{r * 1.25}" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0" stop-color="{p["planet0"]}"/><stop offset="1" stop-color="{p["planet1"]}"/></radialGradient>',
           # rim light: a thin bright band at the planet's edge
           f'<radialGradient id="rim" cx="{cx}" cy="{cy}" r="{r + 60}" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0.955" stop-color="{p["rim"]}" stop-opacity="0"/>'
           f'<stop offset="0.975" stop-color="{p["rim"]}" stop-opacity="{p["rimOp"] * 0.35:.3f}"/>'
           f'<stop offset="0.9785" stop-color="{p["rim2"]}" stop-opacity="{p["rimOp"]}"/>'
           f'<stop offset="0.982" stop-color="{p["rim"]}" stop-opacity="{p["rimOp"] * 0.5:.3f}"/>'
           f'<stop offset="1" stop-color="{p["rim"]}" stop-opacity="0"/></radialGradient>',
           # atmosphere glow just above the rim
           f'<radialGradient id="atmo" cx="{cx}" cy="{cy}" r="{r + 420}" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0.86" stop-color="{p["rim"]}" stop-opacity="0"/>'
           f'<stop offset="0.87" stop-color="{p["rim"]}" stop-opacity="{p["hazeOp"] * 0.9:.3f}"/>'
           f'<stop offset="1" stop-color="{p["rim"]}" stop-opacity="0"/></radialGradient>',
           # top-lit sheen on the planet (fades away from the top)
           f'<linearGradient id="sheen" x1="0" y1="{cy - r}" x2="0" y2="{cy - r + 700}" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0" stop-color="{p["rim"]}" stop-opacity="{p["hazeOp"] * 0.8:.3f}"/>'
           f'<stop offset="1" stop-color="{p["rim"]}" stop-opacity="0"/></linearGradient>',
           f'<radialGradient id="vign" cx="0.5" cy="0.45" r="0.8">'
           f'<stop offset="0.55" stop-color="#000000" stop-opacity="0"/>'
           f'<stop offset="1" stop-color="#000000" stop-opacity="{p["vign"]}"/></radialGradient>',
           "</defs>",
           f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
           f'<rect width="{W}" height="{H}" fill="url(#cool)"/>']

    # stars: denser and brighter toward the top, none on the planet
    stars = []
    for _ in range(p["stars"]):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H) ** 1.35 / H ** 0.35
        if (x - cx) ** 2 + (y - cy) ** 2 < (r + 200) ** 2:
            continue
        size = rnd.choice([1.4, 1.8, 2.2, 2.2, 2.8, 3.6])
        op = rnd.uniform(0.25, 0.9) * (1 - y / H * 0.6)
        stars.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{size}" fill="{p["star"]}" fill-opacity="{op:.2f}"/>')
    out.append("<g>" + "".join(stars) + "</g>")

    out += [f'<rect width="{W}" height="{H}" fill="url(#haze)"/>',
            f'<circle cx="{cx}" cy="{cy}" r="{r + 420}" fill="url(#atmo)"/>']

    # orbit rings: wide, tilted ellipses around the planet (the parts in the sky)
    for i, (rx, ry, rot, op) in enumerate([(3400, 620, -9, 1.0), (3900, 760, -9, 0.6), (4500, 900, -9, 0.35)]):
        out.append(f'<ellipse cx="{cx}" cy="{cy - r + 350}" rx="{rx}" ry="{ry}" fill="none" '
                   f'stroke="{p["ring"]}" stroke-opacity="{p["ringOp"] * op:.3f}" stroke-width="{4 - i}" '
                   f'transform="rotate({rot} {cx} {cy - r + 350})"/>')

    out += [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#planet)"/>',
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#sheen)"/>',
            f'<circle cx="{cx}" cy="{cy}" r="{r + 60}" fill="url(#rim)"/>']

    # a few lights on the planet's night side: tiny warm specks along curves
    if kind != "light":
        specks = []
        for _ in range(70):
            a = rnd.uniform(-0.42, 0.25)
            d = rnd.uniform(r * 0.86, r * 0.985)
            import math
            x, y = cx + d * math.sin(a), cy - d * math.cos(a)
            if 0 <= x <= W and y <= H:
                specks.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rnd.choice([1.5, 2, 2.5])}" '
                              f'fill="{p["rim2"]}" fill-opacity="{rnd.uniform(0.2, 0.6):.2f}"/>')
        out.append("<g>" + "".join(specks) + "</g>")

    out.append(f'<rect width="{W}" height="{H}" fill="url(#vign)"/>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


for kind, name in [("dark", "enclave-default.svg"), ("light", "enclave-default-light.svg"), ("login", "enclave-login.svg")]:
    with open(f"{OUT}/{name}", "w", encoding="utf-8") as f:
        f.write(make(kind))
    print("wrote", name)
