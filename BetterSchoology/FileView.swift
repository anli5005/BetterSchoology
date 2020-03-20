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
    var action: () -> Void
    
    var body: some View {
        let roundedRect = RoundedRectangle(cornerRadius: 3)
        
        return Button(action: action) {
            VStack(alignment: .leading) {
                Text("\(file.name ?? "No Name")").fontWeight(.bold)
                if file.size != nil {
                    Text(file.size!)
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
        FileButton(file: SchoologyFile(name: "Generic File", url: URL(string: "https://anli.dev/test.html"), size: "3 MB", iconClass: nil, typeDescription: nil)) {}.padding()
    }
}

struct FileView: View {
    var file: SchoologyFile
    
    var body: some View {
        FileButton(file: file, action: {
            sharedDownloadManager.downloadAndOpen(self.file)
        })
    }
}
