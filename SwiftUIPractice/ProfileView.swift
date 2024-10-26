import SwiftUI
struct ProfileView: View {
    @State private var isRemoved = false
    let imageName: String
    let itemSize: CGFloat

    var body: some View {
        ZStack {
            // Background Image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: itemSize, height: itemSize)
                .clipped()
                .border(.green)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isRemoved.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 25, height: 25)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 10)

                    Image(systemName: "xmark")
                        .resizable()
                        .frame(width: 7, height: 7)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 10)
            .border(.blue)

            VStack {
                Spacer()

                if isRemoved {
                    VStack {
                        Text("Removed")
                            .font(.caption2)
                            .foregroundColor(.white)

                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15, height: 15)
                            .clipShape(Circle())
                    }
                    .padding(0)
                    .frame(maxWidth: itemSize, maxHeight: 34)
                    .background(
                        Color.black.opacity(0.6)
                            .background(.ultraThinMaterial)
                    )
                    .frame(height: 38)
                    .opacity(isRemoved ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isRemoved)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(width: itemSize, height: itemSize)
        .clipped()
    }
}
