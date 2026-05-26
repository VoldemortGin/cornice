import XCTest
@testable import Niya

struct CPURawSample { let userTicks: UInt64; let systemTicks: UInt64; let idleTicks: UInt64; let niceTicks: UInt64 }

extension CPUDataPoint {
    static func fromDeltas(previous p: CPURawSample, current c: CPURawSample) -> CPUDataPoint {
        let ud = c.userTicks &- p.userTicks, sd = c.systemTicks &- p.systemTicks
        let id = c.idleTicks &- p.idleTicks, nd = c.niceTicks &- p.niceTicks
        let total = ud + sd + id + nd
        guard total > 0 else { return CPUDataPoint(timestamp: Date(), userPercent: 0, systemPercent: 0, idlePercent: 0, nicePercent: 0, perCore: nil, isStale: false) }
        let t = Double(total)
        return CPUDataPoint(timestamp: Date(), userPercent: Double(ud)/t*100, systemPercent: Double(sd)/t*100, idlePercent: Double(id)/t*100, nicePercent: Double(nd)/t*100, perCore: nil, isStale: false)
    }
    static func fromFirstSample(_ s: CPURawSample) -> CPUDataPoint {
        CPUDataPoint(timestamp: Date(), userPercent: 0, systemPercent: 0, idlePercent: 0, nicePercent: 0, perCore: nil, isStale: true)
    }
}

struct RingBuffer<E> {
    private var storage: [E] = []; private var wi = 0; let capacity: Int; private var full = false
    init(capacity: Int) { self.capacity = capacity; storage.reserveCapacity(capacity) }
    var count: Int { full ? capacity : wi }
    var isEmpty: Bool { count == 0 }
    mutating func append(_ e: E) {
        if storage.count < capacity { storage.append(e) } else { storage[wi] = e }
        wi = (wi + 1) % capacity; if wi == 0 && storage.count == capacity { full = true }
    }
    subscript(i: Int) -> E { full ? storage[(wi + i) % capacity] : storage[i] }
    func map<T>(_ f: (E) -> T) -> [T] { (0..<count).map { f(self[$0]) } }
}

final class CPUMonitorTests: XCTestCase {
    func test_deltas_correctPercentages() {
        let dp = CPUDataPoint.fromDeltas(previous: CPURawSample(userTicks: 1000, systemTicks: 500, idleTicks: 8000, niceTicks: 500),
                                          current:  CPURawSample(userTicks: 1200, systemTicks: 600, idleTicks: 8100, niceTicks: 500))
        XCTAssertEqual(dp.userPercent, 50, accuracy: 0.1); XCTAssertEqual(dp.systemPercent, 25, accuracy: 0.1)
        XCTAssertEqual(dp.idlePercent, 25, accuracy: 0.1); XCTAssertEqual(dp.nicePercent, 0, accuracy: 0.1)
    }
    func test_totalUsage() {
        let dp = CPUDataPoint(timestamp: Date(), userPercent: 40, systemPercent: 20, idlePercent: 35, nicePercent: 5, perCore: nil, isStale: false)
        XCTAssertEqual(dp.totalUsage, 65, accuracy: 0.1)
    }
    func test_allIdle() {
        let dp = CPUDataPoint.fromDeltas(previous: CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 1000, niceTicks: 0),
                                          current:  CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 2000, niceTicks: 0))
        XCTAssertEqual(dp.totalUsage, 0, accuracy: 0.1)
    }
    func test_fullLoad() {
        let dp = CPUDataPoint.fromDeltas(previous: CPURawSample(userTicks: 0, systemTicks: 0, idleTicks: 0, niceTicks: 0),
                                          current:  CPURawSample(userTicks: 500, systemTicks: 500, idleTicks: 0, niceTicks: 0))
        XCTAssertEqual(dp.totalUsage, 100, accuracy: 0.1)
    }
    func test_percentagesSumTo100() {
        let dp = CPUDataPoint.fromDeltas(previous: CPURawSample(userTicks: 100, systemTicks: 50, idleTicks: 500, niceTicks: 10),
                                          current:  CPURawSample(userTicks: 300, systemTicks: 150, idleTicks: 700, niceTicks: 30))
        XCTAssertEqual(dp.userPercent + dp.systemPercent + dp.idlePercent + dp.nicePercent, 100, accuracy: 0.1)
    }
    func test_firstSample_staleOrZero() {
        let dp = CPUDataPoint.fromFirstSample(CPURawSample(userTicks: 1000, systemTicks: 500, idleTicks: 8000, niceTicks: 200))
        XCTAssertTrue(dp.isStale || dp.totalUsage == 0)
    }
    func test_zeroDelta_noNaN() {
        let s = CPURawSample(userTicks: 100, systemTicks: 50, idleTicks: 300, niceTicks: 10)
        let dp = CPUDataPoint.fromDeltas(previous: s, current: s)
        XCTAssertFalse(dp.userPercent.isNaN); XCTAssertFalse(dp.systemPercent.isNaN)
    }
    func test_ringBuffer_capacity() {
        var buf = RingBuffer<Int>(capacity: 3)
        for i in 0..<5 { buf.append(i) }
        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf.map { $0 }, [2, 3, 4])
    }
    func test_ringBuffer_empty() { XCTAssertTrue(RingBuffer<Int>(capacity: 10).isEmpty) }
}
