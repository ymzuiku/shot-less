import Foundation

/// Persists on-device Vision analysis results so screenshots are never re-analyzed.
/// Key: PHAsset.localIdentifier  Value: bitmask of which filters triggered
final class VisionResultCache {

    static let shared = VisionResultCache()
    private init() { load() }

    // MARK: - Filter bitmask

    struct Flags: OptionSet, Codable {
        let rawValue: UInt8
        static let face    = Flags(rawValue: 1 << 0)
        static let human   = Flags(rawValue: 1 << 1)
        static let barcode = Flags(rawValue: 1 << 2)
    }

    // MARK: - Storage

    private let defaultsKey = "visionResultCacheV1"
    private var cache: [String: UInt8] = [:]  // localIdentifier → Flags.rawValue
    private var dirty = false

    func flags(for identifier: String) -> Flags? {
        cache[identifier].map { Flags(rawValue: $0) }
    }

    func store(identifier: String, flags: Flags) {
        cache[identifier] = flags.rawValue
        dirty = true
    }

    func flush() {
        guard dirty else { return }
        dirty = false
        let snapshot = cache
        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.defaultsKey)
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: UInt8].self, from: data)
        else { return }
        cache = decoded
    }
}
