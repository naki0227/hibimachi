import SpriteKit
import SwiftUI

/// Bootstrap screen: proves SwiftUI can host a SpriteKit scene. Game features come later.
struct ContentView: View {
    @State private var scene: SKScene = {
        let scene = SKScene(size: CGSize(width: 512, height: 512))
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(red: 0.47, green: 0.74, blue: 0.84, alpha: 1)
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .accessibilityIdentifier("island-view")
    }
}
