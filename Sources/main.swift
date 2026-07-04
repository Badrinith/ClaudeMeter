import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var timer: Timer?
    private let model = UsageModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "blockBudgetTokens": 20_000_000,
            "weekBudgetTokens": 400_000_000,
            "opusWeekBudgetTokens": 250_000_000,
            "menuBarMode": MenuBarMode.percent.rawValue,
        ])
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.imagePosition = .imageLeading
        }

        popover.behavior = .transient
        popover.animates = false
        let hosting = NSHostingController(rootView: ContentView(model: model))
        // Let the SwiftUI content drive the popover size so the card is never
        // clipped and stays a consistent size across opens.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 258, height: 430)

        model.onUpdate = { [weak self] in self?.updateButton() }
        model.reload()

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.model.reload()
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let s = model.stats
        let frac = s.blockActive ? s.blockFraction : 0

        let text: String
        if s.blockActive {
            switch model.displayMode {
            case .tokens:  text = Fmt.compact(s.blockTokens)
            case .percent: text = "\(Int(frac * 100))%"
            case .cost:    text = Fmt.money(s.blockCost)
            }
        } else {
            text = "—"
        }
        button.title = " " + text
        button.image = NSImage(systemSymbolName: gaugeSymbol(frac),
                               accessibilityDescription: "Claude usage")
            ?? NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: nil)

        if frac >= 0.9 {
            button.contentTintColor = .systemRed
        } else if frac >= 0.7 {
            button.contentTintColor = .systemOrange
        } else {
            button.contentTintColor = nil
        }
    }

    private func gaugeSymbol(_ frac: Double) -> String {
        switch frac {
        case ..<0.15: return "gauge.with.dots.needle.0percent"
        case ..<0.45: return "gauge.with.dots.needle.33percent"
        case ..<0.75: return "gauge.with.dots.needle.67percent"
        default:      return "gauge.with.dots.needle.100percent"
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        model.reload()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
