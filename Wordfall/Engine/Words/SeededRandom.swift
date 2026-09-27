import Foundation

/// SplitMix64: a tiny, fast, deterministic generator. The same seed always
/// yields the same sequence on every device, which Daily mode relies on.
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform-enough index in 0..<upperBound. Implemented here rather than via
    /// the standard library so results can never change between Swift versions.
    mutating func index(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

extension Array {
    /// Fisher–Yates shuffle with a stable, version-independent algorithm.
    func stableShuffled(using rng: inout SeededRandom) -> [Element] {
        var result = self
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = rng.index(below: i + 1)
            result.swapAt(i, j)
        }
        return result
    }
}

enum StableHash {
    /// FNV-1a over UTF-8 bytes. Unlike `hashValue`, identical across launches and devices.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
