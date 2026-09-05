#!/usr/bin/env node
// Pure-logic tests for Quattrograph.js. Omarchy has no plugin test runner;
// this is the part we can prove without a display.
import { readFileSync } from "node:fs"
import { createContext, runInContext } from "node:vm"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const source = readFileSync(join(root, "Quattrograph.js"), "utf8").replace(/^\.pragma library\s*/, "")
const ctx = createContext({ Math, Number, String, Array, JSON, isFinite, Date })
runInContext(source, ctx)

let failed = 0
function eq(name, got, want) {
  const ok = Object.is(got, want) || JSON.stringify(got) === JSON.stringify(want)
  if (!ok) {
    failed++
    console.error("FAIL", name, "got", got, "want", want)
  }
}

function approx(name, got, want, eps) {
  if (Math.abs(got - want) > (eps || 1e-6)) {
    failed++
    console.error("FAIL", name, "got", got, "want", want)
  }
}

eq("gcd 100,25", ctx.gcd(100, 25), 25)
eq("gcd 14,21", ctx.gcd(14, 21), 7)

const clamped = ctx.clampLook({ fixedR: 9, rollingR: 400, penP: -3, lineWidth: 99, strokeKey: "nope", inkMode: "path" })
eq("clamp R min", clamped.fixedR, 40)
eq("clamp r max", clamped.rollingR, 100)
eq("clamp p min", clamped.penP, 0)
eq("clamp width max", clamped.lineWidth, 8)
eq("clamp stroke fallback", clamped.strokeKey, "accent")
eq("explicit path stays", clamped.inkMode, "path")
eq("default ink is theme", ctx.clampLook({}).inkMode, "theme")
eq("solid migrates to theme", ctx.clampLook({ inkMode: "solid" }).inkMode, "theme")
eq("theme ink stays", ctx.clampLook({ inkMode: "theme" }).inkMode, "theme")
eq("migrateInk solid", ctx.migrateInk("solid", "theme"), "theme")
eq("migrateInk path", ctx.migrateInk("path", "theme"), "path")

const pal = ctx.themePalette([
  'bright_red = "#111111"',
  'red = "#Ff0000"',
  'yellow = "#ffff00"',
  'green = "#00ff00"',
  'cyan = "#00ffff"',
  'blue = "#0000ff"',
  'magenta = "#ff00ff"'
].join("\n"))
eq("palette skips bright_red", pal.indexOf("#111111"), -1)
eq("palette length without orange", pal.length, 6)
eq("palette red first", pal[0], "#ff0000")
eq("palette magenta last", pal[5], "#ff00ff")
eq("paletteStroke start", ctx.paletteStroke(pal, 0), "#ff0000")
eq("paletteStroke empty", ctx.paletteStroke([], 0.2), "")
eq("mixHex midpoint", ctx.mixHex("#000000", "#00ff00", 0.5), "#008000")

eq("penMax 25", ctx.penMax(25), 80)
eq("penMax 80", ctx.penMax(80), 140)

eq("visibleCount empty", ctx.visibleCount(0, 1), 0)
eq("visibleCount start", ctx.visibleCount(100, 0), 2)
eq("visibleCount full", ctx.visibleCount(100, 1), 100)
eq("visibleCount half", ctx.visibleCount(101, 0.5), 51)

approx("smoothstep 0", ctx.smoothstep(0), 0)
approx("smoothstep 1", ctx.smoothstep(1), 1)
approx("smoothstep .5", ctx.smoothstep(0.5), 0.5)

const a = ctx.clampLook({ fixedR: 100, rollingR: 20, penP: 10 })
const b = ctx.clampLook({ fixedR: 200, rollingR: 40, penP: 30, epi: true })
const mid = ctx.lerpLook(a, b, 0.5)
eq("lerp R midpoint", mid.fixedR, 150)
eq("lerp epi snaps after half", mid.epi, true)

const store = ctx.parseStore('{"last":{"fixedR":120,"rollingR":30,"penP":40},"favorites":[{"name":"A","look":{"fixedR":90}}]}')
eq("parse last R", store.last.fixedR, 120)
eq("parse favorite name", store.favorites[0].name, "A")
eq("parse garbage", ctx.parseStore("nope").favorites.length, 0)

const roundTrip = ctx.parseStore(ctx.serializeStore({
  last: a,
  favorites: [{ id: "fav.1", name: "Look 1", look: b }]
}))
eq("roundtrip favorite id", roundTrip.favorites[0].id, "fav.1")
eq("roundtrip last r", roundTrip.last.rollingR, 20)

eq("period astroid", ctx.periodLoops(120, 30), 1)
eq("period five", ctx.periodLoops(100, 20), 1)
eq("period 178/60", ctx.periodLoops(178, 60), 30)
eq("period coprime", ctx.periodLoops(100, 19), 19)
eq("period r equals R", ctx.periodLoops(80, 80), 1)

function gap(list) {
  if (!list.length) return Infinity
  const a = list[0]
  const b = list[list.length - 1]
  return Math.hypot(a.x - b.x, a.y - b.y)
}

const pts = ctx.pointList(100, 25, 40, 400, 400, 0.05, false)
if (pts.length < 20) {
  failed++
  console.error("FAIL pointList too short", pts.length)
}
if (gap(pts) > 1e-6) {
  failed++
  console.error("FAIL simple curve left a gap", gap(pts))
}

const cases = [
  [40, 8, 8, false],
  [40, 8, 8, true],
  [100, 19, 20, false],
  [100, 19, 20, true],
  [100, 100, 40, false],
  [100, 100, 40, true],
  [178, 60, 54, true],
  [220, 100, 80, false],
  [220, 100, 80, true],
  [90, 30, 30, false],
  [80, 80, 80, true]
]
for (const [R, r, p, epi] of cases) {
  const list = ctx.pointList(R, r, p, 640, 640, 0, epi)
  if (list.length < 2) {
    failed++
    console.error("FAIL too short", R, r, p, epi, list.length)
  } else if (gap(list) > 1e-6) {
    failed++
    console.error("FAIL open curve", R, r, p, epi, gap(list))
  }
}
const cx = 200
let max = 0
for (const p of pts) max = Math.max(max, Math.hypot(p.x - cx, p.y - cx))
if (max > 200) {
  failed++
  console.error("FAIL points escaped box", max)
}

const next = ctx.nextWanderLook(a, 0)
if (ctx.looksClose(next, a)) {
  failed++
  console.error("FAIL wander picked same look")
}

eq("nextFavoriteName", ctx.nextFavoriteName([{ }, { }]), "Look 3")
approx("penRate glacial", ctx.penRate(0), 0.02, 1e-6)
approx("penRate brisk", ctx.penRate(1), 1.1, 1e-6)
eq("sampleBudget one loop", ctx.sampleBudget(1), 1000)
eq("sampleBudget 30 loops", ctx.sampleBudget(30), 1920)
eq("sampleBudget cap", ctx.sampleBudget(100), 2200)
eq("thinPoints keeps ends", ctx.thinPoints([{ x: 0, y: 0 }, { x: 1, y: 1 }, { x: 2, y: 2 }, { x: 3, y: 3 }], 3).length, 3)
eq("migrate slow", ctx.migrateSpeed("slow", 0.28), 0.22)
eq("named deltoid", ctx.presets()[1].name, "Deltoid")
eq("named cardioid", ctx.presets()[3].name, "Cardioid")
eq("lookName deltoid", ctx.lookName({ fixedR: 90, rollingR: 30, penP: 30 }, []), "Deltoid")
eq("lookName cardioid", ctx.lookName({ fixedR: 80, rollingR: 80, penP: 80, epi: true }, []), "Cardioid")
eq("lookName inside fallback", ctx.lookName({ fixedR: 111, rollingR: 22, penP: 48 }, []), "Inside")
eq("lookName outside fallback", ctx.lookName({ fixedR: 150, rollingR: 50, penP: 70, epi: true }, []), "Outside")
eq("lookName favorite", ctx.lookName({ fixedR: 90, rollingR: 25, penP: 40 }, [
  { name: "Mine", look: { fixedR: 90, rollingR: 25, penP: 40 } }
]), "Mine")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("ok")
