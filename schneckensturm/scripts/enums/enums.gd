@tool
# Central enum definitions for Schneckensturm. Globally available via class_name.
class_name Enums

## Hero rarity == hero tier.
enum HeroTier { CHAMPION, LEGEND, MYTH }

## Hero role. Placement (path vs. edge tile) is a separate data field on HeroData.
enum HeroClass { MELEE, RANGED, SUPPORT, HYBRID }

## What a map tile is used for.
enum TileKind { NONE, GROUND, PATH, DEPLOY_PATH, DEPLOY_EDGE, BUILD_SLOT, BLOCKED }

## Which deploy tile a hero may stand on.
enum Placement { PATH, EDGE }

## Target class of a unit (enemies and own troops share it). Drives the target-rule matrix.
enum TargetClass { MELEE, RANGED, FLYER, ASSASSIN, SIEGE }

## How an enemy class picks its victim (see TargetRule).
enum AttackMode { BLOCKER_ONLY, ANY_IN_RANGE, UNPROTECTED_FIRST, BUILDINGS_FIRST }

## How own heroes/troops/towers pick their target.
enum TargetPriority { BLOCKED_THEN_FIRST, FIRST, STRONGEST, WEAKEST }

enum Side { PLAYER, ENEMY }

## STRIKE_ALL hits every living enemy on the map (radius is ignored).
enum AbilityKind { STRIKE, HEAL, SUMMON, BUFF_ATTACK, STUN, STRIKE_ALL }


static func tier_name_key(t: int) -> String:
	match t:
		HeroTier.LEGEND: return "UI_TIER_LEGEND"
		HeroTier.MYTH: return "UI_TIER_MYTH"
	return "UI_TIER_CHAMPION"


static func tier_color(t: int) -> Color:
	match t:
		HeroTier.LEGEND: return Color(0.65, 0.35, 0.90)
		HeroTier.MYTH: return Color(0.95, 0.70, 0.20)
	return Color(0.30, 0.55, 0.95)


static func class_name_key(c: int) -> String:
	match c:
		HeroClass.RANGED: return "UI_CLASS_RANGED"
		HeroClass.SUPPORT: return "UI_CLASS_SUPPORT"
		HeroClass.HYBRID: return "UI_CLASS_HYBRID"
	return "UI_CLASS_MELEE"


static func target_class_key(c: int) -> String:
	match c:
		TargetClass.RANGED: return "UI_TCLASS_RANGED"
		TargetClass.FLYER: return "UI_TCLASS_FLYER"
		TargetClass.ASSASSIN: return "UI_TCLASS_ASSASSIN"
		TargetClass.SIEGE: return "UI_TCLASS_SIEGE"
	return "UI_TCLASS_MELEE"
