import XCTest
@testable import AapSC

final class SwimBenchmarksTests: XCTestCase {
    private func assertOrdered(_ benchmark: BenchmarkTier, file: StaticString = #file, line: UInt = #line) {
        XCTAssertLessThan(benchmark.advanced, benchmark.intermediate, file: file, line: line)
        XCTAssertLessThanOrEqual(benchmark.intermediate, benchmark.median, file: file, line: line)
        XCTAssertLessThanOrEqual(benchmark.median, benchmark.beginner, file: file, line: line)
    }

    func testOrdersTiersCorrectlyForEveryAgeGroupAndSex() {
        for byAge in SwimBenchmarks.allBenchmarksForTesting().values {
            for benchmark in byAge.values {
                assertOrdered(benchmark)
            }
        }
    }

    func testSlowsBenchmarksWithAgeForMales() {
        let young = SwimBenchmarks.benchmark(for: "male", age: 28)
        let older = SwimBenchmarks.benchmark(for: "male", age: 62)
        XCTAssertGreaterThan(older.intermediate, young.intermediate)
        XCTAssertGreaterThan(older.beginner, young.beginner)
    }

    func testHasFemalesSlowerThanMalesInSameAgeBand() {
        let male = SwimBenchmarks.benchmark(for: "male", age: 40)
        let female = SwimBenchmarks.benchmark(for: "female", age: 40)
        XCTAssertGreaterThan(female.intermediate, male.intermediate)
    }

    func testClassifiesRecreationalPacesIntoExpectedLevels() {
        let benchmark = SwimBenchmarks.benchmark(for: "male", age: 35)
        XCTAssertEqual(SwimBenchmarks.swimLevel(paceSecPer100m: 106, benchmark: benchmark), .advanced)
        XCTAssertEqual(SwimBenchmarks.swimLevel(paceSecPer100m: 134, benchmark: benchmark), .intermediate)
        XCTAssertEqual(SwimBenchmarks.swimLevel(paceSecPer100m: 158, benchmark: benchmark), .beginner)
        XCTAssertEqual(SwimBenchmarks.swimLevel(paceSecPer100m: 200, benchmark: benchmark), .developing)
    }

    func testMapsAgesToStandardMastersBrackets() {
        XCTAssertEqual(SwimBenchmarks.ageGroup(for: 24), "18-24")
        XCTAssertEqual(SwimBenchmarks.ageGroup(for: 34), "30-34")
        XCTAssertEqual(SwimBenchmarks.ageGroup(for: 72), "70+")
    }
}
