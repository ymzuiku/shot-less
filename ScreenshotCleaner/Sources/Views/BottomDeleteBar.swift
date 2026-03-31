import UIKit

class BottomDeleteBar: UIView {

    var onAutoSelect: (() -> Void)?
    var onPause: (() -> Void)?
    var onDelete: (() -> Void)?

    // MARK: - Normal mode buttons (plain style, fused inside glass container)

    private let autoSelectButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "wand.and.sparkles")
        config.title = L10n.str("auto_select")
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        return btn
    }()

    private let deleteButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "trash")
        config.title = L10n.str("delete")
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.isEnabled = false
        return btn
    }()

    // MARK: - Divider between buttons

    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.label.withAlphaComponent(0.15)
        return v
    }()

    // MARK: - Auto mode button

    private let pauseButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "pause.fill")
        config.title = L10n.str("pause_auto_select")
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.isHidden = true
        return btn
    }()

    // MARK: - Layout

    private let normalStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 0
        return sv
    }()

    private var contentHost: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let (glassContainer, host) = makeGlassContainer()
        contentHost = host
        addSubview(glassContainer)

        // 中间分隔线
        normalStack.addArrangedSubview(autoSelectButton)
        normalStack.addArrangedSubview(deleteButton)

        host.addSubview(normalStack)
        host.addSubview(divider)
        host.addSubview(pauseButton)

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        normalStack.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            glassContainer.topAnchor.constraint(equalTo: topAnchor),
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            normalStack.topAnchor.constraint(equalTo: host.topAnchor),
            normalStack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            normalStack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            normalStack.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            normalStack.heightAnchor.constraint(equalToConstant: 54),

            // 分隔线居中
            divider.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            divider.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),
            divider.heightAnchor.constraint(equalToConstant: 28),

            pauseButton.topAnchor.constraint(equalTo: host.topAnchor),
            pauseButton.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            pauseButton.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            pauseButton.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            pauseButton.heightAnchor.constraint(equalToConstant: 54)
        ])

        autoSelectButton.addTarget(self, action: #selector(autoSelectTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
    }

    // MARK: - Public API

    func updateCount(_ count: Int) {
        var delConfig = deleteButton.configuration ?? UIButton.Configuration.plain()
        delConfig.title = count > 0 ? L10n.fmt("delete_count", count) : L10n.str("delete")
        deleteButton.configuration = delConfig
        deleteButton.isEnabled = count > 0

        var pauseConfig = pauseButton.configuration ?? UIButton.Configuration.plain()
        pauseConfig.title = L10n.fmt("pause_auto_select_count", count)
        pauseButton.configuration = pauseConfig
    }

    func setAutoSelectMode(_ isAuto: Bool, animated: Bool = true) {
        let duration = animated ? 0.28 : 0
        if isAuto {
            UIView.animate(withDuration: duration) {
                self.normalStack.alpha = 0
                self.divider.alpha = 0
                self.normalStack.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            } completion: { _ in
                self.normalStack.isHidden = true
                self.divider.isHidden = true
                self.pauseButton.isHidden = false
                self.pauseButton.alpha = 0
                self.pauseButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                UIView.animate(withDuration: duration) {
                    self.pauseButton.alpha = 1
                    self.pauseButton.transform = .identity
                }
            }
        } else {
            UIView.animate(withDuration: duration) {
                self.pauseButton.alpha = 0
                self.pauseButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            } completion: { _ in
                self.pauseButton.isHidden = true
                self.normalStack.isHidden = false
                self.divider.isHidden = false
                self.normalStack.alpha = 0
                self.divider.alpha = 0
                self.normalStack.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                UIView.animate(withDuration: duration) {
                    self.normalStack.alpha = 1
                    self.divider.alpha = 1
                    self.normalStack.transform = .identity
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func autoSelectTapped() { onAutoSelect?() }
    @objc private func deleteTapped() { onDelete?() }
    @objc private func pauseTapped() { onPause?() }

    // MARK: - Glass

    private func makeGlassContainer() -> (UIView, UIView) {
        let container: UIVisualEffectView
        if #available(iOS 26, *) {
            container = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            container = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        container.clipsToBounds = true
        container.layer.cornerRadius = 18
        container.layer.cornerCurve = .continuous
        return (container, container.contentView)
    }
}
