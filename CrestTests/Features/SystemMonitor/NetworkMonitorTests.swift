import XCTest
@testable import Niya

struct NetworkRawSnapshot { let timestamp: Date; let bytesIn: UInt64; let bytesOut: UInt64 }
struct NetworkInterface { let name: String; let bytesIn: UInt64; let bytesOut: UInt64; var isLoopback: Bool { name == "lo0" } }

extension NetworkDataPoint {
    static func fromSnapshots(previous p: NetworkRawSnapshot, current c: NetworkRawSnapshot) -> NetworkDataPoint {
        let dt = c.timestamp.timeIntervalSince(p.timestamp)
        guard dt > 0 else { return NetworkDataPoint(timestamp: c.timestamp, downloadSpeed: 0, uploadSpeed: 0, totalDownloaded: c.bytesIn, totalUploaded: c.bytesOut, connectionType: .unknown, isStale: false) }
        let di = c.bytesIn >= p.bytesIn ? c.bytesIn - p.bytesIn : 0
        let do_ = c.bytesOut >= p.bytesOut ? c.bytesOut - p.bytesOut : 0
        return NetworkDataPoint(timestamp: c.timestamp, downloadSpeed: Double(di)/dt, uploadSpeed: Double(do_)/dt, totalDownloaded: c.bytesIn, totalUploaded: c.bytesOut, connectionType: .unknown, isStale: false)
    }
}

enum NetworkSpeedFormatter {
    static func format(_ bps: Double) -> String {
        if bps < 1024 { return "\(Int(bps)) B/s" }
        else if bps < 1_048_576 { return String(format: "%.1f KB/s", bps/1024) }
        else if bps < 1_073_741_824 { return String(format: "%.1f MB/s", bps/1_048_576) }
        else { return String(format: "%.2f GB/s", bps/1_073_741_824) }
    }
}

final class NetworkMonitorTests: XCTestCase {
    func test_speed_basic() {
        let dp = NetworkDataPoint.fromSnapshots(previous: NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 100), bytesIn: 1_000_000, bytesOut: 500_000),
                                                current:  NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 102), bytesIn: 3_000_000, bytesOut: 1_500_000))
        XCTAssertEqual(dp.downloadSpeed, 1_000_000, accuracy: 100)
        XCTAssertEqual(dp.uploadSpeed, 500_000, accuracy: 100)
    }
    func test_speed_noTraffic() {
        let s = NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 0), bytesIn: 1000, bytesOut: 1000)
        let dp = NetworkDataPoint.fromSnapshots(previous: s, current: NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 5), bytesIn: 1000, bytesOut: 1000))
        XCTAssertEqual(dp.downloadSpeed, 0, accuracy: 0.01)
    }
    func test_zeroInterval_noNaN() {
        let s = NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 100), bytesIn: 5000, bytesOut: 3000)
        let dp = NetworkDataPoint.fromSnapshots(previous: s, current: s)
        XCTAssertFalse(dp.downloadSpeed.isNaN); XCTAssertFalse(dp.downloadSpeed.isInfinite)
    }
    func test_loopback_filtered() {
        let ifaces = [NetworkInterface(name: "lo0", bytesIn: 999, bytesOut: 999), NetworkInterface(name: "en0", bytesIn: 50, bytesOut: 25)]
        let filtered = ifaces.filter { !$0.isLoopback }
        XCTAssertEqual(filtered.count, 1); XCTAssertEqual(filtered[0].name, "en0")
    }
    func test_format_bytes() { XCTAssertEqual(NetworkSpeedFormatter.format(512), "512 B/s") }
    func test_format_kb() { XCTAssertEqual(NetworkSpeedFormatter.format(46_285), "45.2 KB/s") }
    func test_format_mb() { XCTAssertEqual(NetworkSpeedFormatter.format(13_316_915), "12.7 MB/s") }
    func test_format_gb() { XCTAssertEqual(NetworkSpeedFormatter.format(1_073_741_824 * 1.05), "1.05 GB/s") }
    func test_format_zero() { XCTAssertEqual(NetworkSpeedFormatter.format(0), "0 B/s") }
    func test_counterWrap_nonnegative() {
        let dp = NetworkDataPoint.fromSnapshots(previous: NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 0), bytesIn: UInt64.max - 100, bytesOut: 0),
                                                current:  NetworkRawSnapshot(timestamp: Date(timeIntervalSince1970: 1), bytesIn: 50, bytesOut: 100))
        XCTAssertGreaterThanOrEqual(dp.downloadSpeed, 0)
    }
}
