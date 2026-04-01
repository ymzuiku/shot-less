import UIKit
import Photos

// MARK: - Filter option

enum FilterOption: CaseIterable {
    case all, lastWeek, lastMonth, lastYear
}

// MARK: - 双指触控检测（不干扰其他手势）
class TwoFingerObserverGestureRecognizer: UIGestureRecognizer {
    var onTwoFingerDown: (() -> Void)?
    var onTwoFingerUp: (() -> Void)?
    private var twoFingerActive = false

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let count = event.allTouches?.filter { $0.phase != .cancelled }.count ?? 0
        if count >= 2 && !twoFingerActive {
            twoFingerActive = true
            onTwoFingerDown?()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        let remaining = event.allTouches?.filter {
            $0.phase != .ended && $0.phase != .cancelled
        }.count ?? 0
        if remaining < 2 && twoFingerActive {
            twoFingerActive = false
            onTwoFingerUp?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        touchesEnded(touches, with: event)
    }
}

// MARK: - FilterSnapshot

private struct FilterSnapshot: Equatable {
    let metadata     = AppSettings.shared.filterPeopleMetadata
    let faces        = AppSettings.shared.filterFaces
    let peopleAI     = AppSettings.shared.filterPeopleAI
    let barcodes     = AppSettings.shared.filterBarcodes
    let libraryMode  = AppSettings.shared.libraryMode
}

// MARK: - ScreenshotListViewController

class ScreenshotListViewController: UIViewController {

    // MARK: - Properties

    private var sections: [ScreenshotSection] = []
    private var allRawItems: [ScreenshotItem] = []      // unfiltered cache from Photos
    private var filteredRawItems: [ScreenshotItem] = [] // after people/barcode filters
    private var flatAssets: [PHAsset] = []
    private var selectedIdentifiers: Set<String> = []

    // Grid
    private var currentColumns = AppSettings.shared.defaultColumns
    private var pinchStartItemWidth: CGFloat = 0

    // Auto-select
    private var isAutoSelecting = false
    private var autoSelectTimer: Timer?
    private var allIndexPaths: [IndexPath] = []
    private var autoSelectCursor: Int = 0

    // Pick 图标可见状态
    private var pickIconsVisible = true

    // Sort & Filter
    private var sortAscending = false
    private var filterOption: FilterOption = .all

    // Snapshot of AppSettings filter state — used to detect changes on tab switch
    private var appliedFilterSnapshot = FilterSnapshot()

    private let sectionDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        df.locale = Locale.current
        return df
    }()

    private let navDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale.current
        return df
    }()

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: GridLayoutHelper.makeLayout(columns: currentColumns))
        cv.backgroundColor = .systemBackground
        cv.alwaysBounceVertical = true
        cv.register(ScreenshotCell.self, forCellWithReuseIdentifier: ScreenshotCell.reuseIdentifier)
        cv.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        v.hidesWhenStopped = true
        return v
    }()

    private lazy var loadingToast = LoadingToastView(message: L10n.str("loading.updating_library"))

    private let emptyStateView: EmptyStateView = {
        let v = EmptyStateView()
        v.configure(title: L10n.str("empty.title"), subtitle: L10n.str("empty.subtitle"))
        v.isHidden = true
        return v
    }()

    private lazy var bottomDeleteBar: BottomDeleteBar = {
        let bar = BottomDeleteBar()
        bar.onAutoSelect = { [weak self] in self?.startAutoSelect() }
        bar.onPause     = { [weak self] in self?.pauseAutoSelect() }
        bar.onDelete    = { [weak self] in self?.confirmDelete() }
        return bar
    }()

    private var deleteBarBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupGestures()
        requestPhotoAccess()
        NotificationCenter.default.addObserver(self, selector: #selector(keptIdsChanged), name: .keptIdsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(aiAnalysisDidComplete), name: .aiAnalysisDidComplete, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func keptIdsChanged() {
        guard !allRawItems.isEmpty else { return }
        applyFiltersAsync()
    }

    @objc private func aiAnalysisDidComplete() {
        guard !allRawItems.isEmpty else { return }
        loadingToast.show(in: view, bottomOffset: 100)
        applyFiltersAsync()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // iOS 26 floating tab bar does not adjust safeAreaInsets automatically —
        // push the delete bar up by the visible tab bar height if it overlaps.
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let safeBottom = view.safeAreaInsets.bottom
        // Extra offset needed when the tab bar sits above the safe area bottom
        let extra = max(0, tabBarHeight - safeBottom)
        deleteBarBottomConstraint?.constant = -(16 + extra)
        updateContentInset(extraBottom: extra)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Re-fetch or re-filter if settings changed
        let current = FilterSnapshot()
        refreshTitle()
        if current != appliedFilterSnapshot {
            let libraryModeChanged = current.libraryMode != appliedFilterSnapshot.libraryMode
            appliedFilterSnapshot = current
            loadingIndicator.startAnimating()
            loadingToast.show(in: view, bottomOffset: 100)
            if libraryModeChanged || allRawItems.isEmpty {
                loadScreenshots()
            } else {
                applyFiltersAsync()
            }
        }

        // Re-apply grid layout if default columns changed
        let desiredColumns = AppSettings.shared.defaultColumns
        if desiredColumns != currentColumns {
            currentColumns = desiredColumns
            collectionView.setCollectionViewLayout(GridLayoutHelper.makeLayout(columns: currentColumns), animated: false)
        }
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        refreshTitle()
        updateNavigationBar()
    }

    private func refreshTitle() {
        let key: String
        switch AppSettings.shared.libraryMode {
        case .screenshots: key = "library.title.screenshots"
        case .allPhotos:   key = "library.title.allPhotos"
        }
        navigationItem.title = L10n.str(key)
    }

    private func updateNavigationBar() {
        navigationItem.rightBarButtonItems = selectedIdentifiers.isEmpty
            ? [makeMenuBarButton()]
            : [makeMoreActionsButton(), makeMenuBarButton()]
        updateDateTitleView()
    }

    private func makeMoreActionsButton() -> UIBarButtonItem {
        let markKeep = UIAction(
            title: L10n.str("action.mark_keep"),
            image: UIImage(systemName: "bookmark")
        ) { [weak self] _ in self?.markSelectedAsKept() }

        let deselect = UIAction(
            title: L10n.str("deselect_all"),
            image: UIImage(systemName: "xmark.circle")
        ) { [weak self] _ in self?.deselectAllTapped() }

        let menu = UIMenu(children: [markKeep, deselect])
        return UIBarButtonItem(title: L10n.str("action.more"),
                               image: UIImage(systemName: "ellipsis.circle"), menu: menu)
    }

    private func markSelectedAsKept() {
        let ids = selectedIdentifiers
        AssetStore.shared.markKept(ids)
        removeFromDisplay(excludedIds: ids)
        selectedIdentifiers.removeAll()
        bottomDeleteBar.updateCount(0)
        updateNavigationBar()
    }

    private func updateDateTitleView() {
        guard !sections.isEmpty else {
            navigationItem.titleView = nil
            return
        }
        let date = visibleTopSectionDate() ?? sections.first!.date
        setDateTitleView(date: date)
    }

    /// Returns the date of the topmost section currently visible in the collection view.
    private func visibleTopSectionDate() -> Date? {
        // Find the section whose header is at or just above the top of the visible area
        let visibleOriginY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        var topSection: Int? = nil
        let cvSections = collectionView.numberOfSections
        for s in 0..<min(sections.count, cvSections) {
            let attrs = collectionView.layoutAttributesForSupplementaryElement(
                ofKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: s)
            )
            guard let frame = attrs?.frame else { continue }
            // Pick the last section header whose top is at or above the visible origin
            if frame.minY <= visibleOriginY + 1 {
                topSection = s
            } else {
                break
            }
        }
        return topSection.map { sections[$0].date }
    }

    private func setDateTitleView(date: Date) {
        if let label = navigationItem.titleView as? UILabel {
            label.text = navDateFormatter.string(from: date)
            label.sizeToFit()
        } else {
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: .regular)
            label.textColor = .secondaryLabel
            label.text = navDateFormatter.string(from: date)
            label.sizeToFit()
            navigationItem.titleView = label
        }
    }

    private func makeMenuBarButton() -> UIBarButtonItem {
        let sortNewest = UIAction(
            title: L10n.str("sort.newest_first"),
            image: UIImage(systemName: "arrow.down"),
            state: sortAscending ? .off : .on
        ) { [weak self] _ in
            self?.sortAscending = false
            self?.reloadSections()
        }
        let sortOldest = UIAction(
            title: L10n.str("sort.oldest_first"),
            image: UIImage(systemName: "arrow.up"),
            state: sortAscending ? .on : .off
        ) { [weak self] _ in
            self?.sortAscending = true
            self?.reloadSections()
        }

        let filterAll = UIAction(
            title: L10n.str("filter.all"),
            state: filterOption == .all ? .on : .off
        ) { [weak self] _ in self?.applyFilter(.all) }
        let filterWeek = UIAction(
            title: L10n.str("filter.last_week"),
            state: filterOption == .lastWeek ? .on : .off
        ) { [weak self] _ in self?.applyFilter(.lastWeek) }
        let filterMonth = UIAction(
            title: L10n.str("filter.last_month"),
            state: filterOption == .lastMonth ? .on : .off
        ) { [weak self] _ in self?.applyFilter(.lastMonth) }
        let filterYear = UIAction(
            title: L10n.str("filter.last_year"),
            state: filterOption == .lastYear ? .on : .off
        ) { [weak self] _ in self?.applyFilter(.lastYear) }

        let menu = UIMenu(children: [
            UIMenu(title: L10n.str("sort"), options: .displayInline, children: [sortNewest, sortOldest]),
            UIMenu(title: L10n.str("filter"), options: .displayInline, children: [filterAll, filterWeek, filterMonth, filterYear])
        ])
        return UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), menu: menu)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        [collectionView, loadingIndicator, emptyStateView, bottomDeleteBar].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomDeleteBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomDeleteBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            {
                let c = bottomDeleteBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
                deleteBarBottomConstraint = c
                return c
            }(),
        ])
    }

    private func updateContentInset(extraBottom: CGFloat = 0) {
        let bottom = 86 + extraBottom
        collectionView.contentInset.bottom = bottom
        collectionView.verticalScrollIndicatorInsets.bottom = bottom
    }

    private func setupGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collectionView.addGestureRecognizer(pinch)

        let twoFinger = TwoFingerObserverGestureRecognizer(target: nil, action: nil)
        twoFinger.onTwoFingerDown = { [weak self] in self?.setPickIconsVisible(false) }
        twoFinger.onTwoFingerUp   = { [weak self] in self?.setPickIconsVisible(true) }
        twoFinger.delegate = self
        collectionView.addGestureRecognizer(twoFinger)
    }

    // MARK: - Layout (delegates to GridLayoutHelper)

    private var currentItemWidth: CGFloat {
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize.width
            ?? UIScreen.main.bounds.width / CGFloat(currentColumns)
    }

    // MARK: - Pinch

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let screenWidth = UIScreen.main.bounds.width
        let minWidth = floor(screenWidth / 6)
        let maxWidth = screenWidth

        switch gesture.state {
        case .began:
            pinchStartItemWidth = currentItemWidth

        case .changed:
            let liveWidth = (pinchStartItemWidth * gesture.scale).clamped(to: minWidth...maxWidth)
            let liveCols = max(1, min(6, Int((screenWidth / liveWidth).rounded())))

            if liveCols != currentColumns {
                currentColumns = liveCols
                collectionView.setCollectionViewLayout(GridLayoutHelper.makeLayout(columns: liveCols), animated: false)
                pinchStartItemWidth = GridLayoutHelper.exactItemWidth(columns: liveCols, screenWidth: screenWidth) / gesture.scale
            }

        case .ended, .cancelled:
            break

        default: break
        }
    }

    // MARK: - Pick 图标显隐

    private func setPickIconsVisible(_ visible: Bool) {
        guard pickIconsVisible != visible else { return }
        pickIconsVisible = visible

        let cells = collectionView.visibleCells.compactMap { $0 as? ScreenshotCell }

        if !visible {
            cells.forEach { cell in
                cell.pickInteractionEnabled = false
                cell.setPickIconsHidden(true, animated: true)
            }
        } else {
            var pending = cells.count
            guard pending > 0 else { return }
            cells.forEach { cell in
                cell.setPickIconsHidden(false, animated: true) {
                    pending -= 1
                    if pending == 0 { cells.forEach { $0.pickInteractionEnabled = true } }
                }
            }
        }
    }

    // MARK: - Photo Access

    private func requestPhotoAccess() {
        loadingIndicator.startAnimating()
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited: self?.loadScreenshots()
                case .denied, .restricted:
                    self?.loadingIndicator.stopAnimating()
                    self?.showPermissionDeniedAlert()
                default: self?.loadingIndicator.stopAnimating()
                }
            }
        }
    }

    private func loadScreenshots() {
        let fetchOptions = PHFetchOptions()
        switch AppSettings.shared.libraryMode {
        case .screenshots:
            fetchOptions.predicate = NSPredicate(
                format: "(mediaSubtype & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        case .allPhotos:
            break // no predicate — fetch everything
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var items: [ScreenshotItem] = []
        result.enumerateObjects { asset, _, _ in items.append(ScreenshotItem(asset: asset)) }

        allRawItems = items
        applyFiltersAsync()
    }

    // MARK: - Filter pipeline

    private func applyFiltersAsync() {
        var items = allRawItems

        // Always filter out items the user has marked as Keep
        let keptIds = AssetStore.shared.keptIds
        if !keptIds.isEmpty {
            items = items.filter { !keptIds.contains($0.localIdentifier) }
        }

        // Metadata filter: check Photos smart album (selfie portraits)
        if AppSettings.shared.filterPeopleMetadata {
            let personIds = fetchPeopleAssetIds()
            items = items.filter { !personIds.contains($0.localIdentifier) }
        }

        // AI filters — use only cached Vision results (no live analysis on launch)
        let s = AppSettings.shared
        if s.filterFaces || s.filterPeopleAI || s.filterBarcodes {
            let cache = VisionResultCache.shared
            items = items.filter { item in
                guard let flags = cache.flags(for: item.localIdentifier) else { return true }
                if s.filterFaces    && flags.contains(.face)    { return false }
                if s.filterPeopleAI && flags.contains(.human)   { return false }
                if s.filterBarcodes && flags.contains(.barcode) { return false }
                return true
            }
        }

        filteredRawItems = items
        appliedFilterSnapshot = FilterSnapshot()
        reloadSections()
        loadingIndicator.stopAnimating()
        loadingToast.hide()
    }

    /// Returns the set of asset identifiers that Photos has tagged in self-portrait (selfie) smart albums.
    /// Note: Photos doesn't expose a public "has faces" property; selfie album is the best available metadata proxy.
    private func fetchPeopleAssetIds() -> Set<String> {
        var ids: Set<String> = []
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil
        )
        collections.enumerateObjects { col, _, _ in
            let assets = PHAsset.fetchAssets(in: col, options: nil)
            assets.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        }
        return ids
    }


    /// Removes items with the given IDs from the displayed sections using animated batch deletions.
    /// No reloadData — only the affected cells are touched, preventing grid flicker.
    private func removeFromDisplay(excludedIds: Set<String>) {
        guard !excludedIds.isEmpty else { return }

        var sectionDeletes = IndexSet()
        var itemDeletes: [IndexPath] = []

        for (sIdx, section) in sections.enumerated() {
            let removals = section.items.indices
                .filter { excludedIds.contains(section.items[$0].localIdentifier) }
                .map { IndexPath(item: $0, section: sIdx) }
            if removals.count == section.items.count {
                sectionDeletes.insert(sIdx)
            } else if !removals.isEmpty {
                itemDeletes.append(contentsOf: removals)
            }
        }

        let itemDeletesToApply = itemDeletes.filter { !sectionDeletes.contains($0.section) }
        guard !sectionDeletes.isEmpty || !itemDeletesToApply.isEmpty else { return }

        // Update data model before performBatchUpdates
        filteredRawItems = filteredRawItems.filter { !excludedIds.contains($0.localIdentifier) }
        for s in sectionDeletes.reversed() { sections.remove(at: s) }
        for ip in itemDeletesToApply.sorted(by: { $0 > $1 }) {
            sections[ip.section].items.remove(at: ip.item)
        }
        flatAssets = sections.flatMap { $0.items.map { $0.asset } }
        rebuildIndexPaths()

        collectionView.performBatchUpdates({
            collectionView.deleteSections(sectionDeletes)
            collectionView.deleteItems(at: itemDeletesToApply)
        })
    }

    private func reloadSections() {
        var items = filteredRawItems

        // Apply date filter
        let now = Date()
        let calendar = Calendar.current
        switch filterOption {
        case .all: break
        case .lastWeek:
            let cutoff = calendar.date(byAdding: .day, value: -7, to: now)!
            items = items.filter { ($0.creationDate ?? .distantPast) >= cutoff }
        case .lastMonth:
            let cutoff = calendar.date(byAdding: .month, value: -1, to: now)!
            items = items.filter { ($0.creationDate ?? .distantPast) >= cutoff }
        case .lastYear:
            let cutoff = calendar.date(byAdding: .year, value: -1, to: now)!
            items = items.filter { ($0.creationDate ?? .distantPast) >= cutoff }
        }

        var grouped = groupByDate(items)

        // Apply sort order
        if sortAscending {
            grouped = grouped.sorted { $0.date < $1.date }
            grouped = grouped.map { section in
                var s = section
                s.items = s.items.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
                return s
            }
        }

        sections = grouped
        flatAssets = sections.flatMap { $0.items.map { $0.asset } }
        rebuildIndexPaths()

        if sections.isEmpty {
            emptyStateView.isHidden = false
            collectionView.reloadData()
        } else {
            emptyStateView.isHidden = true
            collectionView.reloadData()
            if isAutoSelecting { autoSelectCursor = 0; continueAutoSelect() }
        }

        updateDateTitleView()
        // Refresh menu to reflect current state
        updateNavigationBar()
    }

    private func groupByDate(_ items: [ScreenshotItem]) -> [ScreenshotSection] {
        GridLayoutHelper.groupByDate(items, formatter: sectionDateFormatter)
    }

    private func rebuildIndexPaths() {
        allIndexPaths = sections.enumerated().flatMap { sIdx, section in
            section.items.indices.map { IndexPath(item: $0, section: sIdx) }
        }
    }

    // MARK: - Deselect All

    @objc private func deselectAllTapped() {
        selectedIdentifiers.removeAll()
        isAutoSelecting = false
        autoSelectTimer?.invalidate()
        autoSelectTimer = nil
        bottomDeleteBar.setAutoSelectMode(false, animated: false)
        bottomDeleteBar.updateCount(0)
        collectionView.visibleCells.compactMap { $0 as? ScreenshotCell }.forEach { $0.setChecked(false) }
        updateNavigationBar()
    }

    // MARK: - Filter

    private func applyFilter(_ option: FilterOption) {
        filterOption = option
        loadingToast.show(in: view, bottomOffset: 100)
        reloadSections()
        loadingToast.hide()
    }

    // MARK: - Full Screen

    private func openFullScreen(at flatIndex: Int) {
        let vc = FullScreenPhotoViewController(assets: flatAssets, initialIndex: flatIndex)
        vc.getCellFrameInWindow = { [weak self] in self?.cellFrameInWindow(for: $0) }
        present(vc, animated: false)
        let sourceFrame = cellFrameInWindow(for: flatIndex) ?? view.frame
        let thumbnail = (collectionView.cellForItem(at: allIndexPaths[flatIndex]) as? ScreenshotCell)?.thumbnailImage()
        vc.presentAnimated(from: sourceFrame, thumbnail: thumbnail)
    }

    private func cellFrameInWindow(for flatIndex: Int) -> CGRect? {
        guard flatIndex < allIndexPaths.count else { return nil }
        let indexPath = allIndexPaths[flatIndex]
        if let cell = collectionView.cellForItem(at: indexPath) {
            return cell.convert(cell.bounds, to: view.window)
        }
        if let attr = collectionView.layoutAttributesForItem(at: indexPath) {
            return collectionView.convert(attr.frame, to: view.window)
        }
        return nil
    }

    // MARK: - Auto Select

    private func startAutoSelect() {
        isAutoSelecting = true
        if autoSelectCursor > 0 { autoSelectCursor -= 1 }
        bottomDeleteBar.setAutoSelectMode(true)
        continueAutoSelect()
    }

    private func continueAutoSelect() {
        autoSelectTimer?.invalidate()
        autoSelectTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.autoSelectNextBatch()
        }
    }

    private func autoSelectNextBatch() {
        guard isAutoSelecting else { return }
        let end = min(autoSelectCursor + 6, allIndexPaths.count)
        guard autoSelectCursor < allIndexPaths.count else {
            autoSelectTimer?.invalidate()
            isAutoSelecting = false
            bottomDeleteBar.setAutoSelectMode(false)
            return
        }

        for i in autoSelectCursor..<end {
            let indexPath = allIndexPaths[i]
            let item = sections[indexPath.section].items[indexPath.item]
            guard !selectedIdentifiers.contains(item.localIdentifier) else { continue }
            selectedIdentifiers.insert(item.localIdentifier)
            if let cell = collectionView.cellForItem(at: indexPath) as? ScreenshotCell {
                cell.setChecked(true, animated: true)
            }
            if i == end - 1 { collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true) }
        }
        autoSelectCursor = end
        bottomDeleteBar.updateCount(selectedIdentifiers.count)
        updateNavigationBar()
    }

    private func pauseAutoSelect() {
        isAutoSelecting = false
        autoSelectTimer?.invalidate()
        autoSelectTimer = nil
        bottomDeleteBar.setAutoSelectMode(false)
        bottomDeleteBar.updateCount(selectedIdentifiers.count)
    }

    // MARK: - Delete

    private func confirmDelete() {
        let count = selectedIdentifiers.count
        guard count > 0 else { return }
        let alert = UIAlertController(title: L10n.str("delete_alert.title"), message: L10n.fmt("delete_alert.message", count), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.str("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.str("delete_action"), style: .destructive) { [weak self] _ in self?.deleteSelectedScreenshots() })
        present(alert, animated: true)
    }

    private func deleteSelectedScreenshots() {
        if isAutoSelecting { pauseAutoSelect() }
        let toDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(selectedIdentifiers), options: nil)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(toDelete)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.selectedIdentifiers.removeAll()
                    self?.bottomDeleteBar.updateCount(0)
                    self?.updateNavigationBar()
                    self?.loadScreenshots()
                } else {
                    self?.showErrorAlert(message: error?.localizedDescription ?? L10n.str("delete_failed"))
                }
            }
        }
    }

    // MARK: - Alerts

    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: L10n.str("no_photos_access.title"), message: L10n.str("no_photos_access.message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.str("go_to_settings"), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        alert.addAction(UIAlertAction(title: L10n.str("cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: L10n.str("error"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.str("ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension ScreenshotListViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as! SectionHeaderView
        let section = sections[indexPath.section]
        header.configure(dateTitle: section.title, count: section.items.count)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScreenshotCell.reuseIdentifier, for: indexPath) as! ScreenshotCell
        let item = sections[indexPath.section].items[indexPath.item]
        let isChecked = selectedIdentifiers.contains(item.localIdentifier)
        cell.configure(with: item, isChecked: isChecked)

        if !pickIconsVisible { cell.setPickIconsHidden(true, animated: false) }
        cell.pickInteractionEnabled = pickIconsVisible

        let flatIndex = allIndexPaths.firstIndex(of: indexPath) ?? 0

        cell.onViewPhoto = { [weak self] in self?.openFullScreen(at: flatIndex) }
        cell.onCheckToggle = { [weak self] in
            guard let self else { return }
            if self.selectedIdentifiers.contains(item.localIdentifier) {
                self.selectedIdentifiers.remove(item.localIdentifier)
                cell.setChecked(false)
            } else {
                self.selectedIdentifiers.insert(item.localIdentifier)
                cell.setChecked(true)
            }
            self.bottomDeleteBar.updateCount(self.selectedIdentifiers.count)
            self.updateNavigationBar()
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate / FlowLayout

extension ScreenshotListViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 36)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !sections.isEmpty else { return }
        let date = visibleTopSectionDate() ?? sections.first!.date
        setDateTitleView(date: date)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ScreenshotListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Comparable clamped helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
