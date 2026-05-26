import SwiftUI
import Combine
import os

private let log = Logger(subsystem: "com.cornice.app", category: "systemMonitor")

@MainActor
@Observable
final class SystemMonitorViewModel {
    // MARK: - Current values

    var cpuUsage: CPUUsage = CPUUsage(user: 0, system: 0, idle: 100, nice: 0)
    var memoryUsage: MemoryUsage = MemoryUsage(free: 0, active: 0, inactive: 0, wired: 0, compressed: 0)
    var networkSpeed: NetworkSpeed = NetworkSpeed(downloadBytesPerSec: 0, uploadBytesPerSec: 0)
    var batteryInfo: BatteryInfo?

    // MARK: - History buffers

    var cpuHistory = RingBuffer<Double>(capacity: 60)
    var memoryHistory = RingBuffer<Double>(capacity: 60)
    var downloadHistory = RingBuffer<Double>(capacity: 60)
    var uploadHistory = RingBuffer<Double>(capacity: 60)
    var batteryHistory = RingBuffer<Double>(capacity: 60)

    // MARK: - State

    var isMonitoring: Bool = false
    var hasBattery: Bool = false
    var lowBatteryAlertTriggered: Bool = false

    // MARK: - Configuration

    var pollingInterval: TimeInterval = 2.0
    var lowBatteryThreshold: Int = 20

    // MARK: - Private

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private var timer: Timer?
    private var lowBatteryAlertCooldown: Date?

    // MARK: - Lifecycle

    func startMonitoring(interval: TimeInterval? = nil) {
        if let interval { pollingInterval = interval }
        stopMonitoring()
        isMonitoring = true

        // Take an initial reading
        pollMetrics()

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollMetrics()
            }
        }
        log.info("System monitoring started with interval: \(self.pollingInterval)s")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        log.info("System monitoring stopped")
    }

    func setFocusedInterval() {
        startMonitoring(interval: 1.0)
    }

    func setBackgroundInterval() {
        startMonitoring(interval: 2.0)
    }

    // MARK: - Polling

    private func pollMetrics() {
        // CPU
        let cpu = cpuMonitor.read()
        cpuUsage = cpu
        cpuHistory.append(cpu.total)

        // Memory
        let mem = memoryMonitor.read()
        memoryUsage = mem
        memoryHistory.append(mem.usedPercent)

        // Network
        let net = networkMonitor.read()
        networkSpeed = net
        downloadHistory.append(net.downloadBytesPerSec)
        uploadHistory.append(net.uploadBytesPerSec)

        // Battery
        if let battery = batteryMonitor.read() {
            batteryInfo = battery
            hasBattery = true
            batteryHistory.append(Double(battery.level))
            checkLowBattery(battery)
        } else {
            hasBattery = false
            batteryInfo = nil
        }
    }

    // MARK: - Low Battery Alert

    private func checkLowBattery(_ battery: BatteryInfo) {
        guard !battery.isPluggedIn,
              battery.level <= lowBatteryThreshold else {
            lowBatteryAlertTriggered = false
            return
        }

        // Cooldown check: don't re-alert within 10 minutes
        if let cooldown = lowBatteryAlertCooldown,
           Date().timeIntervalSince(cooldown) < 600 {
            return
        }

        lowBatteryAlertTriggered = true
        lowBatteryAlertCooldown = Date()
        log.warning("Low battery alert: \(battery.level)%")
    }

    // MARK: - Formatted Values

    var cpuPercentFormatted: String {
        String(format: "%.0f%%", cpuUsage.total)
    }

    var memoryFormatted: String {
        String(format: "%.1f/%.1f GB", memoryUsage.used, memoryUsage.total)
    }

    var memoryPercentFormatted: String {
        String(format: "%.0f%%", memoryUsage.usedPercent)
    }

    var downloadFormatted: String {
        networkSpeed.formattedDownload
    }

    var uploadFormatted: String {
        networkSpeed.formattedUpload
    }

    var batteryFormatted: String {
        guard let battery = batteryInfo else { return "N/A" }
        return "\(battery.level)%"
    }

    // MARK: - Color Coding

    var cpuColor: Color {
        let usage = cpuUsage.total
        if usage < 50 { return .green }
        if usage < 80 { return .yellow }
        return .red
    }

    var memoryColor: Color {
        let usage = memoryUsage.usedPercent
        if usage < 70 { return .green }
        if usage < 90 { return .yellow }
        return .red
    }

    var batteryColor: Color {
        guard let battery = batteryInfo else { return .gray }
        if battery.level > 50 { return .green }
        if battery.level > 20 { return .yellow }
        return .red
    }
}
