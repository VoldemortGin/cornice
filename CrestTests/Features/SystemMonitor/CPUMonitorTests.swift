import XCTest
@testable import Crest

struct CPURawSample { let userTicks: UInt64; let systemTicks: UInt64; let idleTicks: UInt64; let niceTicks: UInt64 }

extension CPUUsage {
    static func fromDeltas(previous p: CPURawSample, current c: CPURawSample) -> CPUUsage {
        let ud = c.userTicks &- p.userTicks, sd = c.systemTicks &- p.systemTicks
        let id = c.idleTicks &- p.idleTicks, nd = c.niceTicks &- p.niceTicks
        let total = ud + sd + id + nd
        guard total > 0 else { return CPUUsage(user: 0, system: 0, idle: 0, nice: 0, timestamp: Date(), isStale: false) }
        let t = Double(total)
        return CPUUsage(user: Double(ud)/t*100, system: Double(sd)/t*100, idle: Double(id)/t*100, nice: Double(nd)/t*100, timestamp: Date(), isStale: false)
    }
    static func fromFirstSample(_ s: CPURawSample) -> CPUUsage {
        CPUUsage(user: 0, system: 0, idle: 0, nice: 0, timestamp: Date(), isStale: true)
    }
}

final class CPUMonitorTests: XCTestCase {
    func test_deltas_correctPercentages() {
        let dp = CPUUsage.fromDeltas(previous: CPURawSample(userTicks: 1000, systemTicks: 500, idleTicks: 8000, niceTicks: 500),
                                          current:  CPURawSample(userTicks: 1200, systemTicks: 600, idleTicks: 8100, niceTicks: 500))
        XCTAssertEqual(dp.user, 50, accuracy: 0.1); XCTAssertEqual(dp.system, 25, accuracy: 0.1)
        XCTAssertEqual(dp.idle, 25, accuracy: 0.1); XCTAssertEqual(dp.nice, 0, accuracy: 0.1)
    }
    func test_totalUsage() {
        let dp = CPUUsage(user: 40, system: 20, idle: 35, nice: 5, timestamp: Date(), isStale: false)
        XCTAssertEqual(dp.total, 65, accuracy: 0.1)
    }
    func test_allIdle() {
        let dp = CPUUsage.fromDeltas(previous: CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 1000, niceTicks: 0),
                                          current:  CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 2000, niceTicks: 0))
        XCTAssertEqual(dp.total, 0, accuracy: 0.1)
    }
    func test_fullLoad() {
        let dp = CPUUsage.fromDeltas(previous: CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 0, niceTicks: 0),
                                          current:  CPURawSample(userTicks: 500, systemTicks: 500, idleTicks: 0, niceTicks: 0))
        XCTAssertEqual(dp.total, 100, accuracy: 0.1)
    }
    func test_percentagesSumTo100() {
        let dp = CPUUsage.fromDeltas(previous: CPURawSample(userTicks: 100, systemTicks: 50, idleTicks: 500, niceTicks: 10),
                                          current:  CPURawSample(userTicks: 300, systemTicks: 150, idleTicks: 700, niceTicks: 30))
        XCTAssertEqual(dp.user + dp.system + dp.idle + dp.nice, 100, accuracy: 0.1)
    }
    func test_firstSample_staleOrZero() {
        let dp = CPUUsage.fromFirstSample(CPURawSample(userTicks: 1000, systemTicks: 500, idleTicks: 8000, niceTicks: 200))
        XCTAssertTrue(dp.isStale || dp.total == 0)
    }
    func test_zeroDelta_noNaN() {
        let s = CPURawSample(userTicks: 100, systemTicks: 50, idleTicks: 300, niceTicks: 10)
        let dp = CPUUsage.fromDeltas(previous: s, current: s)
        XCTAssertFalse(dp.user.isNaN); XCTAssertFalse(dp.system.isNaN)
    }
    func test_ringBuffer_capacity() {
        var buf = RingBuffer<Int>(capacity: 3)
        for i in 0..<5 { buf.append(i) }
        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf.toArray(), [2, 3, 4])
    }
    func test_ringBuffer_empty() { XCTAssertTrue(RingBuffer<Int>(capacity: 10).isEmpty) }
}
