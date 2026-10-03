@tool
# One line of dialog: who speaks, what they say (localized), optional portrait.
class_name DialogLine
extends Resource

@export var speaker_name_key: String = ""   # tr() key for the speaker's name
@export var text_key: String = ""            # tr() key for the spoken line
@export var portrait: Texture2D              # optional; hidden when null
