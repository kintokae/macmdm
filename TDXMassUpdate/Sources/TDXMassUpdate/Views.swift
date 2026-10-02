import SwiftUI

// MARK: - Main window

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var showConnection = false
    @State private var showTemplate = false
    @State private var confirmLiveRun = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VSplitView {
                RowsTable()
                    .frame(minHeight: 220)
                LogView()
                    .frame(minHeight: 110, idealHeight: 160)
            }
            Divider()
            footer
        }
        .sheet(isPresented: $showConnection) {
            ConnectionView(isSheet: true).environmentObject(model)
        }
        .sheet(isPresented: $showTemplate) {
            TemplateView().environmentObject(model)
        }
        .confirmationDialog("Update \(model.pendingCount) assets in TeamDynamix?",
                            isPresented: $confirmLiveRun) {
            Button("Update Assets", role: .destructive) { model.startRun() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This writes to your live TDX environment and can't be undone. Run a dry run first if you haven't.")
        }
        .onAppear {
            if !model.isConfigured { showConnection = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showConnection = true
                } label: {
                    Label(model.connectionOK ? "Connected" : "Connection…",
                          systemImage: model.connectionOK ? "checkmark.circle.fill" : "network")
                }
                .foregroundStyle(model.connectionOK ? Color.green : Color.primary)
                .help("TeamDynamix URL, app ID and credentials")

                Divider().frame(height: 20)

                Picker("Identify assets by", selection: $model.identifierType) {
                    ForEach(IdentifierType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .disabled(model.isRunning)

                Spacer()

                Button("Download Template…") { showTemplate = true }
                Button("Open CSV…") { model.chooseCSV() }
                    .disabled(model.isRunning)
            }

            if let name = model.csvFileName {
                Text("\(name): \(model.rows.count) rows, columns: \(model.headers.joined(separator: ", "))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("Open a CSV whose first column is the \(model.identifierType.rawValue.lowercased()) and whose other columns are the fields to change. Blank cells are left alone; CLEAR! empties a field.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !model.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.issues) { issue in
                        IssueRow(issue: issue)
                    }
                }
            }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Dry run (preview changes only)", isOn: $model.dryRun)
                .disabled(model.isRunning)

            if model.isRunning || model.processedCount > 0 {
                ProgressView(value: model.progress)
                    .frame(width: 160)
                Text("\(model.processedCount) of \(model.totalToProcess)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(model.statusSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Export Results…") { model.exportResults() }
                .disabled(model.rows.isEmpty || model.isRunning)
            Button("Reset") { model.preflight() }
                .disabled(model.rows.isEmpty || model.isRunning)
                .help("Re-run pre-flight checks and clear row results")

            if model.isRunning {
                Button("Cancel", role: .cancel) { model.cancelRun() }
                    .keyboardShortcut(.cancelAction)
            } else {
                Button(model.dryRun ? "Preview Changes" : "Update Assets") {
                    if model.dryRun { model.startRun() } else { confirmLiveRun = true }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canRun)
            }
        }
        .padding(12)
    }
}

struct IssueRow: View {
    let issue: Issue
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(issue.text).font(.callout).textSelection(.enabled)
        }
    }
    private var icon: String {
        switch issue.severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "checkmark.seal.fill"
        }
    }
    private var color: Color {
        switch issue.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .green
        }
    }
}

// MARK: - Rows table

struct RowsTable: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        Table(model.rows) {
            TableColumn("Line") { row in
                Text("\(row.lineNumber)").monospacedDigit().foregroundStyle(.secondary)
            }
            .width(48)
            TableColumn(model.identifierType.rawValue) { row in
                Text(row.identifier).textSelection(.enabled)
            }
            .width(min: 100, ideal: 150)
            TableColumn("Values from CSV") { row in
                Text(row.summary).lineLimit(1).help(row.summary)
            }
            .width(min: 160, ideal: 280)
            TableColumn("Status") { row in
                StatusBadge(status: row.status)
            }
            .width(90)
            TableColumn("Message") { row in
                Text(row.message).lineLimit(1).help(row.message).textSelection(.enabled)
            }
            .width(min: 160, ideal: 360)
        }
        .overlay {
            if model.rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tablecells").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("No CSV loaded").font(.headline)
                    Text("Open a CSV to check it before anything is sent to TDX.")
                        .foregroundStyle(.secondary)
                    Button("Open CSV…") { model.chooseCSV() }
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: RowStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
    private var color: Color {
        switch status {
        case .pending: return .secondary
        case .invalid: return .red
        case .running: return .blue
        case .skipped: return .gray
        case .dryRun: return .purple
        case .success: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Log

struct LogView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.log) { entry in
                        Text("\(entry.timestamp)  \(entry.text)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color(entry.level))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: model.log.count) { _ in
                if let last = model.log.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(_ level: LogEntry.Level) -> Color {
        switch level {
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Connection

struct ConnectionView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let isSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TeamDynamix connection").font(.title2.weight(.semibold))

            Form {
                TextField("Web API URL", text: $model.baseURL,
                          prompt: Text("https://yourorg.teamdynamix.com/TDWebApi"))
                TextField("Assets app ID", text: $model.appID, prompt: Text("e.g. 42"))
                Picker("Sign in with", selection: $model.authMode) {
                    ForEach(AuthMode.allCases) { Text($0.rawValue).tag($0) }
                }
                if model.authMode == .user {
                    TextField("Username", text: $model.username)
                    SecureField("Password", text: $model.password)
                } else {
                    TextField("BEID", text: $model.beid)
                    SecureField("Web services key", text: $model.webServicesKey)
                }
                Stepper("Requests per minute: \(model.requestsPerMinute)",
                        value: $model.requestsPerMinute, in: 10...600, step: 10)
            }

            Text("Use /SBTDWebApi to test against your sandbox. Secrets are stored in your login keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Verify Connection") { model.verifyConnection() }
                    .disabled(model.isVerifying)
                if model.isVerifying { ProgressView().controlSize(.small) }
                Text(model.connectionMessage)
                    .font(.callout)
                    .foregroundStyle(model.connectionOK ? Color.green : Color.secondary)
                    .lineLimit(2)
                Spacer()
                if isSheet {
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }

            if !model.assetStatuses.isEmpty {
                GroupBox("Asset status IDs (for the StatusID column)") {
                    List(model.assetStatuses) { s in
                        HStack {
                            Text(s.name)
                            Spacer()
                            Text("\(s.id)").monospacedDigit().foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    .frame(height: 150)
                }
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}

// MARK: - Template

struct TemplateView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = ["Name", "StatusID", "LocationID"]
    @State private var attributeIDs = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Download CSV template").font(.title2.weight(.semibold))
            Text("The first column will be \(model.identifierType.csvHeader). Pick the fields you want to change.")
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 6) {
                    ForEach(AssetFields.standard) { f in
                        Toggle(f.header, isOn: binding(for: f.header))
                            .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(height: 230)

            TextField("Custom attribute IDs, comma separated", text: $attributeIDs,
                      prompt: Text("e.g. 10234, 10235"))
            Text("Each becomes an Attribute:<ID> column. For choice attributes, enter the choice ID as the value.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Template…") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty && parsedAttributes.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private var parsedAttributes: [String] {
        attributeIDs.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map { "Attribute:\($0)" }
    }

    private func binding(for header: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(header) },
            set: { on in if on { selected.insert(header) } else { selected.remove(header) } }
        )
    }

    private func save() {
        let fields = AssetFields.standard.map(\.header).filter { selected.contains($0) }
        if model.saveTemplate(columns: fields + parsedAttributes) { dismiss() }
    }
}
