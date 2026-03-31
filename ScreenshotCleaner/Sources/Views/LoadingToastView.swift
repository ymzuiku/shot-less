import UIKit

/// A pill-shaped toast with a spinner and a status label.
/// Show with `show(in:)`, hide with `hide()`.
final class LoadingToastView: UIView {

    private let spinner: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = false
        return v
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .white
        return l
    }()

    init(message: String) {
        super.init(frame: .zero)
        label.text = message

        backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])

        spinner.startAnimating()
        alpha = 0
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func show(in parent: UIView, bottomOffset: CGFloat = 100) {
        guard superview == nil else {
            UIView.animate(withDuration: 0.2) { self.alpha = 1 }
            return
        }
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -bottomOffset),
        ])
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    func hide() {
        UIView.animate(withDuration: 0.25, delay: 0.15) {
            self.alpha = 0
        }
    }
}
