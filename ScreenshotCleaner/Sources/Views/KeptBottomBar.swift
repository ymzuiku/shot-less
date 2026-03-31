import UIKit

class KeptBottomBar: UIView {

    var onUnmark: (() -> Void)?
    var onDelete: (() -> Void)?

    // MARK: - Buttons

    private let unmarkButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "bookmark.slash")
        config.title = L10n.str("keep.unmark")
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.isEnabled = false
        return btn
    }()

    private let deleteButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "trash")
        config.title = L10n.str("keep.delete")
        config.imagePadding = 6
        config.baseForegroundColor = .systemRed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var a = attr; a.font = UIFont.systemFont(ofSize: 15, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.isEnabled = false
        return btn
    }()

    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.label.withAlphaComponent(0.15)
        return v
    }()

    private var contentHost: UIView!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let (glassContainer, host) = makeGlassContainer()
        contentHost = host
        addSubview(glassContainer)

        let stack = UIStackView(arrangedSubviews: [unmarkButton, deleteButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        host.addSubview(stack)
        host.addSubview(divider)

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            glassContainer.topAnchor.constraint(equalTo: topAnchor),
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: host.topAnchor),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            stack.heightAnchor.constraint(equalToConstant: 54),

            divider.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            divider.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),
            divider.heightAnchor.constraint(equalToConstant: 28),
        ])

        unmarkButton.addTarget(self, action: #selector(unmarkTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }

    // MARK: - Public API

    func updateCount(_ count: Int) {
        var uConfig = unmarkButton.configuration ?? .plain()
        uConfig.title = count > 0 ? L10n.fmt("keep.unmark_count", count) : L10n.str("keep.unmark")
        unmarkButton.configuration = uConfig
        unmarkButton.isEnabled = count > 0

        var dConfig = deleteButton.configuration ?? .plain()
        dConfig.title = count > 0 ? L10n.fmt("keep.delete_count", count) : L10n.str("keep.delete")
        deleteButton.configuration = dConfig
        deleteButton.isEnabled = count > 0
    }

    // MARK: - Actions

    @objc private func unmarkTapped() { onUnmark?() }
    @objc private func deleteTapped() { onDelete?() }

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
