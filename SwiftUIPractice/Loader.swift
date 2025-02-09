//
//  Loader.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 29/9/24.
//

import SwiftUI
public struct CircleActivityView: View {
    
    // MARK: -
    
    public var lineWidth: CGFloat
    public var pathColor: Color
    public var lineColor: Color
    
    // MARK: - Init
    
    public init(lineWidth: CGFloat = 30, pathColor: Color, lineColor: Color) {
        self.lineWidth = lineWidth
        self.lineColor = lineColor
        self.pathColor = pathColor
    }
    
    // MARK: - State
    
    @State var isLoading: Bool = false
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(pathColor, lineWidth: lineWidth)
                .opacity(0.3)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(lineColor)
                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                .onAppear { self.isLoading.toggle() }
        }
    }
}
//animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        CircleActivityView(lineWidth: 20, pathColor: .purple, lineColor: .green)
            .padding()
    }
}
