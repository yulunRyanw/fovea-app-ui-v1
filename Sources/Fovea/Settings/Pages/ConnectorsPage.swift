import SwiftUI
import FoveaCore

struct ConnectorsPage: View {
    @Environment(AppModel.self) private var model

    private var connectors: ConnectorsModel { model.connectors }

    var body: some View {
        SettingsPage(title: "Connectors") {
            SettingsSection("Connected", child: .connected) {
                SettingsGroup {
                    if connectors.connected.isEmpty {
                        Text("No connectors yet. Connect one below to deliver captures.")
                            .font(Tokens.Type_.secondary)
                            .foregroundStyle(Tokens.Colors.textSecondary)
                            .padding(Tokens.Space.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(connectors.connected.enumerated()), id: \.element.id) { i, connector in
                        if i > 0 { GroupDivider() }
                        NavigationRow(label: connector.name,
                                      detail: connector.detail,
                                      value: connector.status == .error ? "Needs attention" : "Connected",
                                      leading: { AppGlyph(symbol: connector.symbol, appId: connector.id) }) {
                            model.open(.connectorDetail(connector.id))
                        }
                    }
                }
            }

            SettingsSection("Available", child: .available) {
                SettingsGroup {
                    ForEach(Array(connectors.available.enumerated()), id: \.element.id) { i, connector in
                        if i > 0 { GroupDivider() }
                        SettingsRow(label: connector.name, leading: { AppGlyph(symbol: connector.symbol, appId: connector.id) }) {
                            HStack(spacing: Tokens.Space.m) {
                                if connectors.connecting.contains(connector.id) {
                                    ProgressView().controlSize(.small)
                                    Text("Waiting for \(connector.name)…")
                                        .font(Tokens.Type_.secondary)
                                        .foregroundStyle(Tokens.Colors.textSecondary)
                                    QuietButton(title: "Cancel") { connectors.cancelConnect(connector.id) }
                                } else {
                                    if let error = connectors.connectError[connector.id] {
                                        StatusLabel(text: error, kind: .warning)
                                    }
                                    QuietButton(title: "Connect") { connectors.connect(connector.id) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ConnectorDetailPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.snapshotVariant) private var snapshotVariant
    let connectorId: String
    @State private var confirmDisconnect = false

    private var connectors: ConnectorsModel { model.connectors }

    var body: some View {
        if let connector = connectors.connector(connectorId) {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                // ⌘[ is owned by SettingsSplitView. The hit area reaches left so the arrow lines up with the title.
                BackLink(title: "Connectors", help: "Back to Connectors (⌘[)") { model.back() }
                    .padding(.leading, -Tokens.Space.s)

                SettingsPage(title: connector.name) {
                    SettingsSection("Connection Status") {
                        SettingsGroup {
                            if connector.status == .available {
                                StatusRow(label: "Status", detail: "Connect to deliver captures here.",
                                          status: "Not connected", kind: .neutral,
                                          actionTitle: connectors.connecting.contains(connector.id) ? "Connecting…" : "Connect") {
                                    connectors.connect(connector.id)
                                }
                            } else {
                                StatusRow(label: "Status", detail: connector.detail,
                                          status: connector.status == .error ? "Needs attention" : "Connected",
                                          kind: connector.status == .error ? .warning : .positive)
                            }
                        }
                    }

                    SettingsSection("Permissions") {
                        SettingsGroup {
                            ForEach(Array(connector.permissions.enumerated()), id: \.element) { i, permission in
                                if i > 0 { GroupDivider() }
                                ToggleRow(label: permission,
                                          isOn: Binding(
                                            get: { connector.granted.contains(permission) },
                                            set: { connectors.setPermission(connector.id, permission, granted: $0) }),
                                          disabled: connector.status == .available)
                            }
                        }
                        if connector.status == .available {
                            Text("Permissions apply once the connector is connected.")
                                .font(Tokens.Type_.caption)
                                .foregroundStyle(Tokens.Colors.textTertiary)
                        }
                    }

                    if connector.status != .available {
                        HStack {
                            QuietButton(title: "Disconnect", destructive: true) { confirmDisconnect = true }
                                .confirmationDialog("Disconnect \(connector.name)?",
                                                    isPresented: $confirmDisconnect, titleVisibility: .visible) {
                                    Button("Disconnect", role: .destructive) {
                                        connectors.disconnect(connector.id)
                                        model.back()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("Captures will no longer be delivered to \(connector.name). You can connect it again at any time.")
                                }
                            Spacer()
                        }
                        if snapshotVariant == "disconnect-confirm" {
                            Text("Disconnect \(connector.name)? Captures will no longer be delivered there.")
                                .font(Tokens.Type_.secondary)
                                .foregroundStyle(Tokens.Colors.textSecondary)
                        }
                    }
                }
            }
        } else {
            SettingsPage(title: "Connector") {
                Text("This connector isn’t available.")
                    .font(Tokens.Type_.body)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
    }
}
