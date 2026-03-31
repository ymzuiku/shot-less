import UIKit

class EmptyStateView: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        iv.image = UIImage(systemName: "photo.on.rectangle", withConfiguration: config)
        iv.tintColor = UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "没有找到截图"
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "您的相册中没有截图"
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
}
