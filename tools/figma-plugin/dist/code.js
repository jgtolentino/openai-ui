"use strict";

// src/code.ts
function hexToRGB(hex) {
  const h = hex.replace("#", "");
  const bigint = parseInt(h, 16);
  return { r: (bigint >> 16 & 255) / 255, g: (bigint >> 8 & 255) / 255, b: (bigint & 255) / 255 };
}
function twelveColGrid() {
  return [{ pattern: "COLUMNS", sectionSize: 12, gutterSize: 24, alignment: "STRETCH", count: 12, color: { r: 0.1, g: 0.4, b: 0.9, a: 0.06 }, visible: true }];
}
function abs(node, b) {
  node.layoutPositioning = "ABSOLUTE";
  node.x = b.x;
  node.y = b.y;
  if ("resize" in node) node.resize(b.w, b.h);
}
function size(platform) {
  return platform === "mobile" ? { w: 375, h: 900 } : { w: 1280, h: 900 };
}
async function heading(parent, c, t) {
  const fam = (t.typography?.fontFamily?.base || "Inter").split(",")[0];
  await figma.loadFontAsync({ family: fam, style: "Regular" });
  const n = figma.createText();
  n.characters = String(c.props?.text ?? "Heading");
  n.fontSize = Number(String(t.typography?.size?.xl ?? 24).replace("px", ""));
  n.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.text || "#E6EAF2") }];
  parent.appendChild(n);
  abs(n, c.bounds);
}
function card(parent, c, t, title) {
  const r = figma.createRectangle();
  r.cornerRadius = parseInt((t.radius?.md ?? "10px").toString());
  r.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.["bg-elev"] || "#12151C") }];
  r.strokes = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.border || "#2A2F3A") }];
  r.strokeWeight = 1;
  parent.appendChild(r);
  abs(r, c.bounds);
  if (title) {
    const fam = (t.typography?.fontFamily?.base || "Inter").split(",")[0];
    figma.loadFontAsync({ family: fam, style: "Medium" }).then(() => {
      const tx = figma.createText();
      tx.characters = title;
      tx.fontSize = 14;
      tx.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.text || "#E6EAF2") }];
      parent.appendChild(tx);
      abs(tx, { x: c.bounds.x + 16, y: c.bounds.y + 12, w: 200, h: 24 });
    });
  }
}
async function statTile(p, c, t) {
  card(p, c, t);
  const fam = (t.typography?.fontFamily?.base || "Inter").split(",")[0];
  await figma.loadFontAsync({ family: fam, style: "Regular" });
  const l = figma.createText();
  l.characters = String(c.props?.label ?? "Label");
  l.fontSize = 12;
  l.opacity = 0.7;
  l.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.muted || "#A6B0C3") }];
  p.appendChild(l);
  abs(l, { x: c.bounds.x + 16, y: c.bounds.y + 16, w: c.bounds.w - 32, h: 20 });
  const v = figma.createText();
  v.characters = String(c.props?.value ?? "0");
  v.fontSize = 28;
  v.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.text || "#E6EAF2") }];
  p.appendChild(v);
  abs(v, { x: c.bounds.x + 16, y: c.bounds.y + 44, w: c.bounds.w - 32, h: 34 });
}
function table(p, c, t) {
  card(p, c, t);
  const cols = c.props?.columns || [];
  const fam = (t.typography?.fontFamily?.base || "Inter").split(",")[0];
  figma.loadFontAsync({ family: fam, style: "Medium" }).then(() => {
    let x = c.bounds.x + 16;
    const y = c.bounds.y + 16;
    const colW = Math.floor((c.bounds.w - 32) / Math.max(cols.length, 1));
    for (const h of cols) {
      const th = figma.createText();
      th.characters = h;
      th.fontSize = 12;
      th.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.text || "#E6EAF2") }];
      p.appendChild(th);
      abs(th, { x, y, w: colW, h: 20 });
      x += colW;
    }
  });
}
function chart(p, c, t) {
  card(p, c, t, `Chart: ${c.props?.type ?? "bar"}`);
}
function button(p, c, t) {
  const r = figma.createRectangle();
  r.cornerRadius = parseInt((t.radius?.md ?? "10px").toString());
  r.fills = [{ type: "SOLID", color: hexToRGB(t.color?.brand?.primary || "#0A6EEB") }];
  p.appendChild(r);
  abs(r, c.bounds);
  const fam = (t.typography?.fontFamily?.base || "Inter").split(",")[0];
  figma.loadFontAsync({ family: fam, style: "Medium" }).then(() => {
    const tx = figma.createText();
    tx.characters = String(c.props?.label ?? "Button");
    tx.fontSize = 14;
    tx.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }];
    p.appendChild(tx);
    abs(tx, { x: c.bounds.x + (c.bounds.w / 2 - 26), y: c.bounds.y + (c.bounds.h / 2 - 8), w: 100, h: 20 });
  });
}
async function renderScreen(w, t) {
  const { w: W, h: H } = size(w.platform);
  const frame = figma.createFrame();
  frame.name = w.id;
  frame.resize(W, H);
  frame.fills = [{ type: "SOLID", color: hexToRGB(t.color?.ui?.bg || "#0B0D12") }];
  frame.layoutGrids = twelveColGrid();
  figma.currentPage.appendChild(frame);
  for (const c of w.components) {
    switch (c.type) {
      case "Heading":
        await heading(frame, c, t);
        break;
      case "StatTile":
        await statTile(frame, c, t);
        break;
      case "Card":
        card(frame, c, t, c.props?.title);
        break;
      case "Chart":
        chart(frame, c, t);
        break;
      case "DataTable":
        table(frame, c, t);
        break;
      case "Button":
        button(frame, c, t);
        break;
      default:
        const d = figma.createRectangle();
        frame.appendChild(d);
        abs(d, c.bounds);
        d.strokes = [{ type: "SOLID", color: { r: 0.4, g: 0.4, b: 0.4 } }];
        d.dashPattern = [4, 4];
    }
  }
  figma.viewport.scrollAndZoomIntoView([frame]);
}
figma.showUI(__html__, { width: 360, height: 110 });
figma.ui.onmessage = async (msg) => {
  if (msg.type !== "render") return;
  const tk = await figma.clientStorage.getAsync("TOKENS_JSON") || await figma.prompt("Paste design-tokens.json", { defaultValue: "" });
  await figma.clientStorage.setAsync("TOKENS_JSON", tk);
  const wf = await figma.clientStorage.getAsync("WIRES_JSON") || await figma.prompt("Paste wireframes.json", { defaultValue: "" });
  await figma.clientStorage.setAsync("WIRES_JSON", wf);
  let tokens, wires;
  try {
    tokens = JSON.parse(tk);
    wires = JSON.parse(wf);
  } catch {
    figma.notify("Invalid JSON");
    return;
  }
  const id = msg.screenId || "web.dashboard";
  const screen = wires.screens.find((s) => s.id === id);
  if (!screen) {
    figma.notify("Screen id not found");
    return;
  }
  await renderScreen(screen, tokens);
  figma.notify("Rendered: " + id);
};
