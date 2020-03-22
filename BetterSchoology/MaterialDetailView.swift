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

protocol HasContentAndFiles {
    var content: String { get }
    var files: [SchoologyFile] { get }
}

struct ContentAndFilesView: View {
    var contentAndFiles: HasContentAndFiles
    
    var body: some View {
        let content = contentAndFiles.content
        let files = contentAndFiles.files
        
        let filesList = List(files.filter { $0.id != nil }, id: \.id) { file in
            FileView(file: file)
        }
        
        return VStack(spacing: 0) {
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
        }
    }
}

extension AssignmentMaterialDetail: MaterialDetailViewRepresentable, HasContentAndFiles {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            ContentAndFilesView(contentAndFiles: self)
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

extension DiscussionMaterialDetail: MaterialDetailViewRepresentable, HasContentAndFiles {
    func makeView(url: URL?) -> AnyView {
        AnyView(DetailView(self))
    }
    
    struct DetailView: View {
        var detail: DiscussionMaterialDetail
        
        init(_ detail: DiscussionMaterialDetail) {
            self.detail = detail
        }
        
        enum DiscussionTab: CaseIterable {
            case chat
            case description
            
            var name: String {
                switch self {
                case .chat:
                    return "Chat"
                case .description:
                    return "Description"
                }
            }
            
            func view(for detail: DiscussionMaterialDetail) -> AnyView {
                switch self {
                case .chat:
                    return AnyView(DiscussionView(discussion: detail))
                case .description:
                    return AnyView(ContentAndFilesView(contentAndFiles: detail))
                }
            }
        }
        
        @State var tab = DiscussionTab.allCases[0]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ForEach(DiscussionTab.allCases, id: \.self) { tab in
                        Button(action: {
                            self.tab = tab
                        }) {
                            Text(tab.name).fontWeight(self.tab == tab ? .bold : .regular).opacity(self.tab == tab ? 1.0 : 0.5)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }.padding([.horizontal, .bottom])
                Divider()
                tab.view(for: detail)
            }
        }
    }
}
