extends Node

# WordAudio (autoload)
#
# Central place to play word-pronunciation audio from anywhere in the game
# (quizzes, tutorial signs, etc). Keeps a single re-usable AudioStreamPlayer
# instead of every quiz scene managing its own — so only ONE voice line can ever
# be playing at a time, never two overlapping.
#
# EXPECTED ASSETS
# Place one audio file per word at:
#     res://assets/Sound/Words/<word>.ogg      (lower-case, matches the word exactly)
# e.g. "dog" -> res://assets/Sound/Words/dog.ogg
# 32 core vocabulary words already ship with real recordings (one consistent male
# voice). The same convention is used for single letter-sounds (the "Audio Sequence"
# quiz), e.g. "b" -> res://assets/Sound/Words/b.ogg — these do NOT have recordings yet.
#
# TTS FALLBACK — ONE VOICE ONLY
# Any word without a recorded file falls back to Godot 4's built-in text-to-speech
# (`DisplayServer.tts_speak()`), so the game is never silent while more recordings are
# still being produced. To avoid ever mixing voices, the TTS voice is picked ONCE, on
# startup (`_pickTtsVoice()`), cached in `_ttsVoiceId`, and reused for every single TTS
# call afterwards — it can never drift between a male and a female voice mid-game.
#
# MANUAL OVERRIDE
# If the automatic pick below doesn't land on the right voice on your machine, set
# `_FORCED_VOICE_ID` to an exact ID from the list `DisplayServer.tts_get_voices()`
# prints to the Output panel on startup, and it's used with no guessing involved.
const _FORCED_VOICE_ID: String = ""

# FORCED MASCULINE PITCH
# Voice *name* matching can fail silently on some platforms (e.g. Android/Google TTS
# voice ids like "en-us-x-iol-local" carry no gender hint at all), which is how a
# female system voice could still slip through. To guarantee the result always sounds
# male regardless of which underlying voice got picked, every TTS utterance is also
# synthesized at a deliberately lowered pitch — this is a deterministic, platform
# independent way to "force" a masculine timbre, on top of the name/id matching below.
# Pushed as low as still sounds natural — this is the maximum forcing available
# without a real recorded voice for every word.
const _TTS_PITCH: float = 0.75

signal sequenceFinished

var _player: AudioStreamPlayer
var _sequenceQueue: Array = []
var _sequenceToken: int = 0	# bumped every time a new sequence starts, so an old, still-running
							# sequence can tell it's been superseded and stop scheduling itself
var _ttsVoiceId: String = ""
var _ttsAvailable: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "WordAudioPlayer"
	add_child(_player)

	_pickTtsVoice()

# Picks ONE male-sounding English voice for TTS and sticks with it for the whole
# session — the project's voice-over guideline is "a single, consistent male voice,
# the least robotic one available, never mixed with a female one".
#
# Godot's TTS API doesn't expose a "gender" field directly, so this matches against
# both the voice's display `name` (Windows SAPI5/macOS/iOS naming conventions) AND its
# `id` (Linux/Android espeak-ng voices commonly encode gender right in the id, e.g.
# "en+m3" = English male variant 3, "en+f2" = English female variant 2).
const _MALE_HINTS: Array = [
	"david", "mark", "james", "daniel", "male", "man", "alex", "fred", "guy",
	"ryan", "george", "arthur", "gordon", "matthew", "brian", "eric", "diego", "+m",
	"paul", "tom", "thomas", "sean", "aaron", "oliver", "henry", "liam", "jack",
	"connor", "callum", "boy", "john", "peter", "andrew", "kevin", "roger",
]
const _FEMALE_HINTS: Array = [
	"female", "woman", "girl", "zira", "susan", "samantha", "victoria", "karen", "moira",
	"tessa", "fiona", "kate", "amy", "emma", "joanna", "salli", "ivy", "kendra",
	"kimberly", "sara", "sarah", "lisa", "hazel", "catherine", "+f",
	"nicole", "olivia", "sophia", "ava", "chloe", "grace", "linda", "michelle",
	"heather", "allison", "monica", "maria", "anna", "laura", "helen", "julia",
]

func _pickTtsVoice() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_ttsAvailable = false
		return

	_ttsAvailable = true

	if _FORCED_VOICE_ID != "":
		_ttsVoiceId = _FORCED_VOICE_ID
		print_debug("WordAudio: using manually forced TTS voice '%s'" % _ttsVoiceId)
		return

	var allVoices: Array = DisplayServer.tts_get_voices()	# Array of {name, id, language}
	print_debug("WordAudio: available TTS voices: %s" % [allVoices])

	var englishVoices: Array = []
	for voice in allVoices:
		if String(voice.get("language", "")).begins_with("en"):
			englishVoices.append(voice)
	if englishVoices.is_empty():
		englishVoices = allVoices	# no English voice at all — better than total silence

	# Tier 1: a voice whose name/id clearly says "male".
	var chosenVoice: Dictionary = _findVoiceMatchingHints(englishVoices, _MALE_HINTS)

	# Tier 2: HARD-EXCLUDE anything that looks female, no matter what — pick the first
	# remaining voice. This is the "eliminate the female voice completely" pass: even a
	# voice with an ambiguous/unknown name is safer than one that hints female.
	if chosenVoice.is_empty():
		for voice in englishVoices:
			if _findVoiceMatchingHints([voice], _FEMALE_HINTS).is_empty():
				chosenVoice = voice
				break

	# Tier 3 (worst case: every available voice hints female): still needs A voice to
	# speak at all, so fall back to the first one — but the pitch drop below then does
	# all of the remaining work to keep it from sounding female.
	if chosenVoice.is_empty() and not englishVoices.is_empty():
		chosenVoice = englishVoices[0]
		push_warning("WordAudio: every available TTS voice matched a female-name hint — using '%s' anyway, relying on the pitch drop to mask it. Set _FORCED_VOICE_ID if you know the exact male voice id for this machine." % chosenVoice.get("name", "?"))

	if not chosenVoice.is_empty():
		_ttsVoiceId = chosenVoice.id
		print_debug("WordAudio: using TTS voice '%s' (%s), forced pitch %s" % [chosenVoice.get("name", "?"), _ttsVoiceId, _TTS_PITCH])

func _findVoiceMatchingHints(voices: Array, hints: Array) -> Dictionary:
	for voice in voices:
		var haystack: String = ("%s %s" % [voice.get("name", ""), voice.get("id", "")]).to_lower()
		for hint in hints:
			if haystack.contains(hint):
				return voice
	return {}

# Plays the pronunciation audio for `word`, if a matching file exists; otherwise falls
# back to speaking `word` aloud with TTS (always the SAME cached voice, see above).
# Stops whatever was playing first — only one voice line plays at a time, ever.
func playWord(word: String) -> void:
	if word == null or word == "":
		return

	stop()
	_playWordWithoutCancellingSequence(word)

# Internal variant used by playSequence(). IMPORTANT: this must NOT call stop(), because
# stop() increments _sequenceToken and would cancel the sequence after its first sound.
func _playWordWithoutCancellingSequence(word: String) -> void:
	if word == null or word == "":
		return

	if _player:
		_player.stop()
	if _ttsAvailable:
		DisplayServer.tts_stop()

	var path: String = "res://assets/Sound/Words/%s.ogg" % word.to_lower()
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		_player.stream = stream
		_player.play()
		return

	push_warning("WordAudio: no pronunciation file found for '%s' (expected at %s). Falling back to TTS." % [word, path])
	_player.stream = null
	speakText(word)

# Speaks any arbitrary sentence aloud via TTS (e.g. a full quiz question for "Listen and
# answer"-style prompts), using the one cached voice. Does nothing (silently) on
# platforms without TTS support, rather than erroring.
func speakText(text: String) -> void:
	if text == null or text == "":
		return
	if not _ttsAvailable:
		push_warning("WordAudio: TTS isn't available on this platform, can't speak '%s'." % text)
		return

	DisplayServer.tts_speak(text, _ttsVoiceId, 80, _TTS_PITCH, 1.0, 0, true)	# interrupt=true: never overlaps a previous utterance

# Plays each word/letter in `words` one after another (a short pause between each),
# then emits `sequenceFinished`. Used by the "Audio Sequence" quiz (Level 7) to play a
# short string of letter sounds the child has to remember the order of. Calling this
# again before a sequence finishes cancels the old one instead of overlapping it.
func playSequence(words: Array) -> void:
	_sequenceToken += 1
	var myToken: int = _sequenceToken
	_sequenceQueue = words.duplicate()
	_playNextInSequence(myToken)

func _playNextInSequence(token: int) -> void:
	if token != _sequenceToken:
		return	# a newer playSequence() call (or a repeat-button press) superseded this one

	if _sequenceQueue.is_empty():
		sequenceFinished.emit()
		return

	var word: String = _sequenceQueue.pop_front()
	_playWordWithoutCancellingSequence(word)

	if _player.stream:
		await _player.finished
	else:
		await get_tree().create_timer(0.9).timeout	# TTS fallback — no exact "finished" signal, just pace it out

	if token != _sequenceToken:
		return

	await get_tree().create_timer(0.35).timeout	# a small gap so consecutive sounds don't blur together
	_playNextInSequence(token)

# Stops any pronunciation currently playing (e.g. when a quiz closes, or right before
# a new word starts — see `playWord()`). Guarantees only one voice line is ever
# audible at once.
func stop() -> void:
	_sequenceToken += 1	# cancel any in-flight sequence too
	if _player:
		_player.stop()
	if _ttsAvailable:
		DisplayServer.tts_stop()
