//
//  ContentView.swift
//  DysgraphiaCollect
//
//  Created by Do Thanh Lam on 2/4/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: DysgraphiaCollectDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(DysgraphiaCollectDocument()))
}
