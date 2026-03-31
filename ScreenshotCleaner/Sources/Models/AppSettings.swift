import Foundation

// MARK: - LibraryMode

enum LibraryMode: String, CaseIterable {
    /// Only images with the system screenshot subtype.
    case screenshots
    /// All images in the photo library.
    case allPhotos
}

// MARK: - AppSettings

final class AppSettings {
    static let shared = AppSettings()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - Language

    /// Language code, e.g. "en", "zh-Hans", "ja". "system" means follow device.
    var language: String {
        get { defaults.string(forKey: "appLanguage") ?? "system" }
        set { defaults.set(newValue, forKey: "appLanguage") }
    }

    // MARK: - Metadata Filter

    /// Filter screenshots that Photos.app has tagged as containing people (uses library metadata, no extra computation).
    var filterPeopleMetadata: Bool {
        get { defaults.bool(forKey: "filterPeopleMetadata") }
        set { defaults.set(newValue, forKey: "filterPeopleMetadata") }
    }

    // MARK: - AI Filters (Vision framework, on-device)

    /// Exclude screenshots where Vision detects a human face.
    var filterFaces: Bool {
        get { defaults.bool(forKey: "filterFaces") }
        set { defaults.set(newValue, forKey: "filterFaces") }
    }

    /// Exclude screenshots where Vision detects a human body.
    var filterPeopleAI: Bool {
        get { defaults.bool(forKey: "filterPeopleAI") }
        set { defaults.set(newValue, forKey: "filterPeopleAI") }
    }

    /// Exclude screenshots where Vision detects a barcode or QR code.
    var filterBarcodes: Bool {
        get { defaults.bool(forKey: "filterBarcodes") }
        set { defaults.set(newValue, forKey: "filterBarcodes") }
    }

    // MARK: - Source

    /// Controls which images are shown in the library.
    var libraryMode: LibraryMode {
        get { LibraryMode(rawValue: defaults.string(forKey: "libraryMode") ?? "") ?? .screenshots }
        set { defaults.set(newValue.rawValue, forKey: "libraryMode") }
    }

    // MARK: - Display

    /// Default number of columns in the screenshot grid. Falls back to 4 if never explicitly set.
    var defaultColumns: Int {
        get {
            let v = defaults.integer(forKey: "defaultColumns")
            return v == 0 ? 4 : v
        }
        set { defaults.set(newValue, forKey: "defaultColumns") }
    }
}
