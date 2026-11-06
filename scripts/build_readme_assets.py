#!/usr/bin/env python3
"""Build the README SVGs in assets/readme/.

    python3 scripts/build_readme_assets.py

Needs fontTools (pip install fonttools): the NO SUS wordmark is outlined from
app/assets/google_fonts/Outfit-Bold.ttf. Colours are CanaryTokens in app/lib/theme.dart,
the bird is the CanaryMark sprite, and the slots are the ones the fingerprint engine
(app/lib/features/canary/domain/canary_fingerprint.dart) finds in the app's demo note.
Copy 1 is Priya's real codeword from docs/media/reader-copy.png; the other nine are drawn
the way generateCanaryCodewords draws them (distinct, non-zero, at least 4 bits apart).
"""
import random
from pathlib import Path
from xml.sax.saxutils import escape

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "readme"

BG, SURFACE, SURFACE_HI = "#FAF6EC", "#FFFDF7", "#F3ECDC"
INK, DIM, CANARY, CANARY_HI, CANARY_DEEP = "#141414", "#4A4740", "#F28C28", "#FFB066", "#C9690F"
SOL, SOL_TINT, STOP = "#0F6E63", "#E3EEE9", "#808080"
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace"

BIRD = [
    ".....KKKKK......",
    "...KKYYYYYKK....",
    "..KYYYYYYYWWK...",
    "..KYYYYYYYWKK...",
    ".KYYYYYYYYYYKOO.",
    ".KYYYYYYYYYYKOOO",
    ".KYyyyyYYYYYK...",
    "KYYyyyyyYYYYK...",
    "KYYYyyyyYYYK....",
    ".KYYYyyYYYYK....",
    "..KYYYYYYYK.....",
    "...KKKKKKK......",
    "....K...K.......",
    "...KK..KK.......",
]
BIRD_FILL = {"K": INK, "O": INK, "Y": CANARY, "y": BG, "W": BG}

# The 15 slots of the demo note, in order: (original, alternate).
SLOTS = [("hi", "hello"), ("don't", "do not"), ("it's", "it is"), ("ten", "10"), ("kindly", "please"),
         ("until", "till"), ("organize", "organise"), ("afterwards", "afterward"), ("can't", "cannot"),
         ("email", "e-mail"), ("favorite", "favourite"), ("nobody", "no one"), ("maybe", "perhaps"),
         ("five", "5"), ("don't", "do not")]
PRIYA = [0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0]
LEAKED = [1, 2, 3, 4, 5]          # slots that survive in the pasted excerpt (0-based)
FIRST_MISS = [0, 0, 0, 1, 1, 2, 2, 3, 4]   # where each other copy first disagrees


def codewords():
    rng = random.Random(7)
    words = [PRIYA]
    for miss in FIRST_MISS:
        while True:
            w = [rng.randint(0, 1) for _ in SLOTS]
            for k in LEAKED[:miss]:
                w[k] = 1
            w[LEAKED[miss]] = 0
            if any(w) and all(sum(a != b for a, b in zip(w, o)) >= 4 for o in words):
                words.append(w)
                break
    return words


def svg(w, h, title, desc, body, style=""):
    css = f"<style>{style}</style>" if style else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'role="img" aria-labelledby="t d"><title id="t">{escape(title)}</title>'
        f'<desc id="d">{escape(desc)}</desc>{css}{body}</svg>\n'
    )


def text(x, y, s, size=20, fill=INK, weight=400, family=SANS, anchor="start", extra=""):
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{extra}>{s}</text>')


def outline(s, x, baseline, size, fill=INK, stop=False):
    """Outfit Bold outlines, -0.04em tracking; with stop=True, the wordmark's grey square."""
    font = TTFont(ROOT / "app/assets/google_fonts/Outfit-Bold.ttf")
    cmap, hmtx, glyphs = font.getBestCmap(), font["hmtx"], font.getGlyphSet()
    k = size / font["head"].unitsPerEm
    pen = SVGPathPen(glyphs)
    cx = x
    for ch in s:
        name = cmap[ord(ch)]
        glyphs[name].draw(TransformPen(pen, (k, 0, 0, -k, cx, baseline)))
        cx += hmtx[name][0] * k - 0.04 * size
    out = f'<path d="{pen.getCommands()}" fill="{fill}"/>'
    if stop:
        sq = 0.21 * size
        cx += 0.12 * size
        out += f'<rect x="{cx:.1f}" y="{baseline - sq:.1f}" width="{sq:.1f}" height="{sq:.1f}" fill="{STOP}"/>'
    return out


def bird(x, y, cell):
    out = []
    for r, row in enumerate(BIRD):
        for c, ch in enumerate(row):
            if ch in BIRD_FILL:
                out.append(f'<rect x="{x + c * cell}" y="{y + r * cell}" width="{cell}" height="{cell}" fill="{BIRD_FILL[ch]}"/>')
    return "".join(out)


def frame(w, h):
    """The app's card: cream, a 3-unit ink border and a hard canary offset."""
    return (f'<rect x="10" y="10" width="{w - 12}" height="{h - 12}" rx="28" fill="{CANARY}"/>'
            f'<rect x="1.5" y="1.5" width="{w - 13}" height="{h - 13}" rx="27" fill="{BG}" stroke="{INK}" stroke-width="3"/>')


def card(x, y, w, h, fill=SURFACE, shadow=True, rx=18):
    s = f'<rect x="{x + 5}" y="{y + 5}" width="{w}" height="{h}" rx="{rx}" fill="{INK}"/>' if shadow else ""
    return s + f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{INK}" stroke-width="2.5"/>'


def ticket(x, y, w, h, label):
    """The orange copy badge with round notches at both ends."""
    r = h / 4
    d = (f"M{x} {y}H{x + w}V{y + h / 2 - r}A{r} {r} 0 0 0 {x + w} {y + h / 2 + r}V{y + h}H{x}"
         f"V{y + h / 2 + r}A{r} {r} 0 0 0 {x} {y + h / 2 - r}Z")
    return f'<path d="{d}" fill="{CANARY}"/>' + text(x + 22, y + h / 2 + 7, label, 20, INK, 700, MONO)


def phrase(bits, x, y, size=20):
    """'and it's nearly done. The first ten' with the two slot words set by the codeword."""
    its = SLOTS[2][bits[2]]
    ten = SLOTS[3][bits[3]]
    return (f'<text x="{x}" y="{y}" font-family="{SANS}" font-size="{size}" fill="{DIM}">and '
            f'<tspan fill="{INK}" font-weight="700">{escape(its)}</tspan> nearly done. The first '
            f'<tspan fill="{INK}" font-weight="700">{escape(ten)}</tspan></text>')


def hero():
    w, h = 1200, 420
    cw = codewords()
    b = [frame(w, h)]
    b.append(bird(56, 50, 7))
    b.append(outline("NO SUS", 190, 128, 86, stop=True))
    b.append(outline("Canary", 190, 206, 64))
    b.append(text(56, 284, "Every reader gets their own copy.", 34, INK, 700))
    b.append(text(56, 328, "Every open is a receipt on Solana devnet.", 28, DIM, 600))
    b.append(text(56, 378, "shubham-sahu.me/nosus-canary", 20, DIM, family=MONO))
    b.append(f'<rect x="412" y="364" width="10" height="10" fill="{STOP}"/>')
    b.append(text(438, 378, "Apache-2.0", 20, DIM, family=MONO))
    cards = [(2, "COPY 3 / 10 · not opened", 748, 44, 4), (1, "COPY 2 / 10 · made for Ben", 724, 150, -2),
             (0, "COPY 1 / 10 · made for Priya", 700, 256, 0)]
    for i, label, x, y, rot in cards:
        b.append(f'<g transform="rotate({rot} {x + 200} {y + 56})">'
                 + card(x, y, 404, 108, rx=16)
                 + ticket(x + 14, y + 14, 376, 40, label)
                 + phrase(cw[i], x + 22, y + 88) + "</g>")
    return svg(w, h, "NO SUS Canary",
               "The pixel canary and the NO SUS wordmark. Every reader gets their own copy. Every open is a "
               "receipt on Solana devnet. Three copy badges: copy 1 made for Priya, copy 2 made for Ben, copy 3 "
               "not opened, each with slightly different wording of the same line.", "".join(b))


# ── Which copy leaked: one shared 12 s loop ──────────────────────────────────
D = 12
EASE = "cubic-bezier(.2,.8,.2,1)"
T = [8, 16, 24, 32, 40]   # when the scan reaches each leaked slot, in % of the loop


def kf(name, frames, base="", timing=EASE):
    body = "".join(f"{k}{{{v}}}" for k, v in frames)
    return f"@keyframes {name}{{{body}}}.{name}{{{base}animation:{name} {D}s {timing} infinite}}"


def appear(name, start, end, frm="none"):
    return kf(name, [(f"0%,{start}%", f"opacity:0;transform:{frm}"), (f"{end}%,95%", "opacity:1;transform:none"),
                     ("100%", "opacity:0;transform:none")])


def board():
    w, h = 1200, 700
    cw = codewords()
    css, b = [], [frame(w, h)]

    # Left: the pasted leak, with the slot words that survived in it.
    b.append(text(48, 72, "The leak, pasted", 24, INK, 700))
    b.append(card(40, 92, 500, 252))
    lines = [
        [("…please ", 0), ("do not", 2), (" forward this. We're", 0)],
        [("finalizing the budget and ", 0), ("it is", 3), (" nearly", 0)],
        [("done. The first ", 0), ("10", 4), (" people who reply", 0)],
        [("can join the review, so ", 0), ("please", 5), (" keep", 0)],
        [("it quiet ", 0), ("till", 6), (" Monday.", 0)],
    ]
    for i, parts in enumerate(lines):
        spans = ""
        for s, slot in parts:
            if slot:
                spans += (f'<tspan fill="{CANARY_DEEP}" font-weight="700">{escape(s)}</tspan>'
                          f'<tspan font-family="{MONO}" font-size="16" fill="{CANARY_DEEP}" dy="-9">{slot}</tspan>'
                          f'<tspan dy="9"></tspan>')
            else:
                spans += escape(s)
        b.append(f'<text x="66" y="{140 + 40 * i}" font-family="{SANS}" font-size="21" fill="{INK}">{spans}</text>')
    b.append(f'<rect class="scan" x="56" y="118" width="468" height="3" fill="{CANARY}"/>')
    css.append(kf("scan", [("0%,6%", "opacity:0;transform:none"), ("7%", "opacity:1;transform:none"),
                           ("46%", "opacity:1;transform:translateY(200px)"), ("48%,100%", "opacity:0;transform:translateY(200px)")],
                  base="opacity:0;", timing="linear"))

    b.append(text(48, 400, "What the copies swap", 24, INK, 700))
    for k, slot in enumerate(LEAKED):
        y = 440 + 34 * k
        o, a = SLOTS[slot]
        b.append(f'<rect class="sw{k}" x="48" y="{y - 15}" width="14" height="14" fill="{CANARY}" stroke="{INK}" stroke-width="1.5"/>')
        b.append(text(76, y, str(slot + 1), 20, CANARY_DEEP, 700, MONO))
        b.append(text(110, y, escape(o), 20, INK, family=MONO))
        b.append(text(214, y, "→", 20, DIM, family=MONO))
        b.append(text(248, y, escape(a), 20, INK, 700, MONO))
        css.append(appear(f"sw{k}", T[k], T[k] + 2, "scale(.4)"))
    b.append(text(48, 640, "and 10 more slots, plus an invisible marker", 18, DIM))

    # Right: every copy's codeword against the bits read from the leak.
    x0, cell, pitch = 726, 22, 28
    b.append(text(588, 72, "Which copy fits?", 24, INK, 700))
    for j in range(len(SLOTS)):
        cx = x0 + j * pitch + cell / 2
        col = CANARY_DEEP if j in LEAKED else DIM
        b.append(text(cx, 112, str(j + 1), 16, col, 700 if j in LEAKED else 400, MONO, anchor="middle"))
    b.append(f'<rect class="band" x="{x0 + LEAKED[0] * pitch - 3}" y="96" width="{cell + 6}" height="420" rx="6" fill="{CANARY}" opacity=".22"/>')
    css.append(kf("band", [("0%,6%", "opacity:0;transform:none")]
                  + [(f"{t}%,{t + 4}%", f"opacity:1;transform:translateX({k * pitch}px)") for k, t in enumerate(T)]
                  + [("46%", "opacity:0;transform:translateX(112px)"), ("100%", "opacity:0;transform:translateX(112px)")],
                  base="opacity:0;"))

    y = 126
    b.append(text(588, y + 17, "Leak", 20, INK, 700))
    for j in range(len(SLOTS)):
        x = x0 + j * pitch
        b.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="3" fill="none" stroke="{DIM}" stroke-width="1.5" stroke-dasharray="3 3"/>')
        if j in LEAKED:
            k = LEAKED.index(j)
            b.append(f'<rect class="lk{k}" x="{x}" y="{y}" width="{cell}" height="{cell}" rx="3" fill="{CANARY}" stroke="{INK}" stroke-width="2"/>')
            css.append(appear(f"lk{k}", T[k] + 1, T[k] + 3, "scale(.3)"))
    b.append(f'<line x1="584" y1="164" x2="1150" y2="164" stroke="{INK}" stroke-width="1.5"/>')

    names = {0: "Priya", 1: "Ben"}
    b.append(f'<rect class="win" x="576" y="176" width="578" height="32" rx="8" fill="{CANARY_HI}" fill-opacity=".55"/>')
    for i, word in enumerate(cw):
        y = 181 + 34 * i
        row = [text(588, y + 17, f"Copy {i + 1}", 18, INK, family=MONO)]
        if i in names:
            row.append(text(668, y + 17, names[i], 18, INK, 700))
        for j, bit in enumerate(word):
            fill = CANARY if bit else SURFACE
            row.append(f'<rect x="{x0 + j * pitch}" y="{y}" width="{cell}" height="{cell}" rx="3" fill="{fill}" stroke="{INK}" stroke-width="1.5"/>')
        if i == 0:
            b.append("".join(row))
            continue
        miss = FIRST_MISS[i - 1]
        b.append(f'<g class="r{i}" opacity=".28">{"".join(row)}</g>'
                 f'<line class="s{i}" x1="584" y1="{y + 11}" x2="1150" y2="{y + 11}" stroke="{INK}" stroke-width="2" opacity=".5"/>')
        t = T[miss] + 3
        css.append(kf(f"r{i}", [(f"0%,{t}%", "opacity:1"), (f"{t + 2}%,95%", "opacity:.28"), ("100%", "opacity:1")]))
        css.append(kf(f"s{i}", [(f"0%,{t}%", "opacity:0"), (f"{t + 2}%,95%", "opacity:.5"), ("100%", "opacity:0")]))
    css.append(appear("win", 48, 52))

    # The result, in the app's own words.
    b.append(f'<g class="res">{card(588, 538, 560, 128)}'
             + text(612, 580, "The canary sang", 26, INK, 700)
             + text(1126, 580, "5 of 5 fingerprints match.", 18, DIM, anchor="end")
             + ticket(612, 600, 384, 44, "COPY 1 / 10 · made for Priya")
             + f'<rect x="1010" y="602" width="118" height="40" rx="14" fill="{SOL_TINT}" stroke="{SOL}" stroke-width="1.5"/>'
             + text(1069, 628, "5TXF…Asy2", 18, SOL, 700, MONO, anchor="middle") + "</g>")
    css.append(appear("res", 50, 56, "translateY(14px)"))

    style = ("g,rect{transform-box:fill-box;transform-origin:center} " + " ".join(css)
             + " @media (prefers-reduced-motion: reduce){*{animation:none!important}}")
    return svg(w, h, "Which copy leaked",
               "Left: an excerpt of a leaked note with five swapped words marked: do not, it is, 10, please, till, "
               "which are slots 2 to 6 of 15 in the demo note. Right: ten copies, each a row of 15 bits. The leak "
               "is read slot by slot, every copy that disagrees is struck out, and only copy 1 remains. Result, as "
               "the app shows it: the canary sang, copy 1 of 10, made for Priya, 5 of 5 fingerprints match, with "
               "her open receipt 5TXF…Asy2 on Solana.", "".join(b), style)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in (("hero.svg", hero), ("leak-match.svg", board)):
        (OUT / name).write_text(build(), encoding="utf-8")
        print("wrote", (OUT / name).relative_to(ROOT))


if __name__ == "__main__":
    main()
