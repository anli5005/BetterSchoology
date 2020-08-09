//
//  main.swift
//  BetterSchoology
//
//  Created by Anthony Li on 8/8/20.
//  Copyright © 2020 Anthony Li. All rights reserved.
//

import AppKit

if #available(macOS 11.0, iOS 14.0, *) {
    BetterSchoologyApp.main()
} else {
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
