extends Node


# CONSTS
const HANGMAN_MAX_HINT_CHAR_RATIO = 0.5

# ENUMS
enum QUIZ_TYPES { MATCH_IMAGE, STARTS_WITH, RHYMES_WITH, HANGMAN, SOUND_BINGO, WRITE_PROMPT, WORD_SEARCH, PHONEME_BLEND, CUSTOM_CHOICE, AUDIO_SEQUENCE, RHYMES_WITH_IMAGE }

# Directions used to place words in the "Word Search" grid: right, down, and both
# diagonals-going-down. Deliberately excludes leftward/upward (reversed) directions,
# since reading mirrored/reversed letter sequences is a known extra difficulty for
# dyslexic readers (see project report, chapter 4) — every word always reads the
# same left-to-right / top-to-bottom direction a sentence would.
const _WORD_SEARCH_DIRECTIONS: Array = [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1)]

# VARS
var _quizSet: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# METHODS
func _init():
	randomize()
	_rng.randomize()

# Clear generated quiz sets
func clearQuizSets() -> void:
	_quizSet.clear()

# Randomize generated quiz sets
func randomizeQuizSets() -> void:
	_quizSet.shuffle()

# Gets the next quiz in the last generated set of quizzes
# Quiz sets can be generated with `generateMatchImageQuizSet()`, `generateStartsWithQuizSet()`, `generateRhymesWithQuizSet()` and `generateHangmanQuizSet()`
# Returns an empty `Dictionary` if no quizzes have been generated or the last set of quizzes has been exhausted
# If quizzes of multiple types have been generated, they can be distinguished with the property `quizType` (`QuizGenerator.QUIZ_TYPES`)
func getNextQuiz() -> Dictionary:
	if not len(_quizSet):
		return {}

	return _quizSet.pop_front()

# Generate a random set of "Match Image" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.MATCH_IMAGE`)
# - `target` (`String`)
# - `extraAnswers` (`Array` of `Strings`)
func generateMatchImageQuizSet(pool: Array = []) -> void:
	var words: Array = (pool if not pool.is_empty() else MatchImageDB.words).duplicate()
	words.shuffle()
	for wordEntry in words:
		# Setup dictionary structure
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.MATCH_IMAGE
		quizDictionary.target = ""
		quizDictionary.extraAnswers = []

		# Entries are normally a plain Array (auto-generated distractors). Some entries
		# (e.g. deliberate-misspelling quizzes) are a Dictionary instead, with "words"
		# (Array, target first) — those distractors are specific, hand-picked wrong
		# spellings, so ALL of them are always used, not randomly drawn from a pool.
		var wordSet: Array
		if wordEntry is Dictionary:
			wordSet = wordEntry.words
		else:
			wordSet = wordEntry

		# Set first word as target and remove it from the array
		var tempWordSet: Array = wordSet.duplicate()
		quizDictionary.target = tempWordSet.pop_front()

		# Shuffle remaining values and pick up to 3
		tempWordSet.shuffle()
		for i in range(min(3, tempWordSet.size())):
			quizDictionary.extraAnswers.append(tempWordSet[i])

		_quizSet.append(quizDictionary)

# Generate a random set of "Starts With" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.STARTS_WITH`)
# - `target` (`String`)
# - `correctAnswers` (`Array` of `Strings`)
# - `wrongAnswers` (`Array` of `Strings`)
# Each quiz generates with a total of `numOfCorrectAnswersPerQuiz + numOfWrongAnswersPerQuiz` answers
func generateStartsWithQuizSet(numOfCorrectAnswersPerQuiz: int, numOfWrongAnswersPerQuiz: int) -> void:
	var words: Array = StartsWithDB.words.duplicate()
	words.shuffle()
	for wordSet in words:
		# Setup dictionary structure
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.STARTS_WITH
		quizDictionary.target = ""
		quizDictionary.correctAnswers = []
		quizDictionary.wrongAnswers = []

		# Set target word part
		quizDictionary.target = wordSet[StartsWithDB.TARGET_PROP]

		# Duplicate correct answers array and pick random correct answers
		var correctAnswers: Array = wordSet[StartsWithDB.WORDS_PROP].duplicate()
		var smallestNumOfCorrectAnswers: int = len(correctAnswers) if len(correctAnswers) < numOfCorrectAnswersPerQuiz else numOfCorrectAnswersPerQuiz
		correctAnswers.shuffle()
		for i in range(smallestNumOfCorrectAnswers):
			quizDictionary.correctAnswers.append(correctAnswers[i])

		# Pick random extra answers and check if they're wrong,
		# until `numOfWrongAnswersPerQuiz` is met
		var wordsToExclude: Array = correctAnswers.duplicate()
		var aquiredExtraAnswers: Array = []
		while quizDictionary.wrongAnswers.size() < numOfWrongAnswersPerQuiz:
			aquiredExtraAnswers = _getExtraRandomWords(numOfWrongAnswersPerQuiz - quizDictionary.wrongAnswers.size(), wordsToExclude, QUIZ_TYPES.STARTS_WITH)

			# Find indexes of the random extra answers that aren't actually wrong
			var indexesToExclude: Array = []
			for i in range(aquiredExtraAnswers.size()):
				if (aquiredExtraAnswers[i] as String).begins_with(quizDictionary.target):
					indexesToExclude.append(i)

			# Exclude accidental correct answers
			for i in indexesToExclude:
				wordsToExclude.append(aquiredExtraAnswers.pop_at(i))

			# Place actually wrong answers into quiz dictionary
			quizDictionary.wrongAnswers.append_array(aquiredExtraAnswers)
			aquiredExtraAnswers.clear()

		_quizSet.append(quizDictionary)

# Generate a random set of "Rhymes With" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.RHYMES_WITH`)
# - `target` (`String`)
# - `correctAnswers` (`Array` of `Strings`)
# - `wrongAnswers` (`Array` of `Strings`)
# Each quiz generates with a total of `numOfCorrectAnswersPerQuiz + numOfWrongAnswersPerQuiz` answers
func generateRhymesWithQuizSet(numOfCorrectAnswersPerQuiz: int, numOfWrongAnswersPerQuiz: int) -> void:
	var words: Array = RhymesWithDB.words.duplicate()
	words.shuffle()
	for wordSet in words:
		# Setup dictionary structure
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.RHYMES_WITH
		quizDictionary.target = ""
		quizDictionary.correctAnswers = []
		quizDictionary.wrongAnswers = []

		# Duplicate correct answers array,
		# set random correct word as target and remove it from the array
		var correctAnswers: Array = wordSet.duplicate()
		var wordsToExclude: Array = correctAnswers.duplicate()
		correctAnswers.shuffle()
		quizDictionary.target = correctAnswers.pop_front()

		# Pick random correct answers
		var smallestNumOfCorrectAnswers: int = len(correctAnswers) if len(correctAnswers) < numOfCorrectAnswersPerQuiz else numOfCorrectAnswersPerQuiz
		for i in range(smallestNumOfCorrectAnswers):
			quizDictionary.correctAnswers.append(correctAnswers[i])

		# Pick random wrong answers
		quizDictionary.wrongAnswers = _getExtraRandomWords(numOfWrongAnswersPerQuiz, wordsToExclude, QUIZ_TYPES.RHYMES_WITH)

		_quizSet.append(quizDictionary)

# Generate a set of random "Hangman" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# Each quiz is a `Dictionary` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.HANGMAN`)
# - `target` (`String`)
# - - taken from `match-image.json` DB file, as the first word of each set should have an image associated with it
# - `hiddenTarget` (`String`)
# - - a version of `target` with its characters replaced with underscores, with some exceptions (the hint characters)
# - - hint characters are calculated based on `ratioOfHintCharsPerQuiz`
# - `answers` (`Array` of `Strings`)
# - - the quiz answers (necessary missing characters + random characters)
# - - array size is restricted to even numbers and between [target word's length + 2] and [target word's length x 2]
# `ratioOfHintCharsPerQuiz`:
# - represents the ratio of hint characters to the length of the target word
# - is a number restricted from 0 to `HANGMAN_MAX_HINT_CHAR_RATIO`
func generateHangmanQuizSet(ratioOfHintCharsPerQuiz: float) -> void:
	# Restrict `ratioOfHintCharsPerQuiz`
	ratioOfHintCharsPerQuiz = clamp(ratioOfHintCharsPerQuiz, 0, HANGMAN_MAX_HINT_CHAR_RATIO)

	var words: Array = MatchImageDB.words.duplicate()
	words.shuffle()
	for wordEntry in words:
		var wordSet: Array = wordEntry.words if wordEntry is Dictionary else wordEntry

		# Setup dictionary structure
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.HANGMAN
		quizDictionary.target = ""
		quizDictionary.hiddenTarget = ""
		quizDictionary.answers = []

		# Set first word as target
		quizDictionary.target = wordSet[0]

		# Create target with hidden characters
		var intNumOfHintChars: int = round(ratioOfHintCharsPerQuiz * wordSet[0].length()) as int
		quizDictionary.hiddenTarget = _generateTargetWithHintLetters(quizDictionary.target, intNumOfHintChars)

		# Randomize number of answers and restrict it to even numbers
		var numOfAnswers: int = _rng.randi_range(quizDictionary.target.length() + 2, quizDictionary.target.length() * 2)
		if numOfAnswers & 1:
			numOfAnswers += 1

		# Create answers (necessary missing characters + random characters)
		quizDictionary.answers = _generateHangmanAnswers(quizDictionary.target, quizDictionary.hiddenTarget, numOfAnswers)

		_quizSet.append(quizDictionary)

# Generates a version of `targetWord` with `numOfHintChars` kept and with every other character replaced with underscores
func _generateTargetWithHintLetters(targetWord: String, numOfHintChars: int) -> String:
	var shownTargetWord: String = "_".repeat(targetWord.length())
	var chosenHintCharsIndexes: Array = []

	while chosenHintCharsIndexes.size() < numOfHintChars:
		# Choose character index that hasn't been chosen yet
		var charIndex: int = _rng.randi_range(0, targetWord.length()-1)
		while chosenHintCharsIndexes.has(charIndex):
			charIndex = _rng.randi_range(0, targetWord.length()-1)

		# Display target word's character at the chosen index
		shownTargetWord[charIndex] = targetWord[charIndex]
		chosenHintCharsIndexes.append(charIndex)

	return shownTargetWord

# Generates character answers for a "Hangman" quiz
# `targetWord` is the full target word (no hidden characters)
# `hiddenTargetWord` is the version of `targetWord` with hidden characters
# `numOfAnswers` is the total number of answers (necessary missing characters + random characters) to be generated
func _generateHangmanAnswers(targetWord: String, hiddenTargetWord: String, numOfAnswers: int) -> Array:
	var answerChars: Array = []	# Holds the possible answers

	# Get hint character indexes
	var hintCharIndexes: Array = []
	for i in targetWord.length():
		if not hiddenTargetWord[i] == '_':
			hintCharIndexes.append(i)

	# Add target word's characters to possible answers, except for the hint characters
	for i in range(0, targetWord.length()):
		if not i in hintCharIndexes:
			answerChars.append(targetWord[i])

	# Randomize and add extra characters
	var numOfExtraChars = numOfAnswers - len(answerChars)
	while numOfExtraChars:
		var randomASCII: int = _rng.randi_range(97, 122)	# ASCII values for range a-z
		answerChars.append(String.chr(randomASCII))
		numOfExtraChars -= 1

	answerChars.shuffle()
	return answerChars

# Generate a random set of "Sound Bingo" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# The game plays `promptWord`'s pronunciation and the child picks the letter/digraph (`target`)
# responsible for that sound, out of `target` + `wrongAnswers`.
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.SOUND_BINGO`)
# - `target` (`String`) - the correct letter/digraph
# - `promptWord` (`String`) - the word whose pronunciation should be played (needs a matching audio file)
# - `wrongAnswers` (`Array` of `Strings`)
func generateSoundBingoQuizSet(numOfWrongAnswersPerQuiz: int = 3) -> void:
	var words: Array = SoundBingoDB.words.duplicate()
	words.shuffle()
	for entry in words:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.SOUND_BINGO
		quizDictionary.target = entry.target
		quizDictionary.promptWord = entry.exampleWord

		# Duplicate and shuffle this entry's own distractors, pick up to `numOfWrongAnswersPerQuiz`
		var distractors: Array = entry.distractors.duplicate()
		distractors.shuffle()
		var numOfWrongAnswers: int = min(numOfWrongAnswersPerQuiz, distractors.size())
		quizDictionary.wrongAnswers = distractors.slice(0, numOfWrongAnswers)

		_quizSet.append(quizDictionary)

# Generate a random set of "Write Prompt" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# The child sees an image and a partially-hidden word (some hint letters shown) and must type the
# full word — trains spelling and visual memory of the whole word shape.
# Reuses `MatchImageDB`'s target words, since those are the words with a matching image asset.
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.WRITE_PROMPT`)
# - `target` (`String`)
# - `numOfHintChars` (`int`)
func generateWritePromptQuizSet(ratioOfHintCharsPerQuiz: float = 0.3) -> void:
	var words: Array = MatchImageDB.words.duplicate()
	words.shuffle()
	for wordEntry in words:
		var wordSet: Array = wordEntry.words if wordEntry is Dictionary else wordEntry
		var targetWord: String = wordSet[0]

		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.WRITE_PROMPT
		quizDictionary.target = targetWord
		quizDictionary.numOfHintChars = int(ceil(targetWord.length() * ratioOfHintCharsPerQuiz))

		_quizSet.append(quizDictionary)

# Generate a random set of "Word Search" quizzes. Each quiz can be retrieved by calling `getNextQuiz()`
# The child sees a letter grid with a few words hidden inside it (left-to-right, top-to-bottom,
# or diagonally-down) and must click/select the letters of each listed word, in order, training
# visual tracking and letter-sequence attention.
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.WORD_SEARCH`)
# - `gridSize` (`int`)
# - `letters` (`Array` of single-character `Strings`, size `gridSize * gridSize`, row-major)
# - `words` (`Array` of `Dictionaries`, each with `word` (`String`) and `path` (`Array` of `int` cell indexes, in order)
func generateWordSearchQuizSet(gridSize: int = 5) -> void:
	for puzzle in WordSearchDB.puzzles:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.WORD_SEARCH
		quizDictionary.gridSize = gridSize

		var result: Dictionary = _buildWordSearchGrid(puzzle, gridSize)
		quizDictionary.letters = result.letters
		quizDictionary.words = result.words

		_quizSet.append(quizDictionary)

# Builds a single `gridSize` x `gridSize` letter grid with `words` placed inside it, without any
# two words sharing a cell (keeps the click-to-select logic simple and unambiguous).
# Returns a `Dictionary` with `letters` (flat `Array`) and `words` (`Array` of placement `Dictionaries`)
func _buildWordSearchGrid(words: Array, gridSize: int) -> Dictionary:
	var totalCells: int = gridSize * gridSize
	var letters: Array = []
	letters.resize(totalCells)

	var placedWords: Array = []

	for word in words:
		var path: Array = _tryPlaceWord(word, letters, gridSize)
		if path.is_empty():
			push_warning("QuizGenerator: could not place word '%s' in a %sx%s word search grid" % [word, gridSize, gridSize])
			continue

		for i in range(word.length()):
			letters[path[i]] = word[i]

		placedWords.append({ "word": word, "path": path })

	# Fill every still-empty cell with a random filler letter
	for i in range(totalCells):
		if letters[i] == null:
			letters[i] = String.chr(_rng.randi_range(97, 122))	# random a-z

	return { "letters": letters, "words": placedWords }

# Attempts (up to 200 times) to find a free straight line of cells for `word` in the grid.
# Returns an `Array` of cell indexes (in reading order) if successful, or an empty `Array` if not.
func _tryPlaceWord(word: String, letters: Array, gridSize: int) -> Array:
	var attempts: int = 0
	while attempts < 200:
		attempts += 1

		var direction: Vector2 = _WORD_SEARCH_DIRECTIONS[_rng.randi_range(0, _WORD_SEARCH_DIRECTIONS.size() - 1)]
		var xRange: Array = _startRange(gridSize, int(direction.x), word.length())
		var yRange: Array = _startRange(gridSize, int(direction.y), word.length())
		if xRange[0] > xRange[1] or yRange[0] > yRange[1]:
			continue	# word doesn't fit this direction in this grid at all

		var startX: int = _rng.randi_range(xRange[0], xRange[1])
		var startY: int = _rng.randi_range(yRange[0], yRange[1])

		var path: Array = []
		var freeSpot: bool = true
		for i in range(word.length()):
			var x: int = startX + int(direction.x) * i
			var y: int = startY + int(direction.y) * i
			var index: int = y * gridSize + x
			if letters[index] != null:
				freeSpot = false
				break
			path.append(index)

		if freeSpot:
			return path

	return []

# Returns the inclusive [min, max] range of valid starting coordinates along one axis,
# given the step (`delta`, one of -1/0/1) and the `length` of the word being placed
func _startRange(gridSize: int, delta: int, length: int) -> Array:
	if delta == 1:
		return [0, gridSize - length]
	elif delta == -1:
		return [length - 1, gridSize - 1]
	else:
		return [0, gridSize - 1]

# Finds and returns `numOfExtraWords` random words from the DB files that do not exist in `wordsToExclude`
func _getExtraRandomWords(numOfExtraWords: int, wordsToExclude: Array, quizType) -> Array:
	var extraAnswers: Array = []

	match quizType:
		QUIZ_TYPES.STARTS_WITH:
			while len(extraAnswers) < numOfExtraWords:
				# Keep picking random words until the picked word does not exist in `wordsToExclude`
				var randomIndex: int = _rng.randi_range(0, len(AllDB.words) - 1)
				while AllDB.words[randomIndex] in wordsToExclude:
					randomIndex = _rng.randi_range(0, len(AllDB.words) - 1)

				extraAnswers.append(AllDB.words[randomIndex])

		# Prevent "Rhymes With" quizzes from retrieving wrong answers from all files,
		# so that rhyme maintenance is restricted to the `Rhymes-With.gd` file, instead of all DB files
		QUIZ_TYPES.RHYMES_WITH:
			# Duplicate rhymes DB and remove set of words that correspond to the words in `wordsToExclude`
			var rhymeWordSets: Array = RhymesWithDB.words.duplicate(true)
			var breakOutOfOuterLoop: bool = false
			for wordSet in rhymeWordSets:
				if breakOutOfOuterLoop:
					break;

				for word in wordSet:
					if word in wordsToExclude:
						rhymeWordSets.erase(wordSet)
						breakOutOfOuterLoop = true
						break;

			while len(extraAnswers) < numOfExtraWords:
				# Pick a random word from a random word set
				var randomSetIndex: int = _rng.randi_range(0, len(rhymeWordSets) - 1)
				var randomSet: Array = rhymeWordSets[randomSetIndex]
				var randomWordIndex: int = _rng.randi_range(0, len(randomSet) - 1)
				var randomWord: String = randomSet[randomWordIndex]

				extraAnswers.append(randomWord)

		_:
			assert(false, "Other quiz types are not meant to call this method")

	return extraAnswers

# Generate a random set of "Syllable Blend" quizzes. Each quiz can be retrieved by
# calling `getNextQuiz()`
# These quizzes are `Dictionaries` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.PHONEME_BLEND`)
# - `word` (`String`) — the full target word
# - `syllables` (`Array` of `Strings`) — the word's syllable chunks, shuffled for display
func generatePhonemeBlendQuizSet() -> void:
	var words: Array = SyllableBlendDB.words.duplicate(true)
	words.shuffle()

	for wordEntry in words:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.PHONEME_BLEND
		quizDictionary.word = wordEntry.word
		quizDictionary.correctOrder = wordEntry.syllables.duplicate()
		quizDictionary.syllables = wordEntry.syllables.duplicate()
		quizDictionary.syllables.shuffle()

		_quizSet.append(quizDictionary)

# Generate a set of hand-authored "Custom Choice" quizzes from `pool` (an Array of
# Dictionaries, each with "question", "options" (Array of 4 Strings), and "correct_idx"
# (int)). Unlike the other generators, these questions are NOT auto-generated — every
# option was written by hand for a specific level (mirror-letter b/d/p/q confusions,
# odd-letter-out search, word mazes, etc.), so nothing here should be shuffled into/out
# of existence; only the on-screen ANSWER ORDER is randomized.
# If `pool` has fewer entries than a level has presents, it's cycled (duplicated) so
# there's always enough — repetition is fine (even useful) for this kind of drill.
# Each quiz is a `Dictionary` with the properties:
# - `quizType` (`QuizGenerator.QUIZ_TYPES.CUSTOM_CHOICE`)
# - `question` (`String`)
# - `options` (`Array` of `String`, in their original, still-correct-indexed order)
# - `correctIndex` (`int`) — index into `options` BEFORE shuffling (`prepareCustomChoiceQuiz` shuffles)
func generateCustomChoiceQuizSet(pool: Array) -> void:
	# No padding/cycling here on purpose: repeating an entry would mean the exact same
	# quiz could be handed out twice in one level. Callers top up the total count (if
	# `pool` has fewer entries than the level has presents) by ALSO calling a different
	# generator afterwards, so every quiz a level hands out is genuinely different.
	var entries: Array = pool.duplicate(true)
	entries.shuffle()

	for entry in entries:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.CUSTOM_CHOICE
		quizDictionary.question = entry.question
		quizDictionary.options = entry.options.duplicate()
		quizDictionary.correctIndex = entry.correct_idx

		_quizSet.append(quizDictionary)

# Generate a set of "Audio Sequence" quizzes from `pool` (an Array of Dictionaries, each
# with "sequence" (Array of letter-sound Strings, e.g. ["b","d"]), "options" (Array of
# Strings describing possible orderings, e.g. "B -> D"), and "correct_idx" (int)).
# The child hears each letter sound played in sequence (`WordAudio.playSequence()`, needs
# audio files at res://assets/Sound/Words/<letter>.ogg) and must pick which option
# describes the order they were played in — trains auditory sequential memory, a skill
# specifically called out for dyslexic learners (holding a short sound sequence in
# working memory long enough to reproduce its order).
# Cycled the same way `generateCustomChoiceQuizSet()` is if `pool` is smaller than
# `minimumCount`.
func generateAudioSequenceQuizSet(pool: Array) -> void:
	# No padding/cycling here on purpose: repeating an entry would mean the exact same
	# quiz could be handed out twice in one level. Callers top up the total count (if
	# `pool` has fewer entries than the level has presents) by ALSO calling a different
	# generator afterwards, so every quiz a level hands out is genuinely different.
	var entries: Array = pool.duplicate(true)
	entries.shuffle()

	for entry in entries:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.AUDIO_SEQUENCE
		quizDictionary.sequence = entry.sequence.duplicate()
		quizDictionary.options = entry.options.duplicate()
		quizDictionary.correctIndex = entry.correct_idx

		_quizSet.append(quizDictionary)

# Generate a set of "Rhymes With Image" quizzes from `pool` (an Array of Dictionaries,
# each with "image" (String, an image word — needs res://assets/Database/Images/<image>.png
# or .jpg), "question" (String, the on-screen prompt), "target" (String, the word that
# actually rhymes with the pictured word — NOT the pictured word itself), and
# "wrongAnswers" (Array of Strings)).
# Unlike `MATCH_IMAGE`, the picture and the correct answer are two DIFFERENT words —
# the child sees a picture (e.g. a bee) and must pick the word that rhymes with it
# (e.g. "tree"), not the word for the picture itself.
func generateRhymesWithImageQuizSet(pool: Array) -> void:
	# No padding/cycling here on purpose: repeating an entry would mean the exact same
	# quiz could be handed out twice in one level. Callers top up the total count (if
	# `pool` has fewer entries than the level has presents) by ALSO calling a different
	# generator afterwards, so every quiz a level hands out is genuinely different.
	var entries: Array = pool.duplicate(true)
	entries.shuffle()

	for entry in entries:
		var quizDictionary: Dictionary = {}
		quizDictionary.quizType = QUIZ_TYPES.RHYMES_WITH_IMAGE
		quizDictionary.image = entry.image
		quizDictionary.question = entry.get("question", "")
		quizDictionary.target = entry.target
		quizDictionary.wrongAnswers = entry.wrongAnswers.duplicate()

		_quizSet.append(quizDictionary)
