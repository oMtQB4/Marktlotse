//
//  SplashView.swift
//  Marktlotse
//
//  Branded startup screen shown briefly on launch. Composes the white launch
//  logo and wordmark over the app's green gradient, then fades into the app.
//

import SwiftUI

struct SplashView: View {
    @State private var logoVisible = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.72, blue: 0.52),
                    Color(red: 0.00, green: 0.45, blue: 0.33)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Text("Marktlotse")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(logoVisible ? 1 : 0.88)
            .opacity(logoVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoVisible = true
            }
        }
    }
}

#Preview {
    SplashView()
}
