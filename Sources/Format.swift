import Foundation

enum Fmt {
    static func compact(_ n: Int) -> String {
        let d = Double(n)
        if d >= 1_000_000_000 { return String(format: "%.2fB", d / 1_000_000_000) }
        if d >= 1_000_000 { return String(format: "%.2fM", d / 1_000_000) }
        if d >= 1_000 { return String(format: "%.0fK", d / 1_000) }
        return "\(n)"
    }

    static func money(_ v: Double) -> String {
        String(format: "$%.2f", v)
    }

    // e.g. "2h 14m"
    static func countdown(to end: Date) -> String {
        let secs = max(0, Int(end.timeIntervalSinceNow))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    static func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
}
