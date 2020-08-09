//
//  RefreshItem.swift
//  BetterSchoology
//
//  Created by Anthony Li on 8/8/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

@available(macOS 11.0, iOS 14.0, *) struct RefreshButton: View {
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action ?? {}) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }.disabled(action == nil)
    }
}
