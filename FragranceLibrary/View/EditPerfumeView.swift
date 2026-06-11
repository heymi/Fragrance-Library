import SwiftUI
import SwiftData

struct EditPerfumeView: View {
    let perfume: Perfume

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var brand: String
    @State private var name: String
    @State private var concentration: String
    @State private var volume: String
    @State private var notes: String
    @State private var radarElder: Double
    @State private var radarDate: Double
    @State private var radarGirlApproved: Double
    @State private var radarOffice: Double
    @State private var radarSelf: Double
    @State private var radarImpression: Double
    @State private var strategyLine: String
    @State private var validationMessage: String?
    @State private var saveFailed = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case brand, name, concentration, volume, notes
    }

    private var trimmedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedBrand.isEmpty || !trimmedName.isEmpty
    }

    init(perfume: Perfume) {
        self.perfume = perfume
        _brand = State(initialValue: perfume.brand)
        _name = State(initialValue: perfume.name)
        _concentration = State(initialValue: perfume.concentration)
        _volume = State(initialValue: perfume.volume)
        _notes = State(initialValue: perfume.notes)
        _radarElder = State(initialValue: perfume.radarElder)
        _radarDate = State(initialValue: perfume.radarDate)
        _radarGirlApproved = State(initialValue: perfume.radarGirlApproved)
        _radarOffice = State(initialValue: perfume.radarOffice)
        _radarSelf = State(initialValue: perfume.radarSelf)
        _radarImpression = State(initialValue: perfume.radarImpression)
        _strategyLine = State(initialValue: perfume.strategyLine)
    }

    var body: some View {
        ZStack {
            PerfumePaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        fieldRow(
                            label: "Brand",
                            subtitle: "House or maker",
                            icon: "building.2",
                            text: $brand,
                            field: .brand
                        )

                        fieldRow(
                            label: "Name",
                            subtitle: "Perfume name",
                            icon: "sparkles",
                            text: $name,
                            field: .name
                        )

                        fieldRow(
                            label: "Concentration",
                            subtitle: "EDT, EDP, Parfum",
                            icon: "drop",
                            text: $concentration,
                            field: .concentration
                        )

                        fieldRow(
                            label: "Volume",
                            subtitle: "30ml, 50ml, 100ml",
                            icon: "cylinder",
                            text: $volume,
                            field: .volume
                        )

                        fieldRow(
                            label: "Notes",
                            subtitle: "Memory, season, impression",
                            icon: "pencil.line",
                            text: $notes,
                            field: .notes,
                            isMultiline: true
                        )
                    }

                    // Scene compass
                    VStack(alignment: .leading, spacing: 14) {
                        Divider().background(Color.perfumeBorder)

                        Text("SCENE COMPASS")
                            .font(PerfumeType.label(10))
                            .tracking(2.2)
                            .foregroundStyle(Color.perfumeTextSecondary)

                        radarSlider(icon: "👴", label: "长辈好感", value: $radarElder)
                        radarSlider(icon: "💕", label: "约会引力", value: $radarDate)
                        radarSlider(icon: "👯", label: "闺蜜推荐", value: $radarGirlApproved)
                        radarSlider(icon: "💼", label: "职场安全", value: $radarOffice)
                        radarSlider(icon: "🧘", label: "独处疗愈", value: $radarSelf)
                        radarSlider(icon: "✨", label: "初见印象", value: $radarImpression)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Strategy line")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.perfumeTextSecondary)
                                Spacer()
                                Text("\(strategyLine.count)/12")
                                    .font(.caption)
                                    .foregroundStyle(strategyLine.count > 12 ? Color.perfumeDanger : Color.perfumeTextSecondary.opacity(0.6))
                            }
                            TextField("通勤隐形盔甲", text: $strategyLine)
                                .font(.body)
                                .foregroundStyle(Color.perfumeText)
                                .onChange(of: strategyLine) { _, new in
                                    if new.count > 12 { strategyLine = String(new.prefix(12)) }
                                }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.perfumeCard)
                        )
                    }

                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.perfumeDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: save) {
                        Text("Save Changes")
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.48)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(Color.perfumeTextSecondary)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .sensoryFeedback(.error, trigger: saveFailed) { _, new in new }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERFUME RECORD")
                .font(.caption.weight(.semibold))
                .tracking(2.3)
                .foregroundStyle(Color.perfumeAccent)

            Text("Refine the archive")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Color.perfumeText)

            Text("Keep the record useful and personal. Brand or name is required; everything else can stay beautifully minimal.")
                .font(.footnote)
                .foregroundStyle(Color.perfumeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldRow(
        label: String,
        subtitle: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        isMultiline: Bool = false
    ) -> some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(focusedField == field ? Color.perfumeAccent : Color.perfumeTextSecondary)
                .frame(width: 24)
                .padding(.top, isMultiline ? 10 : 0)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.perfumeText)

                    Spacer()

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.perfumeTextSecondary.opacity(0.78))
                }

                TextField(label, text: text, axis: isMultiline ? .vertical : .horizontal)
                    .lineLimit(isMultiline ? 3...6 : 1...1)
                    .font(.body)
                    .foregroundStyle(Color.perfumeText)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: field)
                    .onChange(of: text.wrappedValue) { _, _ in
                        validationMessage = nil
                    }
            }
        }
        .padding(14)
        .background(Color.perfumeCard.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    focusedField == field ? Color.perfumeAccent.opacity(0.72) : Color.perfumeBorder,
                    lineWidth: focusedField == field ? 1.2 : 1
                )
        )
    }

    private func radarSlider(icon: String, label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.perfumeTextSecondary)
                .frame(width: 56, alignment: .leading)

            Slider(value: value, in: 0...5, step: 0.5)
                .tint(Color.perfumeAccent)

            Text(String(format: "%.1f", value.wrappedValue))
                .font(.caption.weight(.semibold))
                .foregroundStyle(value.wrappedValue > 0 ? Color.perfumeAccent : Color.perfumeTextSecondary.opacity(0.5))
                .frame(width: 28, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.perfumeCard)
        )
    }

    private func save() {
        guard canSave else {
            validationMessage = "Add at least a brand or perfume name before saving."
            saveFailed.toggle()
            focusedField = trimmedBrand.isEmpty ? .brand : .name
            Haptic.error()
            return
        }

        perfume.brand = trimmedBrand
        perfume.name = trimmedName
        perfume.concentration = concentration.trimmingCharacters(in: .whitespacesAndNewlines)
        perfume.volume = volume.trimmingCharacters(in: .whitespacesAndNewlines)
        perfume.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        perfume.radarElder = radarElder
        perfume.radarDate = radarDate
        perfume.radarGirlApproved = radarGirlApproved
        perfume.radarOffice = radarOffice
        perfume.radarSelf = radarSelf
        perfume.radarImpression = radarImpression
        perfume.strategyLine = strategyLine.trimmingCharacters(in: .whitespacesAndNewlines)
        perfume.updatedAt = Date()

        do {
            try modelContext.save()
            Haptic.success()
            dismiss()
        } catch {
            validationMessage = "Could not save changes. Please try again."
            saveFailed.toggle()
            Haptic.error()
        }
    }
}

#Preview {
    NavigationStack {
        EditPerfumeView(perfume: Perfume(
            brand: "Chanel",
            name: "Bleu de Chanel",
            concentration: "EDP",
            volume: "100ml",
            notes: "My signature scent."
        ))
    }
    .modelContainer(for: Perfume.self, inMemory: true)
}
