import Foundation

// MARK: - Ring Buffer

struct RingBuffer<T> {
    private var buffer: [T?]
    private(set) var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = Swift.min(count + 1, capacity)
    }

    subscript(index: Int) -> T? {
        guard index >= 0, index < count else { return nil }
        let actualIndex = (writeIndex - count + index + capacity) % capacity
        return buffer[actualIndex]
    }

    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }

    var latest: T? {
        guard count > 0 else { return nil }
        let index = (writeIndex - 1 + capacity) % capacity
        return buffer[index]
    }

    func toArray() -> [T] {
        guard count > 0 else { return [] }
        var result: [T] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let actualIndex = (writeIndex - count + i + capacity) % capacity
            if let element = buffer[actualIndex] {
                result.append(element)
            }
        }
        return result
    }

    mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}

extension RingBuffer: RandomAccessCollection {
    var startIndex: Int { 0 }
    var endIndex: Int { count }

    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }
}

// MARK: - CPU

struct CPUUsage: Sendable {
    let user: Double
    let system: Double
    let idle: Double
    let nice: Double
    let timestamp: Date
    let isStale: Bool

    var total: Double { user + system + nice }

    init(user: Double, system: Double, idle: Double, nice: Double, timestamp: Date = .now, isStale: Bool = false) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
        self.timestamp = timestamp
        self.isStale = isStale
    }
}

// MARK: - Memory

struct MemoryUsage: Sendable {
    let free: Double       // GB
    let active: Double     // GB
    let inactive: Double   // GB
    let wired: Double      // GB
    let compressed: Double // GB
    let timestamp: Date
    let isStale: Bool

    var used: Double { active + wired + compressed }
    var total: Double { free + active + inactive + wired + compressed }
    var usedPercent: Double { total > 0 ? used / total * 100 : 0 }

    init(free: Double, active: Double, inactive: Double, wired: Double, compressed: Double,
         timestamp: Date = .now, isStale: Bool = false) {
        self.free = free
        self.active = active
        self.inactive = inactive
        self.wired = wired
        self.compressed = compressed
        self.timestamp = timestamp
        self.isStale = isStale
    }
}

// MARK: - Network

enum ConnectionType: String, Sendable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case unknown = "Unknown"
    case disconnected = "Disconnected"
}

struct NetworkSpeed: Sendable {
    let downloadBytesPerSec: Double
    let uploadBytesPerSec: Double
    let connectionType: ConnectionType
    let timestamp: Date
    let isStale: Bool

    init(downloadBytesPerSec: Double, uploadBytesPerSec: Double,
         connectionType: ConnectionType = .unknown, timestamp: Date = .now, isStale: Bool = false) {
        self.downloadBytesPerSec = downloadBytesPerSec
        self.uploadBytesPerSec = uploadBytesPerSec
        self.connectionType = connectionType
        self.timestamp = timestamp
        self.isStale = isStale
    }

    var formattedDownload: String { Self.formatSpeed(downloadBytesPerSec) }
    var formattedUpload: String { Self.formatSpeed(uploadBytesPerSec) }

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1_048_576 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1_073_741_824 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / 1_073_741_824)
        }
    }
}

// MARK: - Battery

struct BatteryInfo: Sendable {
    let level: Int          // 0-100
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeToEmpty: Int?   // minutes
    let timeToFull: Int?    // minutes
    let cycleCount: Int?
    let healthPercent: Double?
    let timestamp: Date
    let isStale: Bool

    init(level: Int, isCharging: Bool, isPluggedIn: Bool,
         timeToEmpty: Int? = nil, timeToFull: Int? = nil,
         cycleCount: Int? = nil, healthPercent: Double? = nil,
         timestamp: Date = .now, isStale: Bool = false) {
        self.level = level
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.timeToEmpty = timeToEmpty
        self.timeToFull = timeToFull
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
        self.timestamp = timestamp
        self.isStale = isStale
    }

    var timeRemainingFormatted: String {
        if isCharging {
            if let ttf = timeToFull, ttf > 0 {
                let hours = ttf / 60
                let mins = ttf % 60
                return hours > 0 ? "\(hours)h \(mins)m until full" : "\(mins)m until full"
            }
            return level >= 100 ? "Fully Charged" : "Charging..."
        } else {
            if let tte = timeToEmpty, tte > 0 {
                let hours = tte / 60
                let mins = tte % 60
                return hours > 0 ? "\(hours)h \(mins)m remaining" : "\(mins)m remaining"
            }
            return level >= 100 && isPluggedIn ? "Fully Charged" : "Calculating..."
        }
    }
}
