import Foundation

enum Preferences {
    private static let key = "ignoredBundleIDs"

    static let defaultIgnored = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop", "com.apple.keychainaccess", "com.apple.Passwords",
        "com.dashlane.dashlanephonefinal", "org.keepassxc.keepassxc", "com.lastpass.LastPass",
    ]

    static var ignoredBundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? defaultIgnored }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var fetchLinkPreviews: Bool {
        get { UserDefaults.standard.object(forKey: "fetchLinkPreviews") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "fetchLinkPreviews") }
    }

    static func ignore(_ id: String) {
        if !ignoredBundleIDs.contains(id) { ignoredBundleIDs.append(id) }
    }

    static func unignore(_ id: String) {
        ignoredBundleIDs.removeAll { $0 == id }
    }
}
