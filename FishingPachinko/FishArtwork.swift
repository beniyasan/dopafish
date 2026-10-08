import SwiftUI

struct FishArtwork: View {
    let imageName: String
    let name: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(name)
    }
}
