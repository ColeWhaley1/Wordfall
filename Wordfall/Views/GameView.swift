import SwiftData
import SwiftUI

/// The play screen: HUD on top, the falling area in the middle, and the
/// answer, letter pad and keyboard toggle within thumb reach at the bottom.
struct GameView: View {
    let configuration: GameConfiguration

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var session: GameSession?
    @State private var keyboardVisible = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let session {
                GameContent(
                    session: session,
                    keyboardVisible: $keyboardVisible,
                    reducedMotion: reducedMotion,
                    onQuit: quit
                )
            }
        }
        .statusBarHidden()
        .onAppear {
            guard session == nil else { return }
            keyboardVisible = services.settings.keyboardInputEnabled && services.settings.showKeyboard
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
        .onChange(of: keyboardVisible) { _, visible in
            services.settings.showKeyboard = visible
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
    @Binding var keyboardVisible: Bool
    let reducedMotion: Bool
    let onQuit: () -> Void

    @Environment(AppServices.self) private var services

    var body: some View {
        let engine = session.engine
        let settings = services.settings
        ZStack {
            DangerGlow(progress: engine.activeWord?.progress ?? 0, threshold: engine.configuration.dangerThreshold, flash: session.missFlash, reducedMotion: reducedMotion)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HUDView(engine: engine, onPause: { session.togglePause() })

                BoardView(session: session, reducedMotion: reducedMotion)
                    .frame(maxHeight: .infinity)

                AnswerView(word: engine.activeWord, input: engine.currentInput, shake: session.answerShake, reducedMotion: reducedMotion)

                Group {
                    if let word = engine.activeWord {
                        LetterPadView(
                            word: word,
                            selection: engine.selection,
                            swipeEnabled: settings.swipeInputEnabled,
                            reducedMotion: reducedMotion,
                            onSelect: { id, method in _ = engine.select(tileID: id, via: method) },
                            onDeselect: { id in engine.deselect(tileID: id) },
                            onToggle: { id in engine.toggle(tileID: id) }
                        )
                    } else {
                        Color.clear
                    }
                }
                .frame(height: keyboardVisible ? 64 : 150)

                ControlsRow(
                    keyboardVisible: $keyboardVisible,
                    keyboardEnabled: settings.keyboardInputEnabled,
                    canClear: !engine.selection.isEmpty,
                    onClear: { engine.clearSelection() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            KeyboardInput(
                isActive: Binding(
                    get: { keyboardVisible && settings.keyboardInputEnabled && engine.status == .playing },
                    set: { keyboardVisible = $0 }
                ),
                onInsert: { session.type($0) },
                onDelete: { session.deleteBackward() }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)

            if engine.status == .paused {
                PauseOverlay(onResume: { session.resume() }, onQuit: onQuit)
                    .transition(.opacity)
            }

            if engine.status == .gameOver {
                GameOverView(
                    engine: engine,
                    recorded: session.recorded,
                    onPlayAgain: session.isDaily ? nil : { session.playAgain() },
                    onHome: onQuit
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: engine.status)
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

                if let banner = session.banner {
                    BannerView(banner: banner)
                        .position(x: size.width / 2, y: size.height * 0.3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(banner.id)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .modifier(ShakeEffect(amount: reducedMotion ? 0 : 12, shakes: 3, animatableData: CGFloat(session.boardShake)))
        .animation(.linear(duration: 0.4), value: session.boardShake)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: session.banner)
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
                .background(Theme.backgroundBottom)
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
            return "DAILY · WORD \(min(progress.played + 1, progress.total)) OF \(progress.total)"
        }
        return "LEVEL \(engine.level)"
    }
}

// MARK: - Answer and controls

private struct AnswerView: View {
    let word: FallingWord?
    let input: String
    let shake: Int
    let reducedMotion: Bool

    var body: some View {
        let count = word?.tiles.count ?? 0
        let letters = Array(input)
        let slot: CGFloat = count > 7 ? 32 : 40
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                let letter = index < letters.count ? String(letters[index]) : ""
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
                    .animation(reducedMotion ? nil : .spring(response: 0.18, dampingFraction: 0.5), value: letter)
            }
        }
        .frame(height: 50)
        .modifier(ShakeEffect(amount: reducedMotion ? 0 : 10, shakes: 3, animatableData: CGFloat(shake)))
        .animation(.linear(duration: 0.3), value: shake)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer")
        .accessibilityValue(input.isEmpty ? "empty" : input)
    }
}

private struct ControlsRow: View {
    @Binding var keyboardVisible: Bool
    let keyboardEnabled: Bool
    let canClear: Bool
    let onClear: () -> Void

    var body: some View {
        HStack {
            if keyboardEnabled {
                Button {
                    keyboardVisible.toggle()
                } label: {
                    Label(keyboardVisible ? "Hide keyboard" : "Keyboard", systemImage: keyboardVisible ? "keyboard.chevron.compact.down" : "keyboard")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.panel, in: Capsule())
                }
            }
            Spacer()
            Button(action: onClear) {
                Label("Clear", systemImage: "delete.left")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.panel, in: Capsule())
            }
            .disabled(!canClear)
            .opacity(canClear ? 1 : 0.4)
        }
        .foregroundStyle(.white)
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
