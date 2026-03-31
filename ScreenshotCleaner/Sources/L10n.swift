import Foundation

enum L10n {

    private static var _bundle: Bundle?

    static var bundle: Bundle {
        if let b = _bundle { return b }
        return refreshBundle()
    }

    /// Call after changing AppSettings.language to pick up the new locale.
    @discardableResult
    static func refreshBundle() -> Bundle {
        let lang = AppSettings.shared.language
        if lang != "system",
           let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let b = Bundle(path: path) {
            _bundle = b
        } else {
            _bundle = .main
        }
        return _bundle!
    }

    static func str(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func fmt(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: bundle, comment: ""), arguments: args)
    }
}
