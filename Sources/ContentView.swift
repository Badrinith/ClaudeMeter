import SwiftUI

struct ContentView: View {
    @ObservedObject var model: UsageModel
    @AppStorage("showWeeklyByModel") private var showWeeklyByModel = true

    private var s: Stats { model.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header

            VStack(alignment: .leading, spacing: 10) {
                if s.blockActive {
                    limitBar(label: "5-hour window",
                             sub: "resets \(Fmt.clock(s.blockEnd)) · \(Fmt.countdown(to: s.blockEnd))",
                             tokens: s.blockTokens, budget: s.blockBudget, fraction: s.blockFraction)
                } else {
                    idleBar
                }
                limitBar(label: "This week · 7d · all models",
                         sub: Fmt.money(s.weekCost),
                         tokens: s.weekTokens, budget: s.weekBudget, fraction: s.weekFraction)
            }

            if !s.weekSlices.isEmpty {
                Divider().opacity(0.4)
                weeklyByModel
            }

            Divider().opacity(0.4)

            HStack {
                Text("Today")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.compact(s.todayTokens))
                    .font(.system(size: 12, weight: .medium))
                Text(Fmt.money(s.todayCost))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.4)
            footer
        }
        .padding(12)
        .frame(width: 262)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.tint)
            Text("Claude Usage")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(Fmt.clock(model.lastUpdated))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func limitBar(label: String, sub: String, tokens: Int, budget: Int, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(fraction, 1.0))
                .tint(color(fraction))
            HStack {
                Text("\(Fmt.compact(tokens)) / \(Fmt.compact(budget))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color(fraction))
            }
        }
    }

    private var idleBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("5-hour window")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ProgressView(value: 0).tint(.green)
            Text("Idle · limit fully reset")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // Collapsible table: each model's share of the shared weekly budget,
    // with its own mini progress bar — answers "which model is eating my week".
    private var weeklyByModel: some View {
        DisclosureGroup(isExpanded: $showWeeklyByModel) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(s.weekSlices) { slice in
                    modelRow(slice)
                }
            }
            .padding(.top, 6)
        } label: {
            Text("Usage by model · this week")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
    }

    private func modelRow(_ slice: ModelSlice) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle().fill(color(for: slice.model)).frame(width: 6, height: 6)
                Text(slice.model)
                    .font(.system(size: 11))
                Spacer()
                Text(Fmt.compact(slice.tokens))
                    .font(.system(size: 11, weight: .medium))
                Text(Fmt.money(slice.cost))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: 6) {
                ProgressView(value: min(slice.fraction, 1.0))
                    .tint(color(for: slice.model))
                Text("\(Int(slice.fraction * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .trailing)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Menu bar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.displayMode },
                    set: { model.displayMode = $0 }
                )) {
                    ForEach(MenuBarMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }

            targetRow("5h target", value: s.blockBudget,
                      dec: { model.bumpBudget(by: -5_000_000) },
                      inc: { model.bumpBudget(by: 5_000_000) })
            targetRow("Weekly target", value: s.weekBudget,
                      dec: { model.bumpWeekly(by: -50_000_000) },
                      inc: { model.bumpWeekly(by: 50_000_000) })

            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                Text("Launch at login")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            HStack {
                Button("Refresh") { model.reload() }
                    .font(.system(size: 11))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
            }
        }
    }

    private func targetRow(_ label: String, value: Int,
                           dec: @escaping () -> Void, inc: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: dec) { Image(systemName: "minus") }
                .buttonStyle(.borderless)
            Text(Fmt.compact(value))
                .font(.system(size: 11, weight: .medium))
                .frame(width: 52)
            Button(action: inc) { Image(systemName: "plus") }
                .buttonStyle(.borderless)
        }
    }

    // MARK: - Helpers

    private func color(_ fraction: Double) -> Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.7 { return .orange }
        return .green
    }

    private func color(for model: String) -> Color {
        switch model {
        case "Opus": return .purple
        case "Sonnet": return .blue
        case "Haiku": return .teal
        default: return .gray
        }
    }
}
