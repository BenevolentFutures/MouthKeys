// Signal callouts: hover any overlay element and an engineering-drawing callout names it.
// A 1 px leader from a 3 pt square terminus on the element runs straight out of the overlay (up for
// the top half, down for the bottom half, sideways for "side" items) to a mono uppercase label on the
// surface colour, with one plain line of description under it. Drawn in a fixed, click-through layer,
// so nothing in the overlay moves. A 60 ms fade, nothing else. Elements that already carry a hover
// bracket (chips, card buttons) keep it; non-clickable ones get only the terminus, per DESIGN.md §7.
//
// SignalCallouts.attach({
//   anchor: ".sg",                       // the overlay root the leaders clear (rails + pill)
//   vars: { surface, edge, text, text2, mono, font },   // CSS custom property names on :root
//   items: [{ sel, label, desc, place: "above" | "below" | "side", anchor }],   // label may be a function(el)
// })
(function () {
  "use strict";
  function attach(cfg) {
    const v = Object.assign({ surface: "--surface", edge: "--edge", text: "--text", text2: "--text-2", mono: "--mono", font: "--font" }, cfg.vars || {});
    const css = document.createElement("style");
    css.textContent = `
.co-layer { position: fixed; inset: 0; z-index: 9999; pointer-events: none; opacity: 0; transition: opacity 60ms linear; }
.co-layer.on { opacity: 1; }
.co-layer svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
.co-layer path { fill: none; stroke: var(${v.text2}); stroke-width: 1; shape-rendering: crispEdges; }
.co-layer rect { fill: var(${v.text}); shape-rendering: crispEdges; }
.co-lab { position: absolute; padding: 5px 8px 6px; background: var(${v.surface}); box-shadow: inset 0 0 0 1px var(${v.edge}); white-space: nowrap; }
.co-lab b { display: block; font: 600 10px/14px var(${v.mono}); letter-spacing: .06em; text-transform: uppercase; color: var(${v.text}); }
.co-lab span { display: block; font: 400 12px/16px var(${v.font}); color: var(${v.text2}); }
.co-lab span:empty { display: none; }
@media (prefers-reduced-motion: reduce) { .co-layer { transition: none; } }`;
    document.head.appendChild(css);
    const layer = document.createElement("div");
    layer.className = "co-layer";
    layer.setAttribute("aria-hidden", "true");
    layer.innerHTML = '<svg><path/><rect width="3" height="3"/></svg><div class="co-lab"><b></b><span></span></div>';
    document.body.appendChild(layer);
    const path = layer.querySelector("path"), dot = layer.querySelector("rect"), lab = layer.querySelector(".co-lab");
    let cur = null;

    function find(target) {
      if (!target || !target.closest) return null;
      let best = null;
      for (const item of cfg.items) {
        const el = target.closest(item.sel);
        if (el && (!best || best.el.contains(el))) best = { el, item };
      }
      return best;
    }
    function hide() { layer.classList.remove("on"); cur = null; }
    function show(hit) {
      const { el, item } = hit;
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height || getComputedStyle(el).visibility === "hidden") return hide();
      const host = (item.anchor && el.closest(item.anchor)) || (cfg.anchor && el.closest(cfg.anchor)) || el;
      const A = host.getBoundingClientRect();
      const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      const left = cx < A.left + A.width / 2;
      const place = item.place || (cy < A.top + A.height / 2 ? "above" : "below");
      lab.querySelector("b").textContent = typeof item.label === "function" ? item.label(el) : item.label;
      lab.querySelector("span").textContent = item.desc || "";
      const lw = lab.offsetWidth, lh = lab.offsetHeight;
      let d, lx, ly, x0, y0;
      if (place === "side") {
        x0 = left ? r.left : r.right; y0 = Math.round(cy) + 0.5;
        const x1 = left ? A.left - 18 : A.right + 18;
        d = `M${x0} ${y0}H${x1}`;
        lx = left ? x1 - lw : x1; ly = y0 - lh / 2;
      } else {
        x0 = Math.round(cx) + 0.5; y0 = place === "above" ? r.top : r.bottom;
        const y1 = Math.round(place === "above" ? A.top - 26 : A.bottom + 24) + 0.5;
        const x2 = x0 + (left ? -12 : 12);
        d = `M${x0} ${y0}V${y1}H${x2}`;
        lx = left ? x2 - lw : x2; ly = y1 - lh / 2;
      }
      lx = Math.max(6, Math.min(innerWidth - lw - 6, lx)); ly = Math.max(6, Math.min(innerHeight - lh - 6, ly));
      path.setAttribute("d", d);
      dot.setAttribute("x", Math.round(x0 - 1.5)); dot.setAttribute("y", Math.round(y0 - 1.5));
      lab.style.left = Math.round(lx) + "px"; lab.style.top = Math.round(ly) + "px";
      layer.classList.add("on");
    }
    document.addEventListener("mouseover", (e) => {
      const hit = find(e.target);
      if (!hit) { if (cur) hide(); return; }
      if (cur && cur.el === hit.el) return;
      cur = hit; show(hit);
    }, true);
    document.addEventListener("mouseleave", hide);
    addEventListener("scroll", () => cur && show(cur), true);
    addEventListener("resize", () => cur && show(cur));
    return { show: (el) => { const hit = find(el); if (hit) { cur = hit; show(hit); } }, hide };
  }
  window.SignalCallouts = { attach };
})();
