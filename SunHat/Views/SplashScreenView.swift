//
//  SplashScreenView.swift
//  SunHat
//
//  Created by Wesley Keetch on 1/30/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let logoSize = min(geometry.size.width, geometry.size.height) * 0.4

            ZStack {
                Color.accentColor
                    .ignoresSafeArea()

                VStack(spacing: logoSize * 0.12) {
                    Image("SplashLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)
                        .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.22, style: .continuous))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    Text("SunHat")
                        .font(.system(size: logoSize * 0.16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
