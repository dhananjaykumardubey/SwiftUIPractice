//
//  RoundedWrapper.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 21/9/24.
//

import Foundation
import SwiftUI


struct CorneredBorderedShadowedWrapperView<Content: View>: View {
    var content: Content
    var cornerRadius: CGFloat = 24
    var borderWidth: CGFloat = 0.5
    var borderColor: Color = .red
    var shadowRadius: CGFloat = 25.0
    var shadowColor: Color = .red.opacity(0.2)
    
    init(cornerRadius: CGFloat = 24, borderWidth: CGFloat = 0.5, borderColor: Color = .red, shadowRadius: CGFloat = 25.0, shadowColor: Color = .black.opacity(0.08), @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.white)
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}
