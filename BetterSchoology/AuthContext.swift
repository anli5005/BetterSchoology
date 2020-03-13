//
//  AuthContext.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

class AuthContext: ObservableObject {
    @Published var username: String?
    
    var isAuthenticated: Bool { username != nil }
}
