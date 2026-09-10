import SwiftUI
import UIKit

enum BundledAssets {
    static let poweredByVeivo: UIImage? = {
        guard let url = Bundle.main.url(forResource: "PoweredByVeivo", withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
}

/// Small brand mark pinned to the bottom of the server list.
struct LogoFooterView: View {
    var body: some View {
        if let logo = BundledAssets.poweredByVeivo {
            HStack {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
