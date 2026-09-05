.pragma library

function gcd(a, b) {
  a = Math.abs(Math.round(a))
  b = Math.abs(Math.round(b))
  while (b) {
    var t = b
    b = a % b
    a = t
  }
  return a || 1
}

function defaultLook() {
  return {
    fixedR: 100,
    rollingR: 25,
    penP: 40,
    epi: false,
    lineWidth: 3,
    inkMode: "theme",
    strokeKey: "accent",
    paper: "inset",
    drawSpeed: 0.22,
    keepLayers: true
  }
}

function clampLook(raw) {
  var d = defaultLook()
  var o = raw && typeof raw === "object" ? raw : {}
  var look = {
    fixedR: Number(o.fixedR),
    rollingR: Number(o.rollingR),
    penP: Number(o.penP),
    epi: o.epi === true,
    lineWidth: Number(o.lineWidth),
    inkMode: migrateInk(o.inkMode, d.inkMode),
    strokeKey: String(o.strokeKey || d.strokeKey),
    paper: o.paper === "lift" ? "lift" : "inset",
    drawSpeed: migrateSpeed(o.drawSpeed, d.drawSpeed),
    keepLayers: o.keepLayers !== false
  }
  if (!isFinite(look.fixedR)) look.fixedR = d.fixedR
  if (!isFinite(look.rollingR)) look.rollingR = d.rollingR
  if (!isFinite(look.penP)) look.penP = d.penP
  if (!isFinite(look.lineWidth)) look.lineWidth = d.lineWidth
  look.fixedR = Math.max(40, Math.min(220, Math.round(look.fixedR)))
  look.rollingR = Math.max(8, Math.min(100, Math.round(look.rollingR)))
  look.penP = Math.max(0, Math.min(penMax(look.rollingR), Math.round(look.penP)))
  look.lineWidth = Math.max(1, Math.min(8, Math.round(look.lineWidth)))
  var keys = { accent: 1, foreground: 1, muted: 1, urgent: 1 }
  if (!keys[look.strokeKey]) look.strokeKey = d.strokeKey
  return look
}

function migrateInk(value, fallback) {
  if (value === "solid") return "theme"
  if (value === "theme" || value === "path") return value
  return fallback
}

function themePalette(text) {
  var order = ["red", "yellow", "orange", "green", "cyan", "blue", "magenta"]
  var found = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*(red|yellow|orange|green|cyan|blue|magenta)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (m)
      found[m[1]] = m[2].toLowerCase()
  }
  var out = []
  for (var j = 0; j < order.length; j++) {
    if (found[order[j]])
      out.push(found[order[j]])
  }
  return out
}

function hexRgb(hex) {
  var h = String(hex || "").replace("#", "")
  if (h.length !== 6)
    return null
  var r = parseInt(h.slice(0, 2), 16)
  var g = parseInt(h.slice(2, 4), 16)
  var b = parseInt(h.slice(4, 6), 16)
  if (!isFinite(r) || !isFinite(g) || !isFinite(b))
    return null
  return { r: r, g: g, b: b }
}

function mixHex(a, b, t) {
  var A = hexRgb(a)
  var B = hexRgb(b)
  if (!A || !B)
    return a
  if (t <= 0)
    return a
  if (t >= 1)
    return b
  function chan(x, y) {
    var n = Math.round(x + (y - x) * t).toString(16)
    return n.length < 2 ? "0" + n : n
  }
  return "#" + chan(A.r, B.r) + chan(A.g, B.g) + chan(A.b, B.b)
}

function paletteStroke(palette, t) {
  if (!palette || palette.length < 2)
    return ""
  var u = Number(t)
  if (!isFinite(u))
    u = 0
  u = u - Math.floor(u)
  if (u < 0)
    u += 1
  var n = palette.length
  var x = u * n
  var i = Math.floor(x) % n
  var f = x - Math.floor(x)
  return mixHex(palette[i], palette[(i + 1) % n], f)
}

function migrateSpeed(value, fallback) {
  if (value === "slow") return 0.22
  if (value === "med") return 0.5
  if (value === "fast") return 0.82
  var n = Number(value)
  if (!isFinite(n)) return fallback
  return Math.max(0, Math.min(1, n))
}

function penRate(t) {
  t = migrateSpeed(t, 0.22)
  return 0.02 * Math.pow(1.1 / 0.02, t)
}

function speedLabel(t) {
  var rate = penRate(t)
  if (!(rate > 0)) return ""
  var s = 1 / rate
  if (s >= 9.5) return Math.round(s) + "s / figure"
  return s.toFixed(1) + "s / figure"
}

function penMax(rollingR) {
  var r = Number(rollingR)
  if (!isFinite(r)) r = 25
  return Math.max(80, Math.min(140, Math.round(r * 1.8)))
}

function copyLook(look) {
  var c = clampLook(look)
  return {
    fixedR: c.fixedR,
    rollingR: c.rollingR,
    penP: c.penP,
    epi: c.epi,
    lineWidth: c.lineWidth,
    inkMode: c.inkMode,
    strokeKey: c.strokeKey,
    paper: c.paper,
    drawSpeed: c.drawSpeed,
    keepLayers: c.keepLayers
  }
}

function presets() {
  return [
    { id: "preset.ellipse", name: "Ellipse", look: clampLook({ fixedR: 100, rollingR: 50, penP: 28 }) },
    { id: "preset.deltoid", name: "Deltoid", look: clampLook({ fixedR: 90, rollingR: 30, penP: 30 }) },
    { id: "preset.astroid", name: "Astroid", look: clampLook({ fixedR: 120, rollingR: 30, penP: 30 }) },
    { id: "preset.cardioid", name: "Cardioid", look: clampLook({ fixedR: 80, rollingR: 80, penP: 80, epi: true }) },
    { id: "preset.nephroid", name: "Nephroid", look: clampLook({ fixedR: 100, rollingR: 50, penP: 50, epi: true }) },
    { id: "preset.five", name: "Five", look: clampLook({ fixedR: 100, rollingR: 20, penP: 20 }) }
  ]
}

function wanderCatalog() {
  var list = presets()
  var out = []
  for (var i = 0; i < list.length; i++)
    out.push(list[i].look)
  out.push(clampLook({ fixedR: 110, rollingR: 22, penP: 48, lineWidth: 4 }))
  out.push(clampLook({ fixedR: 150, rollingR: 50, penP: 70, lineWidth: 3 }))
  return out
}

function looksClose(a, b) {
  if (!a || !b) return false
  return a.fixedR === b.fixedR && a.rollingR === b.rollingR && a.penP === b.penP && a.epi === b.epi
}

function lookName(look, favorites) {
  var cur = clampLook(look)
  var list = presets()
  for (var i = 0; i < list.length; i++) {
    if (looksClose(list[i].look, cur))
      return list[i].name
  }
  if (favorites && favorites.length) {
    for (var j = 0; j < favorites.length; j++) {
      var fav = favorites[j]
      if (fav && looksClose(clampLook(fav.look), cur))
        return String(fav.name || "Look")
    }
  }
  return cur.epi ? "Outside" : "Inside"
}

function nextWanderLook(current, salt) {
  var catalog = wanderCatalog()
  if (!catalog.length) return clampLook(current)
  var start = Math.abs(Math.round(Number(salt) || 0)) % catalog.length
  for (var i = 0; i < catalog.length; i++) {
    var cand = catalog[(start + i) % catalog.length]
    if (!looksClose(cand, current))
      return cand
  }
  return catalog[start]
}

function lerp(a, b, t) {
  return a + (b - a) * t
}

function smoothstep(t) {
  if (t <= 0) return 0
  if (t >= 1) return 1
  return t * t * (3 - 2 * t)
}

function lerpLook(from, to, t) {
  var a = clampLook(from)
  var b = clampLook(to)
  var u = smoothstep(t)
  var look = clampLook({
    fixedR: lerp(a.fixedR, b.fixedR, u),
    rollingR: lerp(a.rollingR, b.rollingR, u),
    penP: lerp(a.penP, b.penP, u),
    lineWidth: lerp(a.lineWidth, b.lineWidth, u),
    epi: u < 0.5 ? a.epi : b.epi,
    inkMode: u < 0.5 ? a.inkMode : b.inkMode,
    strokeKey: u < 0.5 ? a.strokeKey : b.strokeKey,
    paper: u < 0.5 ? a.paper : b.paper,
    drawSpeed: b.drawSpeed,
    keepLayers: b.keepLayers
  })
  return look
}

function visibleCount(total, progress) {
  var n = Math.round(Number(total) || 0)
  if (n < 2) return n
  var p = Number(progress)
  if (!isFinite(p)) p = 1
  if (p <= 0) return 2
  if (p >= 1) return n
  return Math.max(2, Math.round(1 + (n - 1) * p))
}

function emptyStore() {
  return { version: 1, last: null, favorites: [] }
}

function parseStore(text) {
  var store = emptyStore()
  if (!text)
    return store
  try {
    var raw = JSON.parse(text)
  } catch (e) {
    return store
  }
  if (!raw || typeof raw !== "object")
    return store
  if (raw.last)
    store.last = copyLook(raw.last)
  var list = raw.favorites
  if (Array.isArray(list)) {
    for (var i = 0; i < list.length && store.favorites.length < 12; i++) {
      var item = list[i]
      if (!item || typeof item !== "object")
        continue
      store.favorites.push({
        id: String(item.id || ("fav." + i)),
        name: String(item.name || ("Look " + (store.favorites.length + 1))),
        look: copyLook(item.look || item)
      })
    }
  }
  return store
}

function serializeStore(store) {
  var out = { version: 1, last: store.last ? copyLook(store.last) : null, favorites: [] }
  var list = store.favorites || []
  for (var i = 0; i < list.length && out.favorites.length < 12; i++) {
    out.favorites.push({
      id: String(list[i].id),
      name: String(list[i].name),
      look: copyLook(list[i].look)
    })
  }
  return JSON.stringify(out, null, 2) + "\n"
}

function nextFavoriteName(favorites) {
  return "Look " + ((favorites ? favorites.length : 0) + 1)
}

function sampleBudget(loops) {
  loops = Math.max(1, Number(loops) || 1)
  return Math.max(720, Math.min(1600, Math.round(loops * 48)))
}

function thinPoints(pts, cap) {
  if (!pts || pts.length < 2)
    return []
  cap = Math.max(2, Math.round(Number(cap) || 240))
  if (pts.length <= cap)
    return pts.slice()
  var stride = Math.ceil((pts.length - 1) / (cap - 1))
  var out = []
  for (var i = 0; i < pts.length - 1; i += stride)
    out.push(pts[i])
  out.push(pts[pts.length - 1])
  return out
}

function periodLoops(R, r) {
  R = Math.abs(Math.round(Number(R) || 0))
  r = Math.abs(Math.round(Number(r) || 0))
  if (!(r > 0))
    return 1
  return Math.max(1, r / gcd(R, r))
}

function curvePoint(R, r, p, theta, epi) {
  var rolling = epi ? (R + r) : (R - r)
  var k = r > 0 ? rolling / r : 0
  if (epi)
    return {
      x: rolling * Math.cos(theta) - p * Math.cos(k * theta),
      y: rolling * Math.sin(theta) - p * Math.sin(k * theta)
    }
  return {
    x: rolling * Math.cos(theta) + p * Math.cos(k * theta),
    y: rolling * Math.sin(theta) - p * Math.sin(k * theta)
  }
}

function pointList(R, r, p, width, height, step, epi) {
  R = Math.round(Number(R))
  r = Math.round(Number(r))
  p = Number(p)
  if (!(r > 0) || !isFinite(R) || !isFinite(p) || width < 2 || height < 2)
    return []

  var cx = width / 2
  var cy = height / 2
  var rolling = epi ? (R + r) : (R - r)
  var loops = periodLoops(R, r)
  var maxTheta = 2 * Math.PI * loops
  var budget = sampleBudget(loops)
  if (!(step > 0))
    step = maxTheta / budget
  else
    step = Math.max(step, maxTheta / budget)

  var extent = Math.abs(rolling) + Math.abs(p)
  var scale = extent > 0 ? (Math.min(width, height) * 0.42) / extent : 1
  var pts = []
  for (var theta = 0; theta < maxTheta; theta += step) {
    var pt = curvePoint(R, r, p, theta, epi)
    pts.push({ x: cx + pt.x * scale, y: cy + pt.y * scale })
  }
  if (!pts.length) {
    var only = curvePoint(R, r, p, 0, epi)
    pts.push({ x: cx + only.x * scale, y: cy + only.y * scale })
  }
  var close = curvePoint(R, r, p, 0, epi)
  var last = pts[pts.length - 1]
  if (Math.abs(last.x - (cx + close.x * scale)) > 1e-6 ||
      Math.abs(last.y - (cy + close.y * scale)) > 1e-6)
    pts.push({ x: cx + close.x * scale, y: cy + close.y * scale })
  return pts
}
