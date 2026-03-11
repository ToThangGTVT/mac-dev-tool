//
//  SettingsView.swift
//  devtool
//
//  Created by GOLFZON on 11/3/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var enableNotifications = true
    @State private var darkMode = false
    
    var body: some View {
        Form {
            Toggle("Bật thông báo", isOn: $enableNotifications)
            Toggle("Chế độ tối", isOn: $darkMode)
        }
        .padding()
        .navigationTitle("Cài đặt")
    }
}
