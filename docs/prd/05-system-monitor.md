# PRD-05: System Monitor Widgets

## 1. Overview

Real-time system monitoring widgets for CPU, RAM, Network, and Battery, displayed in the macOS Dynamic Island. Each monitor collects hardware metrics via low-level system APIs, maintains a rolling history for sparkline/chart rendering, and adapts its UI across closed, compact, and expanded states.

All monitors share a common `SystemMetric` protocol and lifecycle model: monitoring starts when the widget becomes visible and stops when hidden, ensuring minimal CPU/memory overhead.

---

## 2. Goals

- Provide at-a-glance system health directly in the notch area.
- Use native macOS APIs (Mach kernel, IOKit, Network framework) for accurate, low-latency metrics.
- Keep resource consumption negligible when monitors are hidden.
- Support configurable sample intervals and history depths.

## 3. Non-Goals

- Process management (kill/signal processes) -- out of scope for v1.
- GPU monitoring (Metal Performance Shaders HUD) -- future PRD.
- Disk I/O monitoring -- future PRD.
- Remote system monitoring.

---

## 4. Shared Architecture

### 4.1 SystemMetric Protocol

```swift
protocol SystemMetric: ObservableObject {
    associatedtype DataPoint

    /// Most recent reading.
    var currentValue: DataPoint { get }

    /// Rolling history for sparkline/chart rendering.
    var history: [DataPoint] { get }

    /// Begin periodic sampling.
    /// - Parameter interval: Seconds between samples.
    func startMonitoring(interval: TimeInterval)

    /// Stop periodic sampling and release timer resources.
    func stopMonitoring()
}
```

### 4.2 Ring Buffer

Each monitor stores history in a fixed-capacity ring buffer (`RingBuffer<DataPoint>`).

- Default capacity: 60 data points.
- When full, oldest entry is overwritten.
- Provides O(1) append and subscript access.
- Conforms to `RandomAccessCollection` for direct use in SwiftUI `ForEach` / chart APIs.

### 4.3 Lifecycle

| Widget State | Monitor Behavior |
|---|---|
| Hidden (no widget configured) | `stopMonitoring()` -- no timer, no syscalls |
| Closed state visible | `startMonitoring(interval: backgroundInterval)` (default 5s) |
| Open state (compact or expanded) | `startMonitoring(interval: focusedInterval)` (default 2s) |
| Expanded with chart focused | `startMonitoring(interval: 1s)` for high-fidelity charting |

Transitions between states call `stopMonitoring()` then `startMonitoring(interval:)` with the new interval. Timers use `DispatchSourceTimer` on a shared serial queue (`systemMonitorQueue`) to avoid main-thread work.

### 4.4 Error Handling

- All Mach/IOKit calls check return codes (`KERN_SUCCESS`, `kIOReturnSuccess`).
- On failure: log via `os_log`, keep last known value, set an `isStale: Bool` flag on the data point.
- UI shows a subtle stale indicator (dimmed text) when data is stale.

---

## 5. CPU Monitor

### 5.1 Data Collection

| Item | Detail |
|---|---|
| API | `host_processor_info(mach_host_self(), HOST_CPU_LOAD_INFO, ...)` |
| Fallback | `host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO_COUNT, ...)` for aggregate |
| Ticks collected | `CPU_STATE_USER`, `CPU_STATE_SYSTEM`, `CPU_STATE_IDLE`, `CPU_STATE_NICE` |
| Calculation | Delta ticks between consecutive samples; percentage = delta_state / delta_total * 100 |
| Per-core | `host_processor_info` returns per-processor data; aggregate by summing deltas |

**Critical**: Always compute deltas between samples. Absolute tick counts are monotonically increasing and meaningless as percentages on their own.

### 5.2 Data Point

```swift
struct CPUDataPoint: Sendable {
    let timestamp: Date
    let userPercent: Double      // 0.0 ... 100.0
    let systemPercent: Double
    let idlePercent: Double
    let nicePercent: Double
    let perCore: [CoreLoad]?     // nil when in background/closed sampling
    let isStale: Bool

    var totalUsage: Double { userPercent + systemPercent + nicePercent }
}

struct CoreLoad: Sendable {
    let coreIndex: Int
    let usage: Double  // 0.0 ... 100.0
}
```

### 5.3 Top Processes (Expanded State Only)

- Use `proc_listallpids` + `proc_pidinfo` with `PROC_PIDTASKINFO` to get per-process CPU time.
- Compute delta CPU time between samples, rank by delta.
- Show top 5 processes: name, PID, CPU%.
- Only collected when expanded state is active (expensive call).

### 5.4 UI Layouts

**Closed state**:
- Single numeric label: `"47%"` with color coding (green < 50%, yellow 50-80%, red > 80%).
- Optional: 8-bar mini sparkline (last 8 readings), configurable on/off.

**Open state -- compact**:
- Card with CPU icon, total usage percentage, mini sparkline (last 30 readings).
- Sparkline: 40pt wide, 16pt tall, filled area chart.

**Open state -- expanded**:
- Header: total CPU usage, large sparkline (last 60 readings, 200pt wide).
- Per-core grid: 2-column grid of mini bars, one per core, labeled `"Core 0: 62%"`.
- Top processes table: 5 rows, columns: rank, app icon, name, CPU%.

---

## 6. RAM Monitor

### 6.1 Data Collection

| Item | Detail |
|---|---|
| API | `host_statistics64(mach_host_self(), HOST_VM_INFO64, ...)` returns `vm_statistics64` |
| Page size | `vm_kernel_page_size` (typically 16384 on Apple Silicon) |
| Conversion | bytes = page_count * page_size; display in GB (bytes / 1_073_741_824) |

### 6.2 Metrics

| Metric | Source field | Category |
|---|---|---|
| Free | `free_count` | Available |
| Active | `active_count` | Used |
| Inactive | `inactive_count` | Cached (reclaimable) |
| Wired | `wire_count` | Used (non-evictable) |
| Compressed | `compressor_page_count` | Used |
| App Memory | active + wired + compressed - purgeable | Used (user-facing) |

**Calculated values**:
- `used = active + wired + compressed` (matches Activity Monitor definition)
- `total = free + active + inactive + wired + compressed`
- `usagePercent = used / total * 100`

### 6.3 Data Point

```swift
struct RAMDataPoint: Sendable {
    let timestamp: Date
    let freeGB: Double
    let activeGB: Double
    let inactiveGB: Double
    let wiredGB: Double
    let compressedGB: Double
    let totalGB: Double
    let isStale: Bool

    var usedGB: Double { activeGB + wiredGB + compressedGB }
    var usagePercent: Double { usedGB / totalGB * 100.0 }
}
```

### 6.4 UI Layouts

**Closed state**:
- Compact text: `"12.4/16 GB"` or usage ring (tiny circular progress).

**Open state -- compact**:
- Card with RAM icon, used/total label, horizontal segmented bar (active=blue, wired=orange, compressed=purple, free=gray).

**Open state -- expanded**:
- Segmented donut chart: active, wired, compressed, inactive, free -- each with color and GB label.
- Numeric breakdown table: one row per category with GB and percentage.
- Memory pressure indicator: green/yellow/red (derived from usage percent thresholds: <70% green, 70-90% yellow, >90% red).

---

## 7. Network Monitor

### 7.1 Data Collection -- Throughput

| Item | Detail |
|---|---|
| API | `getifaddrs()` iterating `ifaddrs` linked list |
| Filter | Skip `lo0` (loopback); include `en*`, `utun*`, `bridge*` |
| Data | For `AF_LINK` family: `if_data.ifi_ibytes` (in), `if_data.ifi_obytes` (out) |
| Calculation | `speed = (current_bytes - previous_bytes) / delta_time` |
| Unit formatting | Auto-scale: B/s, KB/s, MB/s, GB/s (1024-based) |

**Important**: Sum across all non-loopback interfaces for aggregate speed. Store per-interface breakdown for expanded view.

### 7.2 Data Collection -- Connection Type

| Item | Detail |
|---|---|
| API | `NWPathMonitor` (Network framework) |
| Info extracted | `path.usesInterfaceType(.wifi)`, `.wiredEthernet`, `.cellular` |
| Status | `path.status == .satisfied` for connectivity |
| Updates | Callback-based; update connection type label on change |

### 7.3 Data Point

```swift
struct NetworkDataPoint: Sendable {
    let timestamp: Date
    let downloadSpeed: Double   // bytes per second
    let uploadSpeed: Double     // bytes per second
    let totalDownloaded: UInt64 // cumulative session bytes
    let totalUploaded: UInt64   // cumulative session bytes
    let connectionType: ConnectionType
    let isStale: Bool
}

enum ConnectionType: String, Sendable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case unknown = "Unknown"
    case disconnected = "Disconnected"
}
```

### 7.4 Speed Formatting

```
func formatSpeed(_ bytesPerSecond: Double) -> String
```

| Range | Format | Example |
|---|---|---|
| < 1024 | `"X B/s"` | `"512 B/s"` |
| < 1_048_576 | `"X.X KB/s"` | `"45.2 KB/s"` |
| < 1_073_741_824 | `"X.X MB/s"` | `"12.7 MB/s"` |
| >= 1_073_741_824 | `"X.XX GB/s"` | `"1.05 GB/s"` |

### 7.5 UI Layouts

**Closed state**:
- Down arrow + speed, up arrow + speed, compact: `"↓ 2.1 MB/s  ↑ 340 KB/s"`.
- If disconnected: show `"--"` with dimmed style.

**Open state -- compact**:
- Card with network icon, connection type badge (Wi-Fi/Ethernet), download speed (large), upload speed (smaller).
- Mini dual-line sparkline (download = blue, upload = green).

**Open state -- expanded**:
- Live dual-axis speed graph (last 60 samples).
- Per-interface table: interface name, download speed, upload speed.
- Session totals: total downloaded, total uploaded (formatted as MB/GB).
- Connection info: type, interface name, local IP (from `getifaddrs` `AF_INET`/`AF_INET6`).

---

## 8. Battery Monitor

### 8.1 Data Collection

| Item | Detail |
|---|---|
| API | `IOPSCopyPowerSourcesInfo()` + `IOPSCopyPowerSourcesList()` |
| Iteration | `IOPSGetPowerSourceDescription(blob, source)` returns `CFDictionary` |
| Keys | `kIOPSCurrentCapacityKey`, `kIOPSMaxCapacityKey`, `kIOPSIsChargingKey`, `kIOPSPowerSourceStateKey`, `kIOPSTimeToEmptyKey`, `kIOPSTimeToFullChargeKey` |
| Adapter | `IOPSCopyExternalPowerAdapterDetails()` for wattage, manufacturer |
| Level | `level = currentCapacity / maxCapacity * 100` (integer 0-100) |

### 8.2 Additional Metrics (IOKit SMC / IOService)

| Metric | Source |
|---|---|
| Cycle count | `IOServiceMatching("AppleSmartBattery")` -> `"CycleCount"` |
| Design capacity | `"DesignCapacity"` |
| Current max capacity | `"MaxCapacity"` |
| Battery health | `currentMax / designCapacity * 100%` |
| Temperature | `"Temperature"` (centi-degrees Celsius, divide by 100) |

### 8.3 Data Point

```swift
struct BatteryDataPoint: Sendable {
    let timestamp: Date
    let level: Int                  // 0-100
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeToEmpty: Int?           // minutes, nil if charging or calculating
    let timeToFull: Int?            // minutes, nil if not charging
    let cycleCount: Int?
    let healthPercent: Double?      // 0.0-100.0
    let temperature: Double?        // Celsius
    let adapterWatts: Int?          // nil if on battery
    let isStale: Bool
}
```

### 8.4 Low Battery Alert

- Triggers a sneak peek notification when battery drops below threshold.
- Default threshold: 20%. Configurable: 5%, 10%, 15%, 20%, 25%, 30%.
- Alert shows: battery level, estimated time remaining, suggestion to plug in.
- Cooldown: do not re-alert for the same threshold crossing within 10 minutes.
- Suppressed when `isPluggedIn == true`.

### 8.5 Time Remaining Formatting

| Scenario | Display |
|---|---|
| Charging, time known | `"1h 23m until full"` |
| Charging, time unknown | `"Charging..."` |
| On battery, time known | `"3h 45m remaining"` |
| On battery, time unknown | `"Calculating..."` |
| Fully charged, plugged in | `"Fully Charged"` |

### 8.6 UI Layouts

**Closed state**:
- Battery icon with fill level (SF Symbol `battery.75percent` etc., or custom drawn).
- Charging bolt overlay when charging.
- Level text: `"82%"`.
- Color: green > 50%, yellow 20-50%, red < 20%.

**Sneak peek**:
- Low battery alert (see 8.4).
- Charging state change notification: `"Power Connected"` / `"Power Disconnected"`.

**Open state -- compact**:
- Card with battery icon, level percentage (large), time remaining, connection type icon (plug/battery).

**Open state -- expanded**:
- Large battery graphic with level fill.
- Metrics grid: level, health, cycle count, temperature.
- Power adapter info: wattage, manufacturer (if available).
- Level history sparkline (useful for seeing drain rate over time).
- Time estimates: time to empty / time to full.

---

## 9. Settings & Configuration

### 9.1 Per-Monitor Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Enabled | Bool | true (CPU, RAM, Network), true (Battery) | on/off per monitor |
| Show in closed state | Bool | false | on/off |
| Background sample interval | TimeInterval | 5.0 | 2.0, 3.0, 5.0, 10.0 |
| Focused sample interval | TimeInterval | 2.0 | 0.5, 1.0, 2.0, 3.0 |
| History buffer size | Int | 60 | 30, 60, 120 |

### 9.2 Battery-Specific Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Low battery alert enabled | Bool | true | on/off |
| Low battery threshold | Int | 20 | 5, 10, 15, 20, 25, 30 |
| Show charging notifications | Bool | true | on/off |

### 9.3 Network-Specific Settings

| Setting | Type | Default | Options |
|---|---|---|---|
| Show per-interface breakdown | Bool | false | on/off |
| Speed unit base | Enum | binary (1024) | binary (1024), decimal (1000) |

---

## 10. Accessibility

- All numeric values exposed via `accessibilityValue`.
- Sparklines: `accessibilityLabel` summarizing trend (e.g., `"CPU usage trending up, currently 62%"`).
- Battery alerts: delivered as `NSAccessibility.Notification` for VoiceOver.
- Charts in expanded view: provide `accessibilityLabel` with summary statistics (min, max, average).
- Color coding always paired with text/icon differentiation (never color-only).

---

## 11. Requirements Table

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---|---|
| SM-001 | CPU monitor calculates usage from tick deltas, not absolute values | P0 | Unit test: two consecutive samples produce correct user/system/idle percentages; percentages sum to ~100% |
| SM-002 | CPU monitor reports per-core usage | P1 | Expanded view shows one bar per logical core; each bar value 0-100% |
| SM-003 | CPU monitor lists top 5 processes by CPU usage | P2 | Expanded view shows process name, PID, CPU% for 5 highest consumers; updates each sample |
| SM-004 | RAM monitor reads vm_statistics64 and converts via page size | P0 | Unit test: page counts * vm_kernel_page_size / 1GB matches expected GB values |
| SM-005 | RAM monitor reports free, active, inactive, wired, compressed | P0 | All five categories present in data point; sum equals total system RAM within rounding tolerance |
| SM-006 | RAM monitor calculates used = active + wired + compressed | P0 | Unit test: usedGB equals activeGB + wiredGB + compressedGB |
| SM-007 | Network monitor calculates speed from byte count deltas | P0 | Unit test: given two snapshots N seconds apart, speed = delta_bytes / N |
| SM-008 | Network monitor skips loopback interface | P0 | Unit test: lo0 excluded from aggregation; only en*/utun*/bridge* counted |
| SM-009 | Network monitor formats speed with auto-scaled units | P0 | Unit test: 512 -> "512 B/s", 46285 -> "45.2 KB/s", 13316915 -> "12.7 MB/s" |
| SM-010 | Network monitor reports connection type via NWPathMonitor | P1 | Connection type label updates within 2s of switching Wi-Fi <-> Ethernet |
| SM-011 | Battery monitor reads level 0-100% from IOPowerSources | P0 | Level matches System Preferences battery display within 1% |
| SM-012 | Battery monitor detects charging state and power source | P0 | isCharging and isPluggedIn update within 5s of plugging/unplugging adapter |
| SM-013 | Battery monitor shows time remaining / time to full | P1 | Displayed value matches menubar battery time estimate; shows "Calculating..." when system returns -1 |
| SM-014 | Battery monitor fires low battery sneak peek at configurable threshold | P1 | Alert appears when level crosses threshold from above; does not re-fire within 10-minute cooldown |
| SM-015 | Battery monitor reports cycle count and health percentage | P2 | Values match `ioreg -l -w0 \| grep -i "cyclecount\|maxcapacity\|designcapacity"` output |
| SM-016 | All monitors conform to SystemMetric protocol | P0 | Compile-time: each monitor type satisfies all protocol requirements |
| SM-017 | History stored in fixed-capacity ring buffer | P0 | Unit test: after inserting capacity+10 items, buffer.count == capacity; oldest items evicted |
| SM-018 | Monitoring starts/stops based on widget visibility | P0 | Integration test: timer is nil when widget hidden; timer is active when widget visible |
| SM-019 | Sample interval adapts to widget state (closed vs open vs expanded) | P1 | When transitioning from closed to expanded, interval decreases; vice versa |
| SM-020 | Stale data flagged and visually indicated | P1 | If Mach call fails, isStale=true; UI shows dimmed style for stale values |
| SM-021 | CPU closed state shows percentage with color coding | P1 | Green < 50%, yellow 50-80%, red > 80%; verified by snapshot test |
| SM-022 | RAM closed state shows used/total GB | P1 | Format: "X.X/Y.Y GB"; values match data point |
| SM-023 | Network closed state shows up/down speed with arrows | P1 | Format: "down-arrow speed  up-arrow speed"; "--" when disconnected |
| SM-024 | Battery closed state shows icon with fill level and bolt when charging | P1 | Icon fill matches level bracket; bolt visible iff isCharging==true |
| SM-025 | Expanded CPU view shows multi-core grid and process list | P2 | Grid has one entry per logical core; process list has exactly 5 rows |
| SM-026 | Expanded RAM view shows segmented donut chart | P2 | Chart segments: active, wired, compressed, inactive, free; segment sizes proportional to GB values |
| SM-027 | Expanded Network view shows live dual-axis speed graph | P2 | Graph updates each sample; X-axis = time, Y-axis = speed; two lines (download, upload) |
| SM-028 | Expanded Battery view shows health, cycle count, temperature | P2 | All three metrics displayed; "N/A" if unavailable |
| SM-029 | All monitors accessible via VoiceOver | P1 | Every displayed value has accessibilityValue; sparklines have trend summary label |
| SM-030 | Sample intervals configurable per monitor | P1 | Changing interval in settings takes effect within one sample period without restart |
| SM-031 | Monitors do not run when Niya app is in background with no visible widgets | P0 | Instruments trace: zero SystemMetric timer fires when app has no visible monitor widgets |
| SM-032 | Ring buffer capacity configurable | P2 | Changing capacity preserves most recent N entries; chart reflects new history length |

---

## 12. Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `host_processor_info` requires Mach port; sandboxed apps may lack entitlement | CPU monitor returns no data | Test in sandboxed build early; fall back to `host_statistics` aggregate if per-core blocked |
| IOKit battery keys vary across Mac models (desktop Macs have no battery) | Crash or nil dereference | Guard every key lookup; Battery monitor auto-disables on desktop Macs (detected via `IOServiceMatching("AppleSmartBattery")` returning nil) |
| `getifaddrs` byte counters wrap at UInt32 max on some interfaces | Speed calculation goes negative or astronomically high | Detect counter wrap (new < old) and skip that sample |
| High-frequency sampling (1s) on low-power Macs causes battery drain | User complaint | Default to 2s; document 1s as "high fidelity" option with battery impact warning |
| `proc_listallpids` requires elevated permissions in sandboxed app | Top processes list empty | Gate feature behind "Full Disk Access" or similar entitlement; show permission prompt in UI |
