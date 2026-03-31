import UIKit
import Photos

class ScreenshotCell: UICollectionViewCell {

    static let reuseIdentifier = "ScreenshotCell"

    var onViewPhoto: (() -> Void)?
    var onCheckToggle: (() -> Void)?

    private(set) var isChecked = false
    /// 双指按下期间设为 false，动画结束后恢复 true
    var pickInteractionEnabled = true

    // MARK: - Subviews

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor(white: 0.15, alpha: 1)
        iv.isUserInteractionEnabled = false
        return iv
    }()

    /// 右下角选择按钮（可点击区域 44x44）
    private let checkButton: UIButton = {
        let btn = UIButton()
        btn.isUserInteractionEnabled = true
        return btn
    }()

    // MARK: 未选中状态：空心白圆圈

    private let ringView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        iv.image = UIImage(systemName: "circle", withConfiguration: config)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    // MARK: 选中状态：固定白色液态玻璃圆圈 + 黑色钩子

    /// 强制浅色模糊，不随图片内容变深
    private let glassCircle: UIVisualEffectView = {
        // .systemMaterialLight 固定输出白色材质，不随 dark mode 或背景内容翻转
        let blur = UIBlurEffect(style: .systemMaterialLight)
        let v = UIVisualEffectView(effect: blur)
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.isUserInteractionEnabled = false
        v.alpha = 0
        return v
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        iv.image = UIImage(systemName: "checkmark", withConfiguration: config)
        iv.tintColor = .black   // 固定黑色，配合白色玻璃
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    private var requestID: PHImageRequestID?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        contentView.layer.masksToBounds = true

        contentView.addSubview(imageView)
        contentView.addSubview(checkButton)
        checkButton.addSubview(ringView)
        checkButton.addSubview(glassCircle)
        glassCircle.contentView.addSubview(checkmarkImageView)

        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        checkButton.translatesAutoresizingMaskIntoConstraints = false
        ringView.translatesAutoresizingMaskIntoConstraints = false
        glassCircle.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            checkButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            checkButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            checkButton.widthAnchor.constraint(equalToConstant: 44),
            checkButton.heightAnchor.constraint(equalToConstant: 44),

            ringView.trailingAnchor.constraint(equalTo: checkButton.trailingAnchor, constant: -7),
            ringView.bottomAnchor.constraint(equalTo: checkButton.bottomAnchor, constant: -7),
            ringView.widthAnchor.constraint(equalToConstant: 24),
            ringView.heightAnchor.constraint(equalToConstant: 24),

            glassCircle.trailingAnchor.constraint(equalTo: checkButton.trailingAnchor, constant: -7),
            glassCircle.bottomAnchor.constraint(equalTo: checkButton.bottomAnchor, constant: -7),
            glassCircle.widthAnchor.constraint(equalToConstant: 24),
            glassCircle.heightAnchor.constraint(equalToConstant: 24),

            checkmarkImageView.centerXAnchor.constraint(equalTo: glassCircle.contentView.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: glassCircle.contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 14),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 14)
        ])

        checkButton.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        contentView.addGestureRecognizer(tap)
    }

    // MARK: - Public API

    func configure(with item: ScreenshotItem, isChecked: Bool) {
        self.isChecked = isChecked
        loadImage(for: item.asset)
        updateCheckVisual(animated: false)
    }

    func setChecked(_ checked: Bool, animated: Bool = true) {
        guard isChecked != checked else { return }
        isChecked = checked
        updateCheckVisual(animated: animated)
    }

    /// 双指按下时隐藏 pick 图标
    func setPickIconsHidden(_ hidden: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        let alpha: CGFloat = hidden ? 0 : 1
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseInOut) {
                self.checkButton.alpha = alpha
            } completion: { _ in completion?() }
        } else {
            checkButton.alpha = alpha
            completion?()
        }
    }

    // MARK: - Private

    private func updateCheckVisual(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.15) {
                self.ringView.alpha = self.isChecked ? 0 : 1
                self.glassCircle.alpha = self.isChecked ? 1 : 0
            }
            if isChecked {
                glassCircle.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                    self.glassCircle.transform = .identity
                }
            }
        } else {
            ringView.alpha = isChecked ? 0 : 1
            glassCircle.alpha = isChecked ? 1 : 0
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let id = requestID { PHImageManager.default().cancelImageRequest(id) }
        imageView.image = nil
    }

    private func loadImage(for asset: PHAsset) {
        let scale = UIScreen.main.scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(
            for: asset, targetSize: size, contentMode: .aspectFill, options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async { self?.imageView.image = image }
        }
    }

    func thumbnailImage() -> UIImage? { imageView.image }

    @objc private func imageTapped() {
        guard pickInteractionEnabled else { return }
        onViewPhoto?()
    }

    @objc private func checkTapped() {
        guard pickInteractionEnabled else { return }
        onCheckToggle?()
    }
}
