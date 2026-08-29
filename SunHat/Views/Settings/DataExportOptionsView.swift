//
//  DataExportOptionsView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DataExportOptionsView: View {
    @State var viewModel: DataPrivacyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .json

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedFormat.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Export Format")
                }

                Section {
                    Label("Reminders and trigger conditions", systemImage: "bell")

                    // The CSV format contains reminders only; listing more here
                    // would overstate the export on a data-portability surface.
                    if selectedFormat == .json {
                        Label("Preferences and notification settings", systemImage: "gearshape")
                        Label("Saved locations", systemImage: "location")
                        Label("Reminder history and related records", systemImage: "clock")
                    }
                } header: {
                    Text("Included Data")
                } footer: {
                    Text("This export is provided to comply with GDPR Article 20 (Right to Data Portability) and CCPA requirements.")
                }

                Section {
                    Button("Export Data", systemImage: "square.and.arrow.up") {
                        Task { await performExport() }
                    }
                    .disabled(viewModel.isExporting)

                    if viewModel.isExporting {
                        HStack {
                            Text("Preparing export")
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text("The exported file may contain personal information. Store and share it carefully.")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Export Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func performExport() async {
        switch selectedFormat {
        case .json:
            await viewModel.exportDataAsJSON()
        case .csv:
            await viewModel.exportDataAsCSV()
        }
        // The share sheet is presented on top of this sheet, so dismissing here
        // would tear it down. The user closes this screen with Cancel when done.
    }
}

enum ExportFormat: CaseIterable {
    case json
    case csv

    var displayName: String {
        switch self {
        case .json: "JSON"
        case .csv: "CSV"
        }
    }

    var description: String {
        switch self {
        case .json: "A complete structured export suitable for backup or transfer."
        case .csv: "A spreadsheet-compatible export of reminder data."
        }
    }
}

#Preview {
    DataExportOptionsView(viewModel: DataPrivacyViewModel())
}
