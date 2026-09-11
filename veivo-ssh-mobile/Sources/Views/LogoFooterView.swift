import SwiftUI
import UIKit

enum BundledAssets {
    static let poweredByVeivo: UIImage? = {
        guard let url = Bundle.main.url(forResource: "PoweredByVeivo", withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
}

/// Small brand mark pinned to the bottom of the server list. The artwork itself is a
/// white wordmark meant for a dark background, so it gets its own dark chip here
/// rather than sitting directly on the list's (light-in-light-mode) background.
struct LogoFooterView: View {
    var body: some View {
        if let logo = BundledAssets.poweredByVeivo {
            HStack {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
