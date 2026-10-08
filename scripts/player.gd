extends CharacterBody2D
class_name SkapPlayer

signal health_changed(value)
signal defeated

var speed := 230.0
var max_health := 120
var health := 120
var facing := Vector2.DOWN
var invuln := 0.0
var dodge_timer := 0.0
var dodge_dir := Vector2.ZERO
var attack_timer := 0.0
var attack_cooldown := 0.0
var combo_step := 0
var combo_timer := 0.0
var hit_flash := 0.0
var stamina := 100.0
var max_stamina := 100.0
var perfect_guard_timer := 0.0
var combo_window := 0.0
var last_hit_time := 0.0
var lock_target: Node2D = null

var sprite: AnimatedSprite2D
var shield_sprite: AnimatedSprite2D
var sheet_ok := false
var shield_ok := false
var shielding := false
var shield_dir := Vector2.RIGHT
var last_move_dir := Vector2.DOWN
var facing_left := false
var sword_sprite: AnimatedSprite2D
var has_sword := false

func _ready():
    collision_layer = 2
    # O jogador colide com o cenário, mas não com os inimigos.
    # O dano/knockback continua sendo tratado pela lógica de combate,
    # evitando que o Max fique grudado ou travado nos inimigos.
    collision_mask = 1

    var shape := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = 13.0
    capsule.height = 34.0
    shape.shape = capsule
    shape.position = Vector2(0, 4)
    add_child(shape)

    # Max: frames already cropped/normalized from the original sprite sheet.
    sprite = AnimatedSprite2D.new()
    sprite.sprite_frames = make_sprite_frames()
    sprite.centered = true
    sprite.position = Vector2(0, -20)
    sprite.scale = Vector2(0.25, 0.25)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.z_index = 2
    sprite.visible = true
    add_child(sprite)
    sheet_ok = sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle")
    if sheet_ok:
        sprite.play("idle")

    # Shield is a separate animated pixel-art overlay. It is only visible
    # while the right mouse button is held.
    shield_sprite = AnimatedSprite2D.new()
    shield_sprite.sprite_frames = make_shield_frames()
    shield_sprite.centered = true
    shield_sprite.position = Vector2(28, -12)
    shield_sprite.scale = Vector2(0.52, 0.52)
    shield_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    shield_sprite.z_index = 3
    shield_sprite.visible = false
    add_child(shield_sprite)
    shield_ok = shield_sprite.sprite_frames != null and shield_sprite.sprite_frames.has_animation("shield")
    if shield_ok:
        shield_sprite.play("shield")

    sword_sprite = AnimatedSprite2D.new()
    sword_sprite.sprite_frames = make_sword_frames()
    sword_sprite.centered = true
    sword_sprite.position = Vector2(28, -34)
    sword_sprite.scale = Vector2(0.58, 0.58)
    sword_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sword_sprite.z_index = 4
    sword_sprite.visible = false
    add_child(sword_sprite)

    queue_redraw()

func make_sprite_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    var names := ["idle", "walk", "attack"]
    var speeds := [6.0, 9.0, 14.0]

    for row in range(3):
        var anim: String = names[row]
        frames.add_animation(anim)
        frames.set_animation_speed(anim, speeds[row])
        frames.set_animation_loop(anim, anim != "attack")
        for col in range(4):
            var path := "res://art/characters/max/frames/%s_%d.png" % [anim, col]
            if ResourceLoader.exists(path):
                var tex := load(path) as Texture2D
                if tex != null:
                    frames.add_frame(anim, tex)
    return frames

func make_shield_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    frames.add_animation("shield")
    frames.set_animation_speed("shield", 8.0)
    frames.set_animation_loop("shield", true)
    for i in range(4):
        var path := "res://art/characters/max/shield/shield_%d.png" % i
        if ResourceLoader.exists(path):
            var tex := load(path) as Texture2D
            if tex != null:
                frames.add_frame("shield", tex)
    return frames

func make_sword_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    frames.add_animation("attack")
    frames.set_animation_speed("attack", 14.0)
    frames.set_animation_loop("attack", false)
    for i in range(4):
        var path := "res://art/characters/max/sword/sword_%d.png" % i
        if ResourceLoader.exists(path):
            var tex := load(path) as Texture2D
            if tex != null:
                frames.add_frame("attack", tex)
    return frames

func _physics_process(delta):
    invuln = max(0.0, invuln - delta)
    dodge_timer = max(0.0, dodge_timer - delta)
    attack_timer = max(0.0, attack_timer - delta)
    attack_cooldown = max(0.0, attack_cooldown - delta)
    combo_timer = max(0.0, combo_timer - delta)
    combo_window = max(0.0, combo_window - delta)
    perfect_guard_timer = max(0.0, perfect_guard_timer - delta)
    last_hit_time = max(0.0, last_hit_time - delta)
    if not shielding:
        stamina = min(max_stamina, stamina + 24.0 * delta)
    hit_flash = max(0.0, hit_flash - delta)
    if combo_timer <= 0.0:
        combo_step = 0
    if Input.is_action_just_pressed("lock_on"):
        toggle_lock_on()
    if is_instance_valid(lock_target) and (lock_target.is_queued_for_deletion() or global_position.distance_to(lock_target.global_position) > 360.0):
        lock_target = null

    # Right mouse = shield. The shield can be held continuously and completely
    # cancels incoming enemy damage while active.
    var was_shielding := shielding
    shielding = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and dodge_timer <= 0.0
    if shielding and not was_shielding:
        perfect_guard_timer = 0.18
    update_shield(delta)

    if dodge_timer > 0.0:
        shielding = false
        velocity = dodge_dir * 520.0
        move_and_slide()
        update_animation(Vector2.ZERO)
        queue_redraw()
        return

    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

    # Movement direction controls Max's facing while he is not attacking.
    # This intentionally ignores the mouse, so walking left still looks left
    # even if the cursor is sitting on the right side of the screen.
    if input_dir.length() > 0.1:
        last_move_dir = input_dir.normalized()
        facing = last_move_dir
        if attack_timer <= 0.0:
            update_facing_from_movement(input_dir)

    velocity = input_dir * speed

    if Input.is_action_just_pressed("dodge") and input_dir.length() > 0.1 and dodge_timer <= 0.0 and invuln <= 0.0 and not shielding and stamina >= 24.0:
        dodge_dir = input_dir.normalized()
        dodge_timer = 0.22
        invuln = 0.32
        stamina -= 24.0
        get_tree().call_group("effects", "burst", global_position, Color("b8a2ff"), 8, 105.0)

    # Left mouse attacks. At the exact moment an attack starts, Max turns toward
    # the mouse. After the attack, normal walking direction takes control again.
    if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("attack")) and attack_cooldown <= 0.0 and attack_timer <= 0.0 and not shielding:
        do_attack()

    move_and_slide()
    global_position.x = clamp(global_position.x, 58.0, 1094.0)
    global_position.y = clamp(global_position.y, 110.0, 590.0)

    update_animation(input_dir)
    queue_redraw()

func update_facing_from_movement(input_dir: Vector2):
    if abs(input_dir.x) > 0.10:
        facing_left = input_dir.x < 0.0
        if sheet_ok:
            sprite.flip_h = facing_left
    # Pure vertical movement keeps the previous horizontal facing. This avoids
    # the character randomly swapping sides when moving up/down.

func update_animation(input_dir: Vector2):
    if is_instance_valid(sword_sprite):
        sword_sprite.visible = has_sword and attack_timer > 0.0
    if not sheet_ok:
        return

    if attack_timer > 0.0:
        sprite.play("attack")
    elif input_dir.length() > 0.1:
        sprite.play("walk")
    else:
        sprite.play("idle")

    # Do not overwrite the attack-facing direction every frame. Mouse direction
    # is sampled only by do_attack(). Walking direction is handled above.
    sprite.flip_h = facing_left

func update_shield(_delta: float):
    if not shield_ok:
        return

    shield_sprite.visible = shielding
    if not shielding:
        return

    var mouse_delta := get_global_mouse_position() - global_position
    if mouse_delta.length() > 0.1:
        shield_dir = mouse_delta.normalized()

    # The shield graphic points upward in its source image, so rotate it to the
    # direction of the mouse. Its position follows that direction too.
    shield_sprite.position = shield_dir * 28.0 + Vector2(0, -10)
    shield_sprite.rotation = shield_dir.angle() + PI * 0.5
    shield_sprite.flip_h = false
    if shield_sprite.animation != "shield" or not shield_sprite.is_playing():
        shield_sprite.play("shield")

func do_attack():
    var dir := (lock_target.global_position - global_position) if is_instance_valid(lock_target) else (get_global_mouse_position() - global_position)
    if dir.length() < 0.1:
        dir = facing
    dir = dir.normalized()
    facing = dir

    # Only attacking changes Max's side based on the mouse.
    if abs(dir.x) > 0.10:
        facing_left = dir.x < 0.0
        if sheet_ok:
            sprite.flip_h = facing_left

    combo_step = combo_step + 1 if combo_timer > 0.0 else 1
    combo_step = clamp(combo_step, 1, 3)
    combo_timer = 0.62
    attack_timer = 0.20
    combo_window = 0.42
    if has_sword and is_instance_valid(sword_sprite):
        sword_sprite.visible = true
        # The source sword is centered, so offset it along the attack vector
        # until the hilt sits by Max's hand instead of over his torso.
        sword_sprite.position = Vector2(0, -23) + dir * 38.0
        sword_sprite.rotation = dir.angle()
        sword_sprite.flip_h = dir.x < 0.0
        sword_sprite.flip_v = false
        sword_sprite.play("attack")
    attack_cooldown = 0.27 if combo_step < 3 else 0.50
    get_tree().call_group("effects", "slash", global_position, dir, combo_step)

    var damages := [0, 10, 15, 24]
    var ranges := [0.0, 66.0, 72.0, 82.0]
    var damage: int = int(round(float(damages[combo_step]) * (1.2 if has_sword else 1.0) * (1.0 + float(combo_step - 1) * 0.12)))
    var reach: float = ranges[combo_step]
    for e in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(e):
            continue
        var to_e: Vector2 = e.global_position - global_position
        var dist := to_e.length()
        if dist <= reach and dist > 0.0 and dir.dot(to_e.normalized()) > 0.35:
            e.take_damage(damage, dir)
            get_tree().call_group("effects", "floating_damage", e.global_position + Vector2(0,-35), damage, combo_step == 3)
            get_tree().call_group("effects", "impact", e.global_position, Color("f0c36b"))

    var boss := get_tree().get_first_node_in_group("boss")
    if is_instance_valid(boss):
        var to_boss: Vector2 = boss.global_position - global_position
        if to_boss.length() <= reach + 20.0 and dir.dot(to_boss.normalized()) > 0.25:
            boss.damage(damage, dir)
            get_tree().call_group("effects", "floating_damage", boss.global_position + Vector2(0,-80), damage, combo_step == 3)
            get_tree().call_group("effects", "impact", boss.global_position, Color("d98cff"))


func toggle_lock_on():
    if is_instance_valid(lock_target):
        lock_target = null
        get_tree().call_group("effects", "burst", global_position, Color("b8a2ff"), 6, 70.0)
        return
    var nearest: Node2D = null
    var best := 360.0
    for e in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(e):
            continue
        var d := global_position.distance_to(e.global_position)
        if d < best:
            best = d
            nearest = e
    var b := get_tree().get_first_node_in_group("boss")
    if is_instance_valid(b):
        var bd := global_position.distance_to(b.global_position)
        if bd < best:
            nearest = b
    lock_target = nearest
    if is_instance_valid(lock_target):
        get_tree().call_group("effects", "burst", lock_target.global_position, Color("e4c8ff"), 8, 80.0)

func attack_point() -> Vector2:
    return global_position + facing * 65.0

func is_attacking() -> bool:
    return attack_timer > 0.0

func is_blocking() -> bool:
    return shielding

func damage(amount: int):
    # Shield has absolute priority over incoming damage.
    if shielding:
        return
    if invuln > 0.0:
        return
    health = max(0, health - amount)
    invuln = 0.65
    hit_flash = 0.18
    health_changed.emit(health)
    if health <= 0:
        defeated.emit()

func take_damage(amount: float, knock_dir: Vector2 = Vector2.ZERO):
    # Perfect guard: the first fraction of a second of a shield reflects attacks.
    if shielding:
        if perfect_guard_timer > 0.0:
            perfect_guard_timer = 0.0
            invuln = 0.35
            get_tree().call_group("effects", "burst", global_position + knock_dir.normalized() * 30.0, Color("ffe59a"), 18, 180.0)
            get_tree().call_group("effects", "floating_text", global_position + Vector2(0,-42), "PARRY!", true)
            if knock_dir.length() > 0.01:
                for e in get_tree().get_nodes_in_group("enemies"):
                    if is_instance_valid(e) and e.global_position.distance_to(global_position) < 105.0 and e.has_method("parry_stagger"):
                        e.parry_stagger(knock_dir)
            var b := get_tree().get_first_node_in_group("boss")
            if is_instance_valid(b) and b.global_position.distance_to(global_position) < 125.0 and b.has_method("parry_stagger"):
                b.parry_stagger(knock_dir)
        return
    if invuln > 0.0:
        return
    damage(int(amount))
    if knock_dir.length() > 0.01 and not shielding:
        velocity = knock_dir.normalized() * 180.0

func _draw():
    if sheet_ok:
        # Keep the sprite permanently visible. Hit feedback uses tint only.
        sprite.visible = true
        sprite.modulate = Color("ffb8b8") if hit_flash > 0.0 else Color.WHITE
        return

    draw_circle(Vector2.ZERO, 16, Color("d2a679"))
    draw_rect(Rect2(-14, 5, 28, 24), Color("263d62"), true)
    draw_line(Vector2.ZERO, facing * 27, Color("e7c27d"), 4)
    if attack_timer > 0.0:
        draw_arc(facing * 48, 38, facing.angle() - 1.1, facing.angle() + 1.1, 20, Color("e7d58b"), 5.0, true)
