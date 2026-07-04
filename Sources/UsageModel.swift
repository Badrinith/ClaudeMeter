import Foundation
import Combine
import ServiceManagement

enum MenuBarMode: Int, CaseIterable, Identifiable {
    case tokens, percent, cost
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .tokens: return "Tokens"
        case .percent: return "%"
        case .cost: return "$"
        }
    }
}

final class UsageModel: ObservableObject {
    @Published var stats = Stats.empty(20_000_000)
    @Published var lastUpdated = Date()

    // AppDelegate sets this to refresh the menu bar label after each reload.
    var onUpdate: (() -> Void)?

    private let queue = DispatchQueue(label: "com.badri.claudemeter.reload")

    @Published var displayMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "menuBarMode")
            onUpdate?()
        }
    }

    init() {
        displayMode = MenuBarMode(rawValue: UserDefaults.standard.integer(forKey: "menuBarMode")) ?? .tokens
    }

    func reload() {
        queue.async {
            let s = UsageReader.compute()
            DispatchQueue.main.async {
                self.stats = s
                self.lastUpdated = Date()
                self.onUpdate?()
            }
        }
    }

    private func budget(_ key: String, min floor: Int, _ delta: Int) {
        let current = max(floor, UserDefaults.standard.integer(forKey: key))
        UserDefaults.standard.set(max(floor, current + delta), forKey: key)
        reload()
    }

    func bumpBudget(by delta: Int) { budget("blockBudgetTokens", min: 1_000_000, delta) }
    func bumpWeekly(by delta: Int) { budget("weekBudgetTokens", min: 10_000_000, delta) }

    // MARK: - Launch at login (macOS 13+)

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("ClaudeMeter: login-item toggle failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
