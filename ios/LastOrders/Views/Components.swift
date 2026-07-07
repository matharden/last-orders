import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 4) {
            Text(value)
                .font(.serif(27, .medium))
                .foregroundStyle(p.ink)
            Text(label.uppercased())
                .font(.mono(9.5, .medium))
                .tracking(1.7)
                .foregroundStyle(p.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(radius: 13)
    }
}

/// Circular drink avatar: catalog image if present, else the deterministic label colour + initials.
struct DrinkMat: View {
    let name: String
    let imageURL: String
    var size: CGFloat = 46
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        ZStack {
            if let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Units.labelColor(name, dark: scheme == .dark)
                }
            } else {
                Units.labelColor(name, dark: scheme == .dark)
                Text(Units.drinkInitials(name))
                    .font(.serif(size * 0.35, .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(p.cardEdge, lineWidth: 1))
    }
}

struct JournalRow: View {
    let entry: EnrichedEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        HStack(spacing: 12) {
            DrinkMat(name: entry.entry.drink, imageURL: entry.image)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.entry.drink)
                    .font(.serif(17, .medium))
                    .foregroundStyle(p.ink)
                    .lineLimit(1)
                Text("\(Units.fmtNum(entry.entry.amount)) × \(sizeLabel) · \(Units.fmtNum(entry.abv))%")
                    .font(.mono(12))
                    .foregroundStyle(p.ink2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", entry.units))
                    .font(.serif(19, .semibold))
                    .foregroundStyle(p.ink)
                Text("UNITS")
                    .font(.mono(9))
                    .tracking(1.1)
                    .foregroundStyle(p.ink3)
            }
        }
        .padding(.vertical, 12)
    }

    private var sizeLabel: String {
        Units.sizeLabels[entry.entry.size] ?? "\(entry.entry.size)ml"
    }
}

struct RankRow: View {
    let index: Int
    let name: String
    let count: Double
    let max: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.mono(10))
                .foregroundStyle(p.ink3)
                .frame(width: 14, alignment: .trailing)
            Text(name)
                .font(.system(size: 13.5))
                .foregroundStyle(p.ink)
                .lineLimit(1)
                .frame(width: 112, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(p.paper2)
                        .overlay(Capsule().stroke(p.cardEdge, lineWidth: 1))
                    Capsule()
                        .fill(p.barGradient)
                        .frame(width: Swift.max(4, geo.size.width * (max > 0 ? count / max : 0)))
                }
            }
            .frame(height: 8)
            Text("\(Int(count.rounded(.up)))")
                .font(.mono(11))
                .foregroundStyle(p.ink2)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

/// The dashed horizontal rule under day headers in the journal.
struct DashedRule: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        LineShape()
            .stroke(p.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .frame(height: 1)
    }

    private struct LineShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            return path
        }
    }
}

/// Field label used inside the bottom sheets.
struct FieldLabel: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(10, .semibold))
            .tracking(1.8)
            .foregroundStyle(Palette.of(scheme).ink3)
    }
}

struct SheetTextFieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let p = Palette.of(scheme)
        content
            .font(.system(size: 16))
            .foregroundStyle(p.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(p.paper)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(p.cardEdge, lineWidth: 1))
    }
}

extension View {
    func sheetField() -> some View {
        modifier(SheetTextFieldStyle())
    }
}

struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : p.ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(p.barGradient) : AnyShapeStyle(p.paper))
                )
                .overlay(Capsule().stroke(selected ? .clear : p.cardEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
