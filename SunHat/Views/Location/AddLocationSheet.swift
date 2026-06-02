//
//  AddLocationSheet.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import MapKit
import SwiftUI

struct AddLocationSheet: View {
    @ObservedObject var viewModel: LocationManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
                viewModel.searchText = searchText
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search for a location", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit { }

            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.searchResults.isEmpty {
            List {
                ForEach(viewModel.searchResults, id: \.self) { result in
                    SearchResultRow(result: result) {
                        viewModel.resolveSearchResult(result)
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)

                Text("Search for locations")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Enter a city name, address, or point of interest to add it to your saved locations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SearchResultRow: View {
    let result: MKLocalSearchCompletion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle")
                    .font(.title3)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
