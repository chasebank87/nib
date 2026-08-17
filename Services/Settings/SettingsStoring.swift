public protocol SettingsStoring: AnyObject {
    func string(for key: String) -> String?
    func set(string: String?, for key: String)
}
