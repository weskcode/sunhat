//
//  LocationPickerHeader.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct LocationPickerHeader: View {
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Cancel", action: onCancel)
                .buttonStyle(LocationPickerHeaderButtonStyle())

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                Text("Select Location")
                    .font(AppFontStyle.title3.font)
                    .foregroundStyle(.primary)

                Text("Weather follows this place")
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)

            Spacer(minLength: 8)

            Button("Done", action: onDone)
                .buttonStyle(LocationPickerHeaderButtonStyle(isEmphasized: true))
        }
        .padding(.horizontal, 2)
    }
}

#Preview {
    LocationPickerHeader(onCancel: {}, onDone: {})
        .padding()
}
