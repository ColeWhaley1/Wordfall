import SwiftData
import SwiftUI

/// The play screen: HUD and banner strip on top, the falling area in the
/// middle, and the answer, letter pad and Clear button within thumb reach.
struct GameView: View {
    let configuration: GameConfiguration

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var session: GameSession?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let session {
                GameContent(session: session, reducedMotion: reducedMotion, onQuit: quit)
            }
        }
        .statusBarHidden()
        .onAppear {
            guard session == nil else { return }
            let session = GameSession(configuration: configuration, services: services)
            self.session = session
            session.begin(modelContext: modelContext)
        }
        .onDisappear {
            session?.end()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session?.pause()
            }
        }
    }

    private var reducedMotion: Bool {
        systemReduceMotion || services.settings.reducedMotion
    }

    private func quit() {
        session?.end()
        dismiss()
    }
}

private struct GameContent: View {
    let session: GameSession
    let reducedMotion: Bool
    let onQuit: () -> Void

    @Environment(AppServices.self) private var services

    var body: some View {
        let engine = session.engine
        ZStack {
            // Fades slowly toward the theme's later colours as the words get harder.
            ThemedBackground(intensity: engine.intensity)
                .animation(reducedMotion ? .linear(duration: 0.3) : .easeInOut(duration: 3.5), value: engine.intensity)

            DangerGlow(progress: engine.activeWord?.progress ?? 0, threshold: engine.configuration.dangerThreshold, flash: session.missFlash, reducedMotion: reducedMotion)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                HUDView(engine: engine, onPause: { session.togglePause() })

                BannerStrip(banner: session.banner)

                BoardView(session: session, reducedMotion: reducedMotion)
                    .frame(maxHeight: .infinity)

                AnswerView(
                    word: engine.activeWord,
                    selection: engine.selection,
                    shake: session.answerShake,
                    reducedMotion: reducedMotion,
                    onRemove: { id in engine.deselect(tileID: id) }
                )

                Group {
                    if let word = engine.activeWord {
                        LetterPadView(
                            word: word,
                            selection: engine.selection,
                            swipeEnabled: services.settings.swipeInputEnabled,
                            reducedMotion: reducedMotion,
                            onSelect: { id, method in _ = engine.select(tileID: id, via: method) },
                            onDeselect: { id in engine.deselect(tileID: id) },
                            onToggle: { id in engine.toggle(tileID: id) }
                        )
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 160)

                // Kept well clear of the letter pad so it isn't hit by accident.
                ClearButton(isEnabled: !engine.selection.isEmpty, onClear: { engine.clearSelection() })
                    .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if engine.status == .paused {
                PauseOverlay(onResume: { session.resume() }, onQuit: onQuit)
                    .transition(.opacity)
            }

            if session.showExtraHeartOffer {
                ExtraHeartOfferView(
                    score: engine.score,
                    bestCombo: engine.bestCombo,
                    isShowingAd: session.isShowingAd,
                    onWatch: { session.watchAdForExtraHeart() },
                    onDecline: { session.declineExtraHeart() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if session.showGameOver {
                GameOverView(
                    engine: engine,
                    recorded: session.recorded,
                    onPlayAgain: session.canPlayAgain ? { session.leaveResults { session.playAgain() } } : nil,
                    onHome: { session.leaveResults(then: onQuit) }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: engine.status)
        .animation(.easeOut(duration: 0.3), value: session.showGameOver)
        .animation(.easeOut(duration: 0.3), value: session.showExtraHeartOffer)
    }
}

/// Out of lives: offers one extra heart for watching a rewarded ad. Only
/// shown when an ad is already loaded, and the ad only plays on a tap.
private struct ExtraHeartOfferView: View {
    let score: Int
    let bestCombo: Int
    let isShowingAd: Bool
    let onWatch: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("OUT OF LIVES")
                    .font(Theme.display(38))
                    .foregroundStyle(.white)

                VStack(spacing: 2) {
                    Text(NumberText.grouped(score))
                        .font(Theme.display(48))
                        .foregroundStyle(Theme.gold)
                        .accessibilityLabel("Score \(score)")
                    Text("BEST COMBO \(bestCombo)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.danger)
                    .shadow(color: Theme.danger.opacity(0.7), radius: 18)
                    .overlay(alignment: .topTrailing) {
                        Text("+1")
                            .font(Theme.display(22))
                            .foregroundStyle(.white)
                            .offset(x: 22, y: -8)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 6)

                Text("Watch a short ad to get 1 more life and keep your score, level and progress.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onWatch) {
                    HStack(spacing: 10) {
                        if isShowingAd {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                        }
                        Text("GET 1 MORE LIFE")
                    }
                }
                .buttonStyle(.arcade)
                .disabled(isShowingAd)

                Button("END GAME", action: onDecline)
                    .buttonStyle(.arcadeSecondary)
                    .disabled(isShowingAd)
            }
            .padding(24)
        }
    }
}

/// Fixed-height strip for PERFECT, LEVEL and combo banners, so they never
/// cover the falling word.
private struct BannerStrip: View {
    let banner: Banner?

    var body: some View {
        ZStack {
            if let banner {
                BannerView(banner: banner)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .id(banner.id)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: banner)
    }
}

// MARK: - Board

private struct BoardView: View {
    let session: GameSession
    let reducedMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let engine = session.engine
            let size = proxy.size
            let dangerY = size.height - 18
            ZStack {
                DangerLine(width: size.width)
                    .position(x: size.width / 2, y: dangerY)

                if let word = engine.activeWord {
                    let tile = Self.tileSize(letters: word.tiles.count, width: size.width)
                    let cardHeight = tile * 1.1 + tile * 0.7
                    FallingWordView(
                        word: word,
                        tileSize: tile,
                        reducedMotion: reducedMotion,
                        dangerThreshold: engine.configuration.dangerThreshold
                    )
                    .position(x: size.width / 2, y: Self.cardY(progress: word.progress, cardHeight: cardHeight, dangerY: dangerY))
                    .id(word.id)
                }

                ForEach(session.bursts) { burst in
                    SolveBurstView(burst: burst, reducedMotion: reducedMotion)
                        .position(x: size.width / 2, y: Self.cardY(progress: burst.progress, cardHeight: 60, dangerY: dangerY))
                }

                if let missed = session.revealedWord {
                    MissedWordView(word: missed)
                        .position(x: size.width / 2, y: dangerY - 44)
                        .transition(.opacity.combined(with: .scale(scale: 1.2)))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .modifier(ShakeEffect(amount: reducedMotion ? 0 : 12, shakes: 3, animatableData: CGFloat(session.boardShake)))
        .animation(.linear(duration: 0.4), value: session.boardShake)
        .animation(.easeOut(duration: 0.2), value: session.revealedWord)
    }

    static func tileSize(letters: Int, width: CGFloat) -> CGFloat {
        min(40, (width - 40) / (CGFloat(letters) * 1.14 + 0.9))
    }

    /// Card centre for a fall progress: touching the top at 0, the danger line at 1.
    static func cardY(progress: Double, cardHeight: CGFloat, dangerY: CGFloat) -> CGFloat {
        let top = cardHeight / 2 + 4
        let bottom = dangerY - cardHeight / 2
        return top + (bottom - top) * CGFloat(progress)
    }
}

/// Shows the answer to a word that reached the bottom.
private struct MissedWordView: View {
    let word: String

    var body: some View {
        VStack(spacing: 2) {
            Text("THE WORD WAS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            Text("✕ \(word)")
                .font(Theme.display(30))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Theme.danger.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.danger.opacity(0.7), radius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Missed. The word was \(word)")
    }
}

private struct DangerLine: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.danger.opacity(0.7))
                .frame(width: width, height: 2)
            Text("DANGER")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.danger)
                .padding(.horizontal, 8)
                .background(Capsule().fill(.black.opacity(0.55)))
        }
        .accessibilityHidden(true)
    }
}

/// Red pulse that builds as the word nears the bottom, and flashes on a miss.
private struct DangerGlow: View {
    let progress: Double
    let threshold: Double
    let flash: Bool
    let reducedMotion: Bool

    var body: some View {
        let danger = max(0, (progress - threshold) / (1 - threshold))
        let pulse = reducedMotion ? 1 : 0.65 + 0.35 * sin(progress * 60)
        LinearGradient(
            colors: [.clear, Theme.danger.opacity(0.45 * danger * pulse)],
            startPoint: .center,
            endPoint: .bottom
        )
        .overlay(Theme.danger.opacity(flash ? 0.28 : 0))
        .animation(.easeOut(duration: 0.3), value: flash)
        .allowsHitTesting(false)
    }
}

// MARK: - HUD

private struct HUDView: View {
    let engine: GameEngine
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<engine.configuration.startingLives, id: \.self) { index in
                        Image(systemName: index < engine.lives ? "heart.fill" : "heart")
                            .foregroundStyle(index < engine.lives ? Theme.danger : .white.opacity(0.3))
                    }
                }
                .font(.system(size: 20, weight: .bold))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(engine.lives) of \(engine.configuration.startingLives) lives")

                Spacer()

                Text(NumberText.grouped(engine.score))
                    .font(Theme.display(30))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: engine.score)
                    .accessibilityLabel("Score \(engine.score)")

                Spacer()

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Theme.panel, in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Pause")
            }

            HStack {
                Text(levelText)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if engine.combo >= 2 {
                    Text("🔥 \(engine.combo)× COMBO")
                        .font(Theme.display(16))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                        .id(engine.combo)
                }
            }
            .frame(height: 22)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: engine.combo)
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private var levelText: String {
        if let progress = engine.dailyProgress {
            return "DAILY · \(engine.difficulty.title) · WORD \(min(progress.played + 1, progress.total)) OF \(progress.total)"
        }
        return "LEVEL \(engine.level) · \(engine.difficulty.title)"
    }
}

// MARK: - Answer and controls

/// The letters spelled so far. Tap a letter to take it back out.
private struct AnswerView: View {
    let word: FallingWord?
    let selection: LetterSelection
    let shake: Int
    let reducedMotion: Bool
    let onRemove: (Int) -> Void

    var body: some View {
        let count = word?.tiles.count ?? 0
        let tiles = word?.tiles ?? []
        let chosen = selection.tileIDs
        let slot: CGFloat = count > 7 ? 34 : 42
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                let tileID: Int? = index < chosen.count ? chosen[index] : nil
                let letter = tileID.flatMap { id in tiles.first { $0.id == id } }.map { String($0.letter) } ?? ""
                Button {
                    if let tileID { onRemove(tileID) }
                } label: {
                    Text(letter)
                        .font(.system(size: slot * 0.55, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: slot, height: slot * 1.15)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(letter.isEmpty ? Theme.panel : Theme.accent.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(letter.isEmpty ? .white.opacity(0.15) : Theme.accent, lineWidth: 1.5)
                        )
                        .scaleEffect(letter.isEmpty ? 1 : 1.04)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(tileID == nil)
                .animation(reducedMotion ? nil : .spring(response: 0.18, dampingFraction: 0.5), value: letter)
                .accessibilityLabel(letter.isEmpty ? "Empty" : letter)
                .accessibilityHint(letter.isEmpty ? "" : "Removes this letter")
            }
        }
        .frame(height: 52)
        .modifier(ShakeEffect(amount: reducedMotion ? 0 : 10, shakes: 3, animatableData: CGFloat(shake)))
        .animation(.linear(duration: 0.3), value: shake)
    }
}

private struct ClearButton: View {
    let isEnabled: Bool
    let onClear: () -> Void

    var body: some View {
        Button(action: onClear) {
            Label("CLEAR", systemImage: "delete.left.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 180, height: 50)
                .background(Theme.panel, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("PAUSED")
                    .font(Theme.display(44))
                    .foregroundStyle(.white)
                Button("RESUME", action: onResume)
                    .buttonStyle(.arcade)
                Button("QUIT", action: onQuit)
                    .buttonStyle(.arcadeSecondary)
            }
            .padding(32)
        }
    }
}
