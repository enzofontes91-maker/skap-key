extends Node2D
class_name SkapEffects

var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready():
    add_to_group("effects")
    rng.randomize()
    z_index = 20

func burst(pos: Vector2, color := Color("d9c2ff"), amount := 10, power := 120.0):
    for i in range(amount):
        var a := rng.randf_range(0.0, TAU)
        var v := Vector2.from_angle(a) * rng.randf_range(power * 0.35, power)
        particles.append({"p":pos, "v":v, "life":rng.randf_range(0.25,0.55), "max":0.55, "c":color, "s":rng.randf_range(1.5,3.5)})
    rings.append({"p":pos, "r":8.0, "life":0.24, "max":0.24, "c":color})
    queue_redraw()

func slash(pos: Vector2, dir: Vector2, step := 1):
    slashes.append({"p":pos, "d":dir.normalized(), "life":0.16, "max":0.16, "step":step})
    burst(pos + dir.normalized() * 24.0, Color("f5dc86"), 4 + step, 70.0)
    queue_redraw()

func impact(pos: Vector2, color := Color("f5dc86")):
    burst(pos, color, 12, 145.0)

func floating_damage(pos: Vector2, value: int, critical := false):
    floating_text(pos, str(value), critical)

func floating_text(pos: Vector2, value: String, critical := false):
    texts.append({"p":pos, "v":Vector2(0,-34), "life":0.75, "max":0.75, "txt":value, "crit":critical})
    queue_redraw()

func _process(delta):
    for p in particles:
        p.p += p.v * delta
        p.v *= pow(0.06, delta)
        p.life -= delta
    particles = particles.filter(func(p): return p.life > 0.0)
    for r in rings:
        r.r += 190.0 * delta
        r.life -= delta
    rings = rings.filter(func(r): return r.life > 0.0)
    for s in slashes:
        s.life -= delta
    slashes = slashes.filter(func(s): return s.life > 0.0)
    for t in texts:
        t.p += t.v * delta
        t.v.y *= 0.93
        t.life -= delta
    texts = texts.filter(func(t): return t.life > 0.0)
    queue_redraw()

func _draw():
    for r in rings:
        var a: float = clampf(r.life / r.max, 0.0, 1.0)
        draw_arc(r.p, r.r, 0.0, TAU, 28, Color(r.c, a), 2.0)
    for p in particles:
        var a: float = clampf(p.life / p.max, 0.0, 1.0)
        draw_circle(p.p, p.s * a + 0.4, Color(p.c, a))
    for s in slashes:
        var a: float = clampf(s.life / s.max, 0.0, 1.0)
        var d: Vector2 = s.d
        var side := Vector2(-d.y, d.x)
        var reach := 72.0 + float(s.step) * 6.0
        var center: Vector2 = s.p + d * 28.0
        var p1 := center - d * reach * 0.42 - side * 42.0
        var p2 := center + d * reach * 0.42 + side * 42.0
        draw_arc(center, 62.0 + float(s.step) * 5.0, d.angle() - 0.72, d.angle() + 0.72, 18, Color(0.98,0.86,0.52,a), 4.0)
        draw_line(p1, p2, Color(1.0,0.95,0.76,a * 0.72), 2.0)
    for t in texts:
        var a: float = clampf(t.life / t.max, 0.0, 1.0)
        var c := Color("ffe8a3") if t.crit else Color("f2d9ff")
        var size := 14 if t.crit else 11
        draw_string(ThemeDB.fallback_font, t.p, t.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(c,a))
