//
//  LocationMapView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import CoreLocation
import MapKit
import SwiftUI

struct LocationMapView: View {
    @ObservedObject var viewModel: LocationManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(mapAnnotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        VStack {
                            Image(systemName: annotation.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(annotation.color)
                                .clipShape(Circle())
                                .shadow(radius: 4)

                            Text(annotation.title)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .glassEffect(in: .rect(cornerRadius: 4))
                        }
                    }
                }
            }
            .navigationTitle("Locations Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }

    private var mapAnnotations: [CustomMapAnnotation] {
        var annotations: [CustomMapAnnotation] = []

        if let currentLocation = viewModel.currentLocation {
            annotations.append(CustomMapAnnotation(
                coordinate: currentLocation.coordinate,
                title: "Current",
                icon: "location.fill",
                color: .blue
            ))
        }

        for location in viewModel.savedLocations {
            annotations.append(CustomMapAnnotation(
                coordinate: location.coordinate,
                title: location.displayName,
                icon: location.isFavorite ? "heart.fill" : "bookmark.fill",
                color: location.isFavorite ? .red : .green
            ))
        }

        return annotations
    }

    private func setupMapRegion() {
        var coordinates: [CLLocationCoordinate2D] = []

        if let currentLocation = viewModel.currentLocation {
            coordinates.append(currentLocation.coordinate)
        }

        coordinates.append(contentsOf: viewModel.savedLocations.map { $0.coordinate })

        if !coordinates.isEmpty {
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let span = MKCoordinateSpan(
                latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
                longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
            )

            let newRegion = MKCoordinateRegion(center: center, span: span)
            cameraPosition = MapCameraPosition.region(newRegion)
        }
    }
}

private struct CustomMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let icon: String
    let color: Color
}
