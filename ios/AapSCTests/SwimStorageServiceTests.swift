import XCTest
@testable import AapSC

final class SwimStorageServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AapSCTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        SwimStorageService.defaults = defaults
        SwimStorageService.clear()
    }

    override func tearDown() {
        SwimStorageService.clear()
        defaults.removePersistentDomain(forName: suiteName)
        SwimStorageService.defaults = .standard
        super.tearDown()
    }

    func testLoadsNormalizedMonthlyRerollState() throws {
        let json = """
        {
          "sessions": [],
          "profile": {"name":"","sex":"male","age":30,"aiApiKey":""},
          "monthlyChallengeRerolls": {
            "2025-06": {"overrides": {"0": "kcal"}, "freeUsed": true}
          }
        }
        """
        defaults.set(Data(json.utf8), forKey: SwimStorageService.storageKey)
        let data = SwimStorageService.load()
        XCTAssertEqual(data.monthlyChallengeRerolls["2025-06"], MonthRerollEntry(overrides: ["0": "kcal"], freeUses: 1))
    }

    func testMigratesLegacySingleRerollObjectsOnLoad() throws {
        let json = """
        {
          "sessions": [],
          "profile": {"name":"","sex":"male","age":30,"aiApiKey":""},
          "monthlyChallengeRerolls": {
            "2025-06": {"tierIndex": 1, "type": "distance"}
          }
        }
        """
        defaults.set(Data(json.utf8), forKey: SwimStorageService.storageKey)
        let data = SwimStorageService.load()
        XCTAssertEqual(data.monthlyChallengeRerolls["2025-06"], MonthRerollEntry(overrides: ["1": "distance"], freeUses: 1))
    }

    func testRoundTripsRerollFieldsThroughSaveAndLoad() {
        var payload = SwimData.empty
        payload.monthlyChallengeRerolls = [
            "2025-07": MonthRerollEntry(overrides: ["2": "streak"], freeUses: 0)
        ]

        SwimStorageService.save(payload)
        let loaded = SwimStorageService.load()

        XCTAssertEqual(loaded.monthlyChallengeRerolls, payload.monthlyChallengeRerolls)
    }

    func testIgnoresLegacyCoinFieldsOnLoad() throws {
        let json = """
        {
          "sessions": [],
          "profile": {"name":"","sex":"male","age":30,"aiApiKey":""},
          "totalCoins": 999,
          "coinsSpent": 100,
          "storeUnlocks": ["theme:gen-z"]
        }
        """
        defaults.set(Data(json.utf8), forKey: SwimStorageService.storageKey)
        let data = SwimStorageService.load()
        XCTAssertEqual(data.sessions.count, 0)
    }
}
