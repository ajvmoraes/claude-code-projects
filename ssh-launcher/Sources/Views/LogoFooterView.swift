import SwiftUI
import AppKit

enum BundledAssets {
    static let poweredByVeivo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "PoweredByVeivo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

/// Small brand mark pinned to the bottom-left of the sidebar. The artwork itself is a
/// white wordmark meant for a dark background, so it gets its own dark chip here
/// rather than sitting directly on the sidebar's (light-in-light-mode) background.
struct LogoFooterView: View {
    var body: some View {
        if let logo = BundledAssets.poweredByVeivo {
            HStack {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SwiftUI.Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
