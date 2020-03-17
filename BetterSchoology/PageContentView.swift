//
//  PageContentView.swift
//  BetterSchoology
//
//  Created by Anthony Li on 3/17/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import SwiftUI
import WebKit

struct PageContentView: View {
    let contentString: NSAttributedString?
    init(_ content: String) {
        if let str = NSMutableAttributedString(html: Data(("<span style='font-family: system-ui;'>" + content + "</style>").utf8), options: [.characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
            str.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSMakeRange(0, str.length))
            // str.addAttribute(.font, value: NSFont( ), range: NSMakeRange(0, str.length))
            contentString = str
        } else {
            contentString = nil
        }
    }
    
    var body: some View {
        if contentString == nil {
            return AnyView(Text("Unable to parse data"))
        } else {
            return AnyView(TextView(attributedString: contentString!).frame(maxWidth: .infinity, maxHeight: .infinity))
        }
    }
    
    struct TextView: NSViewRepresentable {
        let attributedString: NSAttributedString
        
        func makeNSView(context: NSViewRepresentableContext<TextView>) -> NSScrollView {
            let textView = NSTextView(frame: .zero)
            textView.textStorage!.setAttributedString(attributedString)
            textView.autoresizingMask = [.width]
            textView.isVerticallyResizable = true
            textView.isEditable = false
            textView.textColor = .textColor
            
            let scrollView = NSScrollView(frame: .zero)
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            
            return scrollView
        }
        
        func updateNSView(_ nsView: NSScrollView, context: NSViewRepresentableContext<TextView>) {
            let textView = nsView.documentView as! NSTextView
            textView.textStorage!.setAttributedString(attributedString)
        }
    }
}
