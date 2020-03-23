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
        AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            Button(action: {
                self.openChatWindow()
            }) {
                Text("Open Chat Window")
            }.padding()
            Divider()
            ContentAndFilesView(contentAndFiles: self)
        })
    }
    
    func openChatWindow() {
        let delegate = NSApp.delegate as! AppDelegate
        let controller = NSStoryboard(name: "Main", bundle: Bundle.main).instantiateController(withIdentifier: "chatWindowController") as! NSWindowController
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        (controller.contentViewController as? ChatViewController)?.discussion = self
        delegate.windowControllers.insert(controller)
    }
}
