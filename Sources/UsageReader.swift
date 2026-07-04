import Foundation

// A single billable assistant turn pulled from a Claude Code transcript.
// Cache-write tokens are split by TTL bucket because Anthropic prices them
// differently (5-minute vs 1-hour cache), which the transcript records
// separately under usage.cache_creation.
struct Entry {
    let ts: Date
    let model: String
    let input: Int
    let output: Int
    let cacheWrite5m: Int
    let cacheWrite1h: Int
    let cacheRead: Int
}

struct ModelSlice: Identifiable {
    let id = UUID()
    let model: String
    let tokens: Int
    let cost: Double
    let fraction: Double
}

struct Stats {
    var blockActive = false
    var blockStart = Date()
    var blockEnd = Date()
    var blockTokens = 0
    var blockCost = 0.0
    var blockBudget = 20_000_000

    var todayTokens = 0
    var todayCost = 0.0

    var weekTokens = 0
    var weekCost = 0.0
    var weekBudget = 400_000_000

    // Per-model breakdown of the active 5h window (or today, if idle).
    var slices: [ModelSlice] = []
    // Per-model breakdown of the trailing 7 days — each fraction is that
    // model's share of the shared weekly budget, so the bars show how much
    // of the week's allowance a given model alone is consuming.
    var weekSlices: [ModelSlice] = []

    // Uncapped — a bar can only render up to 100%, but the percentage text
    // should still tell the truth when usage exceeds the target.
    fileprivate static func frac(_ used: Int, _ budget: Int) -> Double {
        budget > 0 ? Double(used) / Double(budget) : 0
    }
    var blockFraction: Double { Stats.frac(blockTokens, blockBudget) }
    var weekFraction: Double { Stats.frac(weekTokens, weekBudget) }

    static func empty(_ budget: Int) -> Stats {
        var s = Stats()
        s.blockBudget = budget
        return s
    }
}

// Published API per-million-token prices (input, output). Cache pricing is
// derived from these via Anthropic's standard multipliers, which are the
// same across models: 5-min cache write = 1.25x input, 1-hour cache write =
// 2x input, cache read = 0.1x input.
private func basePricing(for model: String) -> (input: Double, output: Double) {
    let m = model.lowercased()
    if m.contains("opus")  { return (15.0, 75.0) }
    if m.contains("haiku") { return (0.80, 4.00) }
    // Sonnet + fallback
    return (3.0, 15.0)
}

private func cost(of e: Entry) -> Double {
    let p = basePricing(for: e.model)
    let total = Double(e.input) * p.input
              + Double(e.output) * p.output
              + Double(e.cacheWrite5m) * p.input * 1.25
              + Double(e.cacheWrite1h) * p.input * 2.0
              + Double(e.cacheRead) * p.input * 0.1
    return total / 1_000_000.0
}

private func tokens(of e: Entry) -> Int {
    e.input + e.output + e.cacheWrite5m + e.cacheWrite1h + e.cacheRead
}

enum UsageReader {
    private static let fiveHours: TimeInterval = 5 * 3600

    static func compute() -> Stats {
        let defaults = UserDefaults.standard
        let budget = max(1, defaults.integer(forKey: "blockBudgetTokens"))
        let entries = loadEntries()
        guard !entries.isEmpty else { return .empty(budget) }

        var stats = Stats.empty(budget)
        stats.weekBudget = max(1, defaults.integer(forKey: "weekBudgetTokens"))
        let now = Date()

        // --- Rolling 5-hour block detection (ccusage-style) ---
        // A block is anchored to the hour of its first turn and spans 5h; a gap
        // of >=5h with no activity also starts a fresh block.
        var blockStarts: [Date] = []
        var curStart: Date?
        var lastTs: Date?
        for e in entries { // already sorted ascending
            if let cs = curStart, let lt = lastTs {
                if e.ts >= cs.addingTimeInterval(fiveHours) || e.ts.timeIntervalSince(lt) >= fiveHours {
                    curStart = floorToHour(e.ts)
                    blockStarts.append(curStart!)
                }
            } else {
                curStart = floorToHour(e.ts)
                blockStarts.append(curStart!)
            }
            lastTs = e.ts
        }

        if let last = blockStarts.last, now < last.addingTimeInterval(fiveHours) {
            stats.blockActive = true
            stats.blockStart = last
            stats.blockEnd = last.addingTimeInterval(fiveHours)
        }

        // --- Aggregate the windows ---
        let dayStart = Calendar.current.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 86400)
        var blockModelAgg: [String: (Int, Double)] = [:]
        var weekModelAgg: [String: (Int, Double)] = [:]

        for e in entries {
            let t = tokens(of: e)
            let c = cost(of: e)

            if e.ts >= dayStart { stats.todayTokens += t; stats.todayCost += c }

            if e.ts >= weekStart {
                stats.weekTokens += t
                stats.weekCost += c
                let prev = weekModelAgg[e.model] ?? (0, 0)
                weekModelAgg[e.model] = (prev.0 + t, prev.1 + c)
            }

            if stats.blockActive, e.ts >= stats.blockStart, e.ts < stats.blockEnd {
                stats.blockTokens += t
                stats.blockCost += c
                let prev = blockModelAgg[e.model] ?? (0, 0)
                blockModelAgg[e.model] = (prev.0 + t, prev.1 + c)
            }
        }

        // If no active block, show today's model split instead so the panel isn't empty.
        if !stats.blockActive {
            for e in entries where e.ts >= dayStart {
                let prev = blockModelAgg[e.model] ?? (0, 0)
                blockModelAgg[e.model] = (prev.0 + tokens(of: e), prev.1 + cost(of: e))
            }
        }

        stats.slices = blockModelAgg
            .filter { $0.value.0 > 0 }
            .map { ModelSlice(model: shortModel($0.key), tokens: $0.value.0, cost: $0.value.1, fraction: 0) }
            .sorted { $0.tokens > $1.tokens }

        stats.weekSlices = weekModelAgg
            .filter { $0.value.0 > 0 }
            .map { ModelSlice(model: shortModel($0.key), tokens: $0.value.0, cost: $0.value.1,
                               fraction: Stats.frac($0.value.0, stats.weekBudget)) }
            .sorted { $0.tokens > $1.tokens }

        return stats
    }

    // MARK: - Loading

    private static func loadEntries() -> [Entry] {
        let projects = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let fm = FileManager.default
        guard let en = fm.enumerator(at: projects,
                                     includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }

        // Only files touched in the last 8 days can matter for a 7-day window.
        let cutoff = Date().addingTimeInterval(-8 * 86400)
        var files: [URL] = []
        for case let url as URL in en where url.pathExtension == "jsonl" {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let mod, mod >= cutoff { files.append(url) }
        }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var seen = Set<String>()
        var entries: [Entry] = []

        for url in files {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            content.enumerateLines { line, _ in
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (obj["type"] as? String) == "assistant",
                      let msg = obj["message"] as? [String: Any],
                      let usage = msg["usage"] as? [String: Any],
                      let tsStr = obj["timestamp"] as? String else { return }

                let key = (obj["requestId"] as? String ?? "") + ":" + (msg["id"] as? String ?? "")
                if !key.isEmpty, seen.contains(key) { return }
                if !key.isEmpty { seen.insert(key) }

                guard let ts = isoFrac.date(from: tsStr) ?? iso.date(from: tsStr) else { return }

                // cache_creation splits the write by TTL bucket; fall back to
                // treating the whole write as 5-minute cache (the default TTL)
                // when the transcript predates that breakdown being logged.
                let cacheCreation = usage["cache_creation"] as? [String: Any]
                let totalWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                let write5m = cacheCreation?["ephemeral_5m_input_tokens"] as? Int
                let write1h = cacheCreation?["ephemeral_1h_input_tokens"] as? Int

                entries.append(Entry(
                    ts: ts,
                    model: msg["model"] as? String ?? "unknown",
                    input: usage["input_tokens"] as? Int ?? 0,
                    output: usage["output_tokens"] as? Int ?? 0,
                    cacheWrite5m: write5m ?? totalWrite,
                    cacheWrite1h: write1h ?? 0,
                    cacheRead: usage["cache_read_input_tokens"] as? Int ?? 0
                ))
            }
        }

        return entries.sorted { $0.ts < $1.ts }
    }

    private static func floorToHour(_ d: Date) -> Date {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month, .day, .hour], from: d)) ?? d
    }

    private static func shortModel(_ m: String) -> String {
        let s = m.lowercased()
        if s.contains("opus") { return "Opus" }
        if s.contains("sonnet") { return "Sonnet" }
        if s.contains("haiku") { return "Haiku" }
        return m
    }
}
