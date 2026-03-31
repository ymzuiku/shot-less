import UIKit

// Shared grid-layout utilities used by both ScreenshotListViewController and KeptLibraryViewController.

/// UICollectionViewFlowLayout subclass that guards against a UIKit crash:
/// "request for layout attributes for supplementary view in section N when there are only M sections"
/// This can happen during the initial layout pass before data is loaded.
private class SafeFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let cv = collectionView, indexPath.section < cv.numberOfSections else { return nil }
        return super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
    }
}

enum GridLayoutHelper {
    static let itemSpacing: CGFloat = 2

    static func makeLayout(columns: Int) -> UICollectionViewFlowLayout {
        let screenWidth = UIScreen.main.bounds.width
        return makeLayout(itemWidth: exactItemWidth(columns: columns, screenWidth: screenWidth))
    }

    static func exactItemWidth(columns: Int, screenWidth: CGFloat) -> CGFloat {
        floor((screenWidth - itemSpacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    static func makeLayout(itemWidth: CGFloat) -> UICollectionViewFlowLayout {
        let screenWidth = UIScreen.main.bounds.width
        let cols = max(1, Int((screenWidth + itemSpacing) / (itemWidth + itemSpacing)))
        let totalUsed = itemWidth * CGFloat(cols) + itemSpacing * CGFloat(cols - 1)
        let sideInset = floor((screenWidth - totalUsed) / 2)
        let layout = SafeFlowLayout()
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = itemSpacing
        layout.minimumLineSpacing = itemSpacing
        layout.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
        layout.headerReferenceSize = .zero
        return layout
    }

    static func groupByDate(_ items: [ScreenshotItem], formatter: DateFormatter) -> [ScreenshotSection] {
        let calendar = Calendar.current
        var groups: [Date: [ScreenshotItem]] = [:]
        for item in items {
            guard let date = item.creationDate else { continue }
            groups[calendar.startOfDay(for: date), default: []].append(item)
        }
        return groups.keys.sorted(by: >).map { date in
            ScreenshotSection(date: date, title: formatter.string(from: date), items: groups[date] ?? [])
        }
    }
}
