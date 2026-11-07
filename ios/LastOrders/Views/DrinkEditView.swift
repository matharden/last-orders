import SwiftUI
import PhotosUI

struct DrinkEditView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let drink: Drink

    @State private var brewery: String
    @State private var name: String
    @State private var abvText: String
    @State private var rating: Int
    @State private var image: String
    @State private var notes: String

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var deleteError: String?

    init(drink: Drink) {
        self.drink = drink
        _brewery = State(initialValue: drink.brewery)
        _name = State(initialValue: drink.drink)
        _abvText = State(initialValue: drink.abv > 0 ? Units.fmtNum(drink.abv) : "")
        _rating = State(initialValue: drink.rating)
        _image = State(initialValue: drink.image)
        _notes = State(initialValue: drink.notes)
    }

    private var p: Palette { Palette.of(scheme) }

    private var isUsedInLog: Bool {
        state.log.contains { $0.drink.lowercased() == drink.drink.lowercased() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                field("Brewery") {
                    TextField("e.g. Beavertown", text: $brewery).sheetField()
                }
                field("Drink") {
                    TextField("e.g. Neck Oil", text: $name).sheetField()
                }
                field("ABV %") {
                    TextField("4.3", text: $abvText)
                        .keyboardType(.decimalPad)
                        .sheetField()
                }
                field("Rating") {
                    ratingStars
                }
                field("Image") {
                    imageSection
                }
                field("Notes") {
                    TextField("e.g. Seasonal, limited edition…", text: $notes).sheetField()
                }

                saveButton
            }
            .padding(20)
            .onSubmit(submit)
        }
        .background(p.card)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete \"\(drink.drink)\" from the cellar?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if let error = await state.deleteCatalog(id: drink.id) {
                        deleteError = error
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .alert("Couldn't delete", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit beer")
                    .font(.serif(23, .semibold))
                    .foregroundStyle(p.ink)
                Text("Update the catalogue entry.")
                    .font(.system(size: 14))
                    .foregroundStyle(p.ink2)
            }
            Spacer()
            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17))
                    .foregroundStyle(p.ink3)
                    .opacity(isUsedInLog ? 0.3 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isUsedInLog)
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

    private var ratingStars: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    rating = rating == n ? 0 : n
                } label: {
                    Text(n <= rating ? "★" : "☆")
                        .font(.system(size: 26))
                        .foregroundStyle(n <= rating ? p.gold : p.ink3.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            if rating > 0 {
                Text("\(rating)/5")
                    .font(.mono(11))
                    .foregroundStyle(p.ink3)
                    .padding(.leading, 6)
            }
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if photoData != nil || !image.isEmpty {
            HStack(spacing: 12) {
                Group {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage).resizable().scaledToFill()
                    } else if let url = URL(string: image), !image.isEmpty {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            p.paper2
                        }
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Button("✕ Remove") {
                    image = ""
                    photoData = nil
                    photoItem = nil
                }
                .font(.system(size: 12))
                .foregroundStyle(p.ink3)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.cardEdge, lineWidth: 1))
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(8)
            .background(p.paper)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(p.cardEdge, lineWidth: 1))
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundStyle(p.ink3)
                    Text("Upload photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(p.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(p.paper)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(p.cardEdge, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !saving
    }

    private func submit() {
        guard canSave else { return }
        saving = true
        Task {
            await save()
            saving = false
        }
    }

    private var saveButton: some View {
        Button(action: submit) {
            Text(saving ? "Saving…" : "Save changes")
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

    // MARK: - Actions

    private func save() async {
        var finalImage = image
        if let photoData, let jpeg = processedJPEG(from: photoData) {
            do {
                let filename = "photo-\(Int(Date().timeIntervalSince1970)).jpg"
                finalImage = try await state.uploadImage(jpeg, filename: filename)
            } catch {
                state.errorMessage = "Image upload failed: \(error.localizedDescription)"
                return
            }
        }
        let payload = DrinkPayload(
            brewery: brewery,
            drink: name,
            abv: Double(abvText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            rating: rating,
            image: finalImage,
            notes: notes
        )
        if await state.saveCatalog(id: drink.id, payload: payload) {
            dismiss()
        }
    }

    /// Downscale and re-encode so uploads stay under the server's 5MB limit.
    private func processedJPEG(from data: Data) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1200
        let largestSide = max(uiImage.size.width, uiImage.size.height)
        let scale = min(1, maxDimension / largestSide)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
