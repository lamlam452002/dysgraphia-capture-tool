//
//  DysgraphiaCollectApp.swift
//  DysgraphiaCollect
//
//  Created by Do Thanh Lam on 2/4/26.
//

import SwiftUI

@main
struct DysgraphiaCollectApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: DysgraphiaCollectDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
