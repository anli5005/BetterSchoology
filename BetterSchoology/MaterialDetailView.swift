//
//  MaterialDetailView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/15/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI

struct MaterialDetailView: View {
    @EnvironmentObject var store: SchoologyStore
    var materialDetail: MaterialDetail
    
    var url: URL? {
        URL(string: "\(store.client.prefix)/\(materialDetail.material.urlSuffix)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(materialDetail.fullName).font(.headline).fontWeight(.bold).padding([.horizontal, .top])
            Button(action: {
                NSWorkspace.shared.open(self.url!)
            }) {
                Text("Open in Schoology")
            }.buttonStyle(LinkButtonStyle()).disabled(url == nil).padding([.horizontal, .bottom])
            Divider()
            if materialDetail is MaterialDetailViewRepresentable {
                (materialDetail as! MaterialDetailViewRepresentable).makeView()
            } else {
                Text("No details available.").padding()
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

protocol MaterialDetailViewRepresentable {
    func makeView() -> AnyView
}

extension LinkMaterialDetail: MaterialDetailViewRepresentable {
    func makeView() -> AnyView {
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                Text(url?.absoluteString ?? "Invalid URL").multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Button(action: {
                    NSWorkspace.shared.open(self.url!)
                }) {
                    Text("Open Link")
                }.disabled(url == nil)
            }.padding()
            if url != nil {
                GeometryReader { g in
                    ScrollView(showsIndicators: false) {
                        WebView(destination: .url(self.url!)).frame(width: g.size.width, height: g.size.height)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        })
    }
}
