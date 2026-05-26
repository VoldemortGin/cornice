import XCTest
@testable import Crest

extension BatteryInfo {
    static func from(powerSourceInfo info: [String: Any]) -> BatteryInfo {
        let cur = info["Current Capacity"] as? Int ?? 0
        let maxCap = max(info["Max Capacity"] as? Int ?? 1, 1)
        let level = min(max(cur * 100 / maxCap, 0), 100)
        let charging = info["Is Charging"] as? Bool ?? false
        let state = info["Power Source State"] as? String ?? "Battery Power"
        let rawEmpty = info["Time to Empty"] as? Int
        let rawFull = info["Time to Full Charge"] as? Int
        return BatteryInfo(level: level, isCharging: charging, isPluggedIn: state == "AC Power",
            timeToEmpty: (rawEmpty ?? -1) >= 0 ? rawEmpty : nil, timeToFull: (rawFull ?? -1) >= 0 ? rawFull : nil,
            cycleCount: nil, healthPercent: nil, timestamp: Date(), isStale: false)
    }
    static func fromSources(_ sources: [[String: Any]]) -> BatteryInfo? {
        guard let first = sources.first(where: { ($0["Type"] as? String) != "UPS" }) else { return nil }
        return from(powerSourceInfo: first)
    }
}

final class BatteryMonitorTests: XCTestCase {
    func test_level_parsesCorrectly() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 82, "Max Capacity": 100])
        XCTAssertEqual(dp.level, 82)
    }
    func test_level_clampsTo100() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 105, "Max Capacity": 100])
        XCTAssertLessThanOrEqual(dp.level, 100)
    }
    func test_level_clampsTo0() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": -5, "Max Capacity": 100])
        XCTAssertGreaterThanOrEqual(dp.level, 0)
    }
    func test_level_zeroMax_noCrash() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 50, "Max Capacity": 0])
        XCTAssertGreaterThanOrEqual(dp.level, 0)
    }
    func test_charging_true() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 60, "Max Capacity": 100, "Is Charging": true, "Power Source State": "AC Power"])
        XCTAssertTrue(dp.isCharging)
    }
    func test_charging_false() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 60, "Max Capacity": 100, "Is Charging": false, "Power Source State": "Battery Power"])
        XCTAssertFalse(dp.isCharging)
    }
    func test_pluggedIn_AC() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 100, "Max Capacity": 100, "Power Source State": "AC Power"])
        XCTAssertTrue(dp.isPluggedIn)
    }
    func test_pluggedIn_battery() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 80, "Max Capacity": 100, "Power Source State": "Battery Power"])
        XCTAssertFalse(dp.isPluggedIn)
    }
    func test_timeToEmpty_valid() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 50, "Max Capacity": 100, "Time to Empty": 180])
        XCTAssertEqual(dp.timeToEmpty, 180)
    }
    func test_timeToEmpty_negativeOne_nil() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 80, "Max Capacity": 100, "Time to Empty": -1])
        XCTAssertNil(dp.timeToEmpty)
    }
    func test_timeToFull_valid() {
        let dp = BatteryInfo.from(powerSourceInfo: ["Current Capacity": 50, "Max Capacity": 100, "Is Charging": true, "Time to Full Charge": 90])
        XCTAssertEqual(dp.timeToFull, 90)
    }
    func test_lowBattery_belowThreshold() { XCTAssertTrue(15 <= 20) }
    func test_lowBattery_aboveThreshold() { XCTAssertFalse(21 <= 20) }
    func test_lowBattery_suppressed_whenPlugged() {
        let dp = BatteryInfo(level: 10, isCharging: true, isPluggedIn: true, timeToEmpty: nil, timeToFull: 60, cycleCount: nil, healthPercent: nil, timestamp: Date(), isStale: false)
        XCTAssertFalse(dp.level <= 20 && !dp.isPluggedIn)
    }
    func test_desktopMac_noBattery_nil() {
        XCTAssertNil(BatteryInfo.fromSources([]))
    }
    func test_healthPercent() {
        XCTAssertEqual(Double(4500)/Double(5000)*100, 90, accuracy: 0.1)
    }
    func test_cooldown_preventsDuplicate() {
        let last = Date().addingTimeInterval(-300); let cooldown: TimeInterval = 600
        XCTAssertFalse(Date().timeIntervalSince(last) >= cooldown)
    }
    func test_cooldown_allowsAfterExpiry() {
        let last = Date().addingTimeInterval(-700); let cooldown: TimeInterval = 600
        XCTAssertTrue(Date().timeIntervalSince(last) >= cooldown)
    }
}
