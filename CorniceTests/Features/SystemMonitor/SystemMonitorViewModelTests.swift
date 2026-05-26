import XCTest
import SwiftUI
@testable import Cornice

final class SystemMonitorViewModelTests: XCTestCase {

    @MainActor
    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Initial State

    @MainActor
    func test_initialState_isNotMonitoring() {
        let vm = SystemMonitorViewModel()
        XCTAssertFalse(vm.isMonitoring)
    }

    @MainActor
    func test_initialState_hasBatteryFalse() {
        let vm = SystemMonitorViewModel()
        XCTAssertFalse(vm.hasBattery)
    }

    @MainActor
    func test_initialState_lowBatteryAlertNotTriggered() {
        let vm = SystemMonitorViewModel()
        XCTAssertFalse(vm.lowBatteryAlertTriggered)
    }

    @MainActor
    func test_initialState_cpuUsageZero() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.cpuUsage.total, 0)
    }

    @MainActor
    func test_initialState_memoryUsageZero() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.memoryUsage.usedPercent, 0)
    }

    @MainActor
    func test_initialState_networkSpeedZero() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.networkSpeed.downloadBytesPerSec, 0)
        XCTAssertEqual(vm.networkSpeed.uploadBytesPerSec, 0)
    }

    @MainActor
    func test_initialState_batteryInfoNil() {
        let vm = SystemMonitorViewModel()
        XCTAssertNil(vm.batteryInfo)
    }

    @MainActor
    func test_initialState_historyBuffersEmpty() {
        let vm = SystemMonitorViewModel()
        XCTAssertTrue(vm.cpuHistory.isEmpty)
        XCTAssertTrue(vm.memoryHistory.isEmpty)
        XCTAssertTrue(vm.downloadHistory.isEmpty)
        XCTAssertTrue(vm.uploadHistory.isEmpty)
        XCTAssertTrue(vm.batteryHistory.isEmpty)
    }

    // MARK: - Polling Interval Configuration

    @MainActor
    func test_defaultPollingInterval() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.pollingInterval, 2.0)
    }

    @MainActor
    func test_startMonitoring_customInterval() {
        let vm = SystemMonitorViewModel()
        vm.startMonitoring(interval: 5.0)
        XCTAssertEqual(vm.pollingInterval, 5.0)
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    @MainActor
    func test_startMonitoring_nilInterval_usesDefault() {
        let vm = SystemMonitorViewModel()
        vm.pollingInterval = 3.0
        vm.startMonitoring()
        XCTAssertEqual(vm.pollingInterval, 3.0)
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    @MainActor
    func test_setFocusedInterval_setsToOneSecond() {
        let vm = SystemMonitorViewModel()
        vm.setFocusedInterval()
        XCTAssertEqual(vm.pollingInterval, 1.0)
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    @MainActor
    func test_setBackgroundInterval_setsToTwoSeconds() {
        let vm = SystemMonitorViewModel()
        vm.setBackgroundInterval()
        XCTAssertEqual(vm.pollingInterval, 2.0)
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    // MARK: - Start / Stop Lifecycle

    @MainActor
    func test_startMonitoring_setsIsMonitoring() {
        let vm = SystemMonitorViewModel()
        vm.startMonitoring()
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    @MainActor
    func test_stopMonitoring_clearsIsMonitoring() {
        let vm = SystemMonitorViewModel()
        vm.startMonitoring()
        vm.stopMonitoring()
        XCTAssertFalse(vm.isMonitoring)
    }

    @MainActor
    func test_stopMonitoring_whenNotStarted_doesNotCrash() {
        let vm = SystemMonitorViewModel()
        vm.stopMonitoring()
        XCTAssertFalse(vm.isMonitoring)
    }

    @MainActor
    func test_startMonitoring_calledTwice_doesNotCrash() {
        let vm = SystemMonitorViewModel()
        vm.startMonitoring()
        vm.startMonitoring()
        XCTAssertTrue(vm.isMonitoring)
        vm.stopMonitoring()
    }

    // MARK: - Low Battery Threshold

    @MainActor
    func test_defaultLowBatteryThreshold() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.lowBatteryThreshold, 20)
    }

    @MainActor
    func test_lowBatteryThreshold_isConfigurable() {
        let vm = SystemMonitorViewModel()
        vm.lowBatteryThreshold = 10
        XCTAssertEqual(vm.lowBatteryThreshold, 10)
    }

    // MARK: - Color Coding: CPU

    @MainActor
    func test_cpuColor_lowUsage_green() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 20, system: 10, idle: 70, nice: 0)
        XCTAssertEqual(vm.cpuColor, .green)
    }

    @MainActor
    func test_cpuColor_mediumUsage_yellow() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 40, system: 20, idle: 40, nice: 0)
        XCTAssertEqual(vm.cpuColor, .yellow)
    }

    @MainActor
    func test_cpuColor_highUsage_red() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 60, system: 30, idle: 10, nice: 0)
        XCTAssertEqual(vm.cpuColor, .red)
    }

    @MainActor
    func test_cpuColor_boundary_50_isYellow() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 30, system: 20, idle: 50, nice: 0)
        XCTAssertEqual(vm.cpuColor, .yellow)
    }

    @MainActor
    func test_cpuColor_boundary_80_isRed() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 50, system: 30, idle: 20, nice: 0)
        XCTAssertEqual(vm.cpuColor, .red)
    }

    @MainActor
    func test_cpuColor_zeroUsage_green() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 0, system: 0, idle: 100, nice: 0)
        XCTAssertEqual(vm.cpuColor, .green)
    }

    // MARK: - Color Coding: Memory

    @MainActor
    func test_memoryColor_lowUsage_green() {
        let vm = SystemMonitorViewModel()
        // usedPercent = (active + wired + compressed) / total * 100
        // used = 4+2+1 = 7, total = 3+4+1+2+1 = 11, percent = ~63.6%
        vm.memoryUsage = MemoryUsage(free: 3, active: 4, inactive: 1, wired: 2, compressed: 1)
        XCTAssertEqual(vm.memoryColor, .green)
    }

    @MainActor
    func test_memoryColor_mediumUsage_yellow() {
        let vm = SystemMonitorViewModel()
        // used = 6+2+1 = 9, total = 1+6+1+2+1 = 11, percent = ~81.8%
        vm.memoryUsage = MemoryUsage(free: 1, active: 6, inactive: 1, wired: 2, compressed: 1)
        XCTAssertEqual(vm.memoryColor, .yellow)
    }

    @MainActor
    func test_memoryColor_highUsage_red() {
        let vm = SystemMonitorViewModel()
        // used = 8+2+1 = 11, total = 0.5+8+0.5+2+1 = 12, percent = ~91.7%
        vm.memoryUsage = MemoryUsage(free: 0.5, active: 8, inactive: 0.5, wired: 2, compressed: 1)
        XCTAssertEqual(vm.memoryColor, .red)
    }

    // MARK: - Color Coding: Battery

    @MainActor
    func test_batteryColor_noBattery_gray() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = nil
        XCTAssertEqual(vm.batteryColor, .gray)
    }

    @MainActor
    func test_batteryColor_highLevel_green() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 80, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .green)
    }

    @MainActor
    func test_batteryColor_mediumLevel_yellow() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 35, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .yellow)
    }

    @MainActor
    func test_batteryColor_lowLevel_red() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 10, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .red)
    }

    @MainActor
    func test_batteryColor_boundary_51_isGreen() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 51, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .green)
    }

    @MainActor
    func test_batteryColor_boundary_50_isNotGreen() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 50, isCharging: false, isPluggedIn: false)
        // level 50 is NOT > 50, so it falls to > 20 check -> yellow
        XCTAssertEqual(vm.batteryColor, .yellow)
    }

    @MainActor
    func test_batteryColor_boundary_21_isYellow() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 21, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .yellow)
    }

    @MainActor
    func test_batteryColor_boundary_20_isRed() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 20, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryColor, .red)
    }

    // MARK: - Formatted Values

    @MainActor
    func test_cpuPercentFormatted() {
        let vm = SystemMonitorViewModel()
        vm.cpuUsage = CPUUsage(user: 25, system: 10, idle: 65, nice: 0)
        XCTAssertEqual(vm.cpuPercentFormatted, "35%")
    }

    @MainActor
    func test_cpuPercentFormatted_zero() {
        let vm = SystemMonitorViewModel()
        XCTAssertEqual(vm.cpuPercentFormatted, "0%")
    }

    @MainActor
    func test_memoryPercentFormatted() {
        let vm = SystemMonitorViewModel()
        // used = 4+2+2 = 8, total = 2+4+2+2+2 = 12, percent = 66.7%
        vm.memoryUsage = MemoryUsage(free: 2, active: 4, inactive: 2, wired: 2, compressed: 2)
        XCTAssertEqual(vm.memoryPercentFormatted, "67%")
    }

    @MainActor
    func test_batteryFormatted_withBattery() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = BatteryInfo(level: 75, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(vm.batteryFormatted, "75%")
    }

    @MainActor
    func test_batteryFormatted_noBattery() {
        let vm = SystemMonitorViewModel()
        vm.batteryInfo = nil
        XCTAssertEqual(vm.batteryFormatted, "N/A")
    }

    @MainActor
    func test_memoryFormatted() {
        let vm = SystemMonitorViewModel()
        // used = 6+2+0 = 8.0, total = 8+6+0+2+0 = 16.0
        vm.memoryUsage = MemoryUsage(free: 8, active: 6, inactive: 0, wired: 2, compressed: 0)
        XCTAssertEqual(vm.memoryFormatted, "8.0/16.0 GB")
    }
}

// MARK: - Supporting Model Tests

final class CPUUsageTests: XCTestCase {

    func test_total_isSumOfUserSystemNice() {
        let usage = CPUUsage(user: 25, system: 10, idle: 60, nice: 5)
        XCTAssertEqual(usage.total, 40)
    }

    func test_total_zero() {
        let usage = CPUUsage(user: 0, system: 0, idle: 100, nice: 0)
        XCTAssertEqual(usage.total, 0)
    }

    func test_conformsToSendable() {
        let usage = CPUUsage(user: 10, system: 5, idle: 85, nice: 0)
        let _: any Sendable = usage
        _ = usage
    }
}

final class MemoryUsageTests: XCTestCase {

    func test_used_isActiveWiredCompressed() {
        let usage = MemoryUsage(free: 2, active: 4, inactive: 1, wired: 2, compressed: 1)
        XCTAssertEqual(usage.used, 7) // 4+2+1
    }

    func test_total_isSumOfAll() {
        let usage = MemoryUsage(free: 2, active: 4, inactive: 1, wired: 2, compressed: 1)
        XCTAssertEqual(usage.total, 10) // 2+4+1+2+1
    }

    func test_usedPercent_calculation() {
        let usage = MemoryUsage(free: 2, active: 4, inactive: 1, wired: 2, compressed: 1)
        // used=7, total=10, percent=70
        XCTAssertEqual(usage.usedPercent, 70)
    }

    func test_usedPercent_zeroTotal_returnsZero() {
        let usage = MemoryUsage(free: 0, active: 0, inactive: 0, wired: 0, compressed: 0)
        XCTAssertEqual(usage.usedPercent, 0)
    }
}

final class NetworkSpeedTests: XCTestCase {

    func test_formatSpeed_bytes() {
        let result = NetworkSpeed.formatSpeed(500)
        XCTAssertEqual(result, "500 B/s")
    }

    func test_formatSpeed_kilobytes() {
        let result = NetworkSpeed.formatSpeed(2048)
        XCTAssertEqual(result, "2.0 KB/s")
    }

    func test_formatSpeed_megabytes() {
        let result = NetworkSpeed.formatSpeed(5_242_880)
        XCTAssertEqual(result, "5.0 MB/s")
    }

    func test_formatSpeed_gigabytes() {
        let result = NetworkSpeed.formatSpeed(2_147_483_648)
        XCTAssertEqual(result, "2.00 GB/s")
    }

    func test_formattedDownload() {
        let speed = NetworkSpeed(downloadBytesPerSec: 1024, uploadBytesPerSec: 0)
        XCTAssertEqual(speed.formattedDownload, "1.0 KB/s")
    }

    func test_formattedUpload() {
        let speed = NetworkSpeed(downloadBytesPerSec: 0, uploadBytesPerSec: 2048)
        XCTAssertEqual(speed.formattedUpload, "2.0 KB/s")
    }
}

final class BatteryInfoTests: XCTestCase {

    func test_timeRemainingFormatted_charging_withTimeToFull() {
        let info = BatteryInfo(level: 50, isCharging: true, isPluggedIn: true, timeToFull: 90)
        XCTAssertEqual(info.timeRemainingFormatted, "1h 30m until full")
    }

    func test_timeRemainingFormatted_charging_minutesOnly() {
        let info = BatteryInfo(level: 80, isCharging: true, isPluggedIn: true, timeToFull: 30)
        XCTAssertEqual(info.timeRemainingFormatted, "30m until full")
    }

    func test_timeRemainingFormatted_charging_noTimeInfo() {
        let info = BatteryInfo(level: 50, isCharging: true, isPluggedIn: true)
        XCTAssertEqual(info.timeRemainingFormatted, "Charging...")
    }

    func test_timeRemainingFormatted_fullyCharged() {
        let info = BatteryInfo(level: 100, isCharging: true, isPluggedIn: true)
        XCTAssertEqual(info.timeRemainingFormatted, "Fully Charged")
    }

    func test_timeRemainingFormatted_discharging_withTimeToEmpty() {
        let info = BatteryInfo(level: 60, isCharging: false, isPluggedIn: false, timeToEmpty: 150)
        XCTAssertEqual(info.timeRemainingFormatted, "2h 30m remaining")
    }

    func test_timeRemainingFormatted_discharging_minutesOnly() {
        let info = BatteryInfo(level: 10, isCharging: false, isPluggedIn: false, timeToEmpty: 45)
        XCTAssertEqual(info.timeRemainingFormatted, "45m remaining")
    }

    func test_timeRemainingFormatted_discharging_noTimeInfo() {
        let info = BatteryInfo(level: 50, isCharging: false, isPluggedIn: false)
        XCTAssertEqual(info.timeRemainingFormatted, "Calculating...")
    }

    func test_timeRemainingFormatted_fullyChargedPluggedIn() {
        let info = BatteryInfo(level: 100, isCharging: false, isPluggedIn: true)
        XCTAssertEqual(info.timeRemainingFormatted, "Fully Charged")
    }
}

final class RingBufferTests: XCTestCase {

    func test_initialState_empty() {
        let buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertFalse(buffer.isFull)
    }

    func test_append_incrementsCount() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(42)
        XCTAssertEqual(buffer.count, 1)
        XCTAssertFalse(buffer.isEmpty)
    }

    func test_append_wrapsAround() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        XCTAssertTrue(buffer.isFull)
        buffer.append(4)
        XCTAssertEqual(buffer.count, 3)
        // Oldest (1) should be gone
        let arr = buffer.toArray()
        XCTAssertEqual(arr, [2, 3, 4])
    }

    func test_latest_returnsLastAppended() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        XCTAssertEqual(buffer.latest, 30)
    }

    func test_latest_empty_returnsNil() {
        let buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertNil(buffer.latest)
    }

    func test_subscript_validIndex() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        XCTAssertEqual(buffer[0], 10)
        XCTAssertEqual(buffer[1], 20)
        XCTAssertEqual(buffer[2], 30)
    }

    func test_subscript_outOfBounds_returnsNil() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(10)
        XCTAssertNil(buffer[5])
        XCTAssertNil(buffer[-1])
    }

    func test_toArray() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        XCTAssertEqual(buffer.toArray(), [1, 2, 3])
    }

    func test_toArray_empty() {
        let buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertEqual(buffer.toArray(), [])
    }

    func test_clear() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.clear()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
    }

    func test_capacity_isPreserved() {
        let buffer = RingBuffer<Int>(capacity: 10)
        XCTAssertEqual(buffer.capacity, 10)
    }

    func test_randomAccessCollection_conformance() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        XCTAssertEqual(buffer.startIndex, 0)
        XCTAssertEqual(buffer.endIndex, 3)
        // Can iterate
        var collected: [Int] = []
        for value in buffer {
            if let v = value {
                collected.append(v)
            }
        }
        XCTAssertEqual(collected, [1, 2, 3])
    }
}

final class ConnectionTypeTests: XCTestCase {

    func test_rawValues() {
        XCTAssertEqual(ConnectionType.wifi.rawValue, "Wi-Fi")
        XCTAssertEqual(ConnectionType.ethernet.rawValue, "Ethernet")
        XCTAssertEqual(ConnectionType.cellular.rawValue, "Cellular")
        XCTAssertEqual(ConnectionType.unknown.rawValue, "Unknown")
        XCTAssertEqual(ConnectionType.disconnected.rawValue, "Disconnected")
    }
}
