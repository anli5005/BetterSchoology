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
            if materialDetail is MaterialDetailViewRepresentable {
                (materialDetail as! MaterialDetailViewRepresentable).makeView(url: self.url)
            } else {
                Divider()
                Text("No details available.").padding()
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

protocol MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView
}

extension LinkMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
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

extension PageMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack(spacing: 0) {
            Divider()
            PageContentView(content)
        })
    }
}

extension FileMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            FileView(file: file).padding()
        })
    }
}

extension AssignmentMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        let filesList = List(files.filter { $0.id != nil }, id: \.id) { file in
            FileView(file: file)
        }
        
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            if !content.isEmpty || files.isEmpty {
                PageContentView(content)
                if !files.isEmpty {
                    Divider()
                }
            }
            if !files.isEmpty {
                if content.isEmpty {
                    filesList
                } else {
                    filesList.frame(height: 160)
                }
            }
            Divider()
            VStack {
                Text("To submit or view more details, open this assignment in your web browser.").multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button(action: {
                    NSWorkspace.shared.open(url!)
                }) {
                    Text("Open in Web Browser")
                }.disabled(url == nil)
            }.frame(maxWidth: .infinity, alignment: .center).padding()
        })
    }
}
