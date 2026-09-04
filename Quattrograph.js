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

function pointList(R, r, p, width, height, step) {
  if (!(r > 0) || width < 2 || height < 2)
    return []

  var cx = width / 2
  var cy = height / 2
  var k = (R - r) / r
  var loops = Math.min(40, Math.max(1, r / gcd(R, r)))
  var maxTheta = 2 * Math.PI * loops
  if (!(step > 0))
    step = 0.02

  var extent = Math.abs(R - r) + Math.abs(p)
  var scale = extent > 0 ? (Math.min(width, height) * 0.42) / extent : 1
  var pts = []
  for (var theta = 0; theta <= maxTheta; theta += step) {
    var x = (R - r) * Math.cos(theta) + p * Math.cos(k * theta)
    var y = (R - r) * Math.sin(theta) - p * Math.sin(k * theta)
    pts.push({ x: cx + x * scale, y: cy + y * scale })
  }
  return pts
}

function svgPath(R, r, p, width, height, step) {
  var pts = pointList(R, r, p, width, height, step)
  if (pts.length < 2)
    return ""

  var d = "M " + pts[0].x.toFixed(2) + " " + pts[0].y.toFixed(2)
  for (var i = 1; i < pts.length; i++)
    d += " L " + pts[i].x.toFixed(2) + " " + pts[i].y.toFixed(2)
  return d
}
