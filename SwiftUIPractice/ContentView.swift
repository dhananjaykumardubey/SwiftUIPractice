import SwiftUI
import SwiftData

struct VerticalGridView: View {
    @ObservedObject var viewModel: VerticalGridViewModel
    var image: String
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let totalPadding: CGFloat = 8 * 2 + 2 * 2
        let itemSize = ((screenWidth - totalPadding) / 3) - 16
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemSize), spacing: 2),
                                     count: 3), spacing: 2) {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    ProfileView(imageName: image, itemSize: itemSize)
                    .frame(width: itemSize, height: itemSize)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .circular))
        }
    }
}


struct PhotoReviewView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PhotoMetadata.fileName) private var photos: [PhotoMetadata]
    
    @State private var selectedTab: String = "Photos without you"
    @State private var newImage: String = "14"
    @ObservedObject var viewModel: PhotoGalleryViewModel

     var body: some View {
         VStack(spacing: 16) {
             Text("Review 30 photos")
                 .font(.headline)
                 .padding(.top, 32)
             
             HStack(spacing: 10) {
                 CorneredBorderedShadowedWrapperView {
                     Button(action: {
                         withAnimation(.smooth) {
                             selectedTab = "Photos with you"
                         }
                     }) {
                         Text("Photos with you")
                             .padding(.vertical, 12)
                             .padding(.horizontal, 16)
                        
                     }
                     .frame(height: 80)
                     .background(selectedTab == "Photos with you" ? Color.gray.opacity(0.1) : Color.clear)
                     .buttonStyle(PlainButtonStyle())
                 }
                 CorneredBorderedShadowedWrapperView {
                     Button(action: {
                         withAnimation(.smooth) {
                             selectedTab = "Photos without you"
                         }
                         
                     }) {
                         Text("Photos without you")
                             .padding(.vertical, 12)
                             .padding(.horizontal, 16)
                     }
                     .frame(height: 80)
                     .background(selectedTab == "Photos without you" ? Color.gray.opacity(0.1) : Color.clear)

                     .buttonStyle(PlainButtonStyle())
                 }
             }
             
             CorneredBorderedShadowedWrapperView {
                 VStack(alignment: .leading) {
                     HStack {
                         Text(selectedTab)
                             .font(.headline)
                             .animation(nil, value: selectedTab)
                         
                         Spacer()
                         Button(action: {
                             Task {
                                 await viewModel.send()
                             }
                         }) {
                             Text("Send")
                                 .frame(width: 72, height: 28)
                                 .background(Color.white)
                                 .foregroundColor(.black)
                                 .cornerRadius(8)
                                 .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black, lineWidth: 1)
                                 )
                         }
                     }
                     .padding(.top, 5)
                     
                     Text("14:02 mins left to review")
                         .font(.caption)
                     
                     Divider()
                     
                     ScrollView(.vertical, showsIndicators: false) {
                         if selectedTab == "Photos without you" {
                             ScrollView(.horizontal, showsIndicators: false) {
                                 HStack(spacing: 10) {
                                     ForEach(0..<5) { index in
                                         ZStack {
                                             Rectangle()
                                                 .fill(Color.gray.opacity(0.3))
                                                 .frame(width: 100, height: 100)
                                             Image(systemName: "14")
                                                 .resizable()
                                                 .scaledToFit()
                                                 .frame(width: 50, height: 50)
                                                 .clipShape(Circle())
                                         }
                                     }
                                 }
                                 .padding(.vertical)
                             }
                         }
                         VerticalGridView(viewModel: VerticalGridViewModel(),
                                          image: newImage)
                         
                     }
                 }
                 .padding()
             }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal)
        .onAppear {
            photos.forEach {
                print($0.connectionId)
            }
            viewModel.databaseData()
        }
    }
}

struct CircularProgressDemoView: View {
    @State private var progress = 0.6


    var body: some View {
        VStack {
            ProgressView(value: progress)
                .progressViewStyle(.circular)
            Text("\(10)")
                .font(.caption)
        }
    }
}

//struct PhotoReviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        PhotoReviewView()
//    }
//}
