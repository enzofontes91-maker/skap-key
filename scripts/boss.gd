extends CharacterBody2D

signal defeated
var target: Node2D
var max_health := 360
var health := 360
var cooldown := 0.0
var special_cd := 2.2
var flash := 0.0
var stun := 0.0
var phase := 1
var sprite: AnimatedSprite2D
var sheet_ok := false

func _ready():
    add_to_group("boss")
    collision_layer = 4
    collision_mask = 4
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 42.0
    shape.shape = circle
    add_child(shape)
    sprite = AnimatedSprite2D.new()
    sprite.sprite_frames = make_sprite_frames()
    sprite.centered = true
    sprite.scale = Vector2(0.25, 0.25)
    sprite.z_index = 2
    add_child(sprite)
    sheet_ok = ResourceLoader.exists("res://art/characters/lucy/lucy_sheet.png")
    if sheet_ok:
        sprite.play("idle")

func make_sprite_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    var path := "res://art/characters/lucy/lucy_sheet.png"
    if not ResourceLoader.exists(path):
        for anim in ["idle", "walk", "attack"]:
            frames.add_animation(anim)
            frames.set_animation_speed(anim, 8.0 if anim != "attack" else 12.0)
            frames.set_animation_loop(anim, anim != "attack")
        return frames
    var tex := load(path) as Texture2D
    var frame_w: int = int(tex.get_width() / 4)
    var frame_h: int = int(tex.get_height() / 3)
    for row in range(3):
        var anim: String = ["idle", "walk", "attack"][row]
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 8.0 if anim != "attack" else 12.0)
        frames.set_animation_loop(anim, anim != "attack")
        for col in range(4):
            var atlas := AtlasTexture.new()
            atlas.atlas = tex
            atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
            frames.add_frame(anim, atlas)
    return frames

func setup(p: Node2D):
    target = p

func _physics_process(delta):
    if not is_instance_valid(target):
        return
    cooldown = max(0.0, cooldown - delta)
    special_cd = max(0.0, special_cd - delta)
    flash = max(0.0, flash - delta)
    stun = max(0.0, stun - delta)
    if health <= 180 and phase == 1:
        phase = 2
        special_cd = 0.2
        get_tree().call_group("effects", "burst", global_position, Color("d98cff"), 30, 220.0)
        get_tree().call_group("main", "boss_phase", 2)

    if stun > 0.0:
        velocity = velocity.move_toward(Vector2.ZERO, 1800.0 * delta)
        move_and_slide()
        queue_redraw()
        return

    var d: Vector2 = target.global_position - global_position
    var dist := d.length()
    var speed := 82.0 if phase == 1 else 105.0
    if dist > 165.0:
        velocity = d.normalized() * speed
        if sheet_ok: sprite.play("walk")
    else:
        velocity = Vector2.ZERO
        if sheet_ok: sprite.play("idle")

    if abs(velocity.x) > 1.0 and sheet_ok:
        sprite.flip_h = velocity.x < 0.0
    move_and_slide()

    if special_cd <= 0.0:
        special_cd = 3.0 if phase == 1 else 2.15
        if phase == 1:
            cast_ring()
        else:
            cast_burst()

    if dist < (125.0 if phase == 1 else 145.0) and cooldown <= 0.0:
        target.take_damage(16.0 if phase == 1 else 21.0, d.normalized())
        cooldown = 1.0 if phase == 1 else 0.72
        if sheet_ok: sprite.play("attack")
        get_tree().call_group("effects", "impact", target.global_position, Color("d98cff"))
    queue_redraw()

func cast_ring():
    get_tree().call_group("effects", "burst", global_position, Color("c77ae8"), 20, 170.0)
    if is_instance_valid(target) and global_position.distance_to(target.global_position) < 250.0:
        target.take_damage(12.0, (target.global_position - global_position).normalized())

func cast_burst():
    get_tree().call_group("effects", "burst", global_position, Color("ff77b6"), 34, 240.0)
    if is_instance_valid(target):
        var dist := global_position.distance_to(target.global_position)
        if dist < 310.0:
            target.take_damage(18.0, (target.global_position - global_position).normalized())
    velocity = (target.global_position - global_position).normalized() * 260.0

func damage(amount: int, knock: Vector2):
    health = max(0, health - amount)
    flash = 0.14
    velocity = knock * 330.0
    get_tree().call_group("effects", "floating_damage", global_position + Vector2(0,-82), amount, amount >= 30)
    get_tree().call_group("effects", "impact", global_position, Color("e4a0ff"))
    if health <= 0:
        defeated.emit()
        queue_free()

func parry_stagger(dir: Vector2):
    stun = 1.0
    cooldown = 1.0
    special_cd = max(special_cd, 1.0)
    velocity = dir.normalized() * 360.0
    get_tree().call_group("effects", "burst", global_position, Color("fff0aa"), 22, 190.0)

func _draw():
    if sheet_ok:
        sprite.visible = not (flash > 0.0 and int(flash * 60.0) % 2 == 0)
    else:
        if flash > 0.0 and int(flash * 60.0) % 2 == 0:
            return
        var aura := Color("8e3eb1") if phase == 1 else Color("d52f88")
        draw_circle(Vector2.ZERO, 68.0, Color(aura,0.08))
        draw_circle(Vector2(0,8),48,Color("261b38"))
        draw_colored_polygon(PackedVector2Array([Vector2(-42,20),Vector2(-28,-34),Vector2(-14,-58),Vector2(0,-48),Vector2(15,-60),Vector2(31,-34),Vector2(44,20)]),Color("5b285f"))
        draw_circle(Vector2(0,-30),24,Color("e0aa82"))
        draw_colored_polygon(PackedVector2Array([Vector2(-25,-31),Vector2(-20,-62),Vector2(-4,-48),Vector2(10,-67),Vector2(27,-31)]),Color("17121f"))
        draw_circle(Vector2(-9,-31),4,Color("d95cff"))
        draw_circle(Vector2(9,-31),4,Color("d95cff"))
        draw_circle(Vector2(0,8),8,Color("f0c85d"))
    var bar_w := 130.0
    var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
    draw_rect(Rect2(-bar_w * 0.5, -92, bar_w, 10), Color("211925"), true)
    draw_rect(Rect2(-bar_w * 0.5 + 1, -91, (bar_w - 2) * ratio, 8), Color("d45bdb") if phase == 1 else Color("ef4d91"), true)
    draw_rect(Rect2(-bar_w * 0.5, -92, bar_w, 10), Color("e0c8ea"), false, 1.0)
    draw_string(ThemeDB.fallback_font, Vector2(-55,-101), "LUCY  •  FASE %d" % phase, HORIZONTAL_ALIGNMENT_CENTER, 110, 11, Color("ead7ff"))
