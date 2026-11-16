import SwiftUI

@main
struct BiliSoundApp: App {
    init() {
        // Enforce strict memory & disk ceilings on URLCache to prevent memory ballooning
        let memoryLimit = 20 * 1024 * 1024  // 20 MB RAM ceiling
        let diskLimit = 100 * 1024 * 1024   // 100 MB Flash Storage ceiling
        URLCache.shared = URLCache(memoryCapacity: memoryLimit, diskCapacity: diskLimit, diskPath: "bili_image_cache")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}
