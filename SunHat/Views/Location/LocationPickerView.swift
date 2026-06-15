//
//  LocationPickerView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Binding var selectedLocation: ReminderLocation
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search locations", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.searchLocations(searchText)
                        }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if viewModel.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                // Current location option
                Button(action: {
                    selectCurrentLocation()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(AppFontStyle.title3.font)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text("Use device location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedLocation.isCurrentLocation {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
                .buttonStyle(.plain)
                
                // Search results
                List {
                    ForEach(viewModel.searchResults, id: \.self) { result in
                        LocationResultRow(result: result) {
                            selectLocation(result)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                viewModel.searchLocations(newValue)
            } else {
                viewModel.clearResults()
            }
        }
        .alert("Location Search Failed", isPresented: $viewModel.isShowingSearchError) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.searchErrorMessage)
        }
    }
    
    private func selectCurrentLocation() {
        selectedLocation = ReminderLocation.currentLocation
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        Task {
            if let location = await viewModel.resolveLocation(result) {
                selectedLocation = location
                dismiss()
            }
        }
    }
}

#Preview {
    LocationPickerView(selectedLocation: .constant(.currentLocation))
}
