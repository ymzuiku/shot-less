import UIKit

class SectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "SectionHeaderView"

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .systemBackground

        addSubview(dateLabel)
        addSubview(countLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(dateTitle: String, count: Int) {
        dateLabel.text = dateTitle
        countLabel.text = L10n.fmt("section.screenshots_count", count)
    }
}
