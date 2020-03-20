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
                    if downloading {
                        Text("Downloading...").opacity(0.6)
                    } else if errorDescription != nil {
                        Text(errorDescription!).foregroundColor(.red)
                    } else {
                        Text(needsDownload ? "Click to download and open" : "Click to open").opacity(0.4)
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
        FileButton(file: SchoologyFile(name: "Generic File", url: URL(string: "https://anli.dev/test.html"), size: "3 MB", iconClass: nil, typeDescription: "Type Description"), status: DownloadManager.FileStatus(downloadStatus: nil, diskStatus: .fileError(FileDownload(id: "s", bookmark: Data(), userVisible: true), DownloadError.fileNotFound))) {}.padding()
    }
}

struct FileView: View {
    @ObservedObject var downloadManager = sharedDownloadManager
    var file: SchoologyFile
    
    var body: some View {
        if let id = file.id {
            downloadManager.diskStatus(id: id)
        }
        
        let status = file.id == nil ? nil : self.downloadManager.fileStatuses[file.id!]
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
            self.downloadManager.downloadAndOpen(self.file)
        }).contextMenu {
            Button(isNotOnDisk ? "Download" : "Re-Download") {
                self.downloadManager.download(file: self.file)
            }.disabled(file.id == nil)
            Button("Reveal in Finder") {
                try? self.downloadManager.revealInFinder(download: download!)
            }.disabled(download == nil)
        }
    }
}
