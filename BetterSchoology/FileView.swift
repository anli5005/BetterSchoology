//
//  FileView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/19/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import Combine

struct FileButton: View {
    var file: SchoologyFile
    var status: DownloadManager.FileStatus?
    var action: () -> Void
    
    var downloading: Bool {
        if case .some(.downloading(_)) = status?.downloadStatus {
            return true
        } else {
            return false
        }
    }
    
    var needsDownload: Bool {
        if case .some(.notOnDisk) = status?.diskStatus {
            return true
        } else {
            return false
        }
    }
    
    var errorDescription: String? {
        if case .some(.error(_)) = status?.downloadStatus {
            return "Download error"
        }
        
        if let diskStatus = status?.diskStatus {
            switch diskStatus {
            case .fileError(_, _):
                return "Error locating file - click to re-download"
            default:
                break
            }
        }
        
        if status?.locateError != nil {
            return "Error locating file"
        }
        
        return nil
    }
    
    var body: some View {
        let roundedRect = RoundedRectangle(cornerRadius: 3)
        
        return Button(action: action) {
            VStack(alignment: .leading) {
                Text("\(file.name ?? "No Name")").fontWeight(.bold)
                if file.typeDescription != nil {
                    Text(file.typeDescription!).opacity(0.8)
                }
                HStack {
                    if file.isDownload {
                        if downloading {
                            Text("Downloading...").opacity(0.6)
                        } else if errorDescription != nil {
                            Text(errorDescription!).foregroundColor(.red)
                        } else {
                            Text(needsDownload ? "Click to download and open" : "Click to open").opacity(0.4)
                        }
                    }
                    if file.size != nil {
                        Text(file.size!)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                roundedRect.fill(Color(NSColor.windowBackgroundColor)).overlay(roundedRect.stroke(Color.gray, lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(file.id == nil)
    }
}

struct FileView_Previews: PreviewProvider {
    static var previews: some View {
        FileButton(file: SchoologyFile(name: "Generic File", url: URL(string: "https://anli.dev/test.html"), size: "3 MB", iconClass: nil, typeDescription: "Type Description", isDownload: true), status: DownloadManager.FileStatus(downloadStatus: nil, diskStatus: .fileError(FileDownload(id: "s", bookmark: Data(), userVisible: true), DownloadError.fileNotFound))) {}.padding()
    }
}

struct FileView: View {
    @ObservedObject var downloadManager = sharedDownloadManager
    var file: SchoologyFile
    
    var body: some View {
        let status: DownloadManager.FileStatus?
        
        if file.isDownload {
            if let id = file.id {
                downloadManager.diskStatus(id: id)
            }
            
            status = file.id == nil ? nil : self.downloadManager.fileStatuses[file.id!]
        } else {
            status = nil
        }
        
        let isNotOnDisk: Bool
        if case .some(.notOnDisk) = status?.diskStatus {
            isNotOnDisk = true
        } else {
            isNotOnDisk = false
        }
        let download: FileDownload?
        switch status?.diskStatus {
        case .some(.onDisk(let file)), .some(.fileError(let file, _)):
            download = file
        default:
            download = nil
        }
        
        return FileButton(file: file, status: status, action: {
            if self.file.isDownload {
                self.downloadManager.downloadAndOpen(self.file)
            } else if self.file.url != nil {
                NSWorkspace.shared.open(self.file.url!)
            }
        }).contextMenu {
            if file.isDownload {
                Button(isNotOnDisk ? "Download" : "Re-Download") {
                    self.downloadManager.download(file: self.file)
                }.disabled(file.id == nil)
                
                Button("Quick Look") {
                    try? self.downloadManager.withURL(of: download!) { url, done in
                        sharedQuickLook.current = (url, done)
                        sharedQuickLook.panel?.makeKeyAndOrderFront(nil)
                    }
                }.disabled(download == nil)
                
                Button("Reveal in Finder") {
                    try? self.downloadManager.revealInFinder(download: download!)
                }.disabled(download == nil)
                
                Button("Locate File") {
                    let dialog = NSOpenPanel()
                    dialog.showsHiddenFiles = false
                    dialog.allowsMultipleSelection = false
                    dialog.canChooseDirectories = false
                    dialog.showsResizeIndicator = true
                    dialog.prompt = "Locate"
                    
                    if dialog.runModal() == .OK, let url = dialog.url {
                        if !url.startAccessingSecurityScopedResource() {
                            print("Could not access security scoped resource")
                        }
                        self.downloadManager.locate(file: file, at: url, useLocateErrors: true)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            
            Divider()
            
            Button("Copy \(file.isDownload ? "Download" : "Link") URL") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(self.file.url!.absoluteString, forType: .string)
            }.disabled(file.url == nil)
        }
    }
}
