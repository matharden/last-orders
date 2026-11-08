import SwiftUI

struct LogSheetView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: LogDraft
    @State private var suggestions: [Drink] = []
    @State private var suppressSuggestions = false
    @State private var saving = false
    @State private var confirmDelete = false

    init(draft: LogDraft) {
        _draft = State(initialValue: draft)
    }

    private var p: Palette { Palette.of(scheme) }
    private var isEditing: Bool { draft.entryID != nil }

    private var estimatedUnits: Double? {
        guard draft.abv != nil, !draft.drink.isEmpty, draft.size > 0, draft.amount > 0 else { return nil }
        return Units.units(drink: draft.drink, size: draft.size, amount: draft.amount, catalog: state.catalog)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                field("What are you having?") {
                    TextField("Drink name or brewery…", text: $draft.drink)
                        .sheetField()
                        .autocorrectionDisabled()
                        .onChange(of: draft.drink) { _, newValue in
                            if suppressSuggestions {
                                suppressSuggestions = false
                                return
                            }
                            draft.abv = nil
                            let q = newValue.lowercased()
                            suggestions = q.isEmpty ? [] : Array(
                                state.catalog.filter {
                                    $0.drink.lowercased().contains(q) || $0.brewery.lowercased().contains(q)
                                }.prefix(5)
                            )
                        }
                    if !suggestions.isEmpty {
                        suggestionList
                    }
                }

                field("Date") {
                    DatePicker("", selection: dateBinding, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(p.amber)
                }

                field("Serving") {
                    HStack(spacing: 8) {
                        ForEach(Units.sizes, id: \.self) { size in
                            Chip(label: Units.sizeLabels[size] ?? "\(size)", selected: draft.size == size) {
                                draft.size = size
                            }
                        }
                    }
                    TextField("Enter ml…", value: $draft.size, format: .number)
                        .keyboardType(.numberPad)
                        .sheetField()
                }

                field("How many?") {
                    HStack(spacing: 8) {
                        ForEach(Units.amounts, id: \.self) { amount in
                            Chip(label: Units.fmtNum(amount), selected: draft.amount == amount) {
                                draft.amount = amount
                            }
                        }
                        TextField("Amount…", value: $draft.amount, format: .number)
                            .keyboardType(.decimalPad)
                            .sheetField()
                    }
                }

                unitsPanel

                field("Notes (optional)") {
                    TextField("e.g. With Sunday roast at the Crown…", text: $draft.notes)
                        .sheetField()
                }

                saveButton
            }
            .padding(20)
            .onSubmit(onReturn)
        }
        .background(p.card)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let entryID = draft.entryID else { return }
                Task {
                    await state.deleteLog(id: entryID)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Edit entry" : "Put it on the tab")
                    .font(.serif(23, .semibold))
                    .foregroundStyle(p.ink)
            }
            Spacer()
            if isEditing {
                Button {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17))
                        .foregroundStyle(p.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label)
            content()
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { s in
                Button {
                    suppressSuggestions = true
                    draft.drink = s.drink
                    draft.abv = s.abv
                    suggestions = []
                } label: {
                    HStack {
                        Text(s.drink)
                            .font(.system(size: 15))
                            .foregroundStyle(p.ink)
                        Spacer()
                        Text("\(s.brewery) · \(Units.fmtNum(s.abv))%")
                            .font(.mono(11))
                            .foregroundStyle(p.ink3)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if s.id != suggestions.last?.id {
                    Divider().overlay(p.line)
                }
            }
        }
        .background(p.paper)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(p.cardEdge, lineWidth: 1))
    }

    private var unitsPanel: some View {
        HStack {
            Text("ESTIMATED UNITS")
                .font(.mono(10, .semibold))
                .tracking(1.8)
                .foregroundStyle(p.ink3)
            Spacer()
            Text(estimatedUnits.map { String(format: "%.1f", $0) } ?? "—")
                .font(.serif(24, .semibold))
                .foregroundStyle(p.amber)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(p.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var canSave: Bool {
        !draft.drink.trimmingCharacters(in: .whitespaces).isEmpty && !saving
    }

    /// Return key: pick the top suggestion if the list is open (so a half-typed
    /// name isn't logged as a new drink), otherwise save.
    private func onReturn() {
        if let first = suggestions.first {
            suppressSuggestions = true
            draft.drink = first.drink
            draft.abv = first.abv
            suggestions = []
        } else {
            submit()
        }
    }

    private func submit() {
        guard canSave else { return }
        saving = true
        Task {
            let ok = await state.saveLog(draft)
            saving = false
            if ok { dismiss() }
        }
    }

    private var saveButton: some View {
        Button(action: submit) {
            Text(saving ? "Saving…" : (isEditing ? "Save changes" : "Log it"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(p.fabGradient)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.4)
        .padding(.top, 8)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { Units.parse(draft.date) ?? Date() },
            set: { draft.date = Units.iso($0) }
        )
    }
}
