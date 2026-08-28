//
//  ReminderIconColorPicker.swift
//  SunHat
//
//  Tappable icon + horizontal color swatch row for personalizing a reminder.
//  Wires up CustomReminder.availableIcons/availableColors, which previously
//  had no picker UI in the streamlined creation flow.
//

import SwiftUI

struct ReminderIconColorPicker: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: Color

    @State private var showingIconPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Button {
                showingIconPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(selectedColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 84, height: 84)
                        .glassEffect(.regular.tint(selectedColor.opacity(0.16)), in: .circle)
                        .contentTransition(.symbolEffect(.replace))

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(selectedColor)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Icon, currently \(reminderIconName(selectedIcon))")
            .accessibilityHint("Double tap to change icon")

            colorSwatchRow
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $selectedIcon, tint: selectedColor)
                .presentationDetents([.medium])
        }
    }

    private var colorSwatchRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CustomReminder.availableColors) { swatch in
                    colorSwatch(swatch)
                }
            }
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color")
    }

    private func colorSwatch(_ swatch: ReminderColor) -> some View {
        let isSelected = swatch.color == selectedColor

        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                selectedColor = swatch.color
            }
        } label: {
            Circle()
                .fill(swatch.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.85), lineWidth: isSelected ? 2 : 0)
                        .padding(-3)
                )
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    let tint: Color
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CustomReminder.availableIcons, id: \.self) { icon in
                        iconTile(icon)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose an Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func iconTile(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon

        return Button {
            selectedIcon = icon
            dismiss()
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(isSelected ? tint : Color(.tertiarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(reminderIconName(icon))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private func reminderIconName(_ symbol: String) -> String {
    switch symbol {
    case "figure.walk": String(localized: "Walking", comment: "Reminder icon activity name")
    case "figure.run": String(localized: "Running", comment: "Reminder icon activity name")
    case "figure.hiking": String(localized: "Hiking", comment: "Reminder icon activity name")
    case "bicycle", "figure.outdoor.cycle": String(localized: "Cycling", comment: "Reminder icon activity name")
    case "leaf.fill": String(localized: "Gardening", comment: "Reminder icon activity name")
    case "tree.fill": String(localized: "Trees", comment: "Reminder icon activity name")
    case "drop.fill": String(localized: "Water", comment: "Reminder icon activity name")
    case "flame.fill": String(localized: "Fire", comment: "Reminder icon activity name")
    case "snowflake": String(localized: "Snow", comment: "Reminder icon activity name")
    case "tennis.racket", "figure.tennis": String(localized: "Tennis", comment: "Reminder icon activity name")
    case "figure.golf": String(localized: "Golf", comment: "Reminder icon activity name")
    case "figure.yoga": String(localized: "Yoga", comment: "Reminder icon activity name")
    case "dumbbell.fill": String(localized: "Fitness", comment: "Reminder icon activity name")
    case "camera.fill": String(localized: "Photography", comment: "Reminder icon activity name")
    case "paintbrush.fill": String(localized: "Painting", comment: "Reminder icon activity name")
    case "pencil.and.outline": String(localized: "Writing", comment: "Reminder icon activity name")
    case "music.note": String(localized: "Music", comment: "Reminder icon activity name")
    case "book.fill": String(localized: "Reading", comment: "Reminder icon activity name")
    case "basket.fill": String(localized: "Picnic", comment: "Reminder icon activity name")
    case "cart.fill": String(localized: "Shopping", comment: "Reminder icon activity name")
    case "cup.and.saucer.fill": String(localized: "Coffee", comment: "Reminder icon activity name")
    case "takeoutbag.and.cup.and.straw.fill": String(localized: "Takeout", comment: "Reminder icon activity name")
    case "briefcase.fill": String(localized: "Work", comment: "Reminder icon activity name")
    case "laptopcomputer": String(localized: "Laptop", comment: "Reminder icon activity name")
    case "desktopcomputer": String(localized: "Computer", comment: "Reminder icon activity name")
    case "note.text": String(localized: "Notes", comment: "Reminder icon activity name")
    case "dog.fill": String(localized: "Dog", comment: "Reminder icon activity name")
    case "cat.fill": String(localized: "Cat", comment: "Reminder icon activity name")
    case "bird.fill": String(localized: "Bird", comment: "Reminder icon activity name")
    case "fish.fill": String(localized: "Fish", comment: "Reminder icon activity name")
    case "car.fill": String(localized: "Driving", comment: "Reminder icon activity name")
    case "bus.fill": String(localized: "Bus", comment: "Reminder icon activity name")
    case "airplane": String(localized: "Flight", comment: "Reminder icon activity name")
    case "sailboat.fill": String(localized: "Sailing", comment: "Reminder icon activity name")
    case "house.fill": String(localized: "Home", comment: "Reminder icon activity name")
    case "lightbulb.fill": String(localized: "Idea", comment: "Reminder icon activity name")
    case "wrench.and.screwdriver.fill": String(localized: "Maintenance", comment: "Reminder icon activity name")
    case "hammer.fill": String(localized: "Projects", comment: "Reminder icon activity name")
    case "star.fill": String(localized: "Favorite", comment: "Reminder icon activity name")
    case "heart.fill": String(localized: "Heart", comment: "Reminder icon activity name")
    case "flag.fill": String(localized: "Flag", comment: "Reminder icon activity name")
    case "bell.fill": String(localized: "Reminder", comment: "Reminder icon activity name")
    default: String(localized: "Activity", comment: "Reminder icon activity name")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var icon = "figure.walk"
    @Previewable @State var color: Color = .blue

    return ReminderIconColorPicker(selectedIcon: $icon, selectedColor: $color)
        .padding()
}
