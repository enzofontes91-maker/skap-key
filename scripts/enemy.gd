extends CharacterBody2D
class_name SkapEnemy

signal defeated(enemy_kind: String, position: Vector2)

var target: Node2D
var max_hp := 90.0
var hp := 90.0
var speed := 92.0
var attack_damage := 10.0
var attack_cd := 0.0
var attack_windup: float = 0.0
var attack_pending: bool = false
var stun := 0.0
var hit_flash := 0.0
var separation_radius := 38.0
var wolf := false
var sprite: AnimatedSprite2D
var sheet_ok := false

func setup(p: Node2D, is_wolf: bool):
    target = p
    wolf = is_wolf
    if wolf:
        # Zumbi verde: rápido, frágil e agressivo.
        max_hp = 105.0
        hp = max_hp
        speed = 112.0
        attack_damage = 13.0
    else:
        # Zumbi vermelho: pesado, mais resistente e anuncia o golpe antes de atacar.
        max_hp = 130.0
        hp = max_hp
        speed = 78.0
        attack_damage = 16.0
    # setup() is called immediately after add_child(), so rebuild the sprite
    # here as well. This guarantees green enemies really use the green sheet.
    if is_node_ready():
        configure_visuals()

func _ready():
    add_to_group("enemies")
    collision_layer = 4
    # Inimigos não precisam bloquear fisicamente o jogador. O combate
    # usa alcance, dano e knockback, evitando o efeito de "grudar".
    collision_mask = 1 | 4
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 15.0
    shape.shape = circle
    add_child(shape)
    configure_visuals()

func configure_visuals():
    if is_instance_valid(sprite):
        sprite.queue_free()
    sprite = AnimatedSprite2D.new()
    sprite.sprite_frames = make_sprite_frames()
    sprite.centered = true
    sprite.scale = Vector2(0.25, 0.25)
    sprite.z_index = 2
    add_child(sprite)
    sheet_ok = ResourceLoader.exists(get_sheet_path())
    if sheet_ok:
        sprite.play("idle")

func get_sheet_path() -> String:
    return "res://art/characters/enemies/wolf_sheet.png" if wolf else "res://art/characters/enemies/cultist_sheet.png"

func make_sprite_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    var path := get_sheet_path()
    if not ResourceLoader.exists(path):
        for anim in ["idle", "walk", "attack"]:
            frames.add_animation(anim)
            frames.set_animation_speed(anim, 8.0 if anim != "attack" else 14.0)
            frames.set_animation_loop(anim, anim != "attack")
        return frames
    var tex := load(path) as Texture2D
    var frame_w: int = int(tex.get_width() / 4)
    var frame_h: int = int(tex.get_height() / 3)
    var names := ["idle", "walk", "attack"]
    for row in range(3):
        var anim: String = names[row]
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 8.0 if anim != "attack" else 14.0)
        frames.set_animation_loop(anim, anim != "attack")
        for col in range(4):
            var atlas := AtlasTexture.new()
            atlas.atlas = tex
            atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
            frames.add_frame(anim, atlas)
    return frames

func _physics_process(delta):
    attack_cd = max(0.0, attack_cd - delta)
    if attack_windup > 0.0:
        attack_windup = max(0.0, attack_windup - delta)
    stun = max(0.0, stun - delta)
    hit_flash = max(0.0, hit_flash - delta)
    if not is_instance_valid(target):
        return
    if stun > 0.0:
        velocity = velocity.move_toward(Vector2.ZERO, 850.0 * delta)
        move_and_slide()
        update_sprite("idle")
        return

    var to_target: Vector2 = target.global_position - global_position
    var dist := to_target.length()
    var separation := Vector2.ZERO
    for other in get_tree().get_nodes_in_group("enemies"):
        if other == self or not is_instance_valid(other):
            continue
        var away: Vector2 = global_position - other.global_position
        var d := away.length()
        if d > 0.0 and d < separation_radius:
            separation += away.normalized() * ((separation_radius - d) / separation_radius)

    # Zumbi vermelho tem um golpe anunciado: ele para, prepara e só então acerta.
    if attack_pending:
        velocity = velocity.move_toward(Vector2.ZERO, 1700.0 * delta)
        update_sprite("attack")
        if attack_windup <= 0.0:
            attack_pending = false
            if is_instance_valid(target):
                var hit_dir: Vector2 = (target.global_position - global_position).normalized()
                if hit_dir.length() > 0.01 and global_position.distance_to(target.global_position) <= 86.0:
                    target.take_damage(float(attack_damage), hit_dir)
            attack_cd = 1.35
    elif dist > 58.0:
        var dir := (to_target.normalized() + separation * 1.55).normalized()
        velocity = velocity.move_toward(dir * speed, 800.0 * delta)
        update_sprite("walk")
    else:
        velocity = velocity.move_toward(Vector2.ZERO, 1300.0 * delta)
        update_sprite("idle")
        if attack_cd <= 0.0:
            if wolf:
                # Verde entra rápido no alcance e golpeia sem telegraph longo.
                target.take_damage(float(attack_damage), to_target.normalized())
                attack_cd = 1.10
                if sheet_ok:
                    sprite.play("attack")
            else:
                # Vermelho dá uma janela curta para o jogador reagir com dash/escudo.
                attack_windup = 0.52
                attack_pending = true
                if sheet_ok:
                    sprite.play("attack")
    move_and_slide()
    queue_redraw()

func update_sprite(anim: String):
    if not sheet_ok:
        return
    if sprite.animation != "attack" or not sprite.is_playing():
        sprite.play(anim)
    if abs(velocity.x) > 1.0:
        sprite.flip_h = velocity.x < 0.0

func take_damage(amount: float, dir: Vector2):
    hp -= amount
    stun = 0.20
    hit_flash = 0.12
    velocity = dir * 300.0
    if hp <= 0.0:
        defeated.emit("green" if wolf else "red", global_position)
        get_tree().call_group("effects", "impact", global_position, Color("9be18c") if wolf else Color("df7180"))
        queue_free()
    queue_redraw()

func damage(amount: int, dir: Vector2):
    take_damage(float(amount), dir)

func parry_stagger(dir: Vector2):
    stun = 0.75
    attack_pending = false
    attack_windup = 0.0
    velocity = dir.normalized() * 420.0
    get_tree().call_group("effects", "burst", global_position, Color("ffe7a1"), 10, 130.0)

func _draw():
    if sheet_ok:
        sprite.visible = not (hit_flash > 0.0 and int(hit_flash * 30.0) % 2 == 0)
    else:
        var body := Color("7d3434") if not wolf else Color("596d76")
        if hit_flash > 0.0:
            body = Color("f4e7d0")
        draw_circle(Vector2(0, -8), 12, body)
        draw_rect(Rect2(-13, 2, 26, 24), Color("312b38"), true)
        draw_circle(Vector2(-5, -9), 2, Color("e7c86d"))
        draw_circle(Vector2(5, -9), 2, Color("e7c86d"))
    # Telegráfico do golpe do zumbi vermelho.
    if not wolf and attack_windup > 0.0:
        draw_rect(Rect2(-22, -68, 44, 4), Color("211925"), true)
        draw_rect(Rect2(-21, -67, 42.0 * clampf(1.0 - attack_windup / 0.52, 0.0, 1.0), 2), Color("e7b85f"), true)

    # Barra de vida sempre visível, inclusive quando o inimigo usa sprite.
    var bar_w := 52.0
    var bar_x := -bar_w * 0.5
    draw_rect(Rect2(bar_x, -58, bar_w, 7), Color("211925"), true)
    draw_rect(Rect2(bar_x + 1, -57, (bar_w - 2) * clamp(hp / max_hp, 0.0, 1.0), 5), Color("d94f61") if not wolf else Color("74c96b"), true)
    draw_rect(Rect2(bar_x, -58, bar_w, 7), Color("c9b5d4"), false, 1.0)
