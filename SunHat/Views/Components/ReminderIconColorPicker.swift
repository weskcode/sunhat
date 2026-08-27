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
    case "figure.walk": "Walking"
    case "figure.run": "Running"
    case "figure.hiking": "Hiking"
    case "bicycle", "figure.outdoor.cycle": "Cycling"
    case "leaf.fill": "Gardening"
    case "tree.fill": "Trees"
    case "drop.fill": "Water"
    case "flame.fill": "Fire"
    case "snowflake": "Snow"
    case "tennis.racket", "figure.tennis": "Tennis"
    case "figure.golf": "Golf"
    case "figure.yoga": "Yoga"
    case "dumbbell.fill": "Fitness"
    case "camera.fill": "Photography"
    case "paintbrush.fill": "Painting"
    case "pencil.and.outline": "Writing"
    case "music.note": "Music"
    case "book.fill": "Reading"
    case "basket.fill": "Picnic"
    case "cart.fill": "Shopping"
    case "cup.and.saucer.fill": "Coffee"
    case "takeoutbag.and.cup.and.straw.fill": "Takeout"
    case "briefcase.fill": "Work"
    case "laptopcomputer": "Laptop"
    case "desktopcomputer": "Computer"
    case "note.text": "Notes"
    case "dog.fill": "Dog"
    case "cat.fill": "Cat"
    case "bird.fill": "Bird"
    case "fish.fill": "Fish"
    case "car.fill": "Driving"
    case "bus.fill": "Bus"
    case "airplane": "Flight"
    case "sailboat.fill": "Sailing"
    case "house.fill": "Home"
    case "lightbulb.fill": "Idea"
    case "wrench.and.screwdriver.fill": "Maintenance"
    case "hammer.fill": "Projects"
    case "star.fill": "Favorite"
    case "heart.fill": "Heart"
    case "flag.fill": "Flag"
    case "bell.fill": "Reminder"
    default: "Activity"
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var icon = "figure.walk"
    @Previewable @State var color: Color = .blue

    return ReminderIconColorPicker(selectedIcon: $icon, selectedColor: $color)
        .padding()
}
