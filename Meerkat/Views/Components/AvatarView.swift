import SwiftUI

/// Circular avatar: server thumbnail when present, otherwise initials on a tinted disc.
struct AvatarView: View {
    var contact: Contact
    var size: CGFloat = 44
    var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let data = contact.thumbnailData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.18))
                    Text(contact.initials.isEmpty ? "?" : contact.initials)
                        .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
