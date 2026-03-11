//
//  ProfileView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
            
            Text("Hồ sơ người dùng")
                .font(.largeTitle)
                .bold()
            
            Text("Đây là màn hình profile trong app macOS.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
