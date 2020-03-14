//
//  ContentView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/13/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var client: SchoologyClient
    
    var body: some View {
        switch authContext.status {
        case .unknown:
            return AnyView(Text("Loading...").padding().frame(maxWidth: .infinity, maxHeight: .infinity))
        case .unauthenticated:
            return AnyView(AuthView().frame(width: 400).padding().frame(maxWidth: .infinity, maxHeight: .infinity))
        case .authenticated(_, let store):
            return AnyView(MainView().environmentObject(store))
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
