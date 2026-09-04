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
    rollingR: 30,
    penP: 20,
    epi: false,
    lineWidth: 2,
    inkMode: "solid",
    strokeKey: "accent",
    paper: "inset"
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
    inkMode: o.inkMode === "path" ? "path" : "solid",
    strokeKey: String(o.strokeKey || d.strokeKey),
    paper: o.paper === "lift" ? "lift" : "inset"
  }
  if (!isFinite(look.fixedR)) look.fixedR = d.fixedR
  if (!isFinite(look.rollingR)) look.rollingR = d.rollingR
  if (!isFinite(look.penP)) look.penP = d.penP
  if (!isFinite(look.lineWidth)) look.lineWidth = d.lineWidth
  look.fixedR = Math.max(50, Math.min(200, Math.round(look.fixedR)))
  look.rollingR = Math.max(10, Math.min(100, Math.round(look.rollingR)))
  look.penP = Math.max(0, Math.min(80, Math.round(look.penP)))
  look.lineWidth = Math.max(1, Math.min(6, Math.round(look.lineWidth)))
  var keys = { accent: 1, foreground: 1, muted: 1, urgent: 1 }
  if (!keys[look.strokeKey]) look.strokeKey = d.strokeKey
  return look
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
    paper: c.paper
  }
}

function presets() {
  return [
    { id: "preset.classic", name: "Classic", look: clampLook({ fixedR: 100, rollingR: 30, penP: 20 }) },
    { id: "preset.cardioid", name: "Cardioid", look: clampLook({ fixedR: 100, rollingR: 50, penP: 50 }) },
    { id: "preset.nephroid", name: "Nephroid", look: clampLook({ fixedR: 120, rollingR: 40, penP: 40, epi: true }) },
    { id: "preset.ribbon", name: "Ribbon", look: clampLook({ fixedR: 110, rollingR: 35, penP: 45, inkMode: "path", lineWidth: 3 }) }
  ]
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

function pointList(R, r, p, width, height, step, epi) {
  if (!(r > 0) || width < 2 || height < 2)
    return []

  var cx = width / 2
  var cy = height / 2
  var rolling = epi ? (R + r) : (R - r)
  var k = rolling / r
  var loops = Math.min(40, Math.max(1, r / gcd(R, r)))
  var maxTheta = 2 * Math.PI * loops
  if (!(step > 0))
    step = 0.02

  var extent = Math.abs(rolling) + Math.abs(p)
  var scale = extent > 0 ? (Math.min(width, height) * 0.42) / extent : 1
  var pts = []
  for (var theta = 0; theta <= maxTheta; theta += step) {
    var x, y
    if (epi) {
      x = rolling * Math.cos(theta) - p * Math.cos(k * theta)
      y = rolling * Math.sin(theta) - p * Math.sin(k * theta)
    } else {
      x = rolling * Math.cos(theta) + p * Math.cos(k * theta)
      y = rolling * Math.sin(theta) - p * Math.sin(k * theta)
    }
    pts.push({ x: cx + x * scale, y: cy + y * scale })
  }
  return pts
}
