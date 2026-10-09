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

// Slider 0 draws a figure in 50s. Slider 1 draws one in about 0.9s.
// 10s is the pace Wander starts on.
function defaultPace() {
  return Math.log(0.1 / 0.02) / Math.log(1.1 / 0.02)
}

function defaultLook() {
  return {
    fixedR: 100,
    rollingR: 25,
    penP: 40,
    epi: false,
    lineWidth: 3,
    inkMode: "theme",
    drawSpeed: defaultPace()
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
    drawSpeed: migrateSpeed(o.drawSpeed, d.drawSpeed)
  }
  if (!isFinite(look.fixedR)) look.fixedR = d.fixedR
  if (!isFinite(look.rollingR)) look.rollingR = d.rollingR
  if (!isFinite(look.penP)) look.penP = d.penP
  if (!isFinite(look.lineWidth)) look.lineWidth = d.lineWidth
  look.fixedR = Math.max(40, Math.min(220, Math.round(look.fixedR)))
  look.rollingR = Math.max(8, Math.min(100, Math.round(look.rollingR)))
  look.penP = Math.max(0, Math.min(penMax(look.rollingR), Math.round(look.penP)))
  look.lineWidth = Math.max(1, Math.min(8, Math.round(look.lineWidth)))
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
  t = migrateSpeed(t, defaultPace())
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
    drawSpeed: c.drawSpeed
  }
}

function looksClose(a, b) {
  if (!a || !b) return false
  return a.fixedR === b.fixedR && a.rollingR === b.rollingR && a.penP === b.penP && a.epi === b.epi
}

function lookName(look, favorites) {
  var cur = clampLook(look)
  if (favorites && favorites.length) {
    for (var j = 0; j < favorites.length; j++) {
      var fav = favorites[j]
      if (fav && looksClose(clampLook(fav.look), cur))
        return String(fav.name || "Saved")
    }
  }
  return cur.epi ? "Outside" : "Inside"
}

function hashUnit(n) {
  var x = Math.sin(n) * 10000
  return x - Math.floor(x)
}

function nextWanderLook(current, salt) {
  var base = Math.abs(Math.round(Number(salt) || 0))
  for (var i = 0; i < 12; i++) {
    var s = base + 1 + i
    var rollingR = 8 + Math.floor(hashUnit(s * 12.9898) * 93)
    var fixedR = 40 + Math.floor(hashUnit(s * 78.233) * 181)
    var look = clampLook({
      fixedR: fixedR,
      rollingR: rollingR,
      penP: Math.floor(hashUnit(s * 39.346) * (penMax(rollingR) + 1)),
      epi: hashUnit(s * 11.713) >= 0.5
    })
    if (!looksClose(look, current))
      return look
  }
  var fallback = clampLook(current)
  fallback.epi = !fallback.epi
  return fallback
}

function nextSavedLook(current, favorites) {
  var list = []
  var at = -1
  var cur = clampLook(current)
  for (var i = 0; i < (favorites ? favorites.length : 0); i++) {
    var item = favorites[i]
    if (!item || !item.look)
      continue
    var look = clampLook(item.look)
    if (at < 0 && looksClose(look, cur))
      at = list.length
    list.push(look)
  }
  if (!list.length)
    return null
  return list[at < 0 ? 0 : (at + 1) % list.length]
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
    drawSpeed: b.drawSpeed
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
  return Math.max(1000, Math.min(2200, Math.round(loops * 64)))
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
