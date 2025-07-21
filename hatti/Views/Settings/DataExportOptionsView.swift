//
//  DataExportOptionsView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DataExportOptionsView: View {
    @ObservedObject var viewModel: DataPrivacyViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeWeatherData = true
    @State private var includeHistoryData = true
    @State private var dateRange: ExportDateRange = .last30Days
    
    var body: some View {
        NavigationView {
            Form {
                // Export Format Section
                Section {
                    Picker("Export Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            HStack {
                                Image(systemName: format.icon)
                                    .foregroundColor(format.color)
                                VStack(alignment: .leading) {
                                    Text(format.displayName)
                                        .font(.body)
                                    Text(format.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                } header: {
                    Label("Export Format", systemImage: "doc.text")
                } footer: {
                    Text("Choose the format for your exported data. JSON is recommended for complete data portability.")
                }
                
                // Data Selection Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Always Included")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ExportDataRow(
                                icon: "bell.fill",
                                title: "Weather Reminders",
                                description: "All your reminders and trigger conditions",
                                isIncluded: true,
                                isRequired: true
                            )
                            
                            ExportDataRow(
                                icon: "gearshape.fill",
                                title: "App Preferences",
                                description: "Settings, notifications, and customizations",
                                isIncluded: true,
                                isRequired: true
                            )
                            
                            ExportDataRow(
                                icon: "location.fill",
                                title: "Location Data",
                                description: "Saved locations and preferences",
                                isIncluded: true,
                                isRequired: true
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optional Data")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ExportDataRow(
                                icon: "cloud.rain.fill",
                                title: "Weather Data Cache",
                                description: "Recent weather information for your locations",
                                isIncluded: includeWeatherData,
                                isRequired: false
                            ) {
                                includeWeatherData.toggle()
                            }
                            
                            ExportDataRow(
                                icon: "clock.fill",
                                title: "History & Analytics",
                                description: "Reminder triggers and usage patterns",
                                isIncluded: includeHistoryData,
                                isRequired: false
                            ) {
                                includeHistoryData.toggle()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                } header: {
                    Label("Data Selection", systemImage: "checkmark.circle")
                } footer: {
                    Text("Choose which data to include in your export. Required data is always included for compliance purposes.")
                }
                
                // Date Range Section (for historical data)
                if includeWeatherData || includeHistoryData {
                    Section {
                        Picker("Date Range", selection: $dateRange) {
                            ForEach(ExportDateRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Text("Estimated Size")
                            Spacer()
                            Text(estimatedExportSize)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        
                    } header: {
                        Label("Date Range", systemImage: "calendar")
                    } footer: {
                        Text("Historical data older than \(dateRange.displayName.lowercased()) will not be included to reduce file size.")
                    }
                }
                
                // Export Actions Section
                Section {
                    Button("Export Data") {
                        Task {
                            await performExport()
                        }
                    }
                    .disabled(viewModel.isExporting)
                    
                    if viewModel.isExporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Preparing export...")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your data will be exported in the selected format and shared through the system share sheet.")
                        
                        if selectedFormat == .json {
                            Text("💡 JSON exports can be imported into other apps or used for backup purposes.")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Privacy Notice Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Privacy Notice")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Export files contain your personal data")
                            Text("• Share only with trusted recipients")
                            Text("• Delete exported files when no longer needed")
                            Text("• We don't track or access your exported data")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                } footer: {
                    Text("This export is provided to comply with GDPR Article 20 (Right to Data Portability) and CCPA requirements.")
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performExport() async {
        switch selectedFormat {
        case .json:
            await viewModel.exportDataAsJSON()
        case .csv:
            await viewModel.exportDataAsCSV()
        }
        
        // Close the sheet after export
        if !viewModel.isExporting && viewModel.errorMessage == nil {
            dismiss()
        }
    }
    
    private var estimatedExportSize: String {
        guard let summary = viewModel.dataSummary else { return "Unknown" }
        
        // Base size for required data
        var estimatedBytes = 1024 * (summary.reminderCount + summary.locationCount)
        
        // Add weather data if included
        if includeWeatherData {
            let weatherMultiplier = dateRange.weatherDataMultiplier
            estimatedBytes += Int(Double(summary.weatherRecordCount) * weatherMultiplier * 2048)
        }
        
        // Add history data if included
        if includeHistoryData {
            estimatedBytes += summary.reminderCount * 512 // Estimated history per reminder
        }
        
        // Format multiplier
        if selectedFormat == .json {
            estimatedBytes = Int(Double(estimatedBytes) * 1.5) // JSON is larger
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(estimatedBytes))
    }
}

// MARK: - Supporting Views

struct ExportDataRow: View {
    let icon: String
    let title: String
    let description: String
    let isIncluded: Bool
    let isRequired: Bool
    let onToggle: (() -> Void)?
    
    init(icon: String, title: String, description: String, isIncluded: Bool, isRequired: Bool, onToggle: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.isIncluded = isIncluded
        self.isRequired = isRequired
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isIncluded ? .blue : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isRequired {
                        Text("Required")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !isRequired {
                Toggle("", isOn: .constant(isIncluded))
                    .labelsHidden()
                    .onTapGesture {
                        onToggle?()
                    }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: CaseIterable {
    case json
    case csv
    
    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        }
    }
    
    var description: String {
        switch self {
        case .json:
            return "Complete structured data, best for backup"
        case .csv:
            return "Spreadsheet format, good for analysis"
        }
    }
    
    var icon: String {
        switch self {
        case .json:
            return "doc.text"
        case .csv:
            return "tablecells"
        }
    }
    
    var color: Color {
        switch self {
        case .json:
            return .blue
        case .csv:
            return .green
        }
    }
}

enum ExportDateRange: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case lastYear
    case allTime
    
    var displayName: String {
        switch self {
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .last90Days:
            return "Last 3 Months"
        case .lastYear:
            return "Last Year"
        case .allTime:
            return "All Time"
        }
    }
    
    var weatherDataMultiplier: Double {
        switch self {
        case .last7Days:
            return 0.1
        case .last30Days:
            return 0.4
        case .last90Days:
            return 0.7
        case .lastYear:
            return 1.0
        case .allTime:
            return 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    DataExportOptionsView(viewModel: DataPrivacyViewModel())
}