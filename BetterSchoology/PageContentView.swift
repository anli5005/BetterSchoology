//
//  PageContentView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/17/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct PageContentView: View {
    let content: String
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        Text(content)
    }
}
