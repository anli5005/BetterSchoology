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
        URL(string: "\(store.client.prefix)\(materialDetail.material.urlSuffix)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(materialDetail.fullName).font(.headline).fontWeight(.bold).padding([.horizontal, .top])
            Button(action: {
                NSWorkspace.shared.open(self.url!)
            }) {
                Text("Open in Schoology").foregroundColor(.accentColor)
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

extension PageMaterialDetail: MaterialDetailViewRepresentable, HasContentAndFiles {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack(spacing: 0) {
            Divider()
            ContentAndFilesView(contentAndFiles: self)
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
            FileView(file: file).padding(.horizontal, 1)
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
            if material.due != nil {
                Text("Due: \(material.due!, formatter: material.dueTime == true ? userDateFormatter : userDateOnlyFormatter)").fontWeight(.bold).padding([.bottom, .horizontal]).lineLimit(1)
            }
            Divider()
            ContentAndFilesView(contentAndFiles: self)
            if acceptsSubmissions {
                Divider()
                UploadView(destination: self).frame(maxWidth: .infinity, alignment: .center).frame(height: 225)
            }
        })
    }
}

extension QuizMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        return AnyView(VStack {
            Text("To view or take this assessment, open it in a web browser.").frame(alignment: .center).lineLimit(nil).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            Button(action: {
                NSWorkspace.shared.open(url!)
            }) {
                Text("Open in Web Browser")
            }.disabled(url == nil)
        }.padding().frame(maxWidth: .infinity, alignment: .center))
    }
}

extension DiscussionMaterialDetail: MaterialDetailViewRepresentable, HasContentAndFiles {
    struct OpenChatButton: View {
        var detail: DiscussionMaterialDetail
        @EnvironmentObject var store: CourseMaterialsStore
        @available(macOS 10.16, *) @EnvironmentObject var appDelegate: AppDelegate
        
        var body: some View {
            let delegate: AppDelegate
            if #available(macOS 10.16, *) {
                delegate = appDelegate
            } else {
                delegate = NSApp.delegate as! AppDelegate
            }
            
            return Button(action: {
                self.detail.openChatWindow(courseMaterialsStore: self.store, delegate: delegate)
            }) {
                Text("Open Chat Window")
            }
        }
    }
    
    func makeView(url: URL?) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 0) {
            if material.due != nil {
                Text("Due: \(material.due!, formatter: material.dueTime == true ? userDateFormatter : userDateOnlyFormatter)").fontWeight(.bold).padding([.bottom, .horizontal]).lineLimit(1)
            }
            Divider()
            OpenChatButton(detail: self).padding()
            Divider()
            ContentAndFilesView(contentAndFiles: self)
        })
    }
    
    func openChatWindow(courseMaterialsStore: CourseMaterialsStore, delegate: AppDelegate) {
        if let window = delegate.chatWindows[AnyHashable(material.id)] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let controller = NSStoryboard(name: "Chat", bundle: Bundle.main).instantiateController(withIdentifier: "chatWindowController") as! NSWindowController
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

extension FolderMaterialDetail: MaterialDetailViewRepresentable {
    func makeView(url: URL?) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 0) {
            Divider()
            if description != nil {
                PageContentView(description!)
            }
        })
    }
}
