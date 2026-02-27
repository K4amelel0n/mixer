//
//  ContentView.swift
//  mixer
//
//  Created by DawidKozaczuk on 26/01/2026.
//

import SwiftUI
import Foundation

struct MixerRow: View {
    @Bindable var chain: AudioChain
    
    var body: some View {
        HStack(spacing: 15) {
            if let icon = chain.app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            
            Text(chain.app.name)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 120, alignment: .leading)
            
            Slider(value: $chain.volume, in: 0...1)
                .tint(.accentColor)
                .frame(minWidth: 80)
                .layoutPriority(1)
            
            Text("\(Int(chain.volume * 100))%")
                .font(.system(.body, design: .monospaced))
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal)
        .frame(height: 40)
    }
}

struct ContentView: View {
    @Environment(AudioMixer.self) private var mixer
    
    var body: some View {
            VStack(spacing: 10) {
                if !mixer.isShuttingDown {
                    List(mixer.chains) { chain in
                        MixerRow(chain: chain)
                    }
                    .frame(minWidth: 500, maxWidth: 800)
                }
                
                Divider()
                
                Button("Quit App") {
                    NSApp.terminate(nil)
                }
                .padding(8)
            }
        }
}

#Preview {
    ContentView()
}
