import SwiftUI

/// A tappable value row that opens the right system app for the value's kind.
struct ContactValueRow: View {
    enum Kind { case phone, email, url, address, plain }
    var label: String
    var value: String
    var kind: Kind = .plain

    private var url: URL? {
        let v = value.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .phone: return URL(string: "tel:" + v.filter { "+0123456789".contains($0) })
        case .email: return URL(string: "mailto:" + v)
        case .url: return URL(string: v.contains("://") ? v : "https://" + v)
        case .address:
            let q = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            return URL(string: "maps://?q=" + q)
        case .plain: return nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if !label.isEmpty {
                    Text(label.capitalized).font(.caption).foregroundStyle(.secondary)
                }
                Text(value).textSelection(.enabled)
            }
            Spacer()
            if kind == .phone {
                if let sms = URL(string: "sms:" + value.filter { "+0123456789".contains($0) }) {
                    Link(destination: sms) { Image(systemName: "message") }
                        .buttonStyle(.borderless)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if let url { UIApplication.shared.open(url) } }
    }
}

struct ErrorBanner: View {
    var message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

extension Date {
    var shortDate: String { formatted(date: .abbreviated, time: .omitted) }
    var relative: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: .now)
    }
}

extension String {
    /// Meerkat stores birthdays as "YYYY-MM-DD" or "--MM-DD" (year unknown). Render them nicely.
    var birthdayDisplay: String {
        let parts = split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        var comps = DateComponents()
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            comps.month = m; comps.day = d
            if let y = Int(parts[0]) { comps.year = y }
        } else if parts.count == 4, let m = Int(parts[2]), let d = Int(parts[3]) { // "--MM-DD"
            comps.month = m; comps.day = d
        } else { return self }
        guard let date = Calendar.current.date(from: comps) else { return self }
        return comps.year == nil ? date.formatted(.dateTime.month(.wide).day())
                                 : date.formatted(.dateTime.month(.wide).day().year())
    }
}

func describe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}
