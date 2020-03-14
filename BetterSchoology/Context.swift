//
//  AuthContext.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

class AuthContext: ObservableObject {
    @Published var status = Status.unknown
    
    enum Status {
        case unknown
        case unauthenticated
        case authenticated(user: User, store: SchoologyStore)
    }
}

extension SchoologyClient: ObservableObject {}

let sharedClient = SchoologyClient(session: .shared, prefix: "https://bca.schoology.com", schoolId: "11897239")
