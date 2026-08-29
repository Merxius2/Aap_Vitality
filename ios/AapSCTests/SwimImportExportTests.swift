import XCTest
@testable import AapSC

final class SwimImportExportTests: XCTestCase {
    func testRoundTripsExportAndImport() async throws {
        let exported = try await SwimImportExport.generateExportString(from: TestFixtures.sampleImportData)
        XCTAssertTrue(exported.contains(":"))
        let imported = try await SwimImportExport.parseImportString(exported)
        XCTAssertEqual(imported.profile.sex, "male")
        XCTAssertEqual(imported.profile.age, 35)
        XCTAssertEqual(imported.profile.aiApiKey, "")
        XCTAssertNil(imported.profile.activeAmbient)
        XCTAssertEqual(imported.sessions.count, 1)
        XCTAssertEqual(imported.sessions[0].metrics.distanceM, 2550)
        XCTAssertEqual(imported.sessions[0].metrics.paceSecPer100m, 130)
        XCTAssertEqual(imported.sessions[0].metrics.avgHeartRate, 140)
        XCTAssertEqual(imported.sessions[0].metrics.laps, 102)
        XCTAssertEqual(imported.sessions[0].metrics.strokes.freestyleM, 2025)
        XCTAssertEqual(imported.sessions[0].metrics.strokes.breaststrokeM, 475)
    }

    func testRejectsInvalidChecksum() async throws {
        let exported = try await SwimImportExport.generateExportString(from: TestFixtures.sampleImportData)
        let payload = exported.split(separator: ":", maxSplits: 1).first.map(String.init)!
        do {
            _ = try await SwimImportExport.parseImportString("\(payload):00000000")
            XCTFail("Expected checksum failure")
        } catch SwimImportExportError.checksumFailed {
            // expected
        }
    }

    func testCompressesSessionFields() {
        let compressed = SwimImportExport.compressSessionForTesting(TestFixtures.sampleImportData.sessions[0])
        let metrics = compressed["m"] as? [String: Any]
        XCTAssertEqual(metrics?["dm"] as? Int, 2550)
        let restored = SwimImportExport.decompressSessionForTesting(compressed)
        XCTAssertEqual(restored.metrics.distanceM, 2550)
    }

    func testRoundTripsExcludeFromStats() async throws {
        var data = TestFixtures.sampleImportData
        data.sessions[0].excludeFromStats = true
        let exported = try await SwimImportExport.generateExportString(from: data)
        let imported = try await SwimImportExport.parseImportString(exported)
        XCTAssertTrue(imported.sessions[0].excludeFromStats)
    }
}
