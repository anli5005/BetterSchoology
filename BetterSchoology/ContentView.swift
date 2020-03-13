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
    
    var body: some View {
        Text("BetterSchoology")
            .fixedSize()
            .padding()
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: .constant(!authContext.isAuthenticated)) {
                AuthView().frame(width: 400).padding().environmentObject(self.authContext)
            }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
