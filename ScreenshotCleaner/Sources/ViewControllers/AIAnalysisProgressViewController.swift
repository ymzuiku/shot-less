import UIKit
import Photos
import Vision

/// Modal sheet that runs on-device Vision analysis over all screenshots.
/// Results are stored in VisionResultCache; after completion a notification
/// is posted so ScreenshotListViewController re-applies its AI filters.
class AIAnalysisProgressViewController: UIViewController {

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = L10n.str("ai_analysis.title")
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.textAlignment = .center
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = L10n.str("ai_analysis.preparing")
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    private let progressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progress = 0
        return p
    }()

    private let cancelButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.title = L10n.str("cancel")
        config.cornerStyle = .medium
        return UIButton(configuration: config)
    }()

    private let doneButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = L10n.str("ai_analysis.done")
        config.cornerStyle = .medium
        let btn = UIButton(configuration: config)
        btn.isHidden = true
        return btn
    }()

    // MARK: - State

    private var task: DispatchWorkItem?
    private var isCancelled = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        isModalInPresentation = true

        [titleLabel, statusLabel, progressView, cancelButton, doneButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 32),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 160),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),

            doneButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 32),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 160),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnalysis()
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        isCancelled = true
        task?.cancel()
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    // MARK: - Analysis

    private func startAnalysis() {
        let fetchOptions = PHFetchOptions()
        let s = AppSettings.shared
        switch s.libraryMode {
        case .screenshots:
            fetchOptions.predicate = NSPredicate(
                format: "(mediaSubtype & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        case .allPhotos:
            break
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }

        guard !assets.isEmpty else {
            DispatchQueue.main.async { self.finish() }
            return
        }

        let total = assets.count
        let cache = VisionResultCache.shared
        let cancelFlag = { [weak self] in self?.isCancelled ?? true }

        let workTask = DispatchWorkItem {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 4
            queue.qualityOfService = .userInitiated

            let manager = PHImageManager.default()
            let thumbOptions = PHImageRequestOptions()
            thumbOptions.isSynchronous = true
            thumbOptions.deliveryMode = .fastFormat
            thumbOptions.resizeMode = .fast
            let thumbSize = CGSize(width: 300, height: 300)

            let lock = NSLock()
            var processed = 0
            let semaphore = DispatchSemaphore(value: 4)

            for asset in assets {
                guard !cancelFlag() else { break }
                semaphore.wait()

                let op = BlockOperation {
                    defer { semaphore.signal() }
                    guard !cancelFlag() else { return }

                    // Skip if already cached
                    if cache.flags(for: asset.localIdentifier) == nil {
                        manager.requestImage(
                            for: asset,
                            targetSize: thumbSize,
                            contentMode: .aspectFit,
                            options: thumbOptions
                        ) { image, _ in
                            guard let cgImage = image?.cgImage else { return }
                            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                            let faceReq    = VNDetectFaceRectanglesRequest()
                            let humanReq   = VNDetectHumanRectanglesRequest()
                            let barcodeReq = VNDetectBarcodesRequest()
                            try? handler.perform([faceReq, humanReq, barcodeReq])
                            var flags: VisionResultCache.Flags = []
                            if !(faceReq.results    ?? []).isEmpty { flags.insert(.face) }
                            if !(humanReq.results   ?? []).isEmpty { flags.insert(.human) }
                            if !(barcodeReq.results ?? []).isEmpty { flags.insert(.barcode) }
                            cache.store(identifier: asset.localIdentifier, flags: flags)
                        }
                    }

                    lock.lock()
                    processed += 1
                    let snap = processed
                    lock.unlock()

                    DispatchQueue.main.async { [weak self] in
                        self?.updateProgress(processed: snap, total: total)
                    }
                }
                queue.addOperation(op)
            }

            queue.waitUntilAllOperationsAreFinished()

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isCancelled else { return }
                VisionResultCache.shared.flush()
                self.finish()
            }
        }

        task = workTask
        DispatchQueue.global(qos: .userInitiated).async(execute: workTask)
    }

    private func updateProgress(processed: Int, total: Int) {
        progressView.progress = Float(processed) / Float(total)
        statusLabel.text = L10n.fmt("ai_analysis.progress", processed, total)
    }

    private func finish() {
        NotificationCenter.default.post(name: .aiAnalysisDidComplete, object: nil)
        isModalInPresentation = false
        progressView.progress = 1
        statusLabel.text = L10n.str("ai_analysis.completed")
        UIView.animate(withDuration: 0.2) {
            self.cancelButton.isHidden = true
            self.doneButton.isHidden = false
        }
    }
}
