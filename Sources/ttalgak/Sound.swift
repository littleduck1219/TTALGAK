import AVFoundation

// 효과음: Sounds/*.wav (합성 8bit풍). 사운드별 플레이어 풀로 겹침 재생 허용.
final class Sound {
    static let shared = Sound()

    var enabled = !UserDefaults.standard.bool(forKey: "muted") {
        didSet { UserDefaults.standard.set(!enabled, forKey: "muted") }
    }

    private var pools: [String: [AVAudioPlayer]] = [:]
    private var next: [String: Int] = [:]
    private var lastPlay: [String: TimeInterval] = [:]

    private init() {
        for name in ["throw", "hit", "kill", "crit", "power", "card", "gameover"] {
            guard let url = Bundle.module.url(forResource: "Sounds/\(name)", withExtension: "wav")
                ?? Bundle.module.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0 ..< 3 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            pools[name] = pool
        }
    }

    var loadedCount: Int { pools.count }

    func play(_ name: String) {
        guard enabled, let pool = pools[name], !pool.isEmpty else { return }
        // 같은 소리의 같은 프레임 다중 호출(멀티샷 동시 명중) 스로틀 — play()는 싸지 않다
        let now = ProcessInfo.processInfo.systemUptime
        if let t = lastPlay[name], now - t < 0.04 { return }
        lastPlay[name] = now
        let i = (next[name] ?? 0) % pool.count
        next[name] = i + 1
        let p = pool[i]
        p.currentTime = 0
        p.play()
    }
}
