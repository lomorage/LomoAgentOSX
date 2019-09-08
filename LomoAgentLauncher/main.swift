//
//  main.swift
//  LomoAgentLauncher
//
//  Created by Jiantao Fu on 9/1/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
