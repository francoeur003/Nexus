import Foundation
import AppKit
import Darwin
import Combine
import OSLog
import IOKit
import IOKit.ps
import SystemConfiguration
import DiskArbitration

// MARK: - Types

struct ProcInfo: Identifiable {
    let id   = UUID()
    let pid:  Int
    let name: String
    let cpu:  Double
    let mem:  Int64
}

private struct CodexUsageSnapshot {
    var available = false
    var todayTokens: Int64 = 0
    var planType = "Codex"
    var fiveHourUsedPct: Double = 0
    var fiveHourResetAt: Date?
    var weeklyUsedPct: Double = 0
    var weeklyResetAt: Date?
    var rateLimitObservedAt: Date?
}

// MARK: - Model

class SystemStatsModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.francoeur003.Nexus", category: "metrics")

    // CPU
    @Published var cpuUsage:    Int     = 0
    @Published var perCoreCPU: [Double] = []
    @Published var eCoresPct:   Int     = 0
    @Published var pCoresPct:   Int     = 0
    @Published var eCoresMHz:   Int     = 0
    @Published var pCoresMHz:   Int     = 0
    @Published var cpuTemp:     Double  = 0
    @Published var cpuPower:    Double  = 0

    // GPU
    @Published var gpuUsage:    Int     = 0
    @Published var gpuMHz:      Int     = 0
    @Published var gpuTemp:     Double  = 0
    @Published var gpuPower:    Double  = 0

    // Power rails
    @Published var anePower:    Double  = 0
    @Published var dramPower:   Double  = 0
    @Published var sysPower:    Double  = 0
    @Published var totalPower:  Double  = 0
    @Published var dramBW:      Double  = 0

    // M5+ Super cluster (exposed so PopoverView can show it when present)
    @Published var sClusterPct: Int     = 0
    @Published var sClusterMHz: Int     = 0

    // Memory
    @Published var memUsed:     Int64   = 0
    @Published var memTotal:    Int64   = 0
    @Published var memPct:      Int     = 0
    @Published var memPctPrecise: Double = 0
    @Published var swapUsed:    Int64   = 0
    @Published var swapTotal:   Int64   = 0

    // Network
    @Published var netInBps:    Int64   = 0
    @Published var netOutBps:   Int64   = 0
    @Published var currentIP:   String  = "未连接"
    @Published var currentCountry: String = "查询中"

    // Disk
    @Published var diskReadKBs: Double  = 0
    @Published var diskWriteKBs:Double  = 0
    @Published var storageUsed: Int64   = 0
    @Published var storageTotal:Int64   = 0
    @Published var storagePct:  Int     = 0
    @Published var storagePctPrecise: Double = 0

    // Battery — every field
    @Published var batteryPct:       Int     = 0
    @Published var batteryCharging:  Bool    = false
    @Published var batteryCharged:   Bool    = false
    @Published var batteryOnAC:      Bool    = true
    @Published var batteryTimeLeft:  String  = "--:--"
    @Published var batteryTempC:     Double  = 0
    @Published var batteryCycles:    Int     = 0
    @Published var batteryHealthPct: Int     = 100
    @Published var batteryCurrentMAh:Int     = 0
    @Published var batteryMaxMAh:    Int     = 0
    @Published var batteryDesignMAh: Int     = 0
    @Published var adapterWatts:     Double  = 0
    @Published var chargingWatts:    Double  = 0
    @Published var chargerInputWatts:Double  = 0
    @Published var batteryChargeWatts:Double  = 0
    @Published var chargerInputHistory: [Double] = []
    @Published var chipPowerHistory: [Double] = []

    // System info
    @Published var thermalState: String = "正常"
    @Published var chipName:     String = "Apple Silicon"  // e.g. "M2", "M2 Pro", "M2 Max"
    @Published var eCoreCount:   Int    = 0
    @Published var pCoreCount:   Int    = 0
    @Published var gpuCoreCount: Int    = 0

    // Fan (0 = fanless model, e.g. MacBook Air)
    @Published var fanRPM:       Int    = 0
    @Published var fanReason:    String = "正在判断当前任务"
    @Published var fanReasons: [String] = ["正在判断当前任务"]
    @Published var fanStopAdvice: String = "暂不需要"

    // CPU die hotspot — TCMz, the absolute peak temperature on the CPU die.
    // This is the value TG Pro shows as "CPU Die (Hotspot)".
    @Published var cpuDieHotspot: Double = 0

    @Published var topProcs: [ProcInfo] = []
    @Published var nativeReady           = false
    @Published var helperMissing         = false

    // Hermes Agent local usage
    @Published var hermesUsageAvailable = false
    @Published var hermesTodayTokensText = "今日 -- tok"
    @Published var hermesTodayDurationText = "--"

    // Codex local usage / quota
    @Published var codexUsageAvailable   = false
    @Published var codexTodayTokensText  = "今日 --"
    @Published var codexPlanType         = "Codex"
    @Published var codexFiveHourRemainingPct = 0
    @Published var codexFiveHourResetText = "--"
    @Published var codexWeeklyRemainingPct = 0
    @Published var codexWeeklyResetText = "--"

    // Private
    private var smcConn: io_connect_t     = 0
    private var nativeMetricsInFlight     = false
    private var tickInFlight              = false
    private var batteryInFlight           = false
    private var batteryService: io_object_t = 0
    private var prevCPUTicks: [[UInt32]] = []
    private var prevNetIn:    Int64 = 0   // 0 = unseeded (skip first rate calc)
    private var prevNetOut:   Int64 = 0
    private var prevDiskReadBytes:  Int64 = 0
    private var prevDiskWriteBytes: Int64 = 0
    private var diskStatsService: io_registry_entry_t = 0
    private var diskSeeded            = false  // true after first diskCumulative sample
    private var diskInFlight          = false  // prevent concurrent ioreg calls piling up
    private var prevTickTime: Date  = Date()
    private var cachedTopProcs: [ProcInfo] = []
    private var cachedRankedRows: [(pid: Int, cpu: Double, mem: Double, command: String)] = []
    private var cachedHelperData: IOReportData?
    private var lastProcessSample = Date.distantPast
    private var lastHelperSample = Date.distantPast
    private var lastCountryIP = ""
    private var batterySampleCountdown    = 0
    private var timer: Timer?
    private var fastTimer: Timer?
    private var diskTimer: Timer?          // independent timer — keeps ioreg off samplerQueue
    private var hermesUsageTimer: Timer?
    private var codexUsageTimer: Timer?
    private var fastTickInFlight = false
    private var hermesUsageInFlight = false
    private var codexUsageInFlight = false
    private var codexUsageLastSignature = ""
    private var codexUsageSnapshotCache = CodexUsageSnapshot()
    private var codexUsageReadOffsets: [String: UInt64] = [:]
    private var codexUsageLatestRateLimitDate = Date.distantPast
    private var codexUsageLatestRateLimitPriority = -1
    private var codexUsageDay = Calendar.current.startOfDay(for: Date())
    private let samplerQueue = DispatchQueue(label: "com.francoeur003.Nexus.sampler", qos: .utility)
    private let lightSamplerQueue = DispatchQueue(label: "com.francoeur003.Nexus.lightSampler", qos: .userInitiated)
    private let lightSampleInterval: TimeInterval = 1.0
    private let mainSampleInterval: TimeInterval = 1.0
    private let diskSampleInterval: TimeInterval = 3.0
    private let batterySampleEveryTicks = 1
    private static let codexUsageRecentDays = 7
    private static let codexUsageFileLimit = 80
    private let debugMetricsLogging = false
    private let helperPath = "/Users/Shared/Nexus/nexus-helper"
    private let helperSudoersPath = "/etc/sudoers.d/nexus-helper"
    private var helperBootstrapInFlight = false
    private var countryFetchInFlight = false
    private var lastCountryFetch = Date.distantPast

    private func publishIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SystemStatsModel, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func publishIfChanged(_ keyPath: ReferenceWritableKeyPath<SystemStatsModel, Double>, _ value: Double, tolerance: Double = 0.05) {
        if abs(self[keyPath: keyPath] - value) >= tolerance {
            self[keyPath: keyPath] = value
        }
    }

    private func publishCoresIfChanged(_ values: [Double]) {
        guard perCoreCPU.count == values.count else {
            perCoreCPU = values
            return
        }
        for (old, new) in zip(perCoreCPU, values) where abs(old - new) >= 1 {
            perCoreCPU = values
            return
        }
    }

    // MARK: - Start

    func startMonitoring() {
        smcConn = SMCOpen()
        _ = sampleCPU()      // fast Mach call — OK on main thread
        prevTickTime = Date()

        fastTimer = Timer.scheduledTimer(withTimeInterval: lightSampleInterval, repeats: true) { [weak self] _ in
            self?.fastTick()
        }
        fastTick()

        // Start the main tick timer immediately — app is responsive at launch.
        timer = Timer.scheduledTimer(withTimeInterval: mainSampleInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Disk I/O is sampled via ioreg which can take 1-5+ seconds.
        // Run it on its own independent timer so it NEVER blocks samplerQueue.
        // First sample seeds the baseline (shows 0 rate).
        diskTimer = Timer.scheduledTimer(withTimeInterval: diskSampleInterval, repeats: true) { [weak self] _ in
            self?.tickDisk()
        }
        tickDisk()   // seed immediately (async, doesn't block)

        hermesUsageTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshHermesUsage()
        }
        refreshHermesUsage()

        codexUsageTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.refreshCodexUsage()
        }
        refreshCodexUsage(force: true)

        // Static system info (includes one ioreg call for GPU core count).
        // Run on a background queue so it doesn't block samplerQueue either.
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.loadStaticSystemInfo()
        }

        ensurePrivilegedHelperAccess()
        refreshCountryIfNeeded(force: true)
        fetchNativeMetrics()
        fetchBattery()
    }

    // MARK: - Tick

    private func fastTick() {
        guard !fastTickInFlight else { return }
        fastTickInFlight = true

        lightSamplerQueue.async { [weak self] in
            guard let self = self else { return }
            let (cpu, cores) = self.sampleCPU()
            let (mUsed, mTot) = self.sampleMemory()
            let storage = Self.sampleStorage()
            let (ni, no) = Self.netInterfaceCounters()
            let dt = max(Date().timeIntervalSince(self.prevTickTime), 0.001)
            let netSeeded = self.prevNetIn > 0
            let rawInDelta = ni - self.prevNetIn
            let rawOutDelta = no - self.prevNetOut
            let maxPhysicalDelta = Int64(2_000_000_000 * dt)
            let cleanInDelta = (rawInDelta >= 0 && rawInDelta <= maxPhysicalDelta) ? rawInDelta : 0
            let cleanOutDelta = (rawOutDelta >= 0 && rawOutDelta <= maxPhysicalDelta) ? rawOutDelta : 0
            let inBps = netSeeded ? Int64(Double(cleanInDelta) / dt) : 0
            let outBps = netSeeded ? Int64(Double(cleanOutDelta) / dt) : 0
            self.prevNetIn = ni
            self.prevNetOut = no
            self.prevTickTime = Date()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.publishIfChanged(\.cpuUsage, Int(cpu.rounded()))
                self.publishCoresIfChanged(cores)
                self.publishIfChanged(\.memUsed, mUsed)
                self.publishIfChanged(\.memTotal, mTot)
                let memPrecise = mTot > 0 ? Double(mUsed) * 100 / Double(mTot) : 0
                self.publishIfChanged(\.memPctPrecise, memPrecise)
                self.publishIfChanged(\.memPct, Int(memPrecise.rounded()))
                self.publishIfChanged(\.storageUsed, storage.used)
                self.publishIfChanged(\.storageTotal, storage.total)
                self.publishIfChanged(\.storagePct, storage.pct)
                self.publishIfChanged(\.storagePctPrecise, storage.total > 0 ? Double(storage.used) * 100 / Double(storage.total) : Double(storage.pct))
                self.publishIfChanged(\.netInBps, max(0, inBps))
                self.publishIfChanged(\.netOutBps, max(0, outBps))
                self.publishIfChanged(\.currentIP, Self.currentIPv4Address())
                self.fastTickInFlight = false
            }
        }
    }

    private func tick() {
        guard !tickInFlight else { return }
        tickInFlight = true

        samplerQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async { self.tickInFlight = false }
            }

            let (sUsed, sTot) = self.sampleSwap()

            // Disk I/O is handled by diskTimer (every 6 s) on a background queue
            // to avoid ioreg blocking samplerQueue. Nothing to do here.

            self.batterySampleCountdown -= 1
            let shouldFetchBattery = self.batterySampleCountdown <= 0
            if shouldFetchBattery { self.batterySampleCountdown = self.batterySampleEveryTicks }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.publishIfChanged(\.swapUsed, sUsed)
                self.publishIfChanged(\.swapTotal, sTot)
                self.publishIfChanged(\.thermalState, Self.currentThermalState())
            }

            self.fetchNativeMetrics()
            self.refreshCountryIfNeeded()
            if shouldFetchBattery { self.fetchBattery() }
        }
    }

    // MARK: - Disk I/O (independent timer — never blocks samplerQueue)

    // Called from diskTimer on the main thread every few seconds.
    // Runs ioreg on a global background queue so samplerQueue stays clean.
    // All disk state is written on the main thread only.
    private func tickDisk() {
        // Guard: ioreg can take longer than the timer interval.
        // Without this, concurrent ioreg processes pile up and waste CPU/memory.
        guard !diskInFlight else { return }
        diskInFlight = true

        let prevRead  = prevDiskReadBytes
        let prevWrite = prevDiskWriteBytes
        let seeded    = diskSeeded
        diskSeeded = true   // mark seeded so next call computes a delta

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let (readBytes, writeBytes) = self.diskCumulative()
            // First call seeds baseline — show 0 so we don't display boot-time totals.
            let readKBs  = seeded ? max(0, Double(readBytes  - prevRead)  / self.diskSampleInterval / 1024.0) : 0
            let writeKBs = seeded ? max(0, Double(writeBytes - prevWrite) / self.diskSampleInterval / 1024.0) : 0
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.prevDiskReadBytes  = readBytes
                self.prevDiskWriteBytes = writeBytes
                self.publishIfChanged(\.diskReadKBs, readKBs, tolerance: 1)
                self.publishIfChanged(\.diskWriteKBs, writeKBs, tolerance: 1)
                self.diskInFlight       = false
            }
        }
    }

    // MARK: - CPU (Mach kernel)

    private func sampleCPU() -> (Double, [Double]) {
        var numCPUs:   natural_t               = 0
        var rawInfo:   processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t  = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &rawInfo, &infoCount) == KERN_SUCCESS,
              let rawInfo = rawInfo else { return (0, []) }

        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: rawInfo),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let n = Int(numCPUs)
        var cur = [[UInt32]](repeating: [0,0,0,0], count: n)
        for i in 0..<n {
            let b = i * Int(CPU_STATE_MAX)
            cur[i][0] = UInt32(bitPattern: rawInfo[b + Int(CPU_STATE_USER)])
            cur[i][1] = UInt32(bitPattern: rawInfo[b + Int(CPU_STATE_SYSTEM)])
            cur[i][2] = UInt32(bitPattern: rawInfo[b + Int(CPU_STATE_IDLE)])
            cur[i][3] = UInt32(bitPattern: rawInfo[b + Int(CPU_STATE_NICE)])
        }

        var perCore = [Double](); var sumUsed = 0.0; var sumTotal = 0.0
        for i in 0..<n {
            let p = prevCPUTicks.count > i ? prevCPUTicks[i] : [0,0,0,0]
            let user = Double(cur[i][0] &- p[0])
            let sys  = Double(cur[i][1] &- p[1])
            let idle = Double(cur[i][2] &- p[2])
            let nice = Double(cur[i][3] &- p[3])
            let all  = user + sys + idle + nice
            let used = user + sys + nice
            perCore.append(all > 0 ? (used / all * 100) : 0)
            sumUsed += used; sumTotal += all
        }
        prevCPUTicks = cur
        return (sumTotal > 0 ? sumUsed / sumTotal * 100 : 0, perCore)
    }

    // MARK: - Memory (Mach kernel)

    private func sampleMemory() -> (used: Int64, total: Int64) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard kr == KERN_SUCCESS else { return (0, total) }
        let page  = Int64(vm_kernel_page_size)
        let used  = (Int64(stats.active_count) + Int64(stats.wire_count)
                   + Int64(stats.compressor_page_count)) * page
        return (min(max(used, 0), total), total)
    }

    private func sampleSwap() -> (used: Int64, total: Int64) {
        let output = shell("/usr/sbin/sysctl", ["vm.swapusage"])
        let total = Self.firstSizeMatch(in: output, pattern: #"total = ([0-9.]+[KMGTP]i?)"#)
        let used = Self.firstSizeMatch(in: output, pattern: #"used = ([0-9.]+[KMGTP]i?)"#)
        return (used, total)
    }

    // MARK: - Network cumulative

    private static func netInterfaceCounters() -> (rx: Int64, tx: Int64) {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return (0, 0) }
        defer { freeifaddrs(interfaces) }

        var rx: Int64 = 0
        var tx: Int64 = 0
        let primary = primaryNetworkInterface()
        var fallbackRX: Int64 = 0
        var fallbackTX: Int64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = current.pointee.ifa_data else { continue }

            let name = String(cString: current.pointee.ifa_name)
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            let inBytes = Int64(counters.ifi_ibytes)
            let outBytes = Int64(counters.ifi_obytes)

            if !primary.isEmpty, name == primary {
                rx += inBytes
                tx += outBytes
            } else if primary.isEmpty, name.hasPrefix("en") {
                fallbackRX += inBytes
                fallbackTX += outBytes
            }
        }

        return (rx > 0 || tx > 0) ? (rx, tx) : (fallbackRX, fallbackTX)
    }

    private func diskCumulative() -> (readBytes: Int64, writeBytes: Int64) {
        if diskStatsService == 0 {
            diskStatsService = Self.rootDiskStatsService()
        }

        guard diskStatsService != 0,
              let props = Self.ioRegistryProperties(diskStatsService),
              let stats = props["Statistics"] as? [String: Any] else {
            diskStatsService = 0
            return (0, 0)
        }

        let read = (stats["Bytes (Read)"] as? NSNumber)?.int64Value ?? stats["Bytes (Read)"] as? Int64 ?? 0
        let write = (stats["Bytes (Write)"] as? NSNumber)?.int64Value ?? stats["Bytes (Write)"] as? Int64 ?? 0
        return (read, write)
    }

    // MARK: - Battery (IOKit power sources + AppleSmartBattery)

    private func readChargerInputWattsFast() -> Double {
        if batteryService == 0 {
            batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        }
        guard batteryService != 0 else { return 0 }

        func registryValue(_ key: String) -> Any? {
            guard let value = IORegistryEntryCreateCFProperty(batteryService, key as CFString, kCFAllocatorDefault, 0) else {
                return nil
            }
            return value.takeRetainedValue()
        }

        if let telemetry = registryValue("PowerTelemetryData") as? [String: Any],
           let inputMW = Self.number(telemetry["SystemPowerIn"])?.doubleValue,
           inputMW > 0 {
            return inputMW / 1000.0
        }

        let voltageMV = Self.number(registryValue("Voltage"))?.doubleValue ?? 0
        let amperageMA = abs(Self.number(registryValue("Amperage"))?.doubleValue ?? 0)
        let watts = (voltageMV / 1000.0) * (amperageMA / 1000.0)
        return watts.isFinite && watts > 0 ? watts : 0
    }

    private func fetchBattery() {
        guard !batteryInFlight else { return }
        batteryInFlight = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async { self.batteryInFlight = false }
            }

            if self.batteryService == 0 {
                self.batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            }

            func registryValue(_ key: String) -> Any? {
                guard self.batteryService != 0,
                      let value = IORegistryEntryCreateCFProperty(self.batteryService, key as CFString, kCFAllocatorDefault, 0) else {
                    return nil
                }
                return value.takeRetainedValue()
            }

            func ioInt(_ key: String) -> Int {
                if let n = registryValue(key) as? NSNumber { return n.intValue }
                if let n = registryValue(key) as? Int { return n }
                return 0
            }

            func ioBool(_ key: String) -> Bool {
                if let b = registryValue(key) as? Bool { return b }
                if let n = registryValue(key) as? NSNumber { return n.boolValue }
                return false
            }

            func ioDict(_ key: String) -> [String: Any] {
                registryValue(key) as? [String: Any] ?? [:]
            }

            let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
            let powerSource = psList.compactMap {
                IOPSGetPowerSourceDescription(psInfo, $0)?.takeUnretainedValue() as? [String: Any]
            }.first ?? [:]

            let source = powerSource[kIOPSPowerSourceStateKey as String] as? String ?? "AC Power"
            let onAC = source == kIOPSACPowerValue
            let charging = ioBool("IsCharging")
            let charged = (powerSource[kIOPSIsChargedKey as String] as? Bool) ?? false
            let pct = powerSource[kIOPSCurrentCapacityKey as String] as? Int ?? ioInt("CurrentCapacity")
            let minutesToEmpty = powerSource[kIOPSTimeToEmptyKey as String] as? Int ?? -1
            let minutesToFull = powerSource[kIOPSTimeToFullChargeKey as String] as? Int ?? -1
            let rawMinutes = charging ? minutesToFull : minutesToEmpty
            let timeLeft = rawMinutes >= 0 ? String(format: "%d:%02d", rawMinutes / 60, rawMinutes % 60) : "--:--"

            let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
            let adWatts = Double((adapterDetails?[kIOPSPowerAdapterWattsKey as String] as? Int)
                                 ?? (adapterDetails?["Watts"] as? Int)
                                 ?? 0)

            let cycles  = ioInt("CycleCount")
            // MaxCapacity and CurrentCapacity are percentages (0–100), NOT mAh.
            // AppleRawMaxCapacity and AppleRawCurrentCapacity are the actual mAh values.
            // NominalChargeCapacity is the learned full-charge capacity in mAh.
            // DesignCapacity is the factory-rated capacity in mAh.
            let rawMaxCap  = ioInt("AppleRawMaxCapacity")   // mAh — actual full-charge capacity
            let nomCap     = ioInt("NominalChargeCapacity") // mAh — fallback for maxCap
            let desCap     = ioInt("DesignCapacity")        // mAh — factory rated
            let rawCurCap  = ioInt("AppleRawCurrentCapacity") // mAh — actual current charge
            // Use AppleRawMaxCapacity if available; fall back to NominalChargeCapacity.
            let maxCapMAh  = rawMaxCap > 0 ? rawMaxCap : nomCap
            let rawTemp = ioInt("Temperature")           // in 0.01°C
            let battTemp = Double(rawTemp) / 100.0

            // Charging current (mA) × voltage (mV) → watts
            let voltage    = Double(ioInt("Voltage")) / 1000.0        // V
            let amperage   = abs(Double(ioInt("Amperage"))) / 1000.0  // A
            let batteryWattsFromCurrent = voltage * amperage
            let telemetry = ioDict("PowerTelemetryData")
            let telemetryBatteryMW = (telemetry["BatteryPower"] as? NSNumber)?.intValue ?? ioInt("BatteryPower")
            let telemetryInputMW = (telemetry["SystemPowerIn"] as? NSNumber)?.intValue ?? ioInt("SystemPowerIn")
            let rawChrgWatts = telemetryBatteryMW > 0
                ? Double(telemetryBatteryMW) / 1000.0
                : batteryWattsFromCurrent
            let rawInputWatts = telemetryInputMW > 0
                ? Double(telemetryInputMW) / 1000.0
                : rawChrgWatts
            let chrgWatts = onAC ? rawChrgWatts : 0
            let inputWatts = onAC ? rawInputWatts : 0

            let health = desCap > 0 ? Int(Double(maxCapMAh) / Double(desCap) * 100) : 100

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.publishIfChanged(\.batteryPct, pct)
                self.publishIfChanged(\.batteryCharging, charging)
                self.publishIfChanged(\.batteryCharged, charged)
                self.publishIfChanged(\.batteryOnAC, onAC)
                self.publishIfChanged(\.batteryTimeLeft, timeLeft)
                self.publishIfChanged(\.batteryTempC, battTemp)
                self.publishIfChanged(\.batteryCycles, cycles)
                self.publishIfChanged(\.batteryHealthPct, min(100, health))
                self.publishIfChanged(\.batteryCurrentMAh, rawCurCap)
                self.publishIfChanged(\.batteryMaxMAh, maxCapMAh)
                self.publishIfChanged(\.batteryDesignMAh, desCap)
                self.publishIfChanged(\.adapterWatts, adWatts, tolerance: 0.5)
                self.publishIfChanged(\.chargingWatts, chrgWatts, tolerance: 0.3)
                self.publishIfChanged(\.batteryChargeWatts, chrgWatts, tolerance: 0.3)
                self.publishIfChanged(\.chargerInputWatts, inputWatts, tolerance: 0.05)
            }
        }
    }

    // MARK: - Native GPU / Temps / Clusters / Power

    private func fetchNativeMetrics() {
        guard !nativeMetricsInFlight else { return }
        nativeMetricsInFlight = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.nativeMetricsInFlight = false } }

            let nativeData = IOReportWrapper.fetchIOReportData(withSMC: self.smcConn)
            let nativeHasCoreMetrics = nativeData.cpuTemp > 0
                || nativeData.cpuPower > 0
                || nativeData.gpuPower > 0
                || nativeData.fanRPM > 0
            if !nativeHasCoreMetrics && Date().timeIntervalSince(self.lastHelperSample) > 10 {
                self.cachedHelperData = self.fetchHelperMetrics()
                self.lastHelperSample = Date()
            }
            let pData = self.mergeMetrics(primary: nativeData, fallback: self.cachedHelperData ?? nativeData)
            let sysP = SMCGetFloatValue(self.smcConn, "PSTR")
            let chargerInputWatts = self.readChargerInputWattsFast()
            if Date().timeIntervalSince(self.lastProcessSample) > 8 || self.cachedTopProcs.isEmpty {
                self.cachedTopProcs = self.sampleTopProcesses()
                self.cachedRankedRows = self.rankedProcessRows()
                self.lastProcessSample = Date()
            }
            let fanDetails = self.inferFanDetails(
                fanRPM: Int(pData.fanRPM),
                metrics: pData,
                rows: self.cachedRankedRows
            )
            if self.debugMetricsLogging {
                fputs("[metrics] cpuTemp=\(pData.cpuTemp) gpuTemp=\(pData.gpuTemp) cpuPow=\(pData.cpuPower) gpuPow=\(pData.gpuPower) gpuPct=\(pData.gpuUsage) gpuMHz=\(pData.gpuFreqMHz) ePct=\(pData.eClusterActive) eMHz=\(pData.eClusterFreqMHz) pPct=\(pData.pClusterActive) pMHz=\(pData.pClusterFreqMHz) dramR=\(pData.dramReadBytes) dramW=\(pData.dramWriteBytes)\n", stderr)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if pData.cpuTemp > 0 { self.publishIfChanged(\.cpuTemp, pData.cpuTemp, tolerance: 1.0) }
                if pData.cpuDieHotspot > 0 { self.publishIfChanged(\.cpuDieHotspot, pData.cpuDieHotspot, tolerance: 1.0) }
                if pData.gpuTemp > 0 { self.publishIfChanged(\.gpuTemp, pData.gpuTemp, tolerance: 1.0) }
                let nextFanRPM = Int(pData.fanRPM)
                if abs(self.fanRPM - nextFanRPM) >= 50 {
                    self.fanRPM = nextFanRPM
                }
                self.publishIfChanged(\.fanReason, fanDetails.reasons.first ?? "正在判断当前任务")
                self.publishIfChanged(\.fanReasons, fanDetails.reasons)
                self.publishIfChanged(\.fanStopAdvice, fanDetails.stopAdvice)
                
                self.publishIfChanged(\.cpuPower, pData.cpuPower, tolerance: 0.3)
                self.publishIfChanged(\.gpuPower, pData.gpuPower, tolerance: 0.2)
                self.publishIfChanged(\.anePower, pData.anePower, tolerance: 0.1)
                self.publishIfChanged(\.dramPower, pData.dramPower, tolerance: 0.2)
                // systemPower: prefer SMC PSTR (wall input power); IOReport doesn't expose it
                let nextSysPower = sysP > 0 ? sysP : (pData.systemPower > 0 ? pData.systemPower : 0)
                let nextTotalPower = pData.cpuPower + pData.gpuPower + pData.anePower + pData.dramPower
                self.publishIfChanged(\.sysPower, nextSysPower, tolerance: 0.5)
                self.publishIfChanged(\.totalPower, nextTotalPower, tolerance: 0.05)
                self.chipPowerHistory = self.history(self.chipPowerHistory, adding: nextTotalPower)
                let nextChargerInputWatts = self.batteryOnAC
                    ? (chargerInputWatts > 0 ? chargerInputWatts : self.chargerInputWatts)
                    : 0
                self.publishIfChanged(\.chargerInputWatts, nextChargerInputWatts, tolerance: 0.05)
                self.chargerInputHistory = self.history(self.chargerInputHistory, adding: max(0, nextChargerInputWatts))

                self.publishIfChanged(\.gpuUsage, Int(pData.gpuUsage.rounded()))
                self.publishIfChanged(\.gpuMHz, Int(pData.gpuFreqMHz))
                self.publishIfChanged(\.eCoresPct, Int(pData.eClusterActive.rounded()))
                self.publishIfChanged(\.pCoresPct, Int(pData.pClusterActive.rounded()))
                self.publishIfChanged(\.eCoresMHz, Int(pData.eClusterFreqMHz))
                self.publishIfChanged(\.pCoresMHz, Int(pData.pClusterFreqMHz))
                self.publishIfChanged(\.sClusterPct, Int(pData.sClusterActive.rounded()))
                self.publishIfChanged(\.sClusterMHz, Int(pData.sClusterFreqMHz))

                // DRAM bandwidth: bytes transferred / sample interval (0.1 s) → GB/s
                let totalDramBytes = pData.dramReadBytes + pData.dramWriteBytes
                self.publishIfChanged(\.dramBW, Double(totalDramBytes) / 0.1 / 1_000_000_000, tolerance: 0.1)

                if self.topProcs.map(\.pid) != self.cachedTopProcs.map(\.pid) {
                    self.topProcs = self.cachedTopProcs
                }

                self.publishIfChanged(\.nativeReady, true)
                self.publishIfChanged(\.helperMissing, false)
            }
        }
    }

    private func sampleTopProcesses() -> [ProcInfo] {
        let out = shell("/bin/ps", ["-axo", "%cpu,rss,pid,comm", "-r"])
        var results: [ProcInfo] = []
        let lines = out.split(separator: "\n").dropFirst() // Skip header
        
        for line in lines.prefix(12) {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4 else { continue }
            
            let cpu   = Double(parts[0]) ?? 0
            let rssKB = Int64(parts[1]) ?? 0
            let pid   = Int(parts[2]) ?? 0
            let path  = String(parts[3])
            let name  = (path as NSString).lastPathComponent
            
            if name == "kernel_task" || name.lowercased().contains("nexus") { continue }
            
            results.append(ProcInfo(
                pid: pid,
                name: name,
                cpu: cpu,
                mem: rssKB * 1024
            ))
        }
        return Array(results.prefix(8))
    }

    private func inferFanReason(fanRPM: Int, metrics: IOReportData) -> String {
        inferFanDetails(fanRPM: fanRPM, metrics: metrics, rows: cachedRankedRows).reasons.first ?? "正在判断当前任务"
    }

    private func inferFanDetails(
        fanRPM: Int,
        metrics: IOReportData,
        rows: [(pid: Int, cpu: Double, mem: Double, command: String)]
    ) -> (reasons: [String], stopAdvice: String) {
        let candidates = rows.filter { row in
            row.cpu >= 8 && !row.command.localizedCaseInsensitiveContains("nexus")
        }

        var reasons: [String] = []
        for row in candidates.prefix(6) {
            let reason = classifyTask(command: row.command, cpu: row.cpu)
                ?? "主要负载：\(processDisplayName(from: row.command)) · \(String(format: "%.0f", row.cpu))% CPU"
            if !reasons.contains(reason) {
                reasons.append(reason)
            }
            if reasons.count >= 3 { break }
        }

        if metrics.gpuUsage >= 35 {
            reasons.append("图形处理器负载：\(String(format: "%.0f", metrics.gpuUsage))%，可能是视频/生图/窗口渲染")
        }
        if metrics.cpuDieHotspot >= 85 || metrics.cpuTemp >= 75 {
            reasons.append("温度触发散热：CPU \(String(format: "%.0f", metrics.cpuTemp))°C，热点 \(String(format: "%.0f", metrics.cpuDieHotspot))°C")
        }
        if reasons.isEmpty {
            if fanRPM >= 2500 {
                reasons.append("系统散热巡航：未发现明显高占用应用")
            } else {
                reasons.append("低速散热：当前没有明显重负载任务")
            }
        }

        let stopAdvice = forceStopAdvice(fanRPM: fanRPM, metrics: metrics, candidates: candidates)
        return (Array(reasons.prefix(4)), stopAdvice)
    }

    private func forceStopAdvice(
        fanRPM: Int,
        metrics: IOReportData,
        candidates: [(pid: Int, cpu: Double, mem: Double, command: String)]
    ) -> String {
        guard let top = candidates.first else {
            return fanRPM >= 3500 ? "不建议：未定位到高占用用户任务" : "暂不需要"
        }

        let lower = top.command.lowercased()
        let name = processDisplayName(from: top.command)
        if containsAny(lower, ["kernel_task", "windowserver", "launchd", "pmset", "trustd", "syspolicyd", "mds", "mdworker"]) {
            return "不建议：主要是系统进程"
        }
        if containsAny(lower, ["topaz", "tvai", "ffmpeg", "comfyui", "stable-diffusion", "python", "final cut", "resolve", "premiere", "capcut", "jianying"]) {
            if metrics.cpuDieHotspot >= 105 || fanRPM >= 5200 {
                return "可暂停：温度很高，先停重任务降温"
            }
            return "不建议强停：\(name) 仍在跑任务，卡死再停"
        }
        if top.cpu >= 80 || metrics.cpuDieHotspot >= 105 {
            return "可考虑停止：\(name)"
        }
        return "暂不需要"
    }

    private func rankedProcessRows() -> [(pid: Int, cpu: Double, mem: Double, command: String)] {
        let out = shell("/bin/ps", ["-axo", "pid=,%cpu=,%mem=,command=", "-r"])
        var rows: [(pid: Int, cpu: Double, mem: Double, command: String)] = []
        for line in out.split(separator: "\n").prefix(60) {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2])
            else { continue }
            let command = String(parts[3])
            rows.append((pid: pid, cpu: cpu, mem: mem, command: command))
        }
        return rows
    }

    private func classifyTask(command: String, cpu: Double) -> String? {
        let lower = command.lowercased()
        let cpuText = String(format: "%.0f", cpu)

        if containsAny(lower, ["topaz", "video ai", "tvai", "proteus", "iris", "artemis", "gaia", "seedvr", "realesrgan", "real-esrgan", "upscayl", "waifu2x", "video2x"]) {
            return "运行升画质：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if lower.contains("ffmpeg") {
            if containsAny(lower, ["scale", "zscale", "upscale", "realesrgan", "libx265", "hevc", "prores", "videotoolbox"]) {
                return "运行视频升画质/转码：ffmpeg · \(cpuText)% CPU"
            }
            return "运行视频处理：ffmpeg · \(cpuText)% CPU"
        }
        if containsAny(lower, ["comfyui", "stable-diffusion", "automatic1111", "sd-webui", "invokeai", "swarmui", "diffusers", "flux", "sdxl", "kohya", "controlnet"]) {
            return "运行生图：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if lower.contains("python") && containsAny(lower, ["comfy", "diffusion", "flux", "sdxl", "stable", "generate", "image", "txt2img", "img2img"]) {
            return "运行生图脚本：\(pythonScriptName(from: command)) · \(cpuText)% CPU"
        }
        if containsAny(lower, ["wan", "seedance", "hunyuan", "ltx", "cogvideo", "kling", "veo"]) {
            return "运行视频生成：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if containsAny(lower, ["final cut", "davinci", "resolve", "premiere", "after effects", "capcut", "jianying", "剪映"]) {
            return "运行剪辑/渲染：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if lower.contains("auto_file_organizer") {
            return "运行文件整理脚本：auto_file_organizer · \(cpuText)% CPU"
        }
        if lower.contains("codex") {
            return "运行 Codex：界面渲染/代码任务 · \(cpuText)% CPU"
        }
        if lower.contains("windowserver") {
            return "当前窗口渲染：\(frontmostAppName()) · WindowServer \(cpuText)% CPU"
        }
        if containsAny(lower, ["chrome", "safari", "wechat", "electron", "renderer", "gpu-process"]) {
            return "前台应用渲染：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if containsAny(lower, ["mds", "mdworker", "corespotlight", "photoanalysis", "cloudphotod"]) {
            return "系统索引/照片分析：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        if containsAny(lower, ["duetexpertd", "syspolicyd", "trustd", "pmset"]) {
            return "系统后台任务：\(processDisplayName(from: command)) · \(cpuText)% CPU"
        }
        return nil
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func processDisplayName(from command: String) -> String {
        let first = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? command
        let name = (first as NSString).lastPathComponent
        if name == "Python" || name == "python" || name.hasPrefix("python") {
            return pythonScriptName(from: command)
        }
        return name.replacingOccurrences(of: ".app", with: "")
    }

    private func pythonScriptName(from command: String) -> String {
        for token in command.split(separator: " ") {
            if token.hasSuffix(".py") {
                return (String(token) as NSString).lastPathComponent
            }
        }
        return "Python"
    }

    private func frontmostAppName() -> String {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "前台应用"
        return name == "Nexus" ? "前台应用" : name
    }

    private func fetchHelperMetrics() -> IOReportData? {
        let execOK = FileManager.default.isExecutableFile(atPath: helperPath)
        if debugMetricsLogging {
            fputs("[helper] isExecutable=\(execOK) path=\(helperPath)\n", stderr)
        }
        guard execOK else { return nil }

        // IOReport does not require root on Apple Silicon; try direct execution first.
        // Fall back to sudo -n (requires a pre-installed sudoers entry) if direct fails.
        var helperResult = shellResult(helperPath, [])
        if debugMetricsLogging {
            fputs("[helper] direct status=\(helperResult.status) outLen=\(helperResult.stdout.count) err=\(helperResult.stderr)\n", stderr)
        }
        if helperResult.status != 0 {
            helperResult = shellResult("/usr/bin/sudo", ["-n", helperPath])
            if debugMetricsLogging {
                fputs("[helper] sudo status=\(helperResult.status) outLen=\(helperResult.stdout.count)\n", stderr)
            }
        }
        guard helperResult.status == 0 else {
            if debugMetricsLogging {
                fputs("[helper] FAILED status=\(helperResult.status) err=\(helperResult.stderr)\n", stderr)
            }
            return nil
        }

        let output = helperResult.stdout
        if debugMetricsLogging {
            fputs("[helper] raw output prefix=\(output.prefix(120))\n", stderr)
        }
        guard let data = output.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if debugMetricsLogging {
                fputs("[helper] JSON parse failed output=\(output.prefix(200))\n", stderr)
            }
            return nil
        }

        if debugMetricsLogging {
            fputs("[helper] parsed keys=\(payload.keys.sorted())\n", stderr)
        }

        // JSONSerialization returns all numbers as NSNumber. Use .doubleValue / .intValue
        // instead of `as? Int32` / `as? Int64` — those fail when the NSNumber's underlying
        // ObjC type doesn't match exactly (e.g., integer JSON values stored as 64-bit long).
        func dbl(_ key: String) -> Double { (payload[key] as? NSNumber)?.doubleValue ?? 0 }
        func i32(_ key: String) -> Int32  { (payload[key] as? NSNumber).map { Int32($0.intValue) } ?? 0 }
        func i64(_ key: String) -> Int64  { (payload[key] as? NSNumber).map { Int64($0.int64Value) } ?? 0 }

        var result = IOReportData()
        result.cpuTemp         = dbl("cpuTemp")
        result.cpuDieHotspot   = dbl("cpuDieHotspot")
        result.gpuTemp         = dbl("gpuTemp")
        result.cpuPower        = dbl("cpuPower")
        result.gpuPower        = dbl("gpuPower")
        result.anePower        = dbl("anePower")
        result.dramPower       = dbl("dramPower")
        result.systemPower     = dbl("systemPower")
        result.gpuUsage        = dbl("gpuUsage")
        result.gpuFreqMHz      = i32("gpuFreqMHz")
        result.eClusterActive  = dbl("eClusterActive")
        result.pClusterActive  = dbl("pClusterActive")
        result.eClusterFreqMHz = i32("eClusterFreqMHz")
        result.pClusterFreqMHz = i32("pClusterFreqMHz")
        result.dramReadBytes   = i64("dramReadBytes")
        result.dramWriteBytes  = i64("dramWriteBytes")
        result.fanRPM          = i32("fanRPM")
        return result
    }

    private func ensurePrivilegedHelperAccess() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            guard FileManager.default.isExecutableFile(atPath: self.helperPath) else {
                Self.logger.error("helper missing at \(self.helperPath, privacy: .public)")
                return
            }
            guard !self.helperBootstrapInFlight else { return }

            let directProbe = self.shellResult(self.helperPath, [])
            if directProbe.status == 0 {
                Self.logger.debug("helper works without sudo")
                return
            }

            let probe = self.shellResult("/usr/bin/sudo", ["-n", self.helperPath])
            if probe.status == 0 {
                Self.logger.debug("helper already authorized")
                return
            }

            self.helperBootstrapInFlight = true
            defer { self.helperBootstrapInFlight = false }

            Self.logger.notice("requesting one-time administrator approval for helper access")
            let user = NSUserName()
            let sudoersLine = Self.shellSingleQuote("\(user) ALL=(root) NOPASSWD: \(self.helperPath)")
            let command = "/bin/mkdir -p /etc/sudoers.d && /usr/bin/printf '%s\\n' \(sudoersLine) > \(self.helperSudoersPath) && /bin/chmod 440 \(self.helperSudoersPath) && /usr/sbin/visudo -cf \(self.helperSudoersPath)"
            let script = "do shell script \(Self.appleScriptLiteral(command)) with administrator privileges"
            let setup = self.shellResult("/usr/bin/osascript", ["-e", script])

            if setup.status == 0 {
                Self.logger.notice("helper sudoers rule installed successfully")
            } else {
                Self.logger.error("helper bootstrap failed status=\(setup.status) stderr=\(setup.stderr, privacy: .public)")
            }
        }
    }

    private func mergeMetrics(primary: IOReportData?, fallback: IOReportData) -> IOReportData {
        guard let primary = primary else { return fallback }

        var merged = fallback
        if primary.cpuTemp > 0        { merged.cpuTemp        = primary.cpuTemp }
        if primary.gpuTemp > 0        { merged.gpuTemp        = primary.gpuTemp }
        if primary.cpuPower > 0       { merged.cpuPower       = primary.cpuPower }
        if primary.gpuPower > 0       { merged.gpuPower       = primary.gpuPower }
        if primary.anePower > 0       { merged.anePower       = primary.anePower }
        if primary.dramPower > 0      { merged.dramPower      = primary.dramPower }
        if primary.systemPower > 0    { merged.systemPower    = primary.systemPower }
        if primary.gpuUsage > 0       { merged.gpuUsage       = primary.gpuUsage }
        if primary.gpuFreqMHz > 0     { merged.gpuFreqMHz     = primary.gpuFreqMHz }
        if primary.eClusterActive > 0 { merged.eClusterActive = primary.eClusterActive }
        if primary.pClusterActive > 0 { merged.pClusterActive = primary.pClusterActive }
        if primary.eClusterFreqMHz > 0 { merged.eClusterFreqMHz = primary.eClusterFreqMHz }
        if primary.pClusterFreqMHz > 0 { merged.pClusterFreqMHz = primary.pClusterFreqMHz }
        if primary.sClusterActive > 0 { merged.sClusterActive = primary.sClusterActive }
        if primary.sClusterFreqMHz > 0 { merged.sClusterFreqMHz = primary.sClusterFreqMHz }
        if primary.dramReadBytes > 0   { merged.dramReadBytes   = primary.dramReadBytes }
        if primary.dramWriteBytes > 0  { merged.dramWriteBytes  = primary.dramWriteBytes }
        if primary.cpuDieHotspot > 0   { merged.cpuDieHotspot   = primary.cpuDieHotspot }
        if primary.fanRPM > 0          { merged.fanRPM          = primary.fanRPM }
        return merged
    }

    private func loadStaticSystemInfo() {
        // brand_string returns e.g. "Apple M2 Pro" — strip the "Apple " prefix so we
        // display "M2", "M2 Pro", "M2 Max", "M2 Ultra" directly in the UI.
        let rawBrand = Self.sysctlString("machdep.cpu.brand_string")
            ?? Self.sysctlString("hw.model")
            ?? "Apple Silicon"
        let chip = rawBrand.hasPrefix("Apple ") ? String(rawBrand.dropFirst(6)) : rawBrand
        let eCores = Self.sysctlInt("hw.perflevel0.physicalcpu")
        let pCores = Self.sysctlInt("hw.perflevel1.physicalcpu")
        let gpuCores = Self.detectGPUCoreCount()
        let thermal = Self.currentThermalState()

        DispatchQueue.main.async {
            self.chipName = chip
            self.eCoreCount = eCores
            self.pCoreCount = pCores > 0 ? pCores : max(0, ProcessInfo.processInfo.processorCount - eCores)
            self.gpuCoreCount = gpuCores
            self.thermalState = thermal
        }
    }

    // MARK: - Optimize

    func optimize(completion: @escaping () -> Void = {}) {
        let heavyApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        var candidates: [(app: NSRunningApplication, memMB: Int, cpu: Double)] = []
        for proc in topProcs {
            if let app = heavyApps.first(where: { Int($0.processIdentifier) == proc.pid }) {
                let mb = Int(proc.mem / 1_048_576)
                let name = app.localizedName?.lowercased() ?? ""
                let protected = ["finder", "terminal", "iterm", "codex", "nexus", "系统设置", "system settings"]
                    .contains { name.contains($0) }
                if !protected && (mb > 700 || proc.cpu > 45) {
                    candidates.append((app, mb, proc.cpu))
                }
            }
        }

        DispatchQueue.main.async {
            guard !candidates.isEmpty else {
                self.runEmergencyCleanup {
                    DispatchQueue.main.async {
                        let a = NSAlert()
                        a.messageText = "紧急优化已执行"
                        a.informativeText = "已清理系统缓存。\n没有发现需要退出的高占用普通应用。"
                        a.runModal()
                        completion()
                    }
                }
                return
            }
            let names = candidates.map {
                "\($0.app.localizedName ?? "?")  (\($0.memMB) MB / \(String(format: "%.0f", $0.cpu))% CPU)"
            }
            .joined(separator: "\n")
            let alert = NSAlert()
            alert.messageText = "执行紧急优化？"
            alert.informativeText = "会先清理系统缓存，并尝试退出这些高占用普通应用：\n\n\(names)"
            alert.addButton(withTitle: "执行紧急优化")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else {
                completion()
                return
            }

            self.runEmergencyCleanup {
                DispatchQueue.main.async {
                    candidates.forEach { $0.app.terminate() }
                    let a = NSAlert()
                    a.messageText = "紧急优化已执行"
                    a.informativeText = "已清理系统缓存，并向高占用应用发送退出请求。"
                    a.runModal()
                    completion()
                }
            }
        }
    }

    private func runEmergencyCleanup(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let purge = self.shellResult("/usr/bin/purge", [])
            if purge.status != 0 {
                _ = self.shellResult("/usr/bin/sudo", ["-n", "/usr/bin/purge"])
            }
            completion()
        }
    }

    private func history(_ values: [Double], adding value: Double, limit: Int = 14_400) -> [Double] {
        var next = values
        next.append(max(0, value))
        if next.count > limit {
            next.removeFirst(next.count - limit)
        }
        return next
    }

    private func refreshCountryIfNeeded(force: Bool = false) {
        let localIP = currentIP
        guard force || Date().timeIntervalSince(lastCountryFetch) > 60 else { return }
        guard !countryFetchInFlight else { return }
        countryFetchInFlight = true
        lastCountryFetch = Date()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let result = self.lookupCurrentCountry()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !result.country.isEmpty {
                    self.currentCountry = result.country
                } else if self.currentCountry.isEmpty {
                    self.currentCountry = "未知国家"
                }
                self.lastCountryIP = result.ip.isEmpty ? localIP : result.ip
                self.countryFetchInFlight = false
            }
        }
    }

    private func systemProxyCurlArguments() -> [String] {
        let proxy = shell("/usr/sbin/scutil", ["--proxy"])
        guard proxy.contains("HTTPSEnable : 1") || proxy.contains("HTTPEnable : 1") else { return [] }

        var host = ""
        var port = ""
        for rawLine in proxy.split(separator: "\n") {
            let parts = rawLine.split(separator: ":", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            if parts[0] == "HTTPSProxy" || (host.isEmpty && parts[0] == "HTTPProxy") {
                host = parts[1]
            }
            if parts[0] == "HTTPSPort" || (port.isEmpty && parts[0] == "HTTPPort") {
                port = parts[1]
            }
        }

        guard !host.isEmpty, !port.isEmpty else { return [] }
        return ["--proxy", "http://\(host):\(port)"]
    }

    private func countryCurl(_ url: String) -> String {
        shell("/usr/bin/curl", [
            "-fsSL"
        ] + systemProxyCurlArguments() + [
            "--connect-timeout", "1",
            "--max-time", "2",
            url
        ])
    }

    private func lookupCurrentCountry() -> (country: String, ip: String) {
        let primary = countryCurl("https://api.country.is/")
        if let data = primary.data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let primaryCode = payload["country"] as? String,
           primaryCode.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return (
                Self.localizedCountryName(for: primaryCode),
                payload["ip"] as? String ?? ""
            )
        }

        let code = countryCurl("https://ipinfo.io/country").trimmingCharacters(in: .whitespacesAndNewlines)
        if code.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return (Self.localizedCountryName(for: code), "")
        }

        let ipapiCode = countryCurl("https://ipapi.co/country_code/").trimmingCharacters(in: .whitespacesAndNewlines)
        if ipapiCode.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return (Self.localizedCountryName(for: ipapiCode), "")
        }

        let fallbackCode = countryCurl("https://ifconfig.co/country-iso").trimmingCharacters(in: .whitespacesAndNewlines)
        if fallbackCode.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return (Self.localizedCountryName(for: fallbackCode), "")
        }

        return ("", "")
    }

    // MARK: - Hermes Agent usage

    private func refreshHermesUsage() {
        guard !hermesUsageInFlight else { return }
        hermesUsageInFlight = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let usage = self.readHermesTodayUsage()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.publishIfChanged(\.hermesUsageAvailable, usage.available)
                if usage.available {
                    self.publishIfChanged(\.hermesTodayTokensText, "今日 \(Self.compactTokenText(usage.tokens))")
                    self.publishIfChanged(\.hermesTodayDurationText, Self.compactDurationText(usage.seconds))
                } else {
                    self.publishIfChanged(\.hermesTodayTokensText, "今日 -- tok")
                    self.publishIfChanged(\.hermesTodayDurationText, "--")
                }
                self.hermesUsageInFlight = false
            }
        }
    }

    private func readHermesTodayUsage() -> (available: Bool, tokens: Int64, seconds: Double) {
        let dbPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".hermes/state.db")
            .path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return (false, 0, 0)
        }

        let sql = """
        select
          coalesce(sum(coalesce(input_tokens,0)+coalesce(output_tokens,0)+coalesce(cache_read_tokens,0)+coalesce(cache_write_tokens,0)+coalesce(reasoning_tokens,0)),0),
          coalesce(sum(case
            when ended_at is not null and ended_at > started_at then ended_at - started_at
            when ended_at is null then max(0, strftime('%s','now') - started_at)
            else 0
          end),0)
        from sessions
        where started_at >= strftime('%s','now','localtime','start of day','utc');
        """
        let result = shellResult("/usr/bin/sqlite3", ["-batch", "-noheader", "-separator", "|", dbPath, sql])
        guard result.status == 0 else {
            return (false, 0, 0)
        }

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = output.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return (false, 0, 0)
        }
        let tokens = Int64(Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        let seconds = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return (true, max(0, tokens), max(0, seconds))
    }

    // MARK: - Codex quota / usage

    private func refreshCodexUsage(force: Bool = false) {
        guard !codexUsageInFlight else { return }
        codexUsageInFlight = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let snapshot = self.readCodexUsageSnapshotIncremental()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.codexUsageLastSignature = Self.codexUsageSignature()
                self.publishIfChanged(\.codexUsageAvailable, snapshot.available)
                self.publishIfChanged(\.codexTodayTokensText, "今日 \(Self.compactTokenText(snapshot.todayTokens))")
                self.publishIfChanged(\.codexPlanType, Self.displayPlanName(snapshot.planType))
                self.publishIfChanged(\.codexFiveHourRemainingPct, Self.remainingPct(fromUsed: snapshot.fiveHourUsedPct))
                self.publishIfChanged(\.codexWeeklyRemainingPct, Self.remainingPct(fromUsed: snapshot.weeklyUsedPct))
                self.publishIfChanged(\.codexFiveHourResetText, Self.resetText(snapshot.fiveHourResetAt))
                self.publishIfChanged(\.codexWeeklyResetText, Self.resetText(snapshot.weeklyResetAt))
                self.codexUsageInFlight = false
            }
        }
    }

    private func readCodexUsageSnapshotIncremental() -> CodexUsageSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        if today != codexUsageDay {
            codexUsageDay = today
            codexUsageSnapshotCache.todayTokens = 0
        }

        let root = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/sessions")
        let files = Self.codexCandidateSessionFiles(root: root,
                                                    recentDays: Self.codexUsageRecentDays,
                                                    limit: Self.codexUsageFileLimit)

        for file in files {
            let path = file.path
            guard let size = Self.fileSize(file) else { continue }
            let previousOffset = codexUsageReadOffsets[path] ?? 0
            let startOffset = previousOffset <= size ? previousOffset : 0
            guard startOffset < size else { continue }
            guard let text = Self.readFileSegment(file, from: startOffset) else {
                codexUsageReadOffsets[path] = size
                continue
            }

            for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
                Self.applyCodexLine(rawLine,
                                    file: file,
                                    now: now,
                                    snapshot: &codexUsageSnapshotCache,
                                    latestRateLimitDate: &codexUsageLatestRateLimitDate,
                                    latestRateLimitPriority: &codexUsageLatestRateLimitPriority)
            }
            codexUsageReadOffsets[path] = size
        }

        var output = codexUsageSnapshotCache
        if let live = Self.readCodexLiveUsageSnapshot() {
            output.available = live.available
            output.planType = live.planType
            output.fiveHourUsedPct = live.fiveHourUsedPct
            output.fiveHourResetAt = live.fiveHourResetAt
            output.weeklyUsedPct = live.weeklyUsedPct
            output.weeklyResetAt = live.weeklyResetAt
            output.rateLimitObservedAt = live.rateLimitObservedAt
        } else {
            Self.applyCodexUsageOverride(to: &output)
        }
        return output
    }

    private static func readCodexLiveUsageSnapshot() -> CodexUsageSnapshot? {
        guard let token = codexAccessToken(),
              let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("zh-CN", forHTTPHeaderField: "OAI-Language")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("codex_desktop", forHTTPHeaderField: "X-OAI-Client-App")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseStatus = 0
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            responseData = data
            responseStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 9) == .success,
              responseStatus == 200,
              let data = responseData,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            task.cancel()
            return nil
        }

        var snapshot = CodexUsageSnapshot()
        snapshot.available = true
        snapshot.rateLimitObservedAt = Date()
        if let plan = obj["plan_type"] as? String, !plan.isEmpty {
            snapshot.planType = plan
        }

        guard let limits = obj["rate_limit"] as? [String: Any] else { return snapshot }
        if let primary = limits["primary_window"] as? [String: Any] {
            snapshot.fiveHourUsedPct = number(primary["used_percent"])?.doubleValue ?? snapshot.fiveHourUsedPct
            snapshot.fiveHourResetAt = resetDate(primary["reset_at"]) ?? snapshot.fiveHourResetAt
        }
        if let secondary = limits["secondary_window"] as? [String: Any] {
            snapshot.weeklyUsedPct = number(secondary["used_percent"])?.doubleValue ?? snapshot.weeklyUsedPct
            snapshot.weeklyResetAt = resetDate(secondary["reset_at"]) ?? snapshot.weeklyResetAt
        }
        return snapshot
    }

    private static func codexAccessToken() -> String? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = obj["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String,
              !token.isEmpty else { return nil }
        return token
    }

    private static func readCodexUsageSnapshot() -> CodexUsageSnapshot {
        let root = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/sessions")
        let calendar = Calendar.current
        let now = Date()
        var files = codexCandidateSessionFiles(root: root,
                                               recentDays: codexUsageRecentDays,
                                               limit: codexUsageFileLimit)
        files.sort { modificationDate($0) < modificationDate($1) }

        var snapshot = CodexUsageSnapshot()
        var latestRateLimitDate = Date.distantPast
        var latestRateLimitPriority = -1

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = rawLine.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      obj["type"] as? String == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count"
                else { continue }

                snapshot.available = true
                let timestampText = obj["timestamp"] as? String
                let timestamp = parseCodexTimestamp(timestampText) ?? modificationDate(file)
                if let info = payload["info"] as? [String: Any],
                   let last = info["last_token_usage"] as? [String: Any],
                   let total = number(last["total_tokens"]),
                   calendar.isDate(timestamp, inSameDayAs: now) {
                    snapshot.todayTokens += total.int64Value
                }

                guard let limits = (payload["rate_limits"] as? [String: Any]) ?? (obj["rate_limits"] as? [String: Any]) else { continue }
                let rawLimitID = limits["limit_id"] as? String ?? ""
                let limitID = rawLimitID.lowercased()
                let priority = codexLimitPriority(limitID)
                guard priority > 0 else { continue }
                guard priority > latestRateLimitPriority || (priority == latestRateLimitPriority && timestamp > latestRateLimitDate) else { continue }
                latestRateLimitDate = timestamp
                latestRateLimitPriority = priority
                snapshot.rateLimitObservedAt = timestamp

                if let plan = limits["plan_type"] as? String, !plan.isEmpty {
                    snapshot.planType = plan
                } else if let limitName = limits["limit_name"] as? String, !limitName.isEmpty {
                    snapshot.planType = limitName
                } else if !rawLimitID.isEmpty {
                    snapshot.planType = rawLimitID
                }
                if let primary = limits["primary"] as? [String: Any] {
                    snapshot.fiveHourUsedPct = number(primary["used_percent"])?.doubleValue ?? snapshot.fiveHourUsedPct
                    snapshot.fiveHourResetAt = resetDate(primary["resets_at"]) ?? snapshot.fiveHourResetAt
                }
                if let secondary = limits["secondary"] as? [String: Any] {
                    snapshot.weeklyUsedPct = number(secondary["used_percent"])?.doubleValue ?? snapshot.weeklyUsedPct
                    snapshot.weeklyResetAt = resetDate(secondary["resets_at"]) ?? snapshot.weeklyResetAt
                }
            }
        }

        applyCodexUsageOverride(to: &snapshot)
        return snapshot
    }

    private static func applyCodexLine(
        _ rawLine: Substring,
        file: URL,
        now: Date,
        snapshot: inout CodexUsageSnapshot,
        latestRateLimitDate: inout Date,
        latestRateLimitPriority: inout Int
    ) {
        let calendar = Calendar.current
        guard let data = rawLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "event_msg",
              let payload = obj["payload"] as? [String: Any],
              payload["type"] as? String == "token_count"
        else { return }

        snapshot.available = true
        let timestampText = obj["timestamp"] as? String
        let timestamp = parseCodexTimestamp(timestampText) ?? modificationDate(file)
        if let info = payload["info"] as? [String: Any],
           let last = info["last_token_usage"] as? [String: Any],
           let total = number(last["total_tokens"]),
           calendar.isDate(timestamp, inSameDayAs: now) {
            snapshot.todayTokens += total.int64Value
        }

        guard let limits = (payload["rate_limits"] as? [String: Any]) ?? (obj["rate_limits"] as? [String: Any]) else { return }
        let rawLimitID = limits["limit_id"] as? String ?? ""
        let limitID = rawLimitID.lowercased()
        let priority = codexLimitPriority(limitID)
        guard priority > 0 else { return }
        guard priority > latestRateLimitPriority || (priority == latestRateLimitPriority && timestamp > latestRateLimitDate) else { return }
        latestRateLimitDate = timestamp
        latestRateLimitPriority = priority
        snapshot.rateLimitObservedAt = timestamp

        if let plan = limits["plan_type"] as? String, !plan.isEmpty {
            snapshot.planType = plan
        } else if let limitName = limits["limit_name"] as? String, !limitName.isEmpty {
            snapshot.planType = limitName
        } else if !rawLimitID.isEmpty {
            snapshot.planType = rawLimitID
        }
        if let primary = limits["primary"] as? [String: Any] {
            snapshot.fiveHourUsedPct = number(primary["used_percent"])?.doubleValue ?? snapshot.fiveHourUsedPct
            snapshot.fiveHourResetAt = resetDate(primary["resets_at"]) ?? snapshot.fiveHourResetAt
        }
        if let secondary = limits["secondary"] as? [String: Any] {
            snapshot.weeklyUsedPct = number(secondary["used_percent"])?.doubleValue ?? snapshot.weeklyUsedPct
            snapshot.weeklyResetAt = resetDate(secondary["resets_at"]) ?? snapshot.weeklyResetAt
        }
    }

    private static func applyCodexUsageOverride(to snapshot: inout CodexUsageSnapshot) {
        let url = codexOverrideURL()
        if let observedAt = snapshot.rateLimitObservedAt,
           modificationDate(url) < observedAt {
            return
        }
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let five = number(obj["fiveHourRemainingPct"])?.doubleValue {
            snapshot.fiveHourUsedPct = 100 - max(0, min(100, five))
            snapshot.available = true
        }
        if let weekly = number(obj["weeklyRemainingPct"])?.doubleValue {
            snapshot.weeklyUsedPct = 100 - max(0, min(100, weekly))
            snapshot.available = true
        }
    }

    private static func codexUsageSignature() -> String {
        let root = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/sessions")
        var parts: [String] = []
        for file in codexCandidateSessionFiles(root: root,
                                               recentDays: codexUsageRecentDays,
                                               limit: codexUsageFileLimit) {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            parts.append("\(file.path)|\(size)|\(modified)")
        }
        let override = codexOverrideURL()
        let overrideValues = try? override.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let overrideSize = overrideValues?.fileSize ?? 0
        let overrideModified = overrideValues?.contentModificationDate?.timeIntervalSince1970 ?? 0
        parts.append("override|\(overrideSize)|\(overrideModified)")
        return parts.joined(separator: "\n")
    }

    private static func codexLimitPriority(_ limitID: String) -> Int {
        if limitID == "codex" { return 3 }
        if limitID.hasPrefix("codex_") && !limitID.contains("bengalfox") { return 2 }
        if limitID.hasPrefix("codex") || limitID.contains("codex") { return 1 }
        return 0
    }

    private static func codexOverrideURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/codex_quota_override.json")
    }

    private static func codexCandidateSessionFiles(root: URL, recentDays: Int, limit: Int) -> [URL] {
        let fm = FileManager.default
        let calendar = Calendar.current
        var seen = Set<String>()
        var files: [URL] = []

        for dayOffset in 0..<recentDays {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = parts.year, let month = parts.month, let dayNumber = parts.day else { continue }
            let dir = root
                .appendingPathComponent(String(format: "%04d", year))
                .appendingPathComponent(String(format: "%02d", month))
                .appendingPathComponent(String(format: "%02d", dayNumber))
            let dayFiles = ((try? fm.contentsOfDirectory(at: dir,
                                                         includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                         options: [.skipsHiddenFiles])) ?? [])
                .filter { $0.pathExtension == "jsonl" }
            for file in dayFiles where seen.insert(file.path).inserted {
                files.append(file)
            }
        }

        if files.isEmpty {
            files = recentCodexSessionFiles(root: root, limit: limit)
        }

        let sorted = files.sorted { modificationDate($0) > modificationDate($1) }
        return Array(sorted.prefix(limit))
    }

    private static func recentCodexSessionFiles(root: URL, limit: Int) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            files.append(url)
        }
        return Array(files.sorted { modificationDate($0) > modificationDate($1) }.prefix(limit))
    }

    private static func number(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber { return number }
        if let text = value as? String, let double = Double(text) { return NSNumber(value: double) }
        return nil
    }

    private static func resetDate(_ value: Any?) -> Date? {
        guard let seconds = number(value)?.doubleValue, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func parseCodexTimestamp(_ text: String?) -> Date? {
        guard let text = text else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: text) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: text)
    }

    private static func modificationDate(_ url: URL) -> Date {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
            ?? Date.distantPast
    }

    private static func fileSize(_ url: URL) -> UInt64? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
        return UInt64(max(0, size))
    }

    private static func readFileSegment(_ url: URL, from offset: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        try? handle.close()
        return String(data: data, encoding: .utf8)
    }

    private static func compactTokenText(_ tokens: Int64) -> String {
        let value = Double(max(tokens, 0))
        if value >= 1_000_000 {
            return String(format: "%.1fM tok", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK tok", value / 1_000)
        }
        return "\(tokens) tok"
    }

    private static func compactDurationText(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
        if minutes > 0 {
            return secs > 0 ? "\(minutes)分\(secs)秒" : "\(minutes)分"
        }
        return "\(secs)秒"
    }

    private static func displayPlanName(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("codex-spark") || lower.contains("bengalfox") {
            return "Codex Spark"
        }
        switch lower {
        case "prolite": return "Pro"
        case "pro": return "Pro"
        case "plus": return "Plus"
        case "free": return "Free"
        default: return raw.isEmpty ? "Codex" : raw
        }
    }

    private static func remainingPct(fromUsed used: Double) -> Int {
        Int(max(0, min(100, (100 - used).rounded())))
    }

    private static func resetText(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let seconds = max(0, date.timeIntervalSinceNow)
        if seconds >= 86_400 {
            return "\(Int(ceil(seconds / 86_400)))天后"
        }
        if seconds >= 3_600 {
            return "\(Int(ceil(seconds / 3_600)))小时后"
        }
        if seconds >= 60 {
            return "\(Int(ceil(seconds / 60)))分钟后"
        }
        return "马上"
    }

    // MARK: - Shell helper

    private func shell(_ path: String, _ args: [String]) -> String {
        shellResult(path, args).stdout
    }

    private func shellResult(_ path: String, _ args: [String]) -> (stdout: String, stderr: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr
        do {
            try task.run()
        } catch {
            return ("", "启动失败：\(error)", -1)
        }
        // Drain both pipes concurrently BEFORE waitUntilExit. Otherwise, if the
        // child writes more than the pipe buffer (~16-64 KB) it blocks on write
        // while we block on waitUntilExit → deadlock. `ps -axo ... -r` on a busy
        // Mac (~1000 processes) easily exceeds the buffer.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let q = DispatchQueue.global(qos: .utility)
        group.enter()
        q.async {
            outData = stdout.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        q.async {
            errData = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        task.waitUntilExit()
        group.wait()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return (out, err, task.terminationStatus)
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

private extension SystemStatsModel {
    static func currentThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "正常"
        case .fair: return "轻微压力"
        case .serious: return "严重压力"
        case .critical: return "危险"
        @unknown default: return "正常"
        }
    }

    static func currentIPv4Address() -> String {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return "未连接" }
        defer { freeifaddrs(interfaces) }

        let primary = primaryNetworkInterface()
        var fallback: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(address,
                                     socklen_t(address.pointee.sa_len),
                                     &host,
                                     socklen_t(host.count),
                                     nil,
                                     0,
                                     NI_NUMERICHOST)
            guard result == 0 else { continue }

            let ip = String(cString: host)
            guard !ip.hasPrefix("169.254.") else { continue }
            if !primary.isEmpty, name == primary { return ip }
            if name.hasPrefix("en") { return ip }
            if fallback == nil { fallback = ip }
        }

        return fallback ?? "未连接"
    }

    static func primaryNetworkInterface() -> String {
        guard let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let name = global["PrimaryInterface"] as? String else {
            return ""
        }
        return name
    }

    static func rootDiskStatsService() -> io_registry_entry_t {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, URL(fileURLWithPath: "/") as CFURL),
              let bsdNamePtr = DADiskGetBSDName(disk) else {
            return 0
        }

        let bsdName = String(cString: bsdNamePtr)
        let partitionLevel = bsdName.filter { $0 >= "0" && $0 <= "9" }.count
        var current = DADiskCopyIOMedia(disk)
        guard current != 0 else { return 0 }

        for _ in 0..<max(partitionLevel, 1) {
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS, parent != 0 else {
                IOObjectRelease(current)
                return 0
            }
            IOObjectRelease(current)
            current = parent
        }

        return current
    }

    static func ioRegistryProperties(_ service: io_registry_entry_t) -> [String: Any]? {
        var raw: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &raw, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = raw?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return props
    }

    static func localizedCountryName(for code: String) -> String {
        let regionCode = code.uppercased()
        let locale = Locale(identifier: "zh_Hans_CN")
        return locale.localizedString(forRegionCode: regionCode) ?? regionCode
    }

    static func sampleStorage() -> (used: Int64, total: Int64, pct: Int) {
        let path = NSHomeDirectory()
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let totalNumber = attrs[.systemSize] as? NSNumber,
              let freeNumber = attrs[.systemFreeSize] as? NSNumber else {
            return (0, 0, 0)
        }
        let total = totalNumber.int64Value
        let free = freeNumber.int64Value
        let used = max(0, total - free)
        let pct = total > 0 ? Int((Double(used) / Double(total) * 100).rounded()) : 0
        return (used, total, min(max(pct, 0), 100))
    }

    static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(size))
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static func sysctlInt(_ name: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
        return Int(value)
    }

    static func firstSizeMatch(in text: String, pattern: String) -> Int64 {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return 0 }
        let token = String(text[range]).split(separator: " ").last.map(String.init) ?? ""
        return parseSize(token)
    }

    static func firstIntegerMatch(in text: String, pattern: String) -> Int64 {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return 0 }
        let match = String(text[range])
        let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int64(digits) ?? 0
    }

    static func isIOBlockStorageDriverStatsLine(_ line: String) -> Bool {
        guard line.contains(#""Statistics""#), line.contains(#""Bytes ("#) else { return false }

        // `ioreg -r -c IOBlockStorageDriver -l` includes each driver and its child media
        // tree. Count only the driver's own Statistics line; child IOMedia/APFS
        // Statistics repeat the same traffic and would double-count.
        return line.hasPrefix(#"      "Statistics" = "#)
            || line.hasPrefix(#"  |   "Statistics" = "#)
    }

    static func detectGPUCoreCount() -> Int {
        let acceleratorClasses = [
            "AGXAccelerator",
            "AGXAcceleratorG17X",
            "AGXAcceleratorG17",
            "AGXAcceleratorG16X",
            "AGXAcceleratorG16",
            "AGXAcceleratorG15X",
            "AGXAcceleratorG15",
            "AGXAcceleratorG14X",
            "AGXAcceleratorG14",
        ]

        for className in acceleratorClasses {
            let output = shellStatic("/usr/sbin/ioreg", ["-r", "-c", className, "-l"])
            let cores = parseGPUCoreCount(from: output)
            if cores > 0 { return cores }
        }

        let profiler = shellStatic("/usr/sbin/system_profiler", ["SPDisplaysDataType"])
        let profilerCores = firstIntegerMatch(in: profiler, pattern: #"Total Number of Cores:\s*(\d+)"#)
        return Int(profilerCores)
    }

    static func parseGPUCoreCount(from output: String) -> Int {
        let direct = firstIntegerMatch(in: output, pattern: #""gpu-core-count"\s*=\s*(\d+)"#)
        if direct > 0 { return Int(direct) }

        let nested = firstIntegerMatch(in: output, pattern: #""num_cores"\s*=\s*(\d+)"#)
        if nested > 0 { return Int(nested) }
        return 0
    }

    static func shellStatic(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return "" }
        // Drain pipe before waitUntilExit to avoid deadlock on large output
        // (ioreg can emit hundreds of KB, way past the pipe buffer).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func shellSingleQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func parseSize(_ token: String) -> Int64 {
        guard !token.isEmpty else { return 0 }
        let sanitized = token.replacingOccurrences(of: "i", with: "", options: .caseInsensitive)
        let suffix = sanitized.last?.uppercased() ?? ""
        let numericPart: String
        if sanitized.last?.isLetter == true {
            numericPart = String(sanitized.dropLast())
        } else {
            numericPart = sanitized
        }
        let value = Double(numericPart) ?? 0

        switch suffix {
        case "K": return Int64(value * 1024)
        case "M": return Int64(value * 1_048_576)
        case "G": return Int64(value * 1_073_741_824)
        case "T": return Int64(value * 1_099_511_627_776)
        default: return Int64(Double(token) ?? 0)
        }
    }
}
