import UIKit
import Photos

class KeptLibraryViewController: UIViewController {

    // MARK: - Properties

    private var sections: [ScreenshotSection] = []
    private var allItems: [ScreenshotItem] = []
    private var flatAssets: [PHAsset] = []
    private var allIndexPaths: [IndexPath] = []
    private var selectedIdentifiers: Set<String> = []

    private var currentColumns = AppSettings.shared.defaultColumns
    private var pinchStartItemWidth: CGFloat = 0
    private var pickIconsVisible = true

    private let sectionDateFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .none
        df.locale = Locale.current; return df
    }()
    private let navDateFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        df.locale = Locale.current; return df
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
        let v = UIActivityIndicatorView(style: .large); v.hidesWhenStopped = true; return v
    }()

    private let emptyStateView: EmptyStateView = {
        let v = EmptyStateView()
        v.configure(title: L10n.str("keep.empty.title"), subtitle: L10n.str("keep.empty.subtitle"))
        v.isHidden = true
        return v
    }()

    private lazy var bottomBar: KeptBottomBar = {
        let bar = KeptBottomBar()
        bar.onUnmark = { [weak self] in self?.confirmUnmark() }
        bar.onDelete  = { [weak self] in self?.confirmDelete() }
        return bar
    }()

    private var bottomBarBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.str("keep.title")
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        setupUI()
        setupGestures()
        loadKeptAssets()
        NotificationCenter.default.addObserver(self, selector: #selector(keptIdsChanged), name: .keptIdsDidChange, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let extra = max(0, tabBarHeight - view.safeAreaInsets.bottom)
        bottomBarBottomConstraint?.constant = -(16 + extra)
        let bottom = 86 + extra
        collectionView.contentInset.bottom = bottom
        collectionView.verticalScrollIndicatorInsets.bottom = bottom
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let desired = AppSettings.shared.defaultColumns
        if desired != currentColumns {
            currentColumns = desired
            collectionView.setCollectionViewLayout(GridLayoutHelper.makeLayout(columns: currentColumns), animated: false)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        [collectionView, loadingIndicator, emptyStateView, bottomBar].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        let bc = bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        bottomBarBottomConstraint = bc
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

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bc,
        ])
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

    // MARK: - Data

    private func loadKeptAssets() {
        let ids = Array(AssetStore.shared.keptIds)
        guard !ids.isEmpty else {
            allItems = []
            reloadSections()
            return
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var items: [ScreenshotItem] = []
        result.enumerateObjects { asset, _, _ in items.append(ScreenshotItem(asset: asset)) }
        allItems = items
        reloadSections()
    }

    @objc private func keptIdsChanged() {
        loadKeptAssets()
    }

    private func reloadSections() {
        sections = GridLayoutHelper.groupByDate(allItems, formatter: sectionDateFormatter)
        flatAssets = sections.flatMap { $0.items.map { $0.asset } }
        rebuildIndexPaths()
        emptyStateView.isHidden = !sections.isEmpty
        collectionView.reloadData()
        updateDateTitleView()
        updateNavigationBar()
    }

    private func rebuildIndexPaths() {
        allIndexPaths = sections.enumerated().flatMap { sIdx, section in
            section.items.indices.map { IndexPath(item: $0, section: sIdx) }
        }
    }

    // MARK: - Navigation bar

    private func updateNavigationBar() {
        navigationItem.rightBarButtonItems = selectedIdentifiers.isEmpty
            ? []
            : [makeDeselectButton()]
    }

    private func makeDeselectButton() -> UIBarButtonItem {
        UIBarButtonItem(title: L10n.str("deselect_all"), style: .plain, target: self, action: #selector(deselectAll))
    }

    @objc private func deselectAll() {
        selectedIdentifiers.removeAll()
        bottomBar.updateCount(0)
        collectionView.visibleCells.compactMap { $0 as? ScreenshotCell }.forEach { $0.setChecked(false) }
        updateNavigationBar()
    }

    private func updateDateTitleView() {
        guard !sections.isEmpty else { navigationItem.titleView = nil; return }
        let date = visibleTopSectionDate() ?? sections.first!.date
        setDateTitleLabel(date: date)
    }

    private func visibleTopSectionDate() -> Date? {
        let visibleOriginY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        var topSection: Int? = nil
        let cvSections = collectionView.numberOfSections
        for s in 0..<min(sections.count, cvSections) {
            guard let frame = collectionView.layoutAttributesForSupplementaryElement(
                ofKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: s))?.frame else { continue }
            if frame.minY <= visibleOriginY + 1 { topSection = s } else { break }
        }
        return topSection.map { sections[$0].date }
    }

    private func setDateTitleLabel(date: Date) {
        if let label = navigationItem.titleView as? UILabel {
            label.text = navDateFormatter.string(from: date); label.sizeToFit()
        } else {
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: .regular)
            label.textColor = .secondaryLabel
            label.text = navDateFormatter.string(from: date); label.sizeToFit()
            navigationItem.titleView = label
        }
    }

    // MARK: - Pinch

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let screenWidth = UIScreen.main.bounds.width
        let minWidth = floor(screenWidth / 6)
        switch gesture.state {
        case .began:
            pinchStartItemWidth = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize.width ?? screenWidth / CGFloat(currentColumns)
        case .changed:
            let liveWidth = (pinchStartItemWidth * gesture.scale).clamped(to: minWidth...screenWidth)
            let liveCols = max(1, min(6, Int((screenWidth / liveWidth).rounded())))
            if liveCols != currentColumns {
                currentColumns = liveCols
                collectionView.setCollectionViewLayout(GridLayoutHelper.makeLayout(columns: liveCols), animated: false)
                pinchStartItemWidth = GridLayoutHelper.exactItemWidth(columns: liveCols, screenWidth: screenWidth) / gesture.scale
            }
        default: break
        }
    }

    // MARK: - Pick icon visibility

    private func setPickIconsVisible(_ visible: Bool) {
        guard pickIconsVisible != visible else { return }
        pickIconsVisible = visible
        let cells = collectionView.visibleCells.compactMap { $0 as? ScreenshotCell }
        if !visible {
            cells.forEach { $0.pickInteractionEnabled = false; $0.setPickIconsHidden(true, animated: true) }
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

    // MARK: - Full screen

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
        let ip = allIndexPaths[flatIndex]
        if let cell = collectionView.cellForItem(at: ip) { return cell.convert(cell.bounds, to: view.window) }
        if let attr = collectionView.layoutAttributesForItem(at: ip) { return collectionView.convert(attr.frame, to: view.window) }
        return nil
    }

    // MARK: - Unmark / Delete

    private func confirmUnmark() {
        let count = selectedIdentifiers.count
        guard count > 0 else { return }
        let alert = UIAlertController(title: L10n.str("keep.unmark_confirm.title"),
                                      message: L10n.fmt("keep.unmark_confirm.message", count),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.str("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.fmt("keep.unmark_count", count), style: .default) { [weak self] _ in
            self?.performUnmark()
        })
        present(alert, animated: true)
    }

    private func performUnmark() {
        let ids = selectedIdentifiers
        AssetStore.shared.unmarkKept(ids)
        // keptIdsChanged notification will reload this VC; also update Library via same notification
        selectedIdentifiers.removeAll()
        bottomBar.updateCount(0)
        updateNavigationBar()
    }

    private func confirmDelete() {
        let count = selectedIdentifiers.count
        guard count > 0 else { return }
        let alert = UIAlertController(title: L10n.str("delete_alert.title"),
                                      message: L10n.fmt("delete_alert.message", count),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.str("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.fmt("keep.delete_count", count), style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        present(alert, animated: true)
    }

    private func performDelete() {
        let toDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(selectedIdentifiers), options: nil)
        // Also remove from keptIds so the store stays clean
        AssetStore.shared.unmarkKept(selectedIdentifiers)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(toDelete)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.selectedIdentifiers.removeAll()
                    self?.bottomBar.updateCount(0)
                    self?.updateNavigationBar()
                    self?.loadKeptAssets()
                } else {
                    let alert = UIAlertController(title: L10n.str("error"),
                                                  message: error?.localizedDescription ?? L10n.str("delete_failed"),
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.str("ok"), style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension KeptLibraryViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { sections[section].items.count }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as! SectionHeaderView
        let s = sections[indexPath.section]
        header.configure(dateTitle: s.title, count: s.items.count)
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
            self.bottomBar.updateCount(self.selectedIdentifiers.count)
            self.updateNavigationBar()
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension KeptLibraryViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 36)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !sections.isEmpty else { return }
        let date = visibleTopSectionDate() ?? sections.first!.date
        setDateTitleLabel(date: date)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension KeptLibraryViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
