# Word Fallout

A native iOS arcade word game. A scrambled word falls down the screen and you
unscramble it before it hits the danger line, by typing, tapping letters, or
swiping across them. Any real word that uses exactly the same letters counts,
and there is no submit button: the moment the letters spell a word, it bursts.

Built with Swift, SwiftUI, Observation and SwiftData. No backend and no
accounts; the game itself works fully offline. The only network use is Google
AdMob for optional rewarded ads.

The project, target, module and bundle ID are still named `Wordfall`; only the
player-facing name (home screen, title, share text) is "Word Fallout".

## Running it

1. Open `Wordfall.xcodeproj` in Xcode 16 or later.
2. Select the **Wordfall** target → *Signing & Capabilities* → pick your team
   (only needed for a real device; the simulator works without one).
3. Run on an iPhone simulator or device. Portrait, iPhone only, iOS 17+.

## What's in this version

- **Endless mode**: one falling word at a time, 3 lives, level up every 5
  words. Each extra letter adds more fall time than the one before, and part
  of that time never speeds up with level (a 3-letter word falls in 6.5s at
  level 1, a 6-letter word in 15.1s, a 9-letter word in 28.1s; a 7-letter word
  still gets 12.7s at top speed). Word length grows in steps from 3 letters up
  to 9. Levels 1–5 only use everyday words, and names and abbreviations are
  never picked.
- **Difficulty** (endless only), chosen on the home screen: Easy (1.45× time,
  friendlier words up to 6 letters, ×0.35 points), Normal, Hard (words from
  3 levels ahead, 0.82× time, ×1.6 points) and Expert (6 levels ahead, 0.68×
  time, ×2.4 points).
- **Fading background**: during a game the background slowly blends through
  the equipped theme's colors as you level up (a new color about every 4
  levels, starting further along on Hard and Expert).
- **Coins and shop**: every round pays 1 coin per 20 points (+25 for finishing
  a daily). Coins buy cosmetic backgrounds and letter-tile themes in the shop.
- **Missed words** are revealed at the danger line, including the one that
  ends the game, and the game-over screen lists every word with whether you
  got it.
- **Tap and swipe input**: tap tiles, or swipe across them with a forgiving
  hit area, and mix the two freely. Tap a letter in the answer (or its tile)
  to take it back out, slide back over a letter mid-swipe to undo it, or hit
  Clear. A full-length wrong answer shakes and clears. (The system keyboard
  was dropped after playtesting; the engine still supports typed input.)
- **Scoring**: length-based base score × speed bonus × combo multiplier ×
  level multiplier, plus a +25% PERFECT bonus for solving in the first 40% of
  the fall. Combo milestones at 5 (WORD CHAIN), 10 (UNSTOPPABLE) and every 10
  after that.
- **Game feel**: solve burst with sparks, floating score and combo, banners,
  a danger zone that pulses and trembles, screen shake on a miss, haptics for
  every action, and synthesised sound effects (no audio files needed).
- **Extra heart (rewarded ad)**: when an endless game runs out of lives, the
  player is offered one extra heart for watching an ad, once per game. Score,
  level and time carry on. Never offered in the daily, which stays one fair
  attempt. The game's stats and coins are saved only once the game really
  ends.
- **Daily mode**: 10 words, 3 lives, one attempt per day. Generated from the
  date alone, so everyone gets the same puzzle offline. It ignores the
  endless difficulty; instead the day of the week sets it: Monday Easy,
  Tuesday/Wednesday/Sunday Normal, Thursday/Friday Hard, Saturday Expert.
  Harder days have longer words, less time and more points.
  Wordle-style share text that doesn't reveal the answers, plus a daily
  streak.
- **Stats** (SwiftData): high score, best combo, best level, totals, fastest
  solve, longest word, accuracy, recent games.
- **Settings**: haptics, sound, swipe input, reduced motion
  (also follows the iOS Reduce Motion setting).

Not built yet, per the plan's "don't build initially" list: multiple
simultaneous words, special words, power-ups, Game Center leaderboards and
achievements (these need App Store Connect setup).

## Ads (Google AdMob)

- SDK: Google Mobile Ads 13.x and Google's User Messaging Platform 3.x, added
  as Swift packages in the Xcode project (the engine package doesn't use them).
- AdMob app ID `ca-app-pub-8273060205096005~6804088162` and the SKAdNetwork IDs
  live in `Config/Info.plist`, which Xcode merges with the generated Info.plist.
- Code is split by job, and the game engine knows nothing about ads:
  - `AdConfiguration` and `AdPolicy` (`Wordfall/Engine/Ads/`) decide *whether*
    an ad may be shown. Plain Swift, saved in UserDefaults, covered by
    `AdPolicyTests`.
  - `ConsentManager` (`Wordfall/Ads/`) runs Google's consent form at launch,
    only where the law requires it (e.g. EEA/UK). Where required, Settings
    shows **Privacy Choices** so players can change their consent.
  - `AdManager` (`Wordfall/Ads/`) starts the SDK once consent allows, keeps
    one rewarded and one interstitial ad preloaded, and reloads each right
    after it's shown (retrying failed loads with a backoff).
  - `GameSession` reports what happened and asks the policy before each ad.
- **Rewarded (extra heart)**: offered when an endless run is out of lives,
  once per run, and only if an ad is already loaded (the player never waits).
  Never in the daily.
- **Interstitial**: only when leaving an endless game's results (Home or Play
  Again), never during play or in the daily. Requires at least 3 completed
  games ever, 3 games since the last interstitial, no rewarded ad in that run,
  and 2 minutes since the last ad (5 after a rewarded ad).
- **Remove Ads**: `AdPolicy.hasRemovedAds` turns interstitials off and keeps
  the opt-in rewarded ad. There's no purchase yet (it needs an in-app
  purchase product in App Store Connect first).
- **Analytics**: `Analytics.log` (`Wordfall/App/Analytics.swift`) receives the
  ad and game events (`rewarded_ad_started`, `interstitial_shown`,
  `game_over_after_rewarded`, …). No provider is connected; debug builds print
  them. Debug builds also have an **Ads (dev only)** section in Settings to see
  and reset the counters.
- **Tracking:** after the consent step, the app asks for App Tracking
  Transparency permission (text in `Config/Info.plist`), so Google can show
  personalised ads to players who allow it.
- **Test vs live ads:** Debug builds, and TestFlight builds (detected by
  their sandbox receipt), use Google's test units. App Store builds use the
  real units. A Release build run straight from Xcode also counts as
  production, so add your own iPhone as a test device in AdMob before doing
  that. The live units are rewarded `ca-app-pub-8273060205096005/1305097902`, interstitial
  `ca-app-pub-8273060205096005/1378259257`. Never tap or repeatedly watch your
  own live ads.
- Before release: create and publish a GDPR consent message (and optionally
  an IDFA explainer) under *Privacy & messaging* in AdMob, add an
  `app-ads.txt` to the developer website, and fill in the App Store privacy
  "nutrition label" for the data the Google Mobile Ads SDK collects.

## Project layout

```
Wordfall/
├── App/          App entry, shared services, settings, theme, cosmetics
├── Ads/          AdMob consent and rewarded ads
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
├── Persistence/  SwiftData models (stats, results, coins and cosmetics) and the stats recorder
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
about 9,800 are "playable" (eligible to fall). Accepted words are checked
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

- Difficulty curve and fall times: `DifficultyService` (`Wordfall/Engine/Words/DifficultyService.swift`)
- Easy/Normal/Hard/Expert: `GameDifficulty`
- Points and bonuses: `ScoreEngine`
- Coin payout: `CoinRules`
- Shop items and prices, background color stops: `CosmeticCatalog` (`Wordfall/App/Cosmetics.swift`)
- Lives and pacing between words: `GameConfiguration`
- Daily weekday difficulty, length curves and fall speed: `DailyChallengeGenerator`
