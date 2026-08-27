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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                    LocationPickerSearchField(
                        searchText: $searchText,
                        isSearching: viewModel.isSearching,
                        onSubmit: submitSearch
                    )
                    .padding(.horizontal, 16)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            LocationPickerCurrentLocationCard(
                                isSelected: selectedLocation.isCurrentLocation,
                                onSelect: selectCurrentLocation
                            )

                            locationResultsContent
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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

    @ViewBuilder
    private var locationResultsContent: some View {
        if viewModel.searchResults.isEmpty {
            LocationPickerEmptyGuidance(hasSearchText: !searchText.isEmpty)
                .transition(SunHatMotion.transition(reduceMotion: reduceMotion))
        } else {
            ForEach(viewModel.searchResults, id: \.self) { result in
                LocationResultRow(result: result) {
                    selectLocation(result)
                }
            }
        }
    }

    private func submitSearch() {
        viewModel.searchLocations(searchText)
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
