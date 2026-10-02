"""Screenshot every screen of the app-signal prototype in both themes (headless WebKit, nothing on screen).

Usage: python3 shoot.py [name-filter ...]   SCALE=2 for retina shots. Long screens also get -p2, -p3 scroll pages.
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "shots"
OUT.mkdir(exist_ok=True)
URL = (ROOT / "index.html").as_uri()

only = sys.argv[1:]

with sync_playwright() as p:
    b = p.webkit.launch()
    pg = b.new_page(viewport={"width": 1280, "height": 860}, device_scale_factor=int(__import__("os").environ.get("SCALE", "1")))
    errors = []
    pg.on("pageerror", lambda e: errors.append(str(e)))
    pg.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    pg.goto(URL)
    pg.wait_for_timeout(400)
    shots = pg.evaluate("window.PROTO.shots()")
    for theme in ("dark", "light"):
        for s in shots:
            name = f"{s}-{theme}"
            if only and not any(o in name for o in only):
                continue
            pg.evaluate(f"window.PROTO.shot({s!r}, {theme!r})")
            pg.wait_for_timeout(180)
            pg.screenshot(path=str(OUT / f"{name}.png"))
            print("shot", name)
            if s.startswith(("wizard", "menubar", "history", "hotkey", "dict-empty")):
                continue
            sh, ch = pg.evaluate("[document.querySelector('.pane').scrollHeight, document.querySelector('.pane').clientHeight]")
            k = 1
            while (k - 1) * (ch - 80) + ch < sh - 4 and k < 8:
                pg.evaluate(f"document.querySelector('.pane').scrollTop = {k * (ch - 80)}")
                pg.wait_for_timeout(120)
                pg.screenshot(path=str(OUT / f"{name}-p{k + 1}.png"))
                k += 1
    if errors:
        print("ERRORS:", *errors, sep="\n  ")
    b.close()
