import UIKit

// MARK: - Row model

private enum SettingsRow {
    case toggle(key: String, title: String, detail: String?, get: () -> Bool, set: (Bool) -> Void, enabled: (() -> Bool)? = nil)
    case stepper(key: String, title: String, min: Int, max: Int, get: () -> Int, set: (Int) -> Void)
    case navigation(key: String, title: String, valueText: () -> String, action: () -> Void)
    case action(key: String, title: String, detail: String?, action: () -> Void)
}

private struct SettingsSection {
    let header: String
    let rows: [SettingsRow]
}

// MARK: - SettingsViewController

class SettingsViewController: UITableViewController {

    private var sections: [SettingsSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.str("settings.title")
        tableView.register(ToggleCell.self, forCellReuseIdentifier: ToggleCell.reuseID)
        tableView.register(StepperCell.self, forCellReuseIdentifier: StepperCell.reuseID)
        tableView.register(NavigationCell.self, forCellReuseIdentifier: NavigationCell.reuseID)
        tableView.register(GlassButtonCell.self, forCellReuseIdentifier: GlassButtonCell.reuseID)
        tableView.tableHeaderView = makeHeaderView()
        buildSections()
    }

    private func makeHeaderView() -> UIView {
        let container = UIView()

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 16
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            iconView.image = UIImage(named: name)
        }

        let nameLabel = UILabel()
        nameLabel.text = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Shot Less"
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])

        container.frame = CGRect(x: 0, y: 0, width: 0, height: 160)
        return container
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh language row value when returning from language picker
        tableView.reloadData()
    }

    private func buildSections() {
        let s = AppSettings.shared
        sections = [
            SettingsSection(
                header: L10n.str("settings.section.library_source"),
                rows: [
                    .navigation(
                        key: "libraryMode",
                        title: L10n.str("settings.library_mode"),
                        valueText: { L10n.str("settings.library_mode.\(AppSettings.shared.libraryMode.rawValue)") },
                        action: { [weak self] in self?.presentLibraryModePicker() }
                    )
                ]
            ),
            SettingsSection(
                header: L10n.str("settings.section.metadata_filter"),
                rows: [
                    .toggle(
                        key: "filterPeopleMetadata",
                        title: L10n.str("settings.filter_people_metadata"),
                        detail: L10n.str("settings.filter_people_metadata.detail"),
                        get: { s.filterPeopleMetadata },
                        set: { s.filterPeopleMetadata = $0 }
                    )
                ]
            ),
            SettingsSection(
                header: L10n.str("settings.section.ai_filter"),
                rows: [
                    .action(
                        key: "runAIAnalysis",
                        title: L10n.str("settings.ai_analysis.run"),
                        detail: L10n.str("settings.ai_analysis.run.detail"),
                        action: { [weak self] in
                            let vc = AIAnalysisProgressViewController()
                            vc.modalPresentationStyle = .pageSheet
                            if let sheet = vc.sheetPresentationController {
                                sheet.detents = [.medium()]
                                sheet.prefersGrabberVisible = true
                            }
                            self?.present(vc, animated: true)
                        }
                    ),
                    .toggle(
                        key: "filterFaces",
                        title: L10n.str("settings.filter_faces"),
                        detail: L10n.str("settings.filter_faces.detail"),
                        get: { s.filterFaces },
                        set: { s.filterFaces = $0 }
                    ),
                    .toggle(
                        key: "filterPeopleAI",
                        title: L10n.str("settings.filter_people_ai"),
                        detail: L10n.str("settings.filter_people_ai.detail"),
                        get: { s.filterPeopleAI },
                        set: { s.filterPeopleAI = $0 }
                    ),
                    .toggle(
                        key: "filterBarcodes",
                        title: L10n.str("settings.filter_barcodes"),
                        detail: L10n.str("settings.filter_barcodes.detail"),
                        get: { s.filterBarcodes },
                        set: { s.filterBarcodes = $0 }
                    )
                ]
            ),
            SettingsSection(
                header: L10n.str("settings.section.display"),
                rows: [
                    .stepper(
                        key: "defaultColumns",
                        title: L10n.str("settings.default_columns"),
                        min: 2, max: 8,
                        get: { s.defaultColumns },
                        set: { s.defaultColumns = $0 }
                    )
                ]
            ),
            SettingsSection(
                header: L10n.str("settings.section.language"),
                rows: [
                    .navigation(
                        key: "language",
                        title: L10n.str("settings.language"),
                        valueText: { AppLanguage.displayName(for: AppSettings.shared.language) },
                        action: { [weak self] in
                            let vc = LanguageSelectionViewController()
                            self?.navigationController?.pushViewController(vc, animated: true)
                        }
                    )
                ]
            ),
            SettingsSection(
                header: L10n.str("settings.section.feedback"),
                rows: [
                    .action(
                        key: "githubIssues",
                        title: L10n.str("settings.feedback.github_issues"),
                        detail: nil,
                        action: {
                            if let url = URL(string: "https://github.com/ymzuiku/shot-less/issues") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                ]
            )
        ]
    }

    // MARK: - Library Mode Picker

    private func presentLibraryModePicker() {
        let sheet = UIAlertController(title: L10n.str("settings.library_mode"), message: nil, preferredStyle: .actionSheet)
        for mode in LibraryMode.allCases {
            let title = L10n.str("settings.library_mode.\(mode.rawValue)")
            let current = AppSettings.shared.libraryMode == mode
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                AppSettings.shared.libraryMode = mode
                self?.tableView.reloadData()
            }
            if current {
                action.setValue(true, forKey: "checked")
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: L10n.str("cancel"), style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - TableView DataSource

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].header }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case let .toggle(_, title, detail, get, set, enabled):
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleCell.reuseID, for: indexPath) as! ToggleCell
            cell.configure(title: title, detail: detail, isOn: get(), isEnabled: enabled?() ?? true) { set($0) }
            return cell
        case let .stepper(_, title, min, max, get, set):
            let cell = tableView.dequeueReusableCell(withIdentifier: StepperCell.reuseID, for: indexPath) as! StepperCell
            cell.configure(title: title, min: min, max: max, value: get()) { set($0) }
            return cell
        case let .navigation(_, title, valueText, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: NavigationCell.reuseID, for: indexPath) as! NavigationCell
            cell.configure(title: title, valueText: valueText())
            return cell
        case let .action(_, title, detail, action):
            let cell = tableView.dequeueReusableCell(withIdentifier: GlassButtonCell.reuseID, for: indexPath) as! GlassButtonCell
            cell.configure(title: title, detail: detail, onTap: action)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case let .navigation(_, _, _, action): action()
        case let .action(_, _, _, action): action()
        default: break
        }
    }
}

// MARK: - ToggleCell

private class ToggleCell: UITableViewCell {
    static let reuseID = "ToggleCell"

    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryView = toggle
        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)
        detailTextLabel?.textColor = .secondaryLabel
        detailTextLabel?.numberOfLines = 0
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, detail: String?, isOn: Bool, isEnabled: Bool = true, onChange: @escaping (Bool) -> Void) {
        textLabel?.text = title
        detailTextLabel?.text = detail
        toggle.isOn = isOn
        toggle.isEnabled = isEnabled
        textLabel?.textColor = isEnabled ? .label : .tertiaryLabel
        detailTextLabel?.textColor = isEnabled ? .secondaryLabel : .quaternaryLabel
        self.onChange = onChange
    }

    @objc private func switched() { onChange?(toggle.isOn) }
}

// MARK: - StepperCell

private class StepperCell: UITableViewCell {
    static let reuseID = "StepperCell"

    private let stepper = UIStepper()
    private let valueLabel = UILabel()
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        // accessoryView must have an explicit frame; UIStackView has no intrinsic size here
        let container = UIView()
        container.addSubview(valueLabel)
        container.addSubview(stepper)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        stepper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stepper.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 12),
            stepper.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stepper.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 44),
        ])
        // Width will be resolved once stepper's intrinsic size is known; force a layout pass
        stepper.sizeToFit()
        valueLabel.sizeToFit()
        let w = valueLabel.intrinsicContentSize.width + 12 + stepper.intrinsicContentSize.width
        container.frame = CGRect(x: 0, y: 0, width: w, height: 44)
        accessoryView = container

        stepper.addTarget(self, action: #selector(stepped), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, min: Int, max: Int, value: Int, onChange: @escaping (Int) -> Void) {
        textLabel?.text = title
        stepper.minimumValue = Double(min)
        stepper.maximumValue = Double(max)
        stepper.value = Double(value)
        stepper.stepValue = 1
        valueLabel.text = "\(value)"
        self.onChange = onChange
    }

    @objc private func stepped() {
        let v = Int(stepper.value)
        valueLabel.text = "\(v)"
        onChange?(v)
    }
}

// MARK: - GlassButtonCell

private class GlassButtonCell: UITableViewCell {
    static let reuseID = "GlassButtonCell"

    private var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        accessoryType = .disclosureIndicator
        textLabel?.textColor = .systemBlue
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.textColor = .secondaryLabel
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, detail: String?, onTap: @escaping () -> Void) {
        textLabel?.text = title
        detailTextLabel?.text = detail
        self.onTap = onTap
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected { onTap?() }
    }
}

// MARK: - NavigationCell

private class NavigationCell: UITableViewCell {
    static let reuseID = "NavigationCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, valueText: String) {
        textLabel?.text = title
        detailTextLabel?.text = valueText
    }
}
