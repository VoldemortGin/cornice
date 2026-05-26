import XCTest
@testable import Niya

final class MemoryMonitorTests: XCTestCase {
    func test_usedGB_formula() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 4, activeGB: 3.5, inactiveGB: 2, wiredGB: 2.5, compressedGB: 1, totalGB: 16, isStale: false)
        XCTAssertEqual(dp.usedGB, 7, accuracy: 0.01)
    }
    func test_usagePercent() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 8, activeGB: 4, inactiveGB: 1, wiredGB: 2, compressedGB: 1, totalGB: 16, isStale: false)
        XCTAssertEqual(dp.usagePercent, 43.75, accuracy: 0.1)
    }
    func test_zeroTotal_noCrash() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 0, activeGB: 0, inactiveGB: 0, wiredGB: 0, compressedGB: 0, totalGB: 0, isStale: true)
        XCTAssertFalse(dp.usagePercent.isNaN); XCTAssertFalse(dp.usagePercent.isInfinite)
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
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 4, activeGB: 3, inactiveGB: 2, wiredGB: 2.5, compressedGB: 0.5, totalGB: 16, isStale: false)
        XCTAssertGreaterThanOrEqual(dp.freeGB, 0); XCTAssertGreaterThanOrEqual(dp.activeGB, 0)
        XCTAssertGreaterThanOrEqual(dp.wiredGB, 0); XCTAssertGreaterThanOrEqual(dp.compressedGB, 0)
    }
    func test_pressure_green() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 10, activeGB: 3, inactiveGB: 1, wiredGB: 1.5, compressedGB: 0.5, totalGB: 16, isStale: false)
        XCTAssertLessThan(dp.usagePercent, 70)
    }
    func test_pressure_yellow() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 2, activeGB: 7, inactiveGB: 1, wiredGB: 4, compressedGB: 2, totalGB: 16, isStale: false)
        XCTAssertGreaterThanOrEqual(dp.usagePercent, 70); XCTAssertLessThanOrEqual(dp.usagePercent, 90)
    }
    func test_pressure_red() {
        let dp = RAMDataPoint(timestamp: Date(), freeGB: 0.5, activeGB: 8, inactiveGB: 0.5, wiredGB: 5, compressedGB: 2, totalGB: 16, isStale: false)
        XCTAssertGreaterThan(dp.usagePercent, 90)
    }
}
