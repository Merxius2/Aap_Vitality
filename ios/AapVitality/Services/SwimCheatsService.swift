import Foundation

enum SwimCheatsService {
    static let storageKey = "AUDIT_SWIM_CHEATS"

    static func load() -> SwimCheats {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SwimCheats.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func save(_ cheats: SwimCheats) {
        guard let data = try? JSONEncoder().encode(cheats) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
