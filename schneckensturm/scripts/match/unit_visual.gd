# Display component for a unit: a still image as a round medallion token with
# tweened motion (walk bob, attack lunge, hit flash, death fade), facing from the
# movement vector, HP bar and side-coloured ring. When the data provides
# SpriteFrames it plays those instead of the tweened token.
class_name UnitVisual
extends Node2D

const TOKEN_SIZE := 72.0
const LIFT := 30.0            # token centre above the ground point
const BOB_SPEED := 11.0
const BOB_HEIGHT := 3.5
const LUNGE_DIST := 14.0
const LUNGE_TIME := 0.16
const FLASH_TIME := 0.22

static var _material: ShaderMaterial

var ring_color := Color.WHITE
var size_mult := 1.0
var hp_ratio := 1.0
var show_hp := true
var moving := false
## 0..1 extra arc (ability charge / cooldown), < 0 = hidden.
var charge := -1.0
var selected := false

var _body: Node2D
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _t := 0.0
var _lunging := false


func setup(texture: Texture2D, frames: SpriteFrames, ring: Color, mult := 1.0) -> void:
	ring_color = ring
	size_mult = mult
	_body = Node2D.new()
	_body.position = Vector2(0, -LIFT * size_mult)
	add_child(_body)
	if frames != null:
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = frames
		_body.add_child(_anim)
		_play("idle")
	else:
		_sprite = Sprite2D.new()
		_sprite.texture = texture if texture != null else _fallback_texture()
		_sprite.material = _token_material()
		# Tokens are square (tools/square_tokens.gd); scale the longer side to the token size.
		var side := maxf(1.0, float(maxi(_sprite.texture.get_width(), _sprite.texture.get_height())))
		_sprite.scale = Vector2.ONE * (TOKEN_SIZE * size_mult / side)
		_body.add_child(_sprite)
	queue_redraw()


static func _token_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://assets/shaders/token_mask.gdshader")
	return _material


static func _fallback_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	if _body == null or _lunging:
		return
	var bob := -absf(sin(_t * BOB_SPEED)) * BOB_HEIGHT if moving else 0.0
	_body.position = Vector2(0, -LIFT * size_mult + bob)
	if _anim != null:
		_play("walk" if moving else "idle")


func set_facing(dx: float) -> void:
	if absf(dx) < 0.01:
		return
	if _sprite != null:
		_sprite.flip_h = dx < 0.0
	if _anim != null:
		_anim.flip_h = dx < 0.0


func set_hp(ratio: float) -> void:
	if not is_equal_approx(ratio, hp_ratio):
		hp_ratio = clampf(ratio, 0.0, 1.0)
		queue_redraw()


func set_charge(v: float) -> void:
	if not is_equal_approx(v, charge):
		charge = v
		queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func lunge(toward: Vector2) -> void:
	if _body == null or _lunging:
		return
	if _anim != null and _anim.sprite_frames.has_animation("attack"):
		_anim.play("attack")
	var dir := (toward - global_position).normalized() * LUNGE_DIST
	var base := Vector2(0, -LIFT * size_mult)
	_lunging = true
	var tw := create_tween()
	tw.tween_property(_body, "position", base + dir, LUNGE_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position", base, LUNGE_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _lunging = false)


func flash(color := Color(1.8, 0.55, 0.55)) -> void:
	if _body == null:
		return
	_body.modulate = color
	create_tween().tween_property(_body, "modulate", Color.WHITE, FLASH_TIME)


# Fade + shrink, then free. `reason` "leaked" slides forward instead.
func die(reason := "died") -> void:
	show_hp = false
	charge = -1.0
	queue_redraw()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	if reason == "retreated":
		tw.tween_property(self, "position:y", position.y - 40.0, 0.35)
	else:
		tw.tween_property(self, "scale", Vector2(0.6, 0.6), 0.35)
	tw.chain().tween_callback(queue_free)


func _play(anim_name: String) -> void:
	if _anim != null and _anim.sprite_frames.has_animation(anim_name) and _anim.animation != anim_name:
		_anim.play(anim_name)


func _draw() -> void:
	var r := TOKEN_SIZE * 0.5 * size_mult
	# ground shadow (iso ellipse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r * 0.8, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center := Vector2(0, -LIFT * size_mult)
	if selected:
		draw_arc(center, r + 7.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0)
	draw_arc(center, r + 1.5, 0.0, TAU, 48, ring_color, 4.0)
	if charge >= 0.0:
		draw_arc(center, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(charge, 0.0, 1.0), 32, Color(0.55, 0.85, 1.0), 3.0)
	if show_hp and hp_ratio < 0.999:
		var w := 56.0 * size_mult
		var top := center.y - r - 12.0
		draw_rect(Rect2(-w * 0.5 - 1, top - 1, w + 2, 8), Color(0, 0, 0, 0.7))
		var col := Color(0.35, 0.85, 0.35) if hp_ratio > 0.5 else (Color(0.95, 0.8, 0.25) if hp_ratio > 0.25 else Color(0.95, 0.3, 0.25))
		draw_rect(Rect2(-w * 0.5, top, w * hp_ratio, 6), col)
