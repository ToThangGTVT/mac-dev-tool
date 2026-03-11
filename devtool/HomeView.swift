//
//  HomeView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI

struct HomeView: View {
    @State private var counter = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Trang chủ")
                .font(.largeTitle)
                .bold()
            
            Text("Counter: \(counter)")
                .font(.title2)
            
            HStack(spacing: 12) {
                Button("Tăng") {
                    counter += 1
                }
                .buttonStyle(.borderedProminent)
                
                Button("Giảm") {
                    counter -= 1
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
