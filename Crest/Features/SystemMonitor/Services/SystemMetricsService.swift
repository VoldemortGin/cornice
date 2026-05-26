import Foundation
import IOKit
import IOKit.ps
import os

private let log = Logger(subsystem: "com.crest.app", category: "systemMonitor")

// MARK: - CPU Monitor

final class CPUMonitor: @unchecked Sendable {
    private struct CPUTicks: Sendable {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    private let lock = NSLock()
    private var _previousTicks: CPUTicks?
    private var previousTicks: CPUTicks? {
        get { lock.withLock { _previousTicks } }
        set { lock.withLock { _previousTicks = newValue } }
    }

    init() {}

    func read() -> CPUUsage {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = host_cpu_load_info_data_t()

        let result = withUnsafeMutablePointer(to: &hostInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            log.error("host_statistics failed for CPU: \(result)")
            return CPUUsage(user: 0, system: 0, idle: 100, nice: 0, isStale: true)
        }

        let currentTicks = CPUTicks(
            user: UInt64(hostInfo.cpu_ticks.0),
            system: UInt64(hostInfo.cpu_ticks.1),
            idle: UInt64(hostInfo.cpu_ticks.2),
            nice: UInt64(hostInfo.cpu_ticks.3)
        )

        defer { previousTicks = currentTicks }

        guard let previous = previousTicks else {
            return CPUUsage(user: 0, system: 0, idle: 100, nice: 0)
        }

        let deltaUser = currentTicks.user - previous.user
        let deltaSystem = currentTicks.system - previous.system
        let deltaIdle = currentTicks.idle - previous.idle
        let deltaNice = currentTicks.nice - previous.nice
        let deltaTotal = Double(deltaUser + deltaSystem + deltaIdle + deltaNice)

        guard deltaTotal > 0 else {
            return CPUUsage(user: 0, system: 0, idle: 100, nice: 0)
        }

        return CPUUsage(
            user: Double(deltaUser) / deltaTotal * 100,
            system: Double(deltaSystem) / deltaTotal * 100,
            idle: Double(deltaIdle) / deltaTotal * 100,
            nice: Double(deltaNice) / deltaTotal * 100
        )
    }
}

// MARK: - Memory Monitor

final class MemoryMonitor: Sendable {
    init() {}

    func read() -> MemoryUsage {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            log.error("host_statistics64 failed for memory: \(result)")
            return MemoryUsage(free: 0, active: 0, inactive: 0, wired: 0, compressed: 0, isStale: true)
        }

        let pageSize = Double(vm_kernel_page_size)
        let toGB: Double = 1_073_741_824

        return MemoryUsage(
            free: Double(stats.free_count) * pageSize / toGB,
            active: Double(stats.active_count) * pageSize / toGB,
            inactive: Double(stats.inactive_count) * pageSize / toGB,
            wired: Double(stats.wire_count) * pageSize / toGB,
            compressed: Double(stats.compressor_page_count) * pageSize / toGB
        )
    }
}

// MARK: - Network Monitor

final class NetworkMonitor: @unchecked Sendable {
    private struct InterfaceSnapshot {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let timestamp: Date
    }

    private let lock = NSLock()
    private var _previousSnapshot: InterfaceSnapshot?
    private var previousSnapshot: InterfaceSnapshot? {
        get { lock.withLock { _previousSnapshot } }
        set { lock.withLock { _previousSnapshot = newValue } }
    }

    init() {}

    func read() -> NetworkSpeed {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0, let firstAddr = ifaddrsPtr else {
            log.error("getifaddrs failed")
            return NetworkSpeed(downloadBytesPerSec: 0, uploadBytesPerSec: 0, isStale: true)
        }
        defer { freeifaddrs(ifaddrsPtr) }

        var current = firstAddr
        while true {
            let name = String(cString: current.pointee.ifa_name)

            // Skip loopback
            if name != "lo0",
               current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(current.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }

            guard let next = current.pointee.ifa_next else { break }
            current = next
        }

        let now = Date()
        let currentSnapshot = InterfaceSnapshot(bytesIn: totalIn, bytesOut: totalOut, timestamp: now)

        defer { previousSnapshot = currentSnapshot }

        guard let previous = previousSnapshot else {
            return NetworkSpeed(downloadBytesPerSec: 0, uploadBytesPerSec: 0)
        }

        let deltaTime = now.timeIntervalSince(previous.timestamp)
        guard deltaTime > 0 else {
            return NetworkSpeed(downloadBytesPerSec: 0, uploadBytesPerSec: 0)
        }

        // Handle counter wrap
        let deltaIn: UInt64 = totalIn >= previous.bytesIn ? totalIn - previous.bytesIn : 0
        let deltaOut: UInt64 = totalOut >= previous.bytesOut ? totalOut - previous.bytesOut : 0

        return NetworkSpeed(
            downloadBytesPerSec: Double(deltaIn) / deltaTime,
            uploadBytesPerSec: Double(deltaOut) / deltaTime
        )
    }
}

// MARK: - Battery Monitor

final class BatteryMonitor: Sendable {
    init() {}

    func read() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return nil // No battery (desktop Mac)
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let level = maxCapacity > 0 ? currentCapacity * 100 / maxCapacity : 0

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let powerSource = desc[kIOPSPowerSourceStateKey] as? String
            let isPluggedIn = powerSource == kIOPSACPowerValue

            let timeToEmpty: Int? = {
                let val = desc[kIOPSTimeToEmptyKey] as? Int
                return val != nil && val! >= 0 ? val : nil
            }()

            let timeToFull: Int? = {
                let val = desc[kIOPSTimeToFullChargeKey] as? Int
                return val != nil && val! >= 0 ? val : nil
            }()

            let cycleCount = readBatteryCycleCount()

            return BatteryInfo(
                level: level,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                timeToEmpty: timeToEmpty,
                timeToFull: timeToFull,
                cycleCount: cycleCount
            )
        }

        return nil
    }

    private func readBatteryCycleCount() -> Int? {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        let cycleCount = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)
        return cycleCount?.takeRetainedValue() as? Int
    }
}
