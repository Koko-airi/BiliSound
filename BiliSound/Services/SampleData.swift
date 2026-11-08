import Foundation

/// Curated sample playlists loaded with real, verified Bilibili music videos featuring multiple versions (Feature 4).
public struct SampleData {
    public static var defaultPlaylists: [Playlist] {
        [
            jayChouPlaylist,
            jpopPlaylist,
            electronicPlaylist
        ]
    }
    
    // MARK: - Jay Chou Collection (周杰伦经典)
    public static let jayChouPlaylist: Playlist = {
        let nocturne = Song(
            title: "夜曲 (Nocturne)",
            artist: "周杰伦 (Jay Chou)",
            album: "十一月的萧邦 (November's Chopin)",
            artworkUrl: "https://i1.hdslb.com/bfs/archive/276f0b99946cc11ba336b7f46f69611f1c892b15.jpg",
            versions: [
                SongVersion(
                    name: "4K Remastered Official MV",
                    bvid: "BV1Ek4y1r7Rg",
                    cid: 460901307,
                    uploader: "zyl2012_音乐无限",
                    duration: 232,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i1.hdslb.com/bfs/archive/276f0b99946cc11ba336b7f46f69611f1c892b15.jpg"
                ),
                SongVersion(
                    name: "2007 World Tour Live Concert",
                    bvid: "BV1Zp4y1a7uZ",
                    cid: 242034389,
                    uploader: "薄暮思归",
                    duration: 225,
                    audioQuality: "Concert Soundboard",
                    picUrl: "https://i0.hdslb.com/bfs/archive/583cd5c71350d91f9aba3d276a648c5a8e017007.jpg"
                )
            ]
        )
        
        let sunnyDay = Song(
            title: "晴天 (Sunny Day)",
            artist: "周杰伦 (Jay Chou)",
            album: "叶惠美 (Ye Hui Mei)",
            artworkUrl: "https://i2.hdslb.com/bfs/archive/fd3eee1c3257e85941ee86f5123b83366fa3bf0d.jpg",
            versions: [
                SongVersion(
                    name: "World Tour Stadium Live Singalong",
                    bvid: "BV1Yv4y1Z7km",
                    cid: 296423212,
                    uploader: "音乐私藏馆",
                    duration: 265,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i2.hdslb.com/bfs/archive/fd3eee1c3257e85941ee86f5123b83366fa3bf0d.jpg"
                ),
                SongVersion(
                    name: "Vienna Golden Hall Orchestral",
                    bvid: "BV1XG411c7SL",
                    cid: 881163241,
                    uploader: "达伦Asuka",
                    duration: 162,
                    audioQuality: "Hi-Fi Instrumental",
                    picUrl: "https://i2.hdslb.com/bfs/archive/4daa91d40c6ace606ec4145eb2acdece9497e0b1.jpg"
                )
            ]
        )
        
        let qiLiXiang = Song(
            title: "七里香 (Common Jasmine Orange)",
            artist: "周杰伦 (Jay Chou)",
            album: "七里香",
            artworkUrl: "https://i0.hdslb.com/bfs/archive/e31b53d89a624c49f7f7056a9556f10d21de4c2b.jpg",
            versions: [
                SongVersion(
                    name: "4K Official Master MV",
                    bvid: "BV1qD4y1U7fs",
                    cid: 351660720,
                    uploader: "音乐私藏馆",
                    duration: 298,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i0.hdslb.com/bfs/archive/e31b53d89a624c49f7f7056a9556f10d21de4c2b.jpg"
                )
            ]
        )
        
        return Playlist(
            name: "Jay Chou Classics (周杰伦经典)",
            description: "Timeless masterpieces with studio masters, concert live singalongs, and acoustic editions.",
            coverUrl: "https://i1.hdslb.com/bfs/archive/276f0b99946cc11ba336b7f46f69611f1c892b15.jpg",
            songs: [nocturne, sunnyDay, qiLiXiang]
        )
    }()
    
    // MARK: - J-Pop & Anime
    public static let jpopPlaylist: Playlist = {
        let gunjou = Song(
            title: "群青 (Gunjou)",
            artist: "YOASOBI",
            album: "THE BOOK",
            artworkUrl: "https://i2.hdslb.com/bfs/archive/e0243c366cf2424f8748cd5fa42a3a82b707ce0b.jpg",
            versions: [
                SongVersion(
                    name: "Studio Recording Master",
                    bvid: "BV118411w7Pa",
                    cid: 979646717,
                    uploader: "JLRS-LeoFM",
                    duration: 251,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i2.hdslb.com/bfs/archive/e0243c366cf2424f8748cd5fa42a3a82b707ce0b.jpg"
                ),
                SongVersion(
                    name: "Official Music Video",
                    bvid: "BV15k4y1q7g2",
                    cid: 1078558439,
                    uploader: "YOASOBI",
                    duration: 182,
                    audioQuality: "192kbps HQ",
                    picUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80"
                )
            ]
        )
        
        let lemon = Song(
            title: "Lemon",
            artist: "米津玄師 (Kenshi Yonezu)",
            album: "STRAY SHEEP",
            artworkUrl: "https://i2.hdslb.com/bfs/archive/b52bfef3cc286a6180f0e4eabb6edb144440b47f.png",
            versions: [
                SongVersion(
                    name: "Official MV 1080P",
                    bvid: "BV164411D7vc",
                    cid: 109819229,
                    uploader: "成宮光義",
                    duration: 275,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i2.hdslb.com/bfs/archive/b52bfef3cc286a6180f0e4eabb6edb144440b47f.png"
                ),
                SongVersion(
                    name: "2019 Tour Concert Live",
                    bvid: "BV1cY41117NG",
                    cid: 965303764,
                    uploader: "蚕豆音乐侠",
                    duration: 277,
                    audioQuality: "Live Multi-track",
                    picUrl: "https://i2.hdslb.com/bfs/archive/a805c30586c04949db918972959d2809f44a9d5f.png"
                )
            ]
        )
        
        let aoToNatsu = Song(
            title: "青と夏 (Ao to Natsu)",
            artist: "Mrs. GREEN APPLE",
            album: "Attitude",
            artworkUrl: "https://i1.hdslb.com/bfs/archive/b9a3ea43496ccb77a5afb9939d4cdb5f516f3cdd.jpg",
            versions: [
                SongVersion(
                    name: "Official Edition (On Vocal)",
                    bvid: "BV1Xz8T69E2j",
                    cid: 41122074018,
                    uploader: "白詰草",
                    duration: 284,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i1.hdslb.com/bfs/archive/b9a3ea43496ccb77a5afb9939d4cdb5f516f3cdd.jpg"
                )
            ]
        )
        
        return Playlist(
            name: "J-Pop & Anime Masterpieces",
            description: "Modern J-Pop & Anime anthems featuring studio recordings and arena live tour editions.",
            coverUrl: "https://i2.hdslb.com/bfs/archive/e0243c366cf2424f8748cd5fa42a3a82b707ce0b.jpg",
            songs: [gunjou, lemon, aoToNatsu]
        )
    }()
    
    // MARK: - Electronic & Gaming
    public static let electronicPlaylist: Playlist = {
        let shelter = Song(
            title: "Shelter",
            artist: "Porter Robinson & Madeon",
            album: "Shelter",
            artworkUrl: "https://i1.hdslb.com/bfs/archive/e4176db6bbeb1db02ccdd4a3879e2f663521c337.jpg",
            versions: [
                SongVersion(
                    name: "Official Remix & Short Film",
                    bvid: "BV1ht411Q7NZ",
                    cid: 65842375,
                    uploader: "光着屁股奔跑",
                    duration: 261,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i1.hdslb.com/bfs/archive/e4176db6bbeb1db02ccdd4a3879e2f663521c337.jpg"
                )
            ]
        )
        
        let badApple = Song(
            title: "Bad Apple!!",
            artist: "Nomico / Alstroemeria Records",
            album: "Lovelight",
            artworkUrl: "https://i1.hdslb.com/bfs/archive/26e326b6b6e10b1f2aed9523b369989a519da274.jpg",
            versions: [
                SongVersion(
                    name: "4K 60FPS Remastered Classic",
                    bvid: "BV1x5411o7Kn",
                    cid: 505002580,
                    uploader: "蒴奈",
                    duration: 233,
                    audioQuality: "192kbps DASH",
                    picUrl: "https://i1.hdslb.com/bfs/archive/26e326b6b6e10b1f2aed9523b369989a519da274.jpg"
                )
            ]
        )
        
        return Playlist(
            name: "Electronic & Gaming Classics",
            description: "Iconic electronic and gaming themes remastered in pure audio mode.",
            coverUrl: "https://i1.hdslb.com/bfs/archive/26e326b6b6e10b1f2aed9523b369989a519da274.jpg",
            songs: [shelter, badApple]
        )
    }()
}
