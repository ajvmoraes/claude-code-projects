import SwiftUI
import AppKit

enum BundledAssets {
    static let poweredByVeivo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "PoweredByVeivo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

/// Small brand mark pinned to the bottom-left of the sidebar.
struct LogoFooterView: View {
    var body: some View {
        if let logo = BundledAssets.poweredByVeivo {
            HStack {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
