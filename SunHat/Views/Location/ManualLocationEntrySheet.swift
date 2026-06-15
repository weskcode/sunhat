//
//  ManualLocationEntrySheet.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import CoreLocation
import SwiftUI

struct ManualLocationEntrySheet: View {
    @ObservedObject var viewModel: LocationManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var locationName: String = ""
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, latitude, longitude
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                locationDetailsSection
                currentLocationSection
                examplesSection
            }
            .navigationTitle("Enter Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                    .bold()
                    .disabled(!isValidInput)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .alert("Invalid Coordinates", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                focusedField = .name
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manual Location Entry")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Enter coordinates for a custom location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var locationDetailsSection: some View {
        Section("Location Details") {
            TextField("Location Name", text: $locationName)
                .focused($focusedField, equals: .name)
                .textContentType(.addressCity)

            HStack {
                Text("Latitude")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("e.g., 37.7749", text: $latitudeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .latitude)
            }

            HStack {
                Text("Longitude")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("e.g., -122.4194", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .longitude)
            }
        }
    }

    private var currentLocationSection: some View {
        Section {
            Button("Use Current Location") {
                useCurrentLocation()
            }
            .disabled(viewModel.currentLocation == nil)
        } footer: {
            Text("Latitude ranges from -90 to 90. Longitude ranges from -180 to 180.")
        }
    }

    private var examplesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ExampleLocationRow(name: "San Francisco", lat: "37.7749", lon: "-122.4194") {
                    fillExample(name: "San Francisco", lat: "37.7749", lon: "-122.4194")
                }

                ExampleLocationRow(name: "New York", lat: "40.7128", lon: "-74.0060") {
                    fillExample(name: "New York", lat: "40.7128", lon: "-74.0060")
                }

                ExampleLocationRow(name: "London", lat: "51.5074", lon: "-0.1278") {
                    fillExample(name: "London", lat: "51.5074", lon: "-0.1278")
                }

                ExampleLocationRow(name: "Tokyo", lat: "35.6762", lon: "139.6503") {
                    fillExample(name: "Tokyo", lat: "35.6762", lon: "139.6503")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var isValidInput: Bool {
        guard !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        guard let lat = Double(latitudeText),
              let lon = Double(longitudeText),
              lat >= -90 && lat <= 90,
              lon >= -180 && lon <= 180 else {
            return false
        }

        return true
    }

    private func useCurrentLocation() {
        guard let location = viewModel.currentLocation else { return }

        latitudeText = String(format: "%.6f", location.coordinate.latitude)
        longitudeText = String(format: "%.6f", location.coordinate.longitude)

        if locationName.isEmpty {
            locationName = viewModel.currentLocationName
        }
    }

    private func fillExample(name: String, lat: String, lon: String) {
        locationName = name
        latitudeText = lat
        longitudeText = lon
    }

    private func saveLocation() {
        guard let lat = Double(latitudeText),
              let lon = Double(longitudeText) else {
            errorMessage = "Please enter valid numeric coordinates."
            showingError = true
            return
        }

        guard lat >= -90 && lat <= 90 else {
            errorMessage = "Latitude must be between -90 and 90 degrees."
            showingError = true
            return
        }

        guard lon >= -180 && lon <= 180 else {
            errorMessage = "Longitude must be between -180 and 180 degrees."
            showingError = true
            return
        }

        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a location name."
            showingError = true
            return
        }

        let savedLocation = SavedLocation(
            latitude: lat,
            longitude: lon,
            name: trimmedName,
            source: .manual
        )

        viewModel.addSavedLocation(savedLocation)
        dismiss()
    }
}

private struct ExampleLocationRow: View {
    let name: String
    let lat: String
    let lon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(lat), \(lon)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
