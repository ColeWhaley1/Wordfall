import Foundation

/// Wordle-style text summary of a daily run. Never reveals the answers.
enum ShareResult {
    static func emoji(for outcome: WordOutcome?) -> String {
        switch outcome {
        case .perfect: return "🟩"
        case .solved: return "🟨"
        case .missed: return "🟥"
        case nil: return "⬛"
        }
    }

    static func grid(outcomes: [WordOutcome], total: Int, perRow: Int = 5) -> String {
        let cells = (0..<max(total, outcomes.count)).map { index in
            emoji(for: outcomes.indices.contains(index) ? outcomes[index] : nil)
        }
        return stride(from: 0, to: cells.count, by: perRow)
            .map { cells[$0..<min($0 + perRow, cells.count)].joined(separator: " ") }
            .joined(separator: "\n")
    }

    static func text(number: Int, outcomes: [WordOutcome], total: Int, score: Int, bestCombo: Int) -> String {
        let solved = outcomes.filter { $0 != .missed }.count
        var lines = [
            "Wordfall Daily #\(number)",
            "\(solved)/\(total)",
            "",
            grid(outcomes: outcomes, total: total),
            "",
            "Score: \(NumberText.grouped(score))",
        ]
        if bestCombo > 1 {
            lines.append("🔥 \(bestCombo) combo")
        }
        lines.append("Can you beat me?")
        return lines.joined(separator: "\n")
    }
}

enum NumberText {
    /// 12840 → "12,840", independent of locale so shared text is consistent.
    static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var out = ""
        for (index, character) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(character)
        }
        return value < 0 ? "-" + out : out
    }
}
