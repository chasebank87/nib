import NibDomain
import NibServices
import Testing

struct SettingsStoreTests {
    @Test func memoryStoreRoundTrip() {
        let store = MemorySettingsStore()
        #expect(store.string(for: AppearanceController.preferenceKey) == nil)
        store.set(string: AppearancePreference.dark.rawValue, for: AppearanceController.preferenceKey)
        #expect(store.string(for: AppearanceController.preferenceKey) == "dark")
        store.set(string: nil, for: AppearanceController.preferenceKey)
        #expect(store.string(for: AppearanceController.preferenceKey) == nil)
    }

    @Test func appearancePreferenceCycles() {
        #expect(AppearancePreference.system.next == .light)
        #expect(AppearancePreference.light.next == .dark)
        #expect(AppearancePreference.dark.next == .system)
    }
}
