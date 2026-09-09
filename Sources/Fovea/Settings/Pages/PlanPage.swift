import SwiftUI
import FoveaCore

struct PlanPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsPage(title: "Usage & Plan") {
            SettingsSection("Usage", child: .usage) {
                SettingsGroup {
                    HStack(spacing: Tokens.Space.l) {
                        usageRing
                        VStack(alignment: .leading, spacing: 3) {
                            switch model.usage {
                            case .loaded(let u):
                                Text("\(u.percent)% used")
                                    .font(Tokens.Type_.rowLabel)
                                    .foregroundStyle(Tokens.Colors.textPrimary)
                                Text("\(u.used) of \(u.limit) \(u.unitLabel)")
                                    .font(Tokens.Type_.secondary)
                                    .foregroundStyle(Tokens.Colors.textSecondary)
                                Text("Resets \(DateGrouping.shortDate(u.resetsAt))")
                                    .font(Tokens.Type_.secondary)
                                    .foregroundStyle(Tokens.Colors.textSecondary)
                            case .unavailable:
                                Text("Usage unavailable")
                                    .font(Tokens.Type_.rowLabel)
                                    .foregroundStyle(Tokens.Colors.textPrimary)
                                Text("Couldn’t load usage right now.")
                                    .font(Tokens.Type_.secondary)
                                    .foregroundStyle(Tokens.Colors.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Tokens.Layout.rowPaddingH)
                    .padding(.vertical, Tokens.Space.l)
                    .accessibilityElement(children: .combine)
                }
            }

            SettingsSection("Plan", child: .planDetails) {
                SettingsGroup {
                    SettingsRow(label: "Current Plan") {
                        Text(Fixtures.plan.name)
                            .font(Tokens.Type_.rowValue)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                    }
                    if let price = Fixtures.plan.price, let cadence = Fixtures.plan.cadence {
                        GroupDivider()
                        SettingsRow(label: "Price") {
                            Text("\(price) \(cadence)")
                                .font(Tokens.Type_.rowValue)
                                .foregroundStyle(Tokens.Colors.textSecondary)
                        }
                    }
                    GroupDivider()
                    NavigationRow(label: "Manage Subscription", disabled: true,
                                  disabledReason: "Subscription management isn’t connected in the prototype") {}
                }
            }

            SettingsSection("Billing", child: .billing) {
                SettingsGroup {
                    ForEach(Array(Fixtures.billing().enumerated()), id: \.element.id) { i, entry in
                        if i > 0 { GroupDivider() }
                        SettingsRow(label: DateGrouping.shortDate(entry.date), detail: entry.description) {
                            Text(entry.amount)
                                .font(Tokens.Type_.rowValue)
                                .monospacedDigit()
                                .foregroundStyle(Tokens.Colors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private var usageRing: some View {
        ZStack {
            Circle().stroke(Tokens.Colors.ringTrack, lineWidth: 4)
            if case .loaded(let u) = model.usage {
                Circle()
                    .trim(from: 0, to: u.fraction)
                    .stroke(Tokens.Colors.emphasis, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 44, height: 44)
    }
}
