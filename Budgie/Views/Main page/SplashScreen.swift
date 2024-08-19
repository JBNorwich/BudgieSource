//
//  ContentView.swift
//  Budgie
//
//  Created by Joe Baldwin on 19/08/2024.
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        NavigationStack {
                VStack {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(minHeight: 175)
                    ZStack{
                        Circle()
                            .foregroundStyle(.thickMaterial)
                        ZStack {
                            Circle()
                                .fill(.shadow(.drop(color: .black, radius: 4)))
                                .fill(.thickMaterial)
                        }
                        .padding()
                    }.frame(minHeight: 275, maxHeight: 275)
                        .padding()
                    Spacer()
                    GroupBox(label: Text("")) {
                        VStack {
                            Spacer()
                        }
                    }.frame(minHeight: 150)
                    GroupBox(label: Text("")) {
                        VStack {
                            Spacer()
                        }
                    }.frame(minHeight: 300)
                }
                .padding()
            }
        }
    }


#Preview {
    SplashScreen()
}
