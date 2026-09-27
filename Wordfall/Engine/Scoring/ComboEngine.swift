import Foundation

/// Named combo milestones shown as a banner.
enum ComboMilestone: Equatable, Sendable {
    case wordChain      // 5
    case unstoppable    // 10
    case legendary(Int) // 20, 30, ...

    var title: String {
        switch self {
        case .wordChain: return "WORD CHAIN"
        case .unstoppable: return "UNSTOPPABLE"
        case .legendary: return "LEGENDARY"
        }
    }
}

struct ComboEngine: Sendable {
    private(set) var count = 0
    private(set) var best = 0

    /// Registers a solved word and returns a milestone if one was just reached.
    mutating func registerSolve() -> ComboMilestone? {
        count += 1
        best = max(best, count)
        return Self.milestone(for: count)
    }

    mutating func reset() {
        count = 0
    }

    static func milestone(for count: Int) -> ComboMilestone? {
        switch count {
        case 5: return .wordChain
        case 10: return .unstoppable
        case let n where n >= 20 && n % 10 == 0: return .legendary(n)
        default: return nil
        }
    }
}
