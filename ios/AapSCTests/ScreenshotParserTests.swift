import XCTest
@testable import AapSC

final class ScreenshotParserTests: XCTestCase {
    private var refDate: Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 10
        return Calendar.current.date(from: components)!
    }

    func testParsesDutchDateWo3Jun() {
        XCTAssertEqual(ScreenshotParser.parseDutchDate("wo 3 jun", referenceDate: refDate), "2025-06-03")
    }

    func testParsesFullScreenshotJun3() {
        let result = ScreenshotParser.parseScreenshotText(TestFixtures.ocrJun3, referenceDate: refDate)
        XCTAssertFalse(result.missingDate)
        XCTAssertEqual(result.fields.date, "2025-06-03")
        XCTAssertEqual(result.fields.distanceM, 2550)
        XCTAssertEqual(result.fields.durationSec, 54 * 60 + 27)
        XCTAssertEqual(result.fields.paceSecPer100m, 130)
        XCTAssertEqual(result.fields.avgHeartRate, 140)
        XCTAssertEqual(result.fields.activeKcal, 573)
        XCTAssertEqual(result.fields.totalKcal, 680)
        XCTAssertEqual(result.fields.laps, 102)
        XCTAssertEqual(result.fields.poolLengthM, 25)
        XCTAssertEqual(result.fields.goalM, 2500)
        XCTAssertEqual(result.fields.strokes.freestyleM, 2025)
        XCTAssertEqual(result.fields.strokes.breaststrokeM, 475)
        XCTAssertEqual(result.fields.strokes.mixedM, 50)
        XCTAssertEqual(result.fields.location, "Tilburg")
        XCTAssertTrue(result.isSwimWorkout)
        XCTAssertNil(result.detectedSport)
    }

    func testParsesFullScreenshotJun8() {
        let result = ScreenshotParser.parseScreenshotText(TestFixtures.ocrJun8, referenceDate: refDate)
        XCTAssertEqual(result.fields.date, "2025-06-08")
        XCTAssertEqual(result.fields.distanceM, 2500)
        XCTAssertEqual(result.fields.paceSecPer100m, 123)
        XCTAssertEqual(result.fields.laps, 100)
    }

    func testDetectsMissingDate() {
        let result = ScreenshotParser.parseScreenshotText(TestFixtures.ocrNoDate, referenceDate: refDate)
        XCTAssertTrue(result.missingDate)
        XCTAssertNil(result.fields.date)
        XCTAssertEqual(result.fields.distanceM, 2675)
        XCTAssertEqual(result.fields.paceSecPer100m, 120)
        XCTAssertEqual(result.fields.laps, 107)
    }

    func testAcceptsSwimWorkoutsWithEnoughSwimSignals() {
        let result = ScreenshotParser.parseScreenshotText(TestFixtures.ocrJun8, referenceDate: refDate)
        XCTAssertTrue(result.isSwimWorkout)
    }

    func testRejectsRunningWorkout() {
        let ocrRun = """
        wo 10 jun
        Hardlopen
        Outdoor
        Work-outtijd 0:45:12
        Afstand 8,5 KM
        Actieve kilocalorieën 520 KCAL
        Totale kilocalorieën 610 KCAL
        Gem. tempo 5'20" /KM
        Gem. hartslag 155 BPM
        """
        let result = ScreenshotParser.parseScreenshotText(ocrRun, referenceDate: refDate)
        XCTAssertFalse(result.isSwimWorkout)
        XCTAssertEqual(result.detectedSport, "run")
    }

    func testRejectsCyclingByActivityLabel() {
        let ocrCycle = """
        di 11 jun
        Fietsen
        Outdoor
        Work-outtijd 1:05:00
        Afstand 32,4 KM
        Gem. tempo 12,5 km/u
        Gem. hartslag 142 BPM
        """
        let result = ScreenshotParser.parseScreenshotText(ocrCycle, referenceDate: refDate)
        XCTAssertFalse(result.isSwimWorkout)
        XCTAssertEqual(result.detectedSport, "cycle")
    }

    func testRejectsGenericWorkoutsWithoutSwimMarkers() {
        let ocrGeneric = """
        wo 12 jun
        Actieve kilocalorieën 300 KCAL
        Work-outtijd 0:30:00
        """
        let result = ScreenshotParser.parseScreenshotText(ocrGeneric, referenceDate: refDate)
        XCTAssertFalse(result.isSwimWorkout)
        XCTAssertEqual(result.detectedSport, "unknown")
    }
}
