import Photos

struct ScreenshotItem {
    let asset: PHAsset

    var localIdentifier: String { asset.localIdentifier }
    var creationDate: Date? { asset.creationDate }
}

struct ScreenshotSection {
    let date: Date
    let title: String
    var items: [ScreenshotItem]
}
