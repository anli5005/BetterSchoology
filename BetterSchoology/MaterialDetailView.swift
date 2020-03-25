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
                Text(self.url?.absoluteString ?? "Invalid URL").multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Button(action: {
                    NSWorkspace.shared.open(self.url!)
                }) {
                    Text("Open Link")
                }.disabled(self.url == nil)
            }.padding()
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
    struct OpenChatButton: View {
        var detail: DiscussionMaterialDetail
        @EnvironmentObject var store: CourseMaterialsStore
        
        var body: some View {
            Button(action: {
                self.detail.openChatWindow(courseMaterialsStore: self.store)
            }) {
                Text("Open Chat Window")
            }
        }
    }
    
    func makeView(url: URL?) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            OpenChatButton(detail: self).padding()
            Divider()
            ContentAndFilesView(contentAndFiles: self)
        })
    }
    
    func openChatWindow(courseMaterialsStore: CourseMaterialsStore) {
        let delegate = NSApp.delegate as! AppDelegate
        if let window = delegate.chatWindows[AnyHashable(material.id)] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let controller = NSStoryboard(name: "Main", bundle: Bundle.main).instantiateController(withIdentifier: "chatWindowController") as! NSWindowController
            controller.window?.center()
            controller.window?.makeKeyAndOrderFront(nil)
            delegate.chatWindows[AnyHashable(material.id)] = controller.window
            if let chat = controller.contentViewController as? ChatViewController {
                chat.discussion = self
                chat.store = courseMaterialsStore
            }
            delegate.windowControllers.insert(controller)
        }
    }
}
