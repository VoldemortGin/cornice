import SwiftUI

// MARK: - Compact Monitor View

struct CompactMonitorView: View {
    @Bindable var viewModel: SystemMonitorViewModel

    var body: some View {
        HStack(spacing: 12) {
            MetricCard(
                icon: "cpu",
                value: viewModel.cpuPercentFormatted,
                color: viewModel.cpuColor,
                history: viewModel.cpuHistory.toArray(),
                maxValue: 100
            )

            MetricCard(
                icon: "memorychip",
                value: viewModel.memoryPercentFormatted,
                color: viewModel.memoryColor,
                history: viewModel.memoryHistory.toArray(),
                maxValue: 100
            )

            NetworkSpeedView(
                download: viewModel.downloadFormatted,
                upload: viewModel.uploadFormatted
            )

            if viewModel.hasBattery {
                BatteryView(
                    level: viewModel.batteryInfo?.level ?? 0,
                    isCharging: viewModel.batteryInfo?.isCharging ?? false,
                    color: viewModel.batteryColor
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }
}

// MARK: - Expanded Monitor View

struct ExpandedMonitorView: View {
    @Bindable var viewModel: SystemMonitorViewModel

    var body: some View {
        VStack(spacing: 16) {
            // CPU Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(viewModel.cpuColor)
                    Text("CPU")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(viewModel.cpuPercentFormatted)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(viewModel.cpuColor)
                }
                SparklineView(
                    data: viewModel.cpuHistory.toArray(),
                    maxValue: 100,
                    color: viewModel.cpuColor
                )
                .frame(height: 40)

                HStack(spacing: 16) {
                    MetricLabel(label: "User", value: String(format: "%.1f%%", viewModel.cpuUsage.user))
                    MetricLabel(label: "System", value: String(format: "%.1f%%", viewModel.cpuUsage.system))
                    MetricLabel(label: "Idle", value: String(format: "%.1f%%", viewModel.cpuUsage.idle))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            // Memory Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "memorychip")
                        .foregroundStyle(viewModel.memoryColor)
                    Text("Memory")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(viewModel.memoryFormatted)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(viewModel.memoryColor)
                }
                SparklineView(
                    data: viewModel.memoryHistory.toArray(),
                    maxValue: 100,
                    color: viewModel.memoryColor
                )
                .frame(height: 40)

                MemorySegmentBar(memory: viewModel.memoryUsage)
                    .frame(height: 8)

                HStack(spacing: 12) {
                    MetricLabel(label: "Active", value: String(format: "%.1f GB", viewModel.memoryUsage.active))
                    MetricLabel(label: "Wired", value: String(format: "%.1f GB", viewModel.memoryUsage.wired))
                    MetricLabel(label: "Compressed", value: String(format: "%.1f GB", viewModel.memoryUsage.compressed))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            // Network Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "network")
                        .foregroundStyle(.blue)
                    Text("Network")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(viewModel.networkSpeed.connectionType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label(viewModel.downloadFormatted, systemImage: "arrow.down")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading) {
                        Label(viewModel.uploadFormatted, systemImage: "arrow.up")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }

                DualSparklineView(
                    downloadData: viewModel.downloadHistory.toArray(),
                    uploadData: viewModel.uploadHistory.toArray()
                )
                .frame(height: 40)
            }

            // Battery Section
            if viewModel.hasBattery, let battery = viewModel.batteryInfo {
                Divider().background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                            .foregroundStyle(viewModel.batteryColor)
                        Text("Battery")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(battery.level)%")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(viewModel.batteryColor)
                    }

                    Text(battery.timeRemainingFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        if let cycleCount = battery.cycleCount {
                            MetricLabel(label: "Cycles", value: "\(cycleCount)")
                        }
                        if let health = battery.healthPercent {
                            MetricLabel(label: "Health", value: String(format: "%.0f%%", health))
                        }
                        MetricLabel(label: "Status", value: battery.isCharging ? "Charging" : "On Battery")
                    }

                    SparklineView(
                        data: viewModel.batteryHistory.toArray(),
                        maxValue: 100,
                        color: viewModel.batteryColor
                    )
                    .frame(height: 30)
                }
            }
        }
        .padding(16)
        .onAppear { viewModel.startMonitoring(interval: 1.0) }
        .onDisappear { viewModel.stopMonitoring() }
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let data: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                Path { path in
                    let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                    let height = geometry.size.height

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = min(value / maxValue, 1.0)
                        let y = height - (normalizedY * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)

                // Filled area
                Path { path in
                    let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                    let height = geometry.size.height

                    path.move(to: CGPoint(x: 0, y: height))
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = min(value / maxValue, 1.0)
                        let y = height - (normalizedY * height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.15))
            }
        }
    }
}

// MARK: - Dual Sparkline View

struct DualSparklineView: View {
    let downloadData: [Double]
    let uploadData: [Double]

    private var maxVal: Double {
        let maxDown = downloadData.max() ?? 0
        let maxUp = uploadData.max() ?? 0
        return max(maxDown, maxUp, 1)
    }

    var body: some View {
        ZStack {
            SparklineView(data: downloadData, maxValue: maxVal, color: .blue)
            SparklineView(data: uploadData, maxValue: maxVal, color: .green)
        }
    }
}

// MARK: - Memory Segment Bar

struct MemorySegmentBar: View {
    let memory: MemoryUsage

    var body: some View {
        GeometryReader { geometry in
            let total = max(memory.total, 1)
            let width = geometry.size.width

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: width * memory.active / total)
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: width * memory.wired / total)
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: width * memory.compressed / total)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String
    let value: String
    let color: Color
    let history: [Double]
    let maxValue: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
            }
            SparklineView(data: history, maxValue: maxValue, color: color)
                .frame(width: 40, height: 16)
        }
    }
}

// MARK: - Network Speed View

struct NetworkSpeedView: View {
    let download: String
    let upload: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
                Text(download)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white)
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(upload)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Battery View

struct BatteryView: View {
    let level: Int
    let isCharging: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Image(systemName: batteryIconName)
                    .font(.caption)
                    .foregroundStyle(color)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.yellow)
                }
            }
            Text("\(level)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var batteryIconName: String {
        switch level {
        case 0..<13: return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

// MARK: - Metric Label

struct MetricLabel: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Main System Monitor View (Wrapper)

struct SystemMonitorView: View {
    @State private var viewModel = SystemMonitorViewModel()
    var isExpanded: Bool = false

    var body: some View {
        if isExpanded {
            ExpandedMonitorView(viewModel: viewModel)
        } else {
            CompactMonitorView(viewModel: viewModel)
        }
    }
}
