extends Node2D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Boss = preload("res://scripts/boss.gd")
const Dart = preload("res://scripts/dart.gd")
const Effects = preload("res://scripts/effects.gd")

var player: CharacterBody2D
var enemies: Array[Node] = []
var boss: Node = null
var area := 0
var has_key := false
var owl_seen := false
var message := ""
var message_timer := 0.0
var title_mode := true
var game_over := false
var shake := 0.0
var hp_label: Label
var hp_bar: ProgressBar
var area_label: Label
var objective_label: Label
var controls_label: Label
var cage_prompt: Label
var dialogue: Panel
var dialogue_label: Label
var dialogue_speaker: Label
var ui_font: Font
var world_walls: Array[StaticBody2D] = []
var piano_panel: Panel
var piano_hint: Label
var piano_buttons: Array[Button] = []
var piano_progress := 0
var piano_solved := false
var piano_notes := ["DÓ", "RÉ", "MI", "FÁ", "SOL", "LÁ", "SI", "DÓ"]
var piano_solution := [0, 2, 4, 5]
var intro_mode := false
var intro_phase := 0
var intro_timer := 0.0
var intro_control_enabled := false
var intro_carlo: AnimatedSprite2D
var cage_carlo: AnimatedSprite2D
var owl_sprite: AnimatedSprite2D
var owl_event_active := false
var owl_pos := Vector2(940,170)
var sword_received := false
var lucy_key_available := false
var lucy_key_pos := Vector2(850,360)
var carlo_rescued := false
var end_panel: Panel
var replay_button: Button
var piano_marks: Array[bool] = []
var death_checkpoint_area := 0
var lucy_defeated := false
var dart_total: int = 18
var dart_spawned: int = 0
var dart_spawn_timer: float = 0.8
var dart_challenge_complete: bool = false
var darts: Array[Node] = []
var title_max: AnimatedSprite2D
var title_carlo: AnimatedSprite2D
var intro_zombie_green: AnimatedSprite2D
var intro_zombie_red: AnimatedSprite2D
var effects: Node2D
var xp := 0
var level := 1
var xp_next := 100
var intelligence := 0
var level_label: Label
var xp_bar: ProgressBar
var stamina_label: Label
var combo_label: Label
var lock_label: Label
var boss_phase_label: Label

func _ready():
    add_to_group("main")
    build_ui()
    effects = Effects.new()
    add_child(effects)
    setup_title_characters()
    queue_redraw()


func add_wall(pos: Vector2, size: Vector2):
    var body := StaticBody2D.new()
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 2 | 4
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = size
    shape.shape = rect
    body.add_child(shape)
    add_child(body)
    world_walls.append(body)

func add_tree_collision(p: Vector2):
    # Only the trunk is solid, so the player can walk around the canopy.
    add_wall(p + Vector2(0, 25), Vector2(20, 38))

func build_area_collisions(id: int):
    # Map border, with openings kept clear for the two visible doors.
    add_wall(Vector2(576, 100), Vector2(1152, 12))
    add_wall(Vector2(576, 642), Vector2(1152, 12))
    add_wall(Vector2(6, 213), Vector2(12, 234))
    add_wall(Vector2(6, 540), Vector2(12, 204))
    add_wall(Vector2(1146, 213), Vector2(12, 234))
    add_wall(Vector2(1146, 540), Vector2(12, 204))

    if id == 0:
        for p in [Vector2(110,190),Vector2(250,540),Vector2(430,180),Vector2(760,160),Vector2(1020,250),Vector2(1010,540),Vector2(300,250)]:
            add_tree_collision(p)
    elif id == 1:
        # Sala do piano: sem inimigos. As quatro mesas ficam espalhadas pela sala.
        add_wall(Vector2(576, 165), Vector2(250, 18))
        for p in [Vector2(250,250), Vector2(875,250), Vector2(280,440), Vector2(850,430)]:
            add_wall(p, Vector2(118, 58))
        add_wall(Vector2(175,500), Vector2(150,38))
        add_wall(Vector2(977,500), Vector2(150,38))
    elif id == 2:
        # Collision follows the two ruins drawn in the original map.
        add_wall(Vector2(300, 500), Vector2(140, 20))
        add_wall(Vector2(300, 620), Vector2(140, 20))
        add_wall(Vector2(230, 560), Vector2(20, 120))
        add_wall(Vector2(370, 560), Vector2(20, 120))
        add_wall(Vector2(850, 155), Vector2(140, 20))
        add_wall(Vector2(850, 275), Vector2(140, 20))
        add_wall(Vector2(780, 215), Vector2(20, 120))
        add_wall(Vector2(920, 215), Vector2(20, 120))
        add_wall(Vector2(850, 170), Vector2(52, 18))
    elif id == 3:
        # Corredor dos dardos: rota livre, sem obstáculos internos.
        # O desafio vem dos projéteis que atravessam o corredor em várias alturas.
        pass
    else:
        # Sanctuary: keep the left doorway completely open so the player can enter
        # from the previous room. The old full-height wall at x=120 blocked that door.
        add_wall(Vector2(576, 140), Vector2(912, 12))
        add_wall(Vector2(576, 540), Vector2(912, 12))
        # Left wall split around the visible doorway (y=330..450).
        add_wall(Vector2(120, 220), Vector2(12, 160))
        add_wall(Vector2(120, 500), Vector2(12, 80))
        add_wall(Vector2(1032, 340), Vector2(12, 400))
        # Carlo's cage is physically solid, but has a small front gate so Max
        # can approach it and unlock it with E after collecting Lucy's key.
        if not carlo_rescued:
            add_wall(Vector2(865, 455), Vector2(150, 10))
            add_wall(Vector2(865, 560), Vector2(150, 10))
            add_wall(Vector2(935, 507), Vector2(10, 105))
            add_wall(Vector2(790, 475), Vector2(10, 40))
            add_wall(Vector2(790, 550), Vector2(10, 20))

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
        if title_mode or game_over:
            start_game()

func start_game():
    if is_instance_valid(player):
        player.queue_free()
        player = null
    clear_area()
    title_mode = false
    if is_instance_valid(title_max):
        title_max.visible = false
    if is_instance_valid(title_carlo):
        title_carlo.visible = false
    game_over = false
    intro_mode = true
    intro_phase = 0
    intro_timer = 4.5
    intro_control_enabled = false
    has_key = false
    owl_seen = false
    owl_event_active = false
    sword_received = false
    piano_solved = false
    piano_progress = 0
    piano_marks = []
    for i in range(piano_notes.size()):
        piano_marks.append(false)
    lucy_key_available = false
    carlo_rescued = false
    xp = 0
    level = 1
    xp_next = 100
    intelligence = 0
    death_checkpoint_area = 0
    lucy_defeated = false
    if is_instance_valid(end_panel):
        end_panel.visible = false
    spawn_intro_scene()
    setup_owl_sprite()
    show_message("MAX: Vamos dar uma volta na Roda-Gigante?", 4.2)

func spawn_intro_scene():
    # Intro com piso físico: nada de Max/Carlo atravessando ou flutuando pelo mapa.
    if is_instance_valid(player):
        player.queue_free()
    for wall in world_walls.duplicate():
        if is_instance_valid(wall):
            wall.queue_free()
    world_walls.clear()

    player = Player.new()
    add_child(player)
    player.position = Vector2(430,455)
    player.health_changed.connect(_on_hp)
    player.defeated.connect(_on_defeat)
    player.process_mode = Node.PROCESS_MODE_DISABLED

    # Piso, borda superior e laterais da área da cutscene.
    add_wall(Vector2(576,520), Vector2(1152,28))
    add_wall(Vector2(576,118), Vector2(1152,16))
    add_wall(Vector2(6,319), Vector2(12,400))
    add_wall(Vector2(1146,319), Vector2(12,400))

    intro_carlo = AnimatedSprite2D.new()
    intro_carlo.sprite_frames = make_carlo_frames()
    intro_carlo.position = Vector2(470,455)
    intro_carlo.scale = Vector2(0.20,0.20)
    intro_carlo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    intro_carlo.z_index = 4
    intro_carlo.play("idle")
    add_child(intro_carlo)

    # Dois perseguidores visuais reais, usados apenas durante a cutscene.
    intro_zombie_green = AnimatedSprite2D.new()
    intro_zombie_green.sprite_frames = make_sheet_character_frames("res://art/characters/enemies/wolf_sheet.png")
    intro_zombie_green.position = Vector2(790,455)
    intro_zombie_green.scale = Vector2(0.25,0.25)
    intro_zombie_green.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    intro_zombie_green.z_index = 4
    intro_zombie_green.visible = false
    add_child(intro_zombie_green)

    intro_zombie_red = AnimatedSprite2D.new()
    intro_zombie_red.sprite_frames = make_sheet_character_frames("res://art/characters/enemies/cultist_sheet.png")
    intro_zombie_red.position = Vector2(835,455)
    intro_zombie_red.scale = Vector2(0.25,0.25)
    intro_zombie_red.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    intro_zombie_red.z_index = 4
    intro_zombie_red.visible = false
    add_child(intro_zombie_red)

func make_carlo_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for anim in ["idle","walk"]:
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 7.0)
        frames.set_animation_loop(anim, true)
        for i in range(4):
            var path := "res://art/characters/carlo/frames/%s_%d.png" % [anim,i]
            if ResourceLoader.exists(path):
                var tex := load(path) as Texture2D
                if tex != null:
                    frames.add_frame(anim,tex)
    return frames

func spawn_carlo_cage():
    if is_instance_valid(cage_carlo):
        cage_carlo.queue_free()
    cage_carlo = AnimatedSprite2D.new()
    cage_carlo.sprite_frames = make_carlo_frames()
    cage_carlo.position = Vector2(865,505)
    cage_carlo.scale = Vector2(0.20,0.20)
    cage_carlo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    cage_carlo.z_index = 3
    cage_carlo.play("idle")
    add_child(cage_carlo)

func make_owl_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    var path := "res://art/characters/owl_sheet.png"
    if not ResourceLoader.exists(path):
        return frames
    var tex := load(path) as Texture2D
    var frame_w: int = int(tex.get_width() / 4)
    var frame_h: int = int(tex.get_height() / 3)
    for row in range(3):
        var anim: String = ["idle", "fly", "talk"][row]
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 7.0 if anim != "fly" else 11.0)
        frames.set_animation_loop(anim, true)
        for col in range(4):
            var atlas := AtlasTexture.new()
            atlas.atlas = tex
            atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
            frames.add_frame(anim, atlas)
    return frames

func make_character_frames(base_path: String, animations: Array[String]) -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for anim in animations:
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 7.0 if anim != "attack" else 12.0)
        frames.set_animation_loop(anim, anim != "attack")
        for i in range(4):
            var path: String = "%s/%s_%d.png" % [base_path, anim, i]
            if ResourceLoader.exists(path):
                var tex := load(path) as Texture2D
                if tex != null:
                    frames.add_frame(anim, tex)
    return frames

func make_sheet_character_frames(sheet_path: String) -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    if not ResourceLoader.exists(sheet_path):
        return frames
    var tex := load(sheet_path) as Texture2D
    if tex == null:
        return frames
    var frame_w: int = int(tex.get_width() / 4)
    var frame_h: int = int(tex.get_height() / 3)
    var names: Array[String] = ["idle", "walk", "attack"]
    for row in range(3):
        var anim: String = names[row]
        frames.add_animation(anim)
        frames.set_animation_speed(anim, 8.0 if anim != "attack" else 12.0)
        frames.set_animation_loop(anim, anim != "attack")
        for col in range(4):
            var atlas := AtlasTexture.new()
            atlas.atlas = tex
            atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
            frames.add_frame(anim, atlas)
    return frames

func setup_title_characters():
    if is_instance_valid(title_max):
        title_max.queue_free()
    if is_instance_valid(title_carlo):
        title_carlo.queue_free()

    title_max = AnimatedSprite2D.new()
    title_max.sprite_frames = make_character_frames("res://art/characters/max/frames", ["idle", "walk", "attack"])
    title_max.position = Vector2(315, 430)
    title_max.scale = Vector2(0.52, 0.52)
    title_max.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    title_max.z_index = 3
    title_max.play("idle")
    add_child(title_max)

    title_carlo = AnimatedSprite2D.new()
    title_carlo.sprite_frames = make_character_frames("res://art/characters/carlo/frames", ["idle", "walk", "attack"])
    title_carlo.position = Vector2(835, 430)
    title_carlo.scale = Vector2(0.48, 0.48)
    title_carlo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    title_carlo.z_index = 3
    title_carlo.play("idle")
    add_child(title_carlo)

func setup_owl_sprite():
    if is_instance_valid(owl_sprite):
        owl_sprite.queue_free()
    owl_sprite = AnimatedSprite2D.new()
    owl_sprite.sprite_frames = make_owl_frames()
    owl_sprite.position = owl_pos
    owl_sprite.scale = Vector2(0.28,0.28)
    owl_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    owl_sprite.z_index = 5
    owl_sprite.visible = false
    add_child(owl_sprite)

func spawn_player():
    if is_instance_valid(player):
        player.queue_free()
    player = Player.new()
    add_child(player)
    player.position = Vector2(280,390)
    player.health_changed.connect(_on_hp)
    player.defeated.connect(_on_defeat)

func clear_area():
    if is_instance_valid(piano_panel):
        piano_panel.visible = false
    for wall in world_walls:
        if is_instance_valid(wall):
            wall.queue_free()
    world_walls.clear()
    for e in enemies:
        if is_instance_valid(e):
            e.queue_free()
    enemies.clear()
    if is_instance_valid(boss):
        boss.queue_free()
    boss = null
    if is_instance_valid(cage_carlo):
        cage_carlo.queue_free()
    cage_carlo = null
    for dart in darts:
        if is_instance_valid(dart):
            dart.queue_free()
    darts.clear()

func load_area(id: int):
    area = id
    clear_area()
    if is_instance_valid(owl_sprite):
        owl_sprite.visible = (area == 0 and owl_event_active)
    build_area_collisions(area)
    player.position = Vector2(280,390)
    if area == 0:
        for p in [Vector2(700,250),Vector2(860,430),Vector2(550,520)]:
            spawn_enemy(p,true)
    elif area == 1:
        # Piano room is intentionally enemy-free. Puzzle marks/progress survive death.
        if is_instance_valid(piano_panel):
            piano_panel.visible = false
    elif area == 2:
        for p in [Vector2(710,250),Vector2(900,350),Vector2(740,520)]:
            spawn_enemy(p,false)
    elif area == 3:
        dart_spawned = 0
        dart_spawn_timer = 0.55
        # O portal fica aberto desde a entrada. Os dardos continuam surgindo
        # enquanto o jogador atravessa o corredor.
        dart_challenge_complete = true
        darts.clear()
        show_message("CORREDOR DOS DARDOS: atravesse desviando dos projéteis. O portal já está aberto!", 4.0)
    else:
        if not lucy_defeated:
            boss = Boss.new()
            add_child(boss)
            boss.position = Vector2(850,360)
            boss.setup(player)
            boss.defeated.connect(_on_boss_defeated)
        if not carlo_rescued:
            spawn_carlo_cage()
    queue_redraw()

func spawn_enemy(p: Vector2, wolf: bool):
    var e = Enemy.new()
    add_child(e)
    e.position = p
    e.setup(player,wolf)
    e.defeated.connect(_on_enemy_defeated)
    enemies.append(e)

func _process(delta):
    message_timer = max(0.0,message_timer-delta)
    shake = max(0.0,shake-delta)
    if title_mode:
        if is_instance_valid(title_max):
            title_max.visible = true
        if is_instance_valid(title_carlo):
            title_carlo.visible = true
        queue_redraw()
        return
    if game_over:
        queue_redraw()
        return
    if intro_mode:
        process_intro(delta)
        queue_redraw()
        return
    if Input.is_action_just_pressed("interact"):
        interact()
    if area == 0 and not owl_seen and not owl_event_active:
        var remaining_enemies := 0
        for e in enemies:
            if is_instance_valid(e):
                remaining_enemies += 1
        if remaining_enemies == 0:
            owl_event_active = true
            owl_pos = Vector2(940,170)
            show_message("Teresa, a coruja, vem até você...", 3.0)
    if owl_event_active and not owl_seen:
        owl_pos = owl_pos.move_toward(player.global_position + Vector2(0,-35), delta * 230.0)
        if is_instance_valid(owl_sprite):
            owl_sprite.visible = true
            owl_sprite.position = owl_pos
            owl_sprite.play("fly")
        if owl_pos.distance_to(player.global_position) < 55.0:
            owl_event_active = false
            owl_seen = true
            has_key = true
            sword_received = true
            player.has_sword = true
            if is_instance_valid(owl_sprite):
                owl_sprite.play("talk")
                owl_sprite.position = player.global_position + Vector2(0,-55)
            show_message("TERESA: Levaram Carlo para o Santuário de Lucy. Eu tenho uma espada para te ajudar. Pegue-a e siga pelo portal. Ela aumenta seu dano em 20%.", 8.0)
    if area == 3:
        process_dart_challenge(delta)

    if player.position.x > 1050 and area < 4:
        if area == 0:
            var living_enemies := 0
            for e in enemies:
                if is_instance_valid(e):
                    living_enemies += 1
            if living_enemies > 0:
                player.position.x = 1035
                show_message("O portal está selado. Derrote todos os inimigos da floresta primeiro.", 2.5)
            elif not owl_seen:
                player.position.x = 1035
                show_message("Uma coruja antiga percebeu que você derrotou os guardiões...", 3.0)
            else:
                load_area(area+1)
                player.position.x = 90
        elif area == 1 and not piano_solved:
            player.position.x = 1035
            show_message("A porta está trancada. Toque DÓ → MI → SOL → LÁ.", 2.5)
        elif area == 2:
            # As Ruínas levam ao corredor dos dardos.
            load_area(3)
            player.position.x = 90
        elif area == 3:
            # O portal está sempre aberto. O desafio é atravessar vivo, não
            # esperar uma contagem de dardos terminar.
            load_area(4)
            player.position.x = 90
        else:
            load_area(area+1)
            player.position.x = 90
    elif player.position.x < 70 and area > 0:
        load_area(area-1)
        player.position.x = 1050

    if area == 1 and is_instance_valid(piano_panel):
        var near_piano := player.global_position.distance_to(Vector2(576,190)) < 155.0
        piano_panel.visible = near_piano and not piano_solved
    if area == 4 and not carlo_rescued:
        # A chave pode ser recolhida perto de Lucy. Depois disso, E funciona
        # em toda a frente/parte superior da gaiola, sem exigir que o jogador
        # atravesse a grade ou acerte um ponto minúsculo.
        if lucy_key_available and player.global_position.distance_to(lucy_key_pos) < 62.0 and Input.is_action_just_pressed("interact"):
            lucy_key_available = false
            has_key = true
            show_message("Max encontrou a chave que Lucy deixou cair. Vá até Carlo e aperte E.", 3.0)
        var cage_center := Vector2(865,505)
        var near_cage := player.global_position.distance_to(cage_center) < 175.0
        if lucy_defeated and has_key and near_cage and Input.is_action_just_pressed("interact"):
            carlo_rescued = true
            has_key = false
            if is_instance_valid(cage_carlo):
                cage_carlo.queue_free()
                cage_carlo = null
            # Retira todas as partes da colisão da gaiola imediatamente.
            for wall in world_walls.duplicate():
                if is_instance_valid(wall) and wall.position.distance_to(Vector2(865,507)) < 100.0:
                    wall.queue_free()
                    world_walls.erase(wall)
            show_message("CARLO: Nossa... você veio me salvar!\nMAX: Claro que eu te salvaria. A gente precisa ir embora logo. Vamos!", 7.0)
            get_tree().create_timer(7.2).timeout.connect(show_ending)
    update_ui()
    queue_redraw()

func process_intro(delta):
    intro_timer -= delta
    player.velocity = Vector2.ZERO

    # 0 = subida da montanha-russa, 1 = descida, 2 = conversa,
    # 3 = captura de Carlo, 4 = zumbis atravessam o portal e somem, 5 = controle.
    if intro_phase == 0:
        var t: float = clampf(1.0 - intro_timer / 4.0, 0.0, 1.0)
        var x: float = lerpf(430.0, 705.0, t)
        var y: float = lerpf(455.0, 235.0, t)
        player.position = Vector2(x, y)
        intro_carlo.position = Vector2(x + 42.0, y)
        if intro_timer <= 0.0:
            intro_phase = 1
            intro_timer = 3.5
            show_message("CARLO: Essa Roda-Gigante é muito mais alta daqui de cima!", 3.0)
        return

    if intro_phase == 1:
        var t: float = clampf(1.0 - intro_timer / 3.5, 0.0, 1.0)
        var x: float = lerpf(705.0, 855.0, t)
        var y: float = lerpf(235.0, 455.0, t)
        player.position = Vector2(x, y)
        intro_carlo.position = Vector2(x + 42.0, y)
        if intro_timer <= 0.0:
            intro_phase = 2
            intro_timer = 3.5
            show_message("MAX: Foi uma volta boa. Agora vamos procurar a Chave do Conhecimento.", 3.5)
        return

    if intro_phase == 2:
        player.position = Vector2(855,455)
        intro_carlo.position = Vector2(897,455)
        if intro_timer <= 0.0:
            intro_phase = 3
            intro_timer = 2.2
            intro_zombie_green.visible = true
            intro_zombie_red.visible = true
            intro_zombie_green.position = Vector2(1000,455)
            intro_zombie_red.position = Vector2(1040,455)
            intro_zombie_green.play("walk")
            intro_zombie_red.play("walk")
            show_message("Os zumbis surgem da passagem e cercam Carlo!", 2.2)
        return

    if intro_phase == 3:
        var t: float = clampf(1.0 - intro_timer / 2.2, 0.0, 1.0)
        var gx: float = lerpf(1000.0, 925.0, t)
        var rx: float = lerpf(1040.0, 965.0, t)
        intro_zombie_green.position = Vector2(gx,455)
        intro_zombie_red.position = Vector2(rx,455)
        intro_zombie_green.play("walk")
        intro_zombie_red.play("walk")
        intro_carlo.position = Vector2(897.0 + 20.0 * t,455)
        if intro_timer <= 0.0:
            intro_phase = 4
            intro_timer = 2.0
            intro_carlo.position = Vector2(900,455)
            show_message("MAX: CARLO! NÃO!", 2.0)
        return

    if intro_phase == 4:
        var t: float = clampf(1.0 - intro_timer / 2.0, 0.0, 1.0)
        var portal_x: float = 1050.0
        intro_carlo.position = Vector2(900.0 + 150.0 * t, 455)
        intro_zombie_green.position = Vector2(930.0 + 120.0 * t,455)
        intro_zombie_red.position = Vector2(970.0 + 80.0 * t,455)
        intro_zombie_green.play("walk")
        intro_zombie_red.play("walk")
        if t > 0.70:
            intro_carlo.visible = false
            intro_zombie_green.visible = false
            intro_zombie_red.visible = false
        if intro_timer <= 0.0:
            intro_phase = 5
            intro_timer = 0.8
            show_message("MAX: Eu vou te buscar, Carlo!", 2.5)
        return

    if intro_phase == 5:
        if intro_timer <= 0.0:
            intro_control_enabled = true
            player.process_mode = Node.PROCESS_MODE_INHERIT
            show_message("Atravesse o portal e resgate Carlo na Floresta Encantada.", 4.0)
            intro_phase = 6
        return

    # Fase jogável: o chão físico permanece ativo e impede Max de atravessar o mapa.
    if player.position.x > 1020.0:
        finish_intro()

func finish_intro():
    intro_mode = false
    intro_control_enabled = false
    if is_instance_valid(intro_carlo):
        intro_carlo.queue_free()
        intro_carlo = null
    if is_instance_valid(intro_zombie_green):
        intro_zombie_green.queue_free()
        intro_zombie_green = null
    if is_instance_valid(intro_zombie_red):
        intro_zombie_red.queue_free()
        intro_zombie_red = null
    spawn_player()
    load_area(0)
    show_message("Max atravessa o portal. Carlo foi levado para a Floresta Encantada!", 4.5)

func process_dart_challenge(delta: float):
    # Desafio contínuo: os dardos nunca precisam acabar para liberar o portal.
    dart_spawn_timer -= delta
    if dart_spawn_timer <= 0.0:
        spawn_dart_wave(dart_spawned)
        dart_spawned += 1
        dart_spawn_timer = 0.62

func spawn_dart_wave(index: int):
    # Seis alturas, com o centro aparecendo bastante mais vezes. Isso obriga
    # o jogador a realmente se mover, em vez de simplesmente ficar no meio.
    var lanes: Array[float] = [205.0, 275.0, 345.0, 415.0, 485.0, 555.0]
    var pattern: Array[int] = [2, 3, 1, 4, 2, 3, 0, 5, 3, 2, 4, 1, 3, 2, 5, 0]
    var lane_index: int = pattern[index % pattern.size()]
    var dart := Dart.new()
    add_child(dart)
    dart.position = Vector2(1115, lanes[lane_index])
    dart.speed = 405.0 + float((index % 4) * 18)
    dart.damage_amount = 9999
    darts.append(dart)

    # Ondas alternadas com um segundo dardo criam decisões de posicionamento,
    # mas deixam uma abertura vertical para manter a dificuldade atual.
    if index % 5 == 2 or index % 7 == 4:
        var second_offsets: Array[int] = [-2, 2]
        var offset: int = second_offsets[int(index / 5) % 2]
        var second_lane: int = clampi(lane_index + offset, 0, lanes.size() - 1)
        var second := Dart.new()
        add_child(second)
        second.position = Vector2(1115, lanes[second_lane])
        second.speed = 430.0
        second.damage_amount = 14
        darts.append(second)

func combat_check():
    if not player.is_attacking():
        return
    var point = player.attack_point()
    for e in enemies.duplicate():
        if is_instance_valid(e) and point.distance_to(e.global_position) < 70.0:
            e.damage(18,player.facing)
            shake = 0.08
    if is_instance_valid(boss) and point.distance_to(boss.global_position) < 95.0:
        boss.damage(12,player.facing)
        shake = 0.08

func _on_enemy_defeated(enemy_kind: String, pos: Vector2):
    var gain := 35 if enemy_kind == "green" else 55
    intelligence += 5 if enemy_kind == "green" else 9
    gain_xp(gain, pos)

func gain_xp(amount: int, pos: Vector2):
    xp += amount
    if is_instance_valid(effects):
        effects.floating_damage(pos + Vector2(0,-12), amount, false)
    while xp >= xp_next:
        xp -= xp_next
        level += 1
        xp_next = int(round(float(xp_next) * 1.28))
        if is_instance_valid(player):
            player.max_health += 8
            player.health = player.max_health
            player.speed += 4.0
        show_message("NÍVEL %d  •  Sua determinação ficou mais forte." % level, 2.6)
        if is_instance_valid(effects):
            effects.burst(player.global_position, Color("f1d37c"), 28, 190.0)

func _hide_boss_phase():
    if is_instance_valid(boss_phase_label):
        boss_phase_label.visible = false

func boss_phase(_phase: int):
    if is_instance_valid(boss_phase_label):
        boss_phase_label.text = "FASE II  •  A MALDIÇÃO DESPERTA"
        boss_phase_label.visible = true
        get_tree().create_timer(2.4).timeout.connect(_hide_boss_phase)
    show_message("LUCY: Você ainda não entendeu o preço do conhecimento.", 2.8)

func interact():
    if area == 1 and player.position.distance_to(Vector2(576,190)) < 155.0 and not piano_solved:
        if is_instance_valid(piano_panel):
            piano_panel.visible = true
        return

func _on_piano_key_pressed(index: int):
    if area != 1 or piano_solved:
        return
    # Cada tecla pressionada fica marcada. Isso sobrevive a uma morte/reentrada.
    if index >= 0 and index < piano_marks.size():
        piano_marks[index] = true
        piano_buttons[index].modulate = Color("e7c76d")
    if index == piano_solution[piano_progress]:
        piano_progress += 1
        if piano_progress >= piano_solution.size():
            piano_solved = true
            piano_progress = piano_solution.size()
            if is_instance_valid(piano_panel):
                piano_panel.visible = false
            show_message("A melodia ecoa pela sala. A porta das Ruínas do Culto se abriu.", 3.5)
        else:
            piano_hint.text = "♪"
    else:
        piano_progress = 0
        # As marcas visuais não são apagadas e nenhuma sequência é exibida.
        piano_hint.text = "♪"

func _on_boss_defeated():
    gain_xp(250, lucy_key_pos)
    lucy_defeated = true
    boss = null
    lucy_key_available = true
    lucy_key_pos = Vector2(850,360)
    show_message("Lucy caiu. Uma chave surgiu ao lado dela. Pegue-a para libertar Carlo.", 5.0)

func _on_hp(_v):
    update_ui()

func _on_defeat():
    # Morte volta ao último local sem apagar as marcas do piano.
    death_checkpoint_area = area
    get_tree().create_timer(0.35).timeout.connect(respawn_after_death)

func respawn_after_death():
    if game_over or title_mode or intro_mode:
        return
    if not is_instance_valid(player):
        return
    player.health = player.max_health
    player.invuln = 1.0
    load_area(death_checkpoint_area)
    player.position = Vector2(280,390) if death_checkpoint_area != 4 else Vector2(300,420)
    for i in range(min(piano_buttons.size(), piano_marks.size())):
        piano_buttons[i].modulate = Color("e7c76d") if piano_marks[i] else Color.WHITE
    show_message("MAX: Ainda não acabou. Vamos tentar de novo.", 2.5)

func show_ending():
    game_over = true
    if is_instance_valid(end_panel):
        end_panel.visible = true
    if is_instance_valid(dialogue):
        dialogue.visible = false

func show_message(t: String,time := 4.0):
    message = t
    message_timer = time
    dialogue.visible = true
    var speaker := ""
    var body := t
    var colon := t.find(":")
    if colon > 0 and colon < 18:
        speaker = t.substr(0, colon).strip_edges()
        body = t.substr(colon + 1).strip_edges()
    dialogue_speaker.text = speaker if speaker != "" else "SKAP KEY"
    dialogue_label.text = body

func make_ui_box(color: Color, radius: int = 10, border_color: Color = Color("6e5a88"), border_width: int = 1) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = radius
    box.corner_radius_top_right = radius
    box.corner_radius_bottom_left = radius
    box.corner_radius_bottom_right = radius
    box.border_width_left = border_width
    box.border_width_top = border_width
    box.border_width_right = border_width
    box.border_width_bottom = border_width
    box.border_color = border_color
    box.content_margin_left = 12.0
    box.content_margin_right = 12.0
    box.content_margin_top = 7.0
    box.content_margin_bottom = 7.0
    return box

func build_ui():
    var ui := CanvasLayer.new()
    add_child(ui)
    ui.add_to_group("ui")
    ui_font = load("res://art/ui/Orbitron700.ttf") as Font

    # HUD superior: mesma linguagem pixel/fantasia do cenário e dos personagens.
    var top := Panel.new()
    top.position = Vector2(12,10)
    top.size = Vector2(1128,98)
    top.add_theme_stylebox_override("panel", make_ui_box(Color("100c17"), 5, Color("7f5aa6"), 2))
    ui.add_child(top)

    hp_label = Label.new()
    hp_label.position = Vector2(18,10)
    hp_label.size = Vector2(250,24)
    hp_label.text = "MAX   ♥ 120 / 120"
    hp_label.add_theme_font_override("font", ui_font)
    hp_label.add_theme_font_size_override("font_size",14)
    hp_label.add_theme_color_override("font_color",Color("f4e9ff"))
    top.add_child(hp_label)

    hp_bar = ProgressBar.new()
    hp_bar.position = Vector2(18,40)
    hp_bar.size = Vector2(250,16)
    hp_bar.min_value = 0.0
    hp_bar.max_value = 120.0
    hp_bar.value = 120.0
    hp_bar.show_percentage = false
    hp_bar.add_theme_stylebox_override("background", make_ui_box(Color("241b30"), 3, Color("4c3c61"), 1))
    hp_bar.add_theme_stylebox_override("fill", make_ui_box(Color("9b4d78"), 3, Color("d779a6"), 1))
    top.add_child(hp_bar)

    area_label = Label.new()
    area_label.position = Vector2(315,9)
    area_label.size = Vector2(500,31)
    area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    area_label.text = "FLORESTA ENCANTADA"
    area_label.add_theme_font_override("font", ui_font)
    area_label.add_theme_font_size_override("font_size",17)
    area_label.add_theme_color_override("font_color",Color("ead7ff"))
    top.add_child(area_label)

    controls_label = Label.new()
    controls_label.position = Vector2(825,11)
    controls_label.size = Vector2(278,50)
    controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    controls_label.text = "WASD  MOVER\nJ / ESPAÇO  ATACAR  •  E  INTERAGIR\nSHIFT  ESQUIVAR  •  RMB  DEFENDER\nTAB  TRAVAR ALVO"
    controls_label.add_theme_font_override("font", ui_font)
    controls_label.add_theme_font_size_override("font_size",8)
    controls_label.add_theme_color_override("font_color",Color("bca9d0"))
    top.add_child(controls_label)

    objective_label = Label.new()
    objective_label.position = Vector2(18,66)
    objective_label.size = Vector2(1085,23)
    objective_label.text = "OBJETIVO:"
    objective_label.add_theme_font_override("font", ui_font)
    objective_label.add_theme_font_size_override("font_size",9)
    objective_label.add_theme_color_override("font_color",Color("e8c978"))
    top.add_child(objective_label)

    level_label = Label.new()
    level_label.position = Vector2(18,82)
    level_label.size = Vector2(250,18)
    level_label.text = "NÍVEL 1  •  INT 0"
    level_label.add_theme_font_override("font", ui_font)
    level_label.add_theme_font_size_override("font_size",8)
    level_label.add_theme_color_override("font_color",Color("bca9d0"))
    top.add_child(level_label)

    xp_bar = ProgressBar.new()
    xp_bar.position = Vector2(270,82)
    xp_bar.size = Vector2(300,8)
    xp_bar.max_value = 100
    xp_bar.value = 0
    xp_bar.show_percentage = false
    xp_bar.add_theme_stylebox_override("background", make_ui_box(Color("241b30"), 2, Color("4c3c61"), 1))
    xp_bar.add_theme_stylebox_override("fill", make_ui_box(Color("6e52b5"), 2, Color("b59aff"), 1))
    top.add_child(xp_bar)

    stamina_label = Label.new()
    stamina_label.position = Vector2(585,78)
    stamina_label.size = Vector2(180,22)
    stamina_label.text = "VIGOR 100"
    stamina_label.add_theme_font_override("font", ui_font)
    stamina_label.add_theme_font_size_override("font_size",8)
    stamina_label.add_theme_color_override("font_color",Color("9ee7c1"))
    top.add_child(stamina_label)

    combo_label = Label.new()
    combo_label.position = Vector2(770,78)
    combo_label.size = Vector2(120,22)
    combo_label.text = "COMBO 0"
    combo_label.add_theme_font_override("font", ui_font)
    combo_label.add_theme_font_size_override("font_size",8)
    combo_label.add_theme_color_override("font_color",Color("f0cf76"))
    top.add_child(combo_label)

    lock_label = Label.new()
    lock_label.position = Vector2(900,78)
    lock_label.size = Vector2(200,22)
    lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lock_label.text = "TAB  TRAVAR ALVO"
    lock_label.add_theme_font_override("font", ui_font)
    lock_label.add_theme_font_size_override("font_size",8)
    lock_label.add_theme_color_override("font_color",Color("bca9d0"))
    top.add_child(lock_label)

    boss_phase_label = Label.new()
    boss_phase_label.position = Vector2(350,132)
    boss_phase_label.size = Vector2(450,30)
    boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_phase_label.text = "FASE II  •  A MALDIÇÃO DESPERTA"
    boss_phase_label.add_theme_font_override("font", ui_font)
    boss_phase_label.add_theme_font_size_override("font_size",12)
    boss_phase_label.add_theme_color_override("font_color",Color("f18ac8"))
    boss_phase_label.visible = false
    ui.add_child(boss_phase_label)

    cage_prompt = Label.new()
    cage_prompt.position = Vector2(730,415)
    cage_prompt.size = Vector2(270,34)
    cage_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cage_prompt.text = "E  •  USAR CHAVE"
    cage_prompt.add_theme_font_override("font", ui_font)
    cage_prompt.add_theme_font_size_override("font_size",11)
    cage_prompt.add_theme_color_override("font_color",Color("ffe69a"))
    cage_prompt.add_theme_stylebox_override("normal", make_ui_box(Color("120c1b"), 4, Color("c49ae3"), 2))
    cage_prompt.visible = false
    ui.add_child(cage_prompt)

    # Caixa de diálogo redesenhada: moldura pixelada, plaquinha de personagem
    # e tipografia mais pesada, para não parecer uma janela genérica do Godot.
    dialogue = Panel.new()
    dialogue.position = Vector2(48,492)
    dialogue.size = Vector2(1056,126)
    dialogue.visible = false
    dialogue.add_theme_stylebox_override("panel", make_ui_box(Color("120c1a"), 5, Color("a47dbe"), 3))
    ui.add_child(dialogue)

    var dialogue_accent := ColorRect.new()
    dialogue_accent.position = Vector2(16,8)
    dialogue_accent.size = Vector2(7,110)
    dialogue_accent.color = Color("8f63c9")
    dialogue.add_child(dialogue_accent)

    dialogue_speaker = Label.new()
    dialogue_speaker.position = Vector2(35,10)
    dialogue_speaker.size = Vector2(250,26)
    dialogue_speaker.text = "SKAP KEY"
    dialogue_speaker.add_theme_font_override("font", ui_font)
    dialogue_speaker.add_theme_font_size_override("font_size",11)
    dialogue_speaker.add_theme_color_override("font_color",Color("f0cf76"))
    dialogue.add_child(dialogue_speaker)

    dialogue_label = Label.new()
    dialogue_label.position = Vector2(35,43)
    dialogue_label.size = Vector2(985,70)
    dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_label.add_theme_font_override("font", ui_font)
    dialogue_label.add_theme_font_size_override("font_size",11)
    dialogue_label.add_theme_color_override("font_color",Color("f4edff"))
    dialogue.add_child(dialogue_label)

    # Tela final no mesmo estilo: cantos menores, bordas em camadas e botão
    # com acabamento de painel de jogo, em vez de uma caixa arredondada genérica.
    end_panel = Panel.new()
    end_panel.position = Vector2(300,174)
    end_panel.size = Vector2(552,312)
    end_panel.visible = false
    end_panel.add_theme_stylebox_override("panel", make_ui_box(Color("100b18"), 6, Color("a47dbe"), 3))
    ui.add_child(end_panel)

    var end_bar := ColorRect.new()
    end_bar.position = Vector2(18,18)
    end_bar.size = Vector2(516,5)
    end_bar.color = Color("8f63c9")
    end_panel.add_child(end_bar)

    var end_icon := Label.new()
    end_icon.position = Vector2(0,32)
    end_icon.size = Vector2(552,25)
    end_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_icon.text = "✦  FIM DO CAPÍTULO  ✦"
    end_icon.add_theme_font_override("font", ui_font)
    end_icon.add_theme_font_size_override("font_size",9)
    end_icon.add_theme_color_override("font_color",Color("a98ac7"))
    end_panel.add_child(end_icon)

    var end_title := Label.new()
    end_title.position = Vector2(0,62)
    end_title.size = Vector2(552,55)
    end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_title.text = "CARLO ESTÁ A SALVO!"
    end_title.add_theme_font_override("font", ui_font)
    end_title.add_theme_font_size_override("font_size",22)
    end_title.add_theme_color_override("font_color",Color("f1d37c"))
    end_panel.add_child(end_title)

    var end_text := Label.new()
    end_text.position = Vector2(45,125)
    end_text.size = Vector2(462,64)
    end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    end_text.text = "OS IRMÃOS CONSEGUIRAM ESCAPAR DO SANTUÁRIO DE LUCY.\nA AVENTURA CONTINUA EM BREVE..."
    end_text.add_theme_font_override("font", ui_font)
    end_text.add_theme_font_size_override("font_size",9)
    end_text.add_theme_color_override("font_color",Color("e5dced"))
    end_panel.add_child(end_text)

    replay_button = Button.new()
    replay_button.position = Vector2(145,218)
    replay_button.size = Vector2(262,55)
    replay_button.text = "JOGAR NOVAMENTE"
    replay_button.add_theme_font_override("font", ui_font)
    replay_button.add_theme_font_size_override("font_size",11)
    replay_button.add_theme_color_override("font_color",Color("f4edff"))
    replay_button.add_theme_stylebox_override("normal", make_ui_box(Color("24182f"), 3, Color("8f63c9"), 2))
    replay_button.add_theme_stylebox_override("hover", make_ui_box(Color("342047"), 3, Color("c09ae2"), 2))
    replay_button.add_theme_stylebox_override("pressed", make_ui_box(Color("171020"), 3, Color("f0cf76"), 2))
    replay_button.pressed.connect(start_game)
    end_panel.add_child(replay_button)

    piano_panel = Panel.new()
    piano_panel.position = Vector2(142,390)
    piano_panel.size = Vector2(868,205)
    piano_panel.visible = false
    piano_panel.add_theme_stylebox_override("panel", make_ui_box(Color("100b18"), 5, Color("8a6aa8"), 2))
    ui.add_child(piano_panel)

    piano_hint = Label.new()
    piano_hint.position = Vector2(0,10)
    piano_hint.size = Vector2(868,30)
    piano_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    piano_hint.text = "♪  TOQUE A MELODIA"
    piano_hint.add_theme_font_override("font", ui_font)
    piano_hint.add_theme_font_size_override("font_size",13)
    piano_hint.add_theme_color_override("font_color",Color("f0d07b"))
    piano_panel.add_child(piano_hint)

    var keyboard := Control.new()
    keyboard.position = Vector2(22,48)
    keyboard.size = Vector2(824,140)
    piano_panel.add_child(keyboard)

    var key_w: float = 96.0
    var key_h: float = 132.0
    for i in range(piano_notes.size()):
        var b := Button.new()
        b.text = ""
        b.position = Vector2(float(i) * key_w, 0)
        b.size = Vector2(key_w - 3.0, key_h)
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        b.add_theme_stylebox_override("normal", make_ui_box(Color("e7dcc2"), 3, Color("8c765b"), 2))
        b.add_theme_stylebox_override("hover", make_ui_box(Color("f2e8d2"), 3, Color("b49a70"), 2))
        b.add_theme_stylebox_override("pressed", make_ui_box(Color("d2c09b"), 3, Color("6f5b43"), 2))
        b.pressed.connect(_on_piano_key_pressed.bind(i))
        keyboard.add_child(b)
        piano_buttons.append(b)

    for i in [0, 1, 3, 4, 5, 6]:
        var black := Panel.new()
        black.position = Vector2(float(i + 1) * key_w - 27.0, 0)
        black.size = Vector2(54, 78)
        black.mouse_filter = Control.MOUSE_FILTER_IGNORE
        black.add_theme_stylebox_override("panel", make_ui_box(Color("17141a"), 3, Color("08070a"), 2))
        keyboard.add_child(black)

func update_ui():
    if not is_instance_valid(player):
        return
    hp_label.text = "MAX   ♥ %d / %d" % [player.health, player.max_health]
    if is_instance_valid(level_label): level_label.text = "NÍVEL %d  •  INT %d" % [level, intelligence]
    if is_instance_valid(xp_bar): xp_bar.max_value = xp_next; xp_bar.value = xp
    if is_instance_valid(stamina_label): stamina_label.text = "VIGOR %d" % int(player.stamina)
    if is_instance_valid(combo_label): combo_label.text = "COMBO %d" % player.combo_step
    if is_instance_valid(lock_label): lock_label.text = "ALVO: " + ("TRAVADO" if is_instance_valid(player.lock_target) else "TAB  TRAVAR ALVO")
    if is_instance_valid(hp_bar):
        hp_bar.max_value = player.max_health
        hp_bar.value = clamp(player.health, 0, player.max_health)
    var names: Array[String] = ["FLORESTA ENCANTADA","SALA DO PIANO","RUÍNAS DO CULTO","CORREDOR DOS DARDOS","SANTUÁRIO DE LUCY"]
    area_label.text = names[area]
    if area == 0:
        var living_enemies := 0
        for e in enemies:
            if is_instance_valid(e):
                living_enemies += 1
        objective_label.text = "Objetivo: derrote todos os inimigos para liberar o portal." if living_enemies > 0 else "Objetivo: o portal foi liberado. Avance pela direita."
    elif area == 1:
        objective_label.text = "Objetivo: descubra as quatro notas e toque a melodia no piano."
    elif area == 2:
        objective_label.text = "Objetivo: atravesse as Ruínas do Culto e siga para o corredor dos dardos."
    elif area == 3:
        objective_label.text = "Objetivo: atravesse o corredor desviando dos dardos. O portal está aberto."
    else:
        if carlo_rescued:
            objective_label.text = "Objetivo: Carlo está a salvo. Saia do Santuário."
        elif has_key and lucy_defeated:
            objective_label.text = "Objetivo: chegue perto da gaiola de Carlo e aperte E para usar a chave."
        elif lucy_key_available and lucy_defeated:
            objective_label.text = "Objetivo: pegue a chave que Lucy deixou cair."
        elif is_instance_valid(boss) and not lucy_defeated:
            objective_label.text = "Objetivo: derrote Lucy para conseguir a chave de Carlo."
        else:
            objective_label.text = "Objetivo: encontre Carlo."
    if is_instance_valid(cage_prompt):
        var prompt_near_cage := area == 4 and has_key and not carlo_rescued and is_instance_valid(player) and player.global_position.distance_to(Vector2(865,505)) < 175.0
        cage_prompt.visible = prompt_near_cage
    dialogue.visible = message_timer > 0.0

func _draw():
    # Pixel-art world pass: dark outlines, stepped shapes and compact palettes
    # to match the chunky character sprites.
    draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("080d14"))
    if title_mode:
        draw_title()
        return
    if intro_mode:
        draw_intro_scene()
        return

    # Framed playfield, leaving the top HUD clean.
    draw_rect(Rect2(0, 118, 1152, 530), Color("0d141d"))
    draw_rect(Rect2(8, 126, 1136, 514), Color("151b23"))

    if area == 0:
        draw_forest_scene()
    elif area == 1:
        draw_piano_room()
    elif area == 2:
        draw_ruins_scene()
    elif area == 3:
        draw_dart_corridor()
    else:
        draw_sanctuary()

    # Portals / doors retain the same gameplay meaning, but use the same
    # chunky outlined language as the character art.
    if area < 4:
        var portal_open: bool = true
        if area == 0:
            portal_open = owl_seen
        elif area == 1:
            portal_open = piano_solved
        elif area == 3:
            portal_open = true
        draw_portal(Vector2(1125, 390), portal_open, false)
    if area > 0:
        draw_portal(Vector2(27, 390), true, true)

    if is_instance_valid(player) and is_instance_valid(player.lock_target):
        var target_pos: Vector2 = player.lock_target.global_position
        draw_arc(target_pos, 30.0, 0.0, TAU, 24, Color("e8c9ff"), 2.0)
        draw_arc(target_pos, 37.0, -0.55, 0.55, 8, Color("f0cf76"), 3.0)

func draw_forest_scene():
    draw_rect(Rect2(8, 126, 1136, 514), Color("173b32"))
    # Layered grass bands give the floor depth without abandoning the original
    # cross-shaped route.
    for y in range(140, 625, 34):
        var shade: Color = Color("194238") if (y / 34) % 2 == 0 else Color("173b32")
        draw_rect(Rect2(8, y, 1136, 34), shade)
    # Dirt route, outlined in dark pixels.
    draw_rect(Rect2(8, 327, 1136, 136), Color("101b20"))
    draw_rect(Rect2(8, 334, 1136, 122), Color("725238"))
    draw_rect(Rect2(463, 126, 226, 514), Color("101b20"))
    draw_rect(Rect2(470, 126, 212, 514), Color("725238"))
    # Stepped path highlights.
    for x in range(22, 1120, 74):
        draw_rect(Rect2(x, 348 + (int(x / 74.0) % 2) * 26, 28, 7), Color("8d6948"))
    for y in range(145, 620, 74):
        draw_rect(Rect2(505 + (int(y / 74.0) % 2) * 48, y, 34, 7), Color("8d6948"))
    # Forest props, all outlined and blocky.
    var trees: Array[Vector2] = [Vector2(110,190),Vector2(250,540),Vector2(430,180),Vector2(760,160),Vector2(1020,250),Vector2(1010,540),Vector2(300,250)]
    for p in trees:
        draw_pixel_tree(p)
    for p in [Vector2(175,300),Vector2(360,500),Vector2(830,290),Vector2(965,455),Vector2(190,585),Vector2(1080,560)]:
        draw_stone(p, 1.0)
    for p in [Vector2(385,285),Vector2(785,520),Vector2(1080,200)]:
        draw_mushroom(p)
    for p in [Vector2(420,430),Vector2(720,245),Vector2(935,575)]:
        draw_firefly(p)
    # Small rune marker near the forest portal.
    draw_rune_pad(Vector2(1048, 390), Color("8f63c9"), owl_seen)

func draw_pixel_tree(p: Vector2):
    # Heavy 4-6 px outline, then stepped canopy blocks.
    draw_rect(Rect2(p.x - 11, p.y - 2, 22, 58), Color("10191a"))
    draw_rect(Rect2(p.x - 7, p.y + 2, 14, 52), Color("5a3d2d"))
    draw_rect(Rect2(p.x - 31, p.y - 42, 62, 56), Color("10191a"))
    draw_rect(Rect2(p.x - 24, p.y - 54, 48, 62), Color("10191a"))
    draw_rect(Rect2(p.x - 43, p.y - 27, 86, 38), Color("10191a"))
    draw_rect(Rect2(p.x - 28, p.y - 39, 56, 43), Color("235b42"))
    draw_rect(Rect2(p.x - 38, p.y - 18, 76, 28), Color("285f43"))
    draw_rect(Rect2(p.x - 20, p.y - 50, 40, 38), Color("2d6b4a"))
    draw_rect(Rect2(p.x - 25, p.y - 27, 16, 9), Color("3d8054"))
    draw_rect(Rect2(p.x + 10, p.y - 43, 12, 9), Color("3a7950"))
    draw_rect(Rect2(p.x - 5, p.y + 13, 10, 30), Color("68452f"))

func draw_stone(p: Vector2, scale_v: float):
    var w: float = 28.0 * scale_v
    var h: float = 17.0 * scale_v
    draw_rect(Rect2(p.x - w * 0.5 - 3, p.y - h * 0.5 - 3, w + 6, h + 6), Color("11171c"))
    draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), Color("657078"))
    draw_rect(Rect2(p.x - w * 0.28, p.y - h * 0.35, w * 0.42, 4), Color("88929a"))

func draw_mushroom(p: Vector2):
    draw_rect(Rect2(p.x - 4, p.y - 1, 8, 17), Color("16191d"))
    draw_rect(Rect2(p.x - 2, p.y + 1, 4, 13), Color("d2b68b"))
    draw_rect(Rect2(p.x - 16, p.y - 12, 32, 15), Color("17151d"))
    draw_rect(Rect2(p.x - 13, p.y - 10, 26, 10), Color("9a4d61"))
    draw_rect(Rect2(p.x - 8, p.y - 8, 4, 3), Color("f0d7b0"))
    draw_rect(Rect2(p.x + 5, p.y - 7, 4, 3), Color("f0d7b0"))

func draw_firefly(p: Vector2):
    draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), Color("e7c76d"))
    draw_rect(Rect2(p.x - 7, p.y - 1, 3, 2), Color(0.9,0.78,0.35,0.35))
    draw_rect(Rect2(p.x + 4, p.y - 1, 3, 2), Color(0.9,0.78,0.35,0.35))

func draw_rune_pad(p: Vector2, glow: Color, active: bool):
    draw_rect(Rect2(p.x - 38, p.y - 38, 76, 76), Color("11161c"))
    draw_rect(Rect2(p.x - 32, p.y - 32, 64, 64), Color("282034"))
    draw_rect(Rect2(p.x - 26, p.y - 26, 52, 52), Color("17151f"))
    draw_line(p + Vector2(-20,0), p + Vector2(20,0), glow if active else Color("4a4154"), 4.0)
    draw_line(p + Vector2(0,-20), p + Vector2(0,20), glow if active else Color("4a4154"), 4.0)
    draw_rect(Rect2(p.x - 5, p.y - 5, 10, 10), glow if active else Color("4a4154"))

func draw_portal(p: Vector2, active: bool, left_side: bool):
    var outline: Color = Color("11131a")
    var frame: Color = Color("7d6040") if not active else Color("c79a50")
    var inner: Color = Color("161722") if not active else Color("56306f")
    draw_rect(Rect2(p.x - 30, p.y - 72, 60, 144), outline)
    draw_rect(Rect2(p.x - 24, p.y - 66, 48, 132), frame)
    draw_rect(Rect2(p.x - 18, p.y - 58, 36, 116), inner)
    if active:
        for i in range(3):
            draw_rect(Rect2(p.x - 10 + i * 7, p.y - 38 - i * 3, 6, 76 + i * 6), Color("8e55b5"))
    var label_pos: Vector2 = p + Vector2(-70, 92) if left_side else p + Vector2(-88, 92)
    draw_string(ThemeDB.fallback_font, label_pos, "ABERTO" if active else "SELADO", HORIZONTAL_ALIGNMENT_LEFT, 150, 12, Color("e7c76d"))

func draw_ruins_scene():
    draw_rect(Rect2(8, 126, 1136, 514), Color("2b2938"))
    # Stone tiles with chunky seams.
    for y in range(140, 625, 48):
        for x in range(20, 1135, 64):
            var offset: int = 32 if int(y / 48.0) % 2 == 1 else 0
            draw_rect(Rect2(x + offset, y, 60, 44), Color("333344"), false, 2.0)
    # Original two ruin structures, now detailed.
    draw_ruin_detailed(Vector2(300, 520))
    draw_ruin_detailed(Vector2(850, 175))
    # Central ritual route and cracked slabs.
    draw_rect(Rect2(462, 126, 228, 514), Color("171722"))
    draw_rect(Rect2(470, 126, 212, 514), Color("4a414e"))
    for y in range(150, 620, 64):
        draw_line(Vector2(478, y), Vector2(675, y + 11), Color("5b5260"), 2.0)
    draw_rune_circle(Vector2(576, 390), Color("8d62bd"))
    for p in [Vector2(140,180),Vector2(1040,540),Vector2(150,560),Vector2(1020,210)]:
        draw_rubble(p)
    draw_torch(Vector2(430, 255), false)
    draw_torch(Vector2(720, 515), false)
    draw_banner(Vector2(540, 155), Color("69456f"))
    draw_banner(Vector2(650, 155), Color("3f526e"))

func draw_ruin_detailed(p: Vector2):
    draw_rect(Rect2(p.x - 76, p.y - 34, 152, 142), Color("11151b"))
    draw_rect(Rect2(p.x - 68, p.y - 26, 136, 126), Color("5c5967"))
    draw_rect(Rect2(p.x - 55, p.y - 13, 110, 113), Color("272733"))
    for x in [-48,-16,16,48]:
        draw_rect(Rect2(p.x + x - 9, p.y - 43, 18, 45), Color("151a20"))
        draw_rect(Rect2(p.x + x - 6, p.y - 39, 12, 40), Color("77727e"))
    draw_line(Vector2(p.x - 52, p.y + 15), Vector2(p.x - 15, p.y - 2), Color("8c8490"), 3.0)
    draw_line(Vector2(p.x + 18, p.y + 34), Vector2(p.x + 50, p.y + 18), Color("8c8490"), 3.0)
    draw_rect(Rect2(p.x - 28, p.y + 63, 56, 37), Color("3b3946"))

func draw_rubble(p: Vector2):
    draw_rect(Rect2(p.x - 22, p.y - 9, 44, 18), Color("12171d"))
    draw_rect(Rect2(p.x - 17, p.y - 13, 14, 12), Color("6b6871"))
    draw_rect(Rect2(p.x - 2, p.y - 9, 17, 9), Color("7c777f"))
    draw_rect(Rect2(p.x + 10, p.y - 5, 11, 8), Color("55545e"))

func draw_rune_circle(p: Vector2, glow: Color):
    draw_circle(p, 92, Color("14141e"))
    draw_arc(p, 74, 0, TAU, 32, Color("6d6378"), 3.0)
    draw_arc(p, 54, 0, TAU, 32, glow, 3.0)
    draw_line(p + Vector2(-38,0), p + Vector2(38,0), glow, 3.0)
    draw_line(p + Vector2(0,-38), p + Vector2(0,38), glow, 3.0)
    draw_rect(Rect2(p.x - 7, p.y - 7, 14, 14), glow)

func draw_torch(p: Vector2, purple: bool):
    var flame: Color = Color("a95cc8") if purple else Color("e5a64b")
    draw_rect(Rect2(p.x - 7, p.y, 14, 46), Color("15171b"))
    draw_rect(Rect2(p.x - 4, p.y + 3, 8, 42), Color("77523a"))
    draw_rect(Rect2(p.x - 12, p.y - 12, 24, 18), Color("17151b"))
    draw_rect(Rect2(p.x - 7, p.y - 18, 14, 18), flame)
    draw_rect(Rect2(p.x - 3, p.y - 23, 6, 9), Color("f3d18a"))

func draw_banner(p: Vector2, c: Color):
    draw_rect(Rect2(p.x - 20, p.y, 40, 78), Color("11151b"))
    draw_rect(Rect2(p.x - 16, p.y + 4, 32, 70), c)
    draw_colored_polygon(PackedVector2Array([Vector2(p.x - 16,p.y + 74),Vector2(p.x,p.y + 64),Vector2(p.x + 16,p.y + 74)]), c)

func draw_piano_room():
    draw_rect(Rect2(8,126,1136,514), Color("2a2025"))
    # Wooden floor, framed in the same dark pixel outline used by the sprites.
    for y in range(136, 630, 38):
        draw_rect(Rect2(18,y,1116,34), Color("5b3d37") if int(y / 38.0) % 2 == 0 else Color("65443c"))
        draw_line(Vector2(18,y+34), Vector2(1134,y+34), Color("271d21"), 3.0)
    # Cross-shaped carpet keeps the original navigational silhouette.
    draw_rect(Rect2(18,326,1116,140), Color("1a1720"))
    draw_rect(Rect2(470,136,212,494), Color("1a1720"))
    draw_rect(Rect2(24,334,1104,124), Color("704d58"))
    draw_rect(Rect2(478,136,196,494), Color("704d58"))
    for x in range(40,1120,70):
        draw_rect(Rect2(x,346,30,6), Color("895d68"))
    # Piano, now with feet, lid, keys, and outline.
    draw_rect(Rect2(414,128,324,78), Color("111217"))
    draw_rect(Rect2(424,138,304,58), Color("4d302a"))
    draw_rect(Rect2(436,148,280,38), Color("1d181b"))
    for i in range(10):
        draw_rect(Rect2(444 + i*26,152,22,27), Color("eadfca"))
        if i in [1,3,6,8]:
            draw_rect(Rect2(458 + i*26,152,9,17), Color("292126"))
    draw_rect(Rect2(448,192,22,30), Color("111217"))
    draw_rect(Rect2(682,192,22,30), Color("111217"))
    draw_string(ThemeDB.fallback_font, Vector2(492,119), "PIANO ANTIGO", HORIZONTAL_ALIGNMENT_LEFT, 180, 16, Color("e0c88a"))
    # Four puzzle pedestals, preserving the original positions.
    var table_pos: Array[Vector2] = [Vector2(250,250),Vector2(875,250),Vector2(280,440),Vector2(850,430)]
    var table_notes: Array[String] = ["DÓ", "MI", "SOL", "LÁ"]
    for i in range(4):
        var q: Vector2 = table_pos[i]
        draw_rect(Rect2(q-Vector2(64,34),Vector2(128,68)), Color("17151a"))
        draw_rect(Rect2(q-Vector2(57,27),Vector2(114,54)), Color("7b5949"))
        var marked: bool = i < piano_marks.size() and piano_marks[i]
        draw_rect(Rect2(q-Vector2(19,19),Vector2(38,38)), Color("e7c76d") if marked else Color("b98552"))
        draw_rect(Rect2(q-Vector2(12,12),Vector2(24,24)), Color("2c2025"))
        draw_string(ThemeDB.fallback_font, q+Vector2(-5,7), str(i+1), HORIZONTAL_ALIGNMENT_LEFT, 18, 16, Color("f4e8c9"))
        draw_string(ThemeDB.fallback_font, q+Vector2(-28,51), table_notes[i], HORIZONTAL_ALIGNMENT_LEFT, 65, 14, Color("ead9b0"))
    # Candles and wall frames.
    for q in [Vector2(125,190),Vector2(1020,190),Vector2(120,520),Vector2(1030,520)]:
        draw_torch(q, true)
    for q in [Vector2(130,280),Vector2(1015,280)]:
        draw_rect(Rect2(q.x-34,q.y-44,68,88), Color("15151c"))
        draw_rect(Rect2(q.x-27,q.y-37,54,74), Color("554866"))
        draw_rect(Rect2(q.x-18,q.y-28,36,56), Color("2c2737"))
    # Door remains exactly where gameplay expects it.
    if piano_solved:
        draw_portal(Vector2(1125,390), true, false)
        draw_string(ThemeDB.fallback_font,Vector2(1010,315),"ABERTA",HORIZONTAL_ALIGNMENT_LEFT,90,14,Color("d7bf75"))
    else:
        draw_portal(Vector2(1125,390), false, false)

func draw_intro_scene():
    draw_rect(Rect2(0,0,1152,648),Color("101a27"))
    # Parque em pixel-art, com a montanha-russa no centro da cutscene.
    draw_rect(Rect2(0,470,1152,178), Color("151a22"))
    draw_rect(Rect2(0,476,1152,8), Color("2b303a"))

    # Fundo do parque.
    draw_rect(Rect2(45,178,330,250),Color("0e141d"))
    draw_rect(Rect2(55,188,310,230),Color("30475a"))
    draw_rect(Rect2(77,210,266,184),Color("21384b"))
    draw_rect(Rect2(93,226,234,64),Color("6b4665"))
    draw_string(ThemeDB.fallback_font,Vector2(109,266),"PARQUE ENCANTADO",HORIZONTAL_ALIGNMENT_LEFT,210,24,Color("f2d47b"))
    draw_string(ThemeDB.fallback_font,Vector2(111,314),"MONTANHA-RUSSA",HORIZONTAL_ALIGNMENT_LEFT,210,19,Color("c9d9ea"))

    # Roda-gigante ao fundo.
    draw_circle(Vector2(865,210),150,Color("0b1119"))
    draw_circle(Vector2(865,210),140,Color("5b5264"),false,8.0)
    draw_circle(Vector2(865,210),100,Color("777083"),false,5.0)
    for i in range(12):
        var a: float = TAU * float(i) / 12.0
        var q: Vector2 = Vector2(865,210) + Vector2(cos(a),sin(a)) * 136.0
        draw_line(Vector2(865,210),q,Color("6f6877"),4.0)
        draw_rect(Rect2(q-Vector2(11,8),Vector2(22,16)),Color("10151c"))
        draw_rect(Rect2(q-Vector2(7,5),Vector2(14,10)),Color("b96b69" if i%2==0 else "6f80a9"))
    draw_rect(Rect2(857,210,16,170),Color("12171e"))
    draw_rect(Rect2(730,380,270,12),Color("12171e"))

    # Trilha da montanha-russa: subida íngreme, topo e descida.
    var rail: PackedVector2Array = PackedVector2Array([
        Vector2(330,470), Vector2(430,470), Vector2(575,405),
        Vector2(705,235), Vector2(855,455), Vector2(1020,455)
    ])
    for i in range(rail.size() - 1):
        draw_line(rail[i] + Vector2(0,-7), rail[i + 1] + Vector2(0,-7), Color("17151c"), 9.0, true)
        draw_line(rail[i] + Vector2(0,7), rail[i + 1] + Vector2(0,7), Color("17151c"), 9.0, true)
    draw_polyline(rail, Color("c18a54"), 4.0, true)
    for q in [Vector2(430,470),Vector2(575,405),Vector2(705,235),Vector2(855,455)]:
        draw_rect(Rect2(q.x-5,q.y+2,10,48),Color("3e3440"))

    # Carrinho acompanha Max e Carlo durante a subida/descida.
    if intro_phase <= 1 and is_instance_valid(player):
        var cart_pos: Vector2 = player.position + Vector2(22,17)
        draw_rect(Rect2(cart_pos.x-34,cart_pos.y-12,68,24),Color("15131a"))
        draw_rect(Rect2(cart_pos.x-29,cart_pos.y-8,58,17),Color("8f4f58"))
        draw_circle(cart_pos+Vector2(-20,15),7,Color("111217"))
        draw_circle(cart_pos+Vector2(20,15),7,Color("111217"))

    # Vegetação decorativa.
    for x in [35,400,470,1040,1090]:
        draw_rect(Rect2(x,430,46,42),Color("0d1718"))
        draw_rect(Rect2(x+5,420,36,48),Color("24513f"))

    if intro_control_enabled:
        draw_portal(Vector2(1050,390),true,false)
        draw_string(ThemeDB.fallback_font,Vector2(870,470),"PORTAL DA FLORESTA",HORIZONTAL_ALIGNMENT_LEFT,220,17,Color("e7c76d"))
    draw_string(ThemeDB.fallback_font,Vector2(60,75),"SKAP KEY",HORIZONTAL_ALIGNMENT_LEFT,400,34,Color("f2d47b"))
    draw_string(ThemeDB.fallback_font,Vector2(60,108),"A CHAVE DO CONHECIMENTO",HORIZONTAL_ALIGNMENT_LEFT,360,16,Color("b9c9e9"))

func draw_pixel_zombie_hint(p: Vector2, green: bool):
    var body: Color = Color("58784c") if green else Color("913f55")
    draw_rect(Rect2(p.x-19,p.y-18,38,44),Color("11151a"))
    draw_rect(Rect2(p.x-15,p.y-14,30,38),body)
    draw_rect(Rect2(p.x-12,p.y-29,24,16),Color("11151a"))
    draw_rect(Rect2(p.x-9,p.y-26,18,13),body)
    draw_rect(Rect2(p.x-7,p.y-24,4,4),Color("e9d9a4"))
    draw_rect(Rect2(p.x+3,p.y-24,4,4),Color("e9d9a4"))

func draw_title():
    draw_rect(Rect2(0,0,1152,648),Color("090d15"))
    # Tela inicial com composição de aventura, mantendo a mesma linguagem
    # pixel-art dos personagens do jogo.
    for i in range(24):
        var p: Vector2 = Vector2(35 + i*48, 125 + sin(Time.get_ticks_msec()/900.0 + float(i))*15.0)
        draw_rect(Rect2(p.x-2,p.y-2,4,4),Color("d9bb68"))

    # Moldura central para o título e a chave.
    draw_rect(Rect2(310,78,532,392),Color("11151c"))
    draw_rect(Rect2(320,88,512,372),Color("211a31"),false,4.0)
    draw_rect(Rect2(350,108,452,285),Color("171b29"))
    draw_rect(Rect2(366,124,420,253),Color("2a2039"),false,3.0)

    # Chave do Conhecimento estilizada no centro.
    draw_circle(Vector2(576,265),50,Color("e7c76d"))
    draw_circle(Vector2(576,265),29,Color("2a2039"))
    draw_rect(Rect2(568,214,16,102),Color("e7c76d"))
    draw_rect(Rect2(576,300,78,13),Color("e7c76d"))
    draw_rect(Rect2(640,300,13,25),Color("e7c76d"))
    draw_rect(Rect2(616,300,13,19),Color("e7c76d"))

    draw_string(ThemeDB.fallback_font,Vector2(345,62),"SKAP KEY",HORIZONTAL_ALIGNMENT_LEFT,462,54,Color("f2d47b"))
    draw_string(ThemeDB.fallback_font,Vector2(365,420),"A CHAVE DO CONHECIMENTO",HORIZONTAL_ALIGNMENT_LEFT,422,19,Color("d4c5e7"))

    # Base visual para os dois personagens da tela inicial.
    draw_rect(Rect2(170,485,812,4),Color("6b557d"))
    draw_rect(Rect2(195,489,762,3),Color("30273b"))
    draw_string(ThemeDB.fallback_font,Vector2(205,535),"MAX",HORIZONTAL_ALIGNMENT_LEFT,120,16,Color("e7c76d"))
    draw_string(ThemeDB.fallback_font,Vector2(790,535),"CARLO",HORIZONTAL_ALIGNMENT_LEFT,130,16,Color("e7c76d"))

    # Instrução principal em uma placa própria, sem competir com o título.
    draw_rect(Rect2(360,555,432,54),Color("11151c"))
    draw_rect(Rect2(365,560,422,44),Color("2a2039"),false,2.0)
    draw_string(ThemeDB.fallback_font,Vector2(414,589),"PRESSIONE ENTER PARA COMEÇAR",HORIZONTAL_ALIGNMENT_LEFT,335,17,Color("ffffff"))
    draw_string(ThemeDB.fallback_font,Vector2(478,626),"WASD  •  J  •  SHIFT  •  E",HORIZONTAL_ALIGNMENT_LEFT,240,13,Color("9f91ad"))

func draw_tree(p: Vector2):
    draw_circle(p+Vector2(0,25),28,Color(0.03,0.08,0.06,0.35))
    draw_rect(Rect2(p.x-7,p.y,14,48),Color("553b2c"))
    draw_circle(p+Vector2(-18,-5),31,Color("214d39"))
    draw_circle(p+Vector2(16,-10),36,Color("285a3f"))
    draw_circle(p+Vector2(0,-34),34,Color("326947"))

func draw_owl(p: Vector2):
    draw_circle(p,34,Color("d0a66b"))
    draw_circle(p+Vector2(0,-25),25,Color("d8b67a"))
    draw_circle(p+Vector2(-9,-27),9,Color("f5e7c0"))
    draw_circle(p+Vector2(9,-27),9,Color("f5e7c0"))
    draw_circle(p+Vector2(-9,-27),3,Color("211d29"))
    draw_circle(p+Vector2(9,-27),3,Color("211d29"))
    draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-17),p+Vector2(5,-17),p+Vector2(0,-8)]),Color("c78148"))

func draw_ruin(p: Vector2):
    draw_rect(Rect2(p.x-70,p.y-20,140,120),Color("51495c"))
    draw_rect(Rect2(p.x-55,p.y-5,110,105),Color("252536"))
    for x in [-48,-16,16,48]:
        draw_rect(Rect2(p.x+x-7,p.y-30,14,35),Color("71687a"))

func draw_key(p: Vector2,active := true):
    var c = Color("f3d46b") if active else Color("635b6c")
    draw_circle(p,18,c)
    draw_circle(p,10,Color("252033"))
    draw_rect(Rect2(p.x,p.y-4,60,8),c)
    draw_rect(Rect2(p.x+42,p.y-4,8,22),c)
    draw_rect(Rect2(p.x+55,p.y-4,8,15),c)

func draw_dart_corridor():
    draw_rect(Rect2(8,126,1136,514),Color("24212d"))
    # Corredor de pedra, preservando a linguagem visual das Ruínas.
    for y in range(140,630,48):
        for x in range(20,1135,64):
            var off: int = 32 if int(y / 48.0) % 2 == 1 else 0
            draw_rect(Rect2(x+off,y,60,44),Color("34303d"),false,2.0)
    draw_rect(Rect2(8,190,1136,400),Color("1b1924"))
    draw_rect(Rect2(24,205,1104,370),Color("2c2837"),false,3.0)
    # Faixas de segurança e nichos laterais.
    draw_rect(Rect2(30,220,1090,5),Color("5d4b64"))
    draw_rect(Rect2(30,555,1090,5),Color("5d4b64"))
    for y in [245, 315, 385, 455, 525]:
        draw_rect(Rect2(46,y,72,38),Color("17151d"))
        draw_rect(Rect2(54,y+8,56,22),Color("40374b"))
        draw_rect(Rect2(1030,y,72,38),Color("17151d"))
        draw_rect(Rect2(1038,y+8,56,22),Color("40374b"))
    # Mecanismo de disparo à direita.
    draw_rect(Rect2(1080,245,42,300),Color("111018"))
    for y in [255,325,395,465,535]:
        draw_rect(Rect2(1086,y,28,10),Color("8c6b45"))
        draw_rect(Rect2(1090,y+10,20,4),Color("c9a365"))
    draw_string(ThemeDB.fallback_font,Vector2(850,165),"CORREDOR DOS DARDOS",HORIZONTAL_ALIGNMENT_LEFT,270,18,Color("e7c76d"))
    draw_string(ThemeDB.fallback_font,Vector2(360,615),"DESVIE • DASH [SHIFT] • ALCANCE O PORTAL",HORIZONTAL_ALIGNMENT_LEFT,440,13,Color("bca9d0"))
    # Portal sempre ativo: o desafio é atravessar vivo, não concluir uma contagem.
    draw_rune_pad(Vector2(1048,390),Color("8f63c9"),true)

func draw_sanctuary():
    draw_rect(Rect2(8,126,1136,514),Color("211c2d"))
    # Stone sanctuary floor with the same chunky outline language.
    for y in range(140,630,48):
        for x in range(20,1135,64):
            var off: int = 32 if int(y / 48.0) % 2 == 1 else 0
            draw_rect(Rect2(x+off,y,60,44),Color("2d273a"),false,2.0)
    # Central aisle and magical seal.
    draw_rect(Rect2(462,126,228,514),Color("15131e"))
    draw_rect(Rect2(470,126,212,514),Color("463b50"))
    draw_rune_circle(Vector2(576,390),Color("a45bc6"))
    for i in range(3):
        draw_arc(Vector2(576,390),115+i*18,0,TAU,32,Color(0.55,0.2,0.65,0.16),4.0)
    # Tall pillars frame the room.
    for q in [Vector2(190,190),Vector2(190,515),Vector2(962,190),Vector2(962,515)]:
        draw_rect(Rect2(q.x-26,q.y-72,52,144),Color("11151c"))
        draw_rect(Rect2(q.x-19,q.y-65,38,130),Color("5e5568"))
        draw_rect(Rect2(q.x-28,q.y-74,56,12),Color("777080"))
        draw_rect(Rect2(q.x-28,q.y+62,56,12),Color("777080"))
    draw_torch(Vector2(250,205),true)
    draw_torch(Vector2(900,205),true)
    draw_banner(Vector2(390,150),Color("67466e"))
    draw_banner(Vector2(762,150),Color("67466e"))
    # Carlo's cage, same location and collision footprint, but with a stronger
    # pixel-art silhouette and a clearly readable front gate.
    if not carlo_rescued:
        draw_rect(Rect2(786,451,158,114),Color("0f1319"))
        draw_rect(Rect2(794,459,142,98),Color("302b3b"))
        for x in range(802,936,19):
            draw_rect(Rect2(x,456,6,108),Color("11151a"))
            draw_rect(Rect2(x+2,460,2,100),Color("a298a8"))
        draw_rect(Rect2(790,451,150,7),Color("15191f"))
        draw_rect(Rect2(790,557,150,7),Color("15191f"))
        draw_string(ThemeDB.fallback_font,Vector2(805,441),"CARLO",HORIZONTAL_ALIGNMENT_LEFT,120,15,Color("e7c76d"))
        # Front gate opening is visually highlighted, matching the interaction zone.
        draw_rect(Rect2(846,498,42,58),Color("11151a"))
        draw_rect(Rect2(850,502,34,50),Color("40394a"))
        draw_rect(Rect2(862,520,4,4),Color("e7c76d"))
    if lucy_key_available:
        draw_key(lucy_key_pos,true)
        draw_string(ThemeDB.fallback_font,lucy_key_pos+Vector2(-25,38),"CHAVE",HORIZONTAL_ALIGNMENT_LEFT,70,12,Color("f3d46b"))
    if carlo_rescued:
        draw_rect(Rect2(795,455,140,100),Color("211c2b"))
        draw_string(ThemeDB.fallback_font,Vector2(805,590),"CARLO: VAMOS EMBORA!",HORIZONTAL_ALIGNMENT_LEFT,170,14,Color("e7c76d"))

