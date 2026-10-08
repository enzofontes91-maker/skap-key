extends Area2D
class_name SkapDart

var speed: float = 430.0
var damage_amount: int = 9999
var active: bool = true

func _ready():
    collision_layer = 8
    collision_mask = 2
    monitoring = true
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(38, 10)
    shape.shape = rect
    add_child(shape)
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _physics_process(delta: float):
    if not active:
        return
    position.x -= speed * delta
    if position.x < -60.0:
        active = false
        queue_free()
    queue_redraw()

func _on_body_entered(body: Node2D):
    if not active:
        return
    if body is SkapPlayer:
        var player := body as SkapPlayer
        player.damage(damage_amount)
        active = false
        queue_free()

func _draw():
    var dark := Color("17131c")
    var metal := Color("d7c9aa")
    var gold := Color("b98d4d")
    draw_line(Vector2(-18, 0), Vector2(13, 0), dark, 7.0, true)
    draw_line(Vector2(-16, 0), Vector2(12, 0), metal, 3.0, true)
    draw_colored_polygon(PackedVector2Array([
        Vector2(12, -6), Vector2(24, 0), Vector2(12, 6)
    ]), dark)
    draw_colored_polygon(PackedVector2Array([
        Vector2(12, -3), Vector2(20, 0), Vector2(12, 3)
    ]), gold)
    draw_line(Vector2(-18, -5), Vector2(-10, 0), dark, 3.0, true)
    draw_line(Vector2(-18, 5), Vector2(-10, 0), dark, 3.0, true)
