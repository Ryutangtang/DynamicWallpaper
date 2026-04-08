import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AnimationController

    var body: some View {
        Form {
            // MARK: Preset
            Section {
                Picker("Preset", selection: $controller.currentPreset) {
                    ForEach(AnimationPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Animation").font(.headline)
            }

            Divider()

            // MARK: Speed
            Section {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%.1fx", controller.speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $controller.speed, in: 0.1...3.0, step: 0.1) {
                    EmptyView()
                } minimumValueLabel: {
                    Text("0.1x").font(.caption).foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("3.0x").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            // MARK: Playback
            Section {
                Toggle("Run animation", isOn: $controller.isRunning)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 340)
    }
}
