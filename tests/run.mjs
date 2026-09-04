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
eq("path is default-ish", clamped.inkMode, "path")

eq("penMax 25", ctx.penMax(25), 80)
eq("penMax 80", ctx.penMax(80), 140)

eq("snap 100,24 toward 25", ctx.snapRolling(100, 24), 25)
eq("snap 100,19 toward 20", ctx.snapRolling(100, 19), 20)

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

const pts = ctx.pointList(100, 25, 40, 400, 400, 0.05, false)
if (pts.length < 20) {
  failed++
  console.error("FAIL pointList too short", pts.length)
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
approx("penRate glacial", ctx.penRate(0), 0.035, 1e-6)
approx("penRate brisk", ctx.penRate(1), 2.5, 1e-6)
eq("migrate slow", ctx.migrateSpeed("slow", 0.28), 0.22)
eq("named deltoid", ctx.presets()[1].name, "Deltoid")
eq("named cardioid", ctx.presets()[3].name, "Cardioid")
eq("lookName deltoid", ctx.lookName({ fixedR: 90, rollingR: 30, penP: 30 }, []), "Deltoid")
eq("lookName cardioid", ctx.lookName({ fixedR: 80, rollingR: 80, penP: 80, epi: true }, []), "Cardioid")
eq("lookName hypo fallback", ctx.lookName({ fixedR: 111, rollingR: 22, penP: 48 }, []), "Hypo")
eq("lookName epi fallback", ctx.lookName({ fixedR: 150, rollingR: 50, penP: 70, epi: true }, []), "Epi")
eq("lookName favorite", ctx.lookName({ fixedR: 90, rollingR: 25, penP: 40 }, [
  { name: "Mine", look: { fixedR: 90, rollingR: 25, penP: 40 } }
]), "Mine")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("ok")
