import UIKit
import Photos

// MARK: - FullScreenPhotoViewController

class FullScreenPhotoViewController: UIViewController {

    private let assets: [PHAsset]
    private(set) var currentIndex: Int
    var getCellFrameInWindow: ((Int) -> CGRect?)?

    private let backgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.alpha = 0
        return v
    }()

    private let pageVC = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: [.interPageSpacing: 16.0]
    )

    // 右上角关闭按钮
    private let closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark.circle.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium))
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.85)
        let btn = UIButton(configuration: config)
        btn.alpha = 0
        return btn
    }()

    init(assets: [PHAsset], initialIndex: Int) {
        self.assets = assets
        self.currentIndex = initialIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        view.addSubview(backgroundView)
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.view.frame = view.bounds
        pageVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pageVC.view.backgroundColor = .clear
        pageVC.didMove(toParent: self)
        pageVC.dataSource = self
        pageVC.delegate = self

        let initialVC = SinglePhotoViewController(asset: assets[currentIndex])
        pageVC.setViewControllers([initialVC], direction: .forward, animated: false)

        // 关闭按钮
        view.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // 下滑 → 关闭
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    // MARK: - 展开动画

    func presentAnimated(from sourceFrame: CGRect, thumbnail: UIImage?) {
        pageVC.view.alpha = 0
        backgroundView.alpha = 0
        closeButton.alpha = 0

        let snapView = UIImageView(image: thumbnail)
        snapView.contentMode = .scaleAspectFill
        snapView.clipsToBounds = true
        snapView.frame = sourceFrame
        view.addSubview(snapView)

        UIView.animate(withDuration: 0.36, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.2) {
            snapView.frame = self.view.bounds
            self.backgroundView.alpha = 1
        } completion: { _ in
            snapView.removeFromSuperview()
            self.pageVC.view.alpha = 1
            UIView.animate(withDuration: 0.15) { self.closeButton.alpha = 1 }
        }
    }

    // MARK: - 关闭动画

    func dismissAnimated() {
        let targetFrame = getCellFrameInWindow?(currentIndex)

        guard let targetFrame,
              let photoVC = pageVC.viewControllers?.first as? SinglePhotoViewController,
              let snap = photoVC.makeFullScreenSnapshot(in: view) else {
            UIView.animate(withDuration: 0.2) { self.view.alpha = 0 } completion: { _ in
                self.dismiss(animated: false)
            }
            return
        }

        closeButton.alpha = 0
        pageVC.view.alpha = 0
        view.addSubview(snap)
        snap.frame = view.bounds

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            snap.frame = targetFrame
            snap.layer.cornerRadius = 4
            snap.clipsToBounds = true
            self.backgroundView.alpha = 0
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    @objc private func closeTapped() { dismissAnimated() }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let t = gesture.translation(in: view)
        switch gesture.state {
        case .changed:
            guard t.y > 0 else { return }
            pageVC.view.transform = CGAffineTransform(translationX: 0, y: t.y)
            backgroundView.alpha = max(0, 1 - t.y / 300)
            closeButton.alpha = max(0, 1 - t.y / 150)
        case .ended:
            if t.y > 100 || gesture.velocity(in: view).y > 600 {
                dismissAnimated()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
                    self.pageVC.view.transform = .identity
                    self.backgroundView.alpha = 1
                    self.closeButton.alpha = 1
                }
            }
        default:
            UIView.animate(withDuration: 0.3) {
                self.pageVC.view.transform = .identity
                self.backgroundView.alpha = 1
                self.closeButton.alpha = 1
            }
        }
    }
}

// MARK: - UIPageViewControllerDataSource / Delegate

extension FullScreenPhotoViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? SinglePhotoViewController,
              let idx = assets.firstIndex(where: { $0.localIdentifier == vc.asset.localIdentifier }),
              idx > 0 else { return nil }
        return SinglePhotoViewController(asset: assets[idx - 1])
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? SinglePhotoViewController,
              let idx = assets.firstIndex(where: { $0.localIdentifier == vc.asset.localIdentifier }),
              idx < assets.count - 1 else { return nil }
        return SinglePhotoViewController(asset: assets[idx + 1])
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let vc = pageViewController.viewControllers?.first as? SinglePhotoViewController,
              let idx = assets.firstIndex(where: { $0.localIdentifier == vc.asset.localIdentifier })
        else { return }
        currentIndex = idx
    }
}

// MARK: - UIGestureRecognizerDelegate

extension FullScreenPhotoViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - SinglePhotoViewController

class SinglePhotoViewController: UIViewController, UIScrollViewDelegate {

    let asset: PHAsset

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 5
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.backgroundColor = .clear
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()

    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.addSubview(imageView)
        loadImage()

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerImageInScrollView()
    }

    private func loadImage() {
        let thumbOptions = PHImageRequestOptions()
        thumbOptions.deliveryMode = .fastFormat
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 400, height: 400), contentMode: .aspectFit, options: thumbOptions) { [weak self] image, _ in
            DispatchQueue.main.async { self?.imageView.image = image; self?.centerImageInScrollView() }
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] image, info in
            guard let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            DispatchQueue.main.async { self?.imageView.image = image; self?.centerImageInScrollView() }
        }
    }

    private func centerImageInScrollView() {
        guard let image = imageView.image else { return }
        let scrollSize = scrollView.bounds.size
        guard scrollSize.width > 0 else { return }

        let imageAspect = image.size.width / image.size.height
        let scrollAspect = scrollSize.width / scrollSize.height
        let imageSize: CGSize = imageAspect > scrollAspect
            ? CGSize(width: scrollSize.width, height: scrollSize.width / imageAspect)
            : CGSize(width: scrollSize.height * imageAspect, height: scrollSize.height)

        imageView.frame = CGRect(
            x: (scrollSize.width - imageSize.width) / 2,
            y: (scrollSize.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        scrollView.contentSize = scrollSize
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(x: scrollView.contentSize.width / 2 + offsetX, y: scrollView.contentSize.height / 2 + offsetY)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            scrollView.zoom(to: CGRect(x: point.x - 50, y: point.y - 80, width: 100, height: 160), animated: true)
        }
    }

    func makeFullScreenSnapshot(in container: UIView) -> UIImageView? {
        guard let image = imageView.image else { return nil }
        let snap = UIImageView(image: image)
        snap.contentMode = .scaleAspectFill
        snap.clipsToBounds = true
        return snap
    }
}
