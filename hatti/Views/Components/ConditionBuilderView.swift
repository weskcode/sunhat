import SwiftUI

// MARK: - Condition Builder View
struct ConditionBuilderView: View {
    @State private var condition = WeatherConditionBuilderModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create a Weather Condition")
                .font(.title2)
                .fontWeight(.bold)

            ConditionTypePicker(selection: $condition.type)
            
            TemperatureSelector(condition: $condition)

            TimeOfDayRestriction(condition: $condition)
            
            PreviewTextView(condition: condition)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Data Model
struct WeatherConditionBuilderModel {
    enum ConditionType: String, CaseIterable, Identifiable {
        case exact = "Exact"
        case range = "Range"
        case consecutiveDays = "Consecutive Days"
        
        var id: String { self.rawValue }
    }
    
    var type: ConditionType = .exact
    var temperature: Double = 20
    var temperatureRange: ClosedRange<Double> = 15...25
    var timeRestrictionEnabled = false
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600)
    var consecutiveDays: Int = 2
}

// MARK: - Subcomponents
struct ConditionTypePicker: View {
    @Binding var selection: WeatherConditionBuilderModel.ConditionType
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Condition Type")
                .font(.headline)
            Picker("Condition Type", selection: $selection) {
                ForEach(WeatherConditionBuilderModel.ConditionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityLabel("Select the type of weather condition.")
        }
    }
}

struct TemperatureSelector: View {
    @Binding var condition: WeatherConditionBuilderModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Temperature")
                .font(.headline)
            
            if condition.type == .exact {
                HStack {
                    Slider(value: $condition.temperature, in: -20...40, step: 1)
                        .accessibilityLabel("Temperature slider")
                    Text("\(Int(condition.temperature))°C")
                        .frame(width: 50)
                }
            } else {
                Text("Coming soon for range and consecutive days")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct TimeOfDayRestriction: View {
    @Binding var condition: WeatherConditionBuilderModel

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $condition.timeRestrictionEnabled) {
                Text("Time of Day Restriction")
                    .font(.headline)
            }
            .accessibilityHint("Enable to restrict the trigger to a specific time range.")

            if condition.timeRestrictionEnabled {
                HStack {
                    DatePicker("Start", selection: $condition.startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $condition.endTime, displayedComponents: .hourAndMinute)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Time restriction range. From \(condition.startTime, style: .time) to \(condition.endTime, style: .time)")
            }
        }
    }
}

struct PreviewTextView: View {
    let condition: WeatherConditionBuilderModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Summary")
                .font(.headline)
            Text(generatePreviewText())
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
        }
    }
    
    private func generatePreviewText() -> String {
        var text = "Notify me when the temperature is "
        
        switch condition.type {
        case .exact:
            text += "exactly \(Int(condition.temperature))°C"
        case .range:
            text += "between \(Int(condition.temperatureRange.lowerBound))°C and \(Int(condition.temperatureRange.upperBound))°C"
        case .consecutiveDays:
            text += "around \(Int(condition.temperature))°C for \(condition.consecutiveDays) consecutive days"
        }
        
        if condition.timeRestrictionEnabled {
            let startTimeStr = condition.startTime.formatted(date: .omitted, time: .shortened)
            let endTimeStr = condition.endTime.formatted(date: .omitted, time: .shortened)
            text += " between \(startTimeStr) and \(endTimeStr)."
        }
        
        return text
    }
}

// MARK: - Preview
#if DEBUG
struct ConditionBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        ConditionBuilderView()
    }
}
#endif