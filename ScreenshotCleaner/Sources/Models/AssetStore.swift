import Foundation

extension Notification.Name {
    static let keptIdsDidChange    = Notification.Name("AssetStore.keptIdsDidChange")
    static let aiAnalysisDidComplete = Notification.Name("AIAnalysis.didComplete")
}

final class AssetStore {
    static let shared = AssetStore()
    private init() { load() }

    private let keptKey        = "keptAssetIds_v1"
    private let skipKey        = "skipAnalysisIds_v1"

    private(set) var keptIds:         Set<String> = []
    private(set) var skipAnalysisIds: Set<String> = []

    // MARK: - Kept

    func markKept(_ ids: Set<String>) {
        keptIds.formUnion(ids)
        persist(keptIds, key: keptKey)
        NotificationCenter.default.post(name: .keptIdsDidChange, object: nil)
    }

    func unmarkKept(_ ids: Set<String>) {
        keptIds.subtract(ids)
        persist(keptIds, key: keptKey)
        NotificationCenter.default.post(name: .keptIdsDidChange, object: nil)
    }

    func isKept(_ id: String) -> Bool { keptIds.contains(id) }

    // MARK: - Skip Analysis

    func markSkipAnalysis(_ ids: Set<String>) {
        skipAnalysisIds.formUnion(ids)
        persist(skipAnalysisIds, key: skipKey)
    }

    func shouldSkipAnalysis(_ id: String) -> Bool { skipAnalysisIds.contains(id) }

    // MARK: - Persistence (compact: store array, not JSON dict)

    private func persist(_ set: Set<String>, key: String) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }

    private func load() {
        keptIds         = Set(UserDefaults.standard.stringArray(forKey: keptKey)        ?? [])
        skipAnalysisIds = Set(UserDefaults.standard.stringArray(forKey: skipKey) ?? [])
    }
}
