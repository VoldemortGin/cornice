import XCTest
@testable import Cornice

final class MemoryMonitorTests: XCTestCase {
    func test_usedGB_formula() {
        let dp = MemoryUsage(free: 4, active: 3.5, inactive: 2, wired: 2.5, compressed: 1, timestamp: Date(), isStale: false)
        XCTAssertEqual(dp.used, 7, accuracy: 0.01)
    }
    func test_usagePercent() {
        let dp = MemoryUsage(free: 8, active: 4, inactive: 1, wired: 2, compressed: 1, timestamp: Date(), isStale: false)
        XCTAssertEqual(dp.usedPercent, 43.75, accuracy: 0.1)
    }
    func test_zeroTotal_noCrash() {
        let dp = MemoryUsage(free: 0, active: 0, inactive: 0, wired: 0, compressed: 0, timestamp: Date(), isStale: true)
        XCTAssertFalse(dp.usedPercent.isNaN); XCTAssertFalse(dp.usedPercent.isInfinite)
    }
    func test_pageCount_16KBPages_1GB() {
        let gb = Double(65536) * Double(16384) / 1_073_741_824.0
        XCTAssertEqual(gb, 1.0, accuracy: 0.01)
    }
    func test_pageCount_4KBPages_1GB() {
        let gb = Double(262144) * Double(4096) / 1_073_741_824.0
        XCTAssertEqual(gb, 1.0, accuracy: 0.01)
    }
    func test_categoriesPresent() {
        let dp = MemoryUsage(free: 4, active: 3, inactive: 2, wired: 2.5, compressed: 0.5, timestamp: Date(), isStale: false)
        XCTAssertGreaterThanOrEqual(dp.free, 0); XCTAssertGreaterThanOrEqual(dp.active, 0)
        XCTAssertGreaterThanOrEqual(dp.wired, 0); XCTAssertGreaterThanOrEqual(dp.compressed, 0)
    }
    func test_pressure_green() {
        let dp = MemoryUsage(free: 10, active: 3, inactive: 1, wired: 1.5, compressed: 0.5, timestamp: Date(), isStale: false)
        XCTAssertLessThan(dp.usedPercent, 70)
    }
    func test_pressure_yellow() {
        let dp = MemoryUsage(free: 2, active: 7, inactive: 1, wired: 4, compressed: 2, timestamp: Date(), isStale: false)
        XCTAssertGreaterThanOrEqual(dp.usedPercent, 70); XCTAssertLessThanOrEqual(dp.usedPercent, 90)
    }
    func test_pressure_red() {
        let dp = MemoryUsage(free: 0.5, active: 8, inactive: 0.5, wired: 5, compressed: 2, timestamp: Date(), isStale: false)
        XCTAssertGreaterThan(dp.usedPercent, 90)
    }
}
