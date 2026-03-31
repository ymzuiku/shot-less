import UIKit

class TitleHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "TitleHeaderView"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.str("app.title")
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label.textColor = .label
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
