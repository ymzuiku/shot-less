import UIKit

// MARK: - AppLanguage

enum AppLanguage: CaseIterable {
    case system, en, zhHans, ja, ko, de, fr, es, id

    var code: String {
        switch self {
        case .system: return "system"
        case .en:     return "en"
        case .zhHans: return "zh-Hans"
        case .ja:     return "ja"
        case .ko:     return "ko"
        case .de:     return "de"
        case .fr:     return "fr"
        case .es:     return "es"
        case .id:     return "id"
        }
    }

    var localName: String {
        switch self {
        case .system: return L10n.str("settings.language.system")
        case .en:     return "English"
        case .zhHans: return "简体中文"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        case .de:     return "Deutsch"
        case .fr:     return "Français"
        case .es:     return "Español"
        case .id:     return "Bahasa Indonesia"
        }
    }

    static func displayName(for code: String) -> String {
        AppLanguage.allCases.first { $0.code == code }?.localName
            ?? L10n.str("settings.language.system")
    }
}

// MARK: - LanguageSelectionViewController

class LanguageSelectionViewController: UITableViewController {

    private let languages = AppLanguage.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.str("settings.language")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LangCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LangCell", for: indexPath)
        let lang = languages[indexPath.row]
        cell.textLabel?.text = lang.localName
        cell.accessoryType = (AppSettings.shared.language == lang.code) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = languages[indexPath.row]
        AppSettings.shared.language = selected.code
        L10n.refreshBundle()
        tableView.reloadData()

        // Rebuild the root tab bar so all VCs reflect the new language
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = SceneDelegate.makeRootViewController()
        }
    }
}
