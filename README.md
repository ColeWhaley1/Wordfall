# Wordfall

A native iOS arcade word game. A scrambled word falls down the screen and you
unscramble it before it hits the danger line, by typing, tapping letters, or
swiping across them. Any real word that uses exactly the same letters counts,
and there is no submit button: the moment the letters spell a word, it bursts.

Built with Swift, SwiftUI, Observation and SwiftData. Fully offline: no
backend, no accounts, no API.

## Running it

1. Open `Wordfall.xcodeproj` in Xcode 16 or later.
2. Select the **Wordfall** target → *Signing & Capabilities* → pick your team
   (only needed for a real device; the simulator works without one).
3. Run on an iPhone simulator or device. Portrait, iPhone only, iOS 17+.

## What's in this version

- **Endless mode**: one falling word at a time, 3 lives, level up every 5
  words. The difficulty curve alternates between faster falls and longer
  words (3 letters at level 1 up to 9 letters later), and rare words are kept
  out of early levels.
- **Three input methods at once**: the system keyboard, tapping tiles, and
  swiping across tiles with a forgiving hit area. They all feed the same
  selection, so you can tap R and then type ATE. Sliding back over a letter
  during a swipe undoes it; a full-length wrong answer shakes and clears.
- **Scoring**: length-based base score × speed bonus × combo multiplier ×
  level multiplier, plus a +25% PERFECT bonus for solving in the first 40% of
  the fall. Combo milestones at 5 (WORD CHAIN), 10 (UNSTOPPABLE) and every 10
  after that.
- **Game feel**: solve burst with sparks, floating score and combo, banners,
  a danger zone that pulses and trembles, screen shake on a miss, haptics for
  every action, and synthesised sound effects (no audio files needed).
- **Daily mode**: 10 words (4 to 7 letters), 3 lives, one attempt per day.
  Generated from the date alone, so everyone gets the same puzzle offline.
  Wordle-style share text that doesn't reveal the answers, plus a daily
  streak.
- **Stats** (SwiftData): high score, best combo, best level, totals, fastest
  solve, longest word, accuracy, recent games.
- **Settings**: haptics, sound, swipe input, keyboard input, reduced motion
  (also follows the iOS Reduce Motion setting).

Not built yet, per the plan's "don't build initially" list: multiple
simultaneous words, special words, power-ups, Game Center leaderboards and
achievements (these need App Store Connect setup).

## Project layout

```
Wordfall/
├── App/          App entry, shared services, settings, theme
├── Engine/       Pure game logic, no UI (also a Swift package, see below)
│   ├── Words/    Word database, anagram signatures, validator, generator, difficulty
│   ├── Core/     GameEngine, falling words, configuration, events
│   ├── Input/    LetterSelection, the shared result of every input method
│   ├── Scoring/  ScoreEngine and ComboEngine, all tuning numbers in one place
│   └── Daily/    Deterministic daily challenge and share text
├── Game/         GameSession (connects the engine to the screen) and the frame clock
├── Input/        Keyboard capture and the tap/swipe letter pad
├── Views/        Home, game, game over, daily, stats, settings
├── Effects/      Haptics and sound
├── Persistence/  SwiftData models and the stats recorder
└── Resources/    words.json
Tests/            Unit tests for the engine
tools/            Word list builder
```

`GameEngine` owns the rules and never touches SwiftUI. The app calls
`tick(_:)` every frame with the elapsed time, and views observe the engine's
state. One-off moments (solved, missed, level up) arrive as `GameEvent`s,
which `GameSession` turns into animation, sound and haptics. Nothing is
written to disk during play; stats are saved once when a game ends.

## Tests

The engine is also a Swift package (`Package.swift` points at
`Wordfall/Engine`), so the game logic can be tested without a simulator:

```sh
swift test
```

CI (`.github/workflows/ci.yml`) runs those tests and builds the iOS app on
every push to `main`.

## Word list

`Wordfall/Resources/words.json` holds about 32,000 accepted answers, of which
about 12,300 are "playable" (eligible to fall). Accepted words are checked
against two dictionaries plus word frequency data; playable words are
additionally common, in both dictionaries, and pass a profanity filter. Each
entry has a length, a 1–5 difficulty, a normalised frequency and a `common`
flag. To rebuild it:

```sh
pip install wordfreq english-words better_profanity
python3 tools/build_words.py
```

Changing the word list changes daily puzzles, so bump
`DailyChallengeGenerator.version` if you rebuild it after release.

## Tuning

- Difficulty curve: `DifficultyService` (`Wordfall/Engine/Words/DifficultyService.swift`)
- Points and bonuses: `ScoreEngine`
- Lives and pacing between words: `GameConfiguration`
- Daily length curve and fall speed: `DailyChallengeGenerator`
