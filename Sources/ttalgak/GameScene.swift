import SpriteKit
import AppKit

// 창(spear) 노드: +x 방향, 중심 기준 -len/2..+len/2
final class Spear: SKNode {
    var vel = CGVector.zero
    var pierce = 0
    var damage: CGFloat = 0
    var isPower = false
    var landed = false
    var hitSet = Set<ObjectIdentifier>()

    init(color: SKColor) {
        super.init()
        let len = Tuning.spearLen
        let shaft = CGMutablePath()
        shaft.move(to: CGPoint(x: -len / 2, y: 0))
        shaft.addLine(to: CGPoint(x: len / 2 - 7, y: 0))
        let s = SKShapeNode(path: shaft)
        s.strokeColor = color
        s.lineWidth = 2.5
        s.lineCap = .round
        addChild(s)
        let tipPath = CGMutablePath()
        tipPath.move(to: CGPoint(x: len / 2, y: 0))
        tipPath.addLine(to: CGPoint(x: len / 2 - 9, y: 3.2))
        tipPath.addLine(to: CGPoint(x: len / 2 - 9, y: -3.2))
        tipPath.closeSubpath()
        let tip = SKShapeNode(path: tipPath)
        tip.fillColor = color
        tip.strokeColor = color
        addChild(tip)
    }
    required init?(coder: NSCoder) { fatalError() }

    var tipPoint: CGPoint {
        CGPoint(x: position.x + cos(zRotation) * Tuning.spearLen / 2,
                y: position.y + sin(zRotation) * Tuning.spearLen / 2)
    }
}

final class Enemy: SKNode {
    let kind: EnemyKind
    let fig: any CreatureFigure
    var hp: CGFloat
    let maxHP: CGFloat
    var moveSpeed: CGFloat
    var damage: CGFloat
    let hitHalfW: CGFloat
    let hitH: CGFloat
    var attackTimer: TimeInterval = 0
    var walkPhase: CGFloat = .random(in: 0 ..< (2 * .pi))
    var chillTimer: TimeInterval = 0
    var blinkTimer: TimeInterval = .random(in: 1.5 ... 2.5)   // 리퍼 순간이동 주기
    var inMelee = false   // 근접 공격 중 (와이번은 급강하로 낮아지므로 명중 하한 해제)
    var dying = false

    init(kind: EnemyKind, hp: CGFloat, speed: CGFloat, damage: CGFloat) {
        self.kind = kind
        self.hp = hp
        self.maxHP = hp
        self.moveSpeed = speed
        self.damage = damage
        hitHalfW = kind.hitHalfW
        hitH = kind.hitH
        fig = kind.makeFigure(color: .black)
        super.init()
        addChild(fig)
    }
    required init?(coder: NSCoder) { fatalError() }

    func chill() { chillTimer = 2 }

    func update(dt: TimeInterval, playerX: CGFloat, inRange: Bool, speedMul: CGFloat) {
        let facing: CGFloat = playerX >= position.x ? 1 : -1
        fig.xScale = facing
        chillTimer = max(0, chillTimer - dt)
        inMelee = inRange
        if inRange {
            // 공격 주기 시작 직후 0.3초 동안 스윙
            let t = CGFloat(min(1, (Tuning.enemyAttackInterval - attackTimer) / 0.3))
            fig.attack(sin(t * .pi))
        } else {
            let mul = speedMul * (chillTimer > 0 ? 0.7 : 1)
            walkPhase += CGFloat(dt) * kind.gaitFreq * mul
            position.x += facing * moveSpeed * mul * CGFloat(dt)
            fig.animate(phase: walkPhase)
            if kind == .reaper {   // 주기적 순간이동 전진
                blinkTimer -= dt
                if blinkTimer <= 0 {
                    blinkTimer = 2.5
                    position.x += facing * 70
                    fig.run(.sequence([.fadeAlpha(to: 0.15, duration: 0.06),
                                       .fadeAlpha(to: 1, duration: 0.3)]))
                }
            }
        }
    }

    func die() {
        dying = true
        let fall = SKAction.rotate(toAngle: fig.xScale > 0 ? -.pi / 2 : .pi / 2, duration: 0.35)
        fall.timingMode = .easeIn
        run(.sequence([.group([fall, .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }
}

// 포물선 조준: 고정 속력 v로 (0,0)→(dx,dy) 명중각(낮은 궤적) 풀이
func aimVelocity(from p: CGPoint, to t: CGPoint, speed v: CGFloat) -> CGVector {
    let dx = t.x - p.x, dy = t.y - p.y
    let g = Tuning.gravity
    let ax = abs(dx)
    let disc = v * v * v * v - g * (g * ax * ax + 2 * dy * v * v)
    let sign: CGFloat = dx < 0 ? -1 : 1
    if disc > 0, ax > 1 {
        let theta = atan((v * v - sqrt(disc)) / (g * ax))
        return CGVector(dx: cos(theta) * v * sign, dy: sin(theta) * v)
    }
    let ang = atan2(dy, ax) + 0.35   // 사거리 밖: 최대한 멀리
    return CGVector(dx: cos(ang) * v * sign, dy: sin(ang) * v)
}

final class GameScene: SKScene {
    var onInteractive: ((Bool) -> Void)?

    private enum State { case playing, choosing, gameover }
    private var state = State.playing

    private let player = Player()
    private var enemies: [Enemy] = []
    private var spears: [Spear] = []
    private var stats = Stats()
    private var wave = 1
    private var toSpawn = 0
    private var spawnIndex = 0
    private var eliteAt: [Int: EnemyKind] = [:]   // 이번 웨이브 정예 스폰 슬롯
    private var spawnTimer: TimeInterval = 0
    private var throwTimer: TimeInterval = 0
    private var pendingAim: CGPoint?
    private var combo = 0
    private var comboTimer: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var mirrored = UserDefaults.standard.bool(forKey: "mirrored")
    private var themeColor: SKColor = UserDefaults.standard.bool(forKey: "whiteTheme") ? .white : .black
    private var ground: SKShapeNode!

    private let groundY: CGFloat = 26
    private let hpBar = SKSpriteNode(color: .black, size: CGSize(width: 36, height: 3.5))
    private var overlay: SKNode?
    private var pendingUpgrades: [UpgradeDef] = []
    private var uniquesTaken = Set<String>()
    private var throwCount = 0

    private var playerX: CGFloat { mirrored ? size.width - Tuning.playerMargin : Tuning.playerMargin }

    override func didMove(to view: SKView) {
        // 잠금 해제 복구 시 씬을 재부착하면 didMove가 다시 불림 → 중복 셋업 방지
        guard ground == nil else { return }
        backgroundColor = .clear

        ground = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 20, y: groundY))
            p.addLine(to: CGPoint(x: size.width - 20, y: groundY))
            return p
        }())
        ground.strokeColor = themeColor.withAlphaComponent(0.3)
        ground.lineWidth = 1.5
        addChild(ground)

        player.position = CGPoint(x: playerX, y: groundY)
        player.setColor(themeColor)
        addChild(player)
        player.onRelease = { [weak self] in self?.launchSpears() }

        hpBar.color = themeColor
        hpBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBar.alpha = 0
        addChild(hpBar)

        applyLayout()
        startWave()
    }

    // MARK: - 레이아웃/설정

    func setTheme(white: Bool) {
        UserDefaults.standard.set(white, forKey: "whiteTheme")
        themeColor = white ? .white : .black
        ground.strokeColor = themeColor.withAlphaComponent(0.3)
        hpBar.color = themeColor
        player.setColor(themeColor)
        for e in enemies { e.tintShapes(themeColor) }
        for s in spears { s.tintShapes(themeColor) }
    }

    func setMirrored(_ flag: Bool) {
        mirrored = flag
        UserDefaults.standard.set(flag, forKey: "mirrored")
        for e in enemies { e.position.x = size.width - e.position.x }
        for s in spears { s.removeFromParent() }
        spears.removeAll()
        applyLayout()
    }

    private func applyLayout() {
        player.position.x = playerX
        player.xScale = mirrored ? -1 : 1
        hpBar.position = CGPoint(x: playerX - 18, y: groundY + 72)
    }

    func restart() {
        overlay?.removeFromParent(); overlay = nil
        for e in enemies { e.removeFromParent() }
        for s in spears { s.removeFromParent() }
        enemies = []; spears = []
        stats = Stats()
        uniquesTaken.removeAll()
        throwCount = 0
        wave = 1
        combo = 0
        hpBar.alpha = 0
        state = .playing
        onInteractive?(false)
        startWave()
    }

    // MARK: - 웨이브

    private func startWave() {
        toSpawn = Tuning.waveBaseCount + Tuning.waveCountGrowth * (wave - 1)
        spawnTimer = 0.5
        throwTimer = 0.6
        spawnIndex = 0
        // 정예 편성: 웨이브 5+ 1마리, 9+ 2마리. 스폰 순번 중간 이후 랜덤 슬롯에 배치
        eliteAt = [:]
        if wave >= 6 {
            let unlocked = EnemyKind.allCases.filter { $0.isElite && wave >= $0.unlockWave }
            let count = min(5, 1 + (wave - 6) / 4)   // w6:1, w10:2, w14:3, w18:4, w22+:5
            var slots = Array(1 ..< toSpawn).shuffled()
            for _ in 0 ..< count {
                if let kind = unlocked.randomElement(), let slot = slots.popLast() {
                    eliteAt[slot] = kind
                }
            }
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "WAVE \(wave)"
        label.fontSize = 15
        label.fontColor = themeColor.withAlphaComponent(0.85)
        label.position = CGPoint(x: size.width / 2, y: size.height - 34)
        label.alpha = 0
        addChild(label)
        label.run(.sequence([.fadeIn(withDuration: 0.25), .wait(forDuration: 1.2),
                             .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    // 하급 풀: 웨이브가 오를수록 하운드/브루트 비중 증가 (정예는 eliteAt 슬롯으로 별도 편성)
    private func rollKind() -> EnemyKind {
        var pool: [(EnemyKind, Double)] = [(.grunt, 1.0)]
        if wave >= 2 { pool.append((.runner, 0.2 + 0.05 * Double(wave))) }
        if wave >= 4 { pool.append((.brute, 0.1 + 0.03 * Double(wave))) }
        var r = Double.random(in: 0 ..< pool.reduce(0) { $0 + $1.1 })
        for (k, w) in pool { r -= w; if r < 0 { return k } }
        return .grunt
    }

    private func spawnEnemy(_ kind: EnemyKind, offset: CGFloat = 0) {
        let w = CGFloat(wave - 1)
        let hpGrowth = (1 + Tuning.enemyHPGrowth * w) * pow(Tuning.enemyHPExpo, w)
        let hp = Tuning.enemyBaseHP * kind.hpMul * hpGrowth
        let sp = Tuning.enemySpeed * kind.speedMul * (1 + Tuning.enemySpeedGrowth * w)
        let dmg = Tuning.enemyDamage * kind.dmgMul * (1 + Tuning.enemyDmgGrowth * w)
        let e = Enemy(kind: kind, hp: hp, speed: sp, damage: dmg)
        e.tintShapes(themeColor)
        let edge: CGFloat = mirrored ? -30 - offset : size.width + 30 + offset
        e.position = CGPoint(x: edge, y: groundY)
        addChild(e)
        enemies.append(e)
    }

    // MARK: - 투척

    // 클릭 → 쿨다운/모션 체크 후 던지기 시작. (스냅샷 모드도 이걸 호출)
    func requestThrow(at point: CGPoint) {
        guard state == .playing, throwTimer <= 0, !player.isThrowing else { return }
        pendingAim = point
        player.startThrow()
        throwTimer = stats.cooldown
    }

    private func launchSpears() {
        guard let aim = pendingAim else { return }
        pendingAim = nil
        throwCount += 1
        let isPower = stats.powershotEvery > 0 && throwCount % stats.powershotEvery == 0
        let hand = player.fig.hand.convert(CGPoint.zero, to: self)
        fireVolley(from: hand, to: aim, isPower: isPower)
        if Double.random(in: 0 ..< 1) < stats.doubleThrowChance {
            run(.sequence([.wait(forDuration: 0.1), .run { [weak self] in
                self?.fireVolley(from: hand, to: aim, isPower: isPower, extraOffset: 0.05)
            }]))
        }
    }

    // 멀티샷: 부채꼴로 동시 발사. 첫 발 100%, 추가 창 75% 피해
    private func fireVolley(from p: CGPoint, to aim: CGPoint, isPower: Bool, extraOffset: CGFloat = 0) {
        let offsets: [CGFloat] = [0, 0.09, -0.09, 0.18, -0.18]
        for i in 0 ... stats.multishot {
            fire(from: p, to: aim, angleOffset: offsets[i] + extraOffset,
                 damageMul: (i == 0 ? 1 : 0.75) * (isPower ? 2 : 1), isPower: isPower)
        }
    }

    private func fire(from p: CGPoint, to aim: CGPoint, angleOffset: CGFloat,
                      damageMul: CGFloat, isPower: Bool) {
        let s = Spear(color: themeColor)
        s.position = p
        let v = aimVelocity(from: p, to: aim, speed: stats.spearSpeed)
        s.vel = CGVector(dx: v.dx * cos(angleOffset) - v.dy * sin(angleOffset),
                         dy: v.dx * sin(angleOffset) + v.dy * cos(angleOffset))
        s.zRotation = atan2(s.vel.dy, s.vel.dx)
        s.damage = stats.damage * damageMul
        s.pierce = stats.pierce
        s.isPower = isPower
        if isPower { s.setScale(1.25) }
        addChild(s)
        spears.append(s)
    }

    // MARK: - 메인 루프

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime

        player.update(dt: dt)
        updateSpears(dt: dt)

        guard state == .playing else { return }

        // 스폰
        if toSpawn > 0 {
            spawnTimer -= dt
            if spawnTimer <= 0 {
                let kind = eliteAt[spawnIndex] ?? rollKind()
                spawnEnemy(kind)
                spawnIndex += 1
                toSpawn -= 1
                // 하운드는 무리지어 등장
                if kind == .runner, toSpawn > 0, Bool.random() {
                    spawnEnemy(.runner, offset: 26)
                    toSpawn -= 1
                }
                let maxGap = max(0.5, Tuning.spawnIntervalMax - 0.05 * Double(wave - 1))
                spawnTimer = .random(in: Tuning.spawnIntervalMin ... maxGap)
            }
        }

        // 적
        for e in enemies where !e.dying {
            let inRange = abs(e.position.x - playerX) < 30
            e.update(dt: dt, playerX: playerX, inRange: inRange, speedMul: stats.globalSlow)
            if inRange {
                e.attackTimer -= dt
                if e.attackTimer <= 0 {
                    e.attackTimer = Tuning.enemyAttackInterval
                    playerHit(e.damage)
                }
            }
        }

        throwTimer -= dt   // 투척 쿨다운 (클릭으로 소비)

        // 콤보 타임아웃
        if combo > 0 {
            comboTimer -= dt
            if comboTimer <= 0 { combo = 0 }
        }

        // 웨이브 클리어
        if toSpawn == 0, enemies.isEmpty {
            showUpgradeChoices()
        }
    }

    private func updateSpears(dt: TimeInterval) {
        var dead: [Spear] = []
        for s in spears where !s.landed {
            s.vel.dy -= Tuning.gravity * CGFloat(dt)
            s.position.x += s.vel.dx * CGFloat(dt)
            s.position.y += s.vel.dy * CGFloat(dt)
            s.zRotation = atan2(s.vel.dy, s.vel.dx)
            let tip = s.tipPoint

            if tip.x < -80 || tip.x > size.width + 80 { dead.append(s); continue }

            if tip.y <= groundY {   // 땅에 꽂힘
                s.landed = true
                s.run(.sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.4), .removeFromParent()]))
                dead.append(s)
                continue
            }

            for e in enemies where !e.dying && !s.hitSet.contains(ObjectIdentifier(e)) {
                // 촉 + 창 중심 두 점 판정: 딱 붙은 적은 촉이 스폰 순간 이미 지나쳐 있어 중심점이 잡아줌
                let yMin = e.position.y + (e.inMelee ? 0 : e.kind.hitYMin)   // 와이번: 비행 중엔 낮은 창이 밑으로 통과
                let yMax = e.position.y + e.hitH
                let hit = [tip, s.position].contains {
                    abs($0.x - e.position.x) < e.hitHalfW && $0.y < yMax && $0.y >= yMin
                }
                if hit {
                    s.hitSet.insert(ObjectIdentifier(e))
                    spearHit(s, e)
                    s.pierce -= 1
                    if s.pierce < 0 {
                        s.removeFromParent()
                        dead.append(s)
                        break
                    }
                }
            }
        }
        if !dead.isEmpty { spears.removeAll { d in dead.contains { $0 === d } } }
    }

    // 창 명중: 배율(콤보/브루트/크리) 계산 후 부가 효과(냉기/스플래시/체인) 발동
    private func spearHit(_ s: Spear, _ e: Enemy) {
        var dmg = s.damage * (1 + min(0.3, CGFloat(combo) * stats.comboDmgPer))
        if e.kind == .brute || e.kind == .juggernaut { dmg *= stats.bruteMul }   // 거인 사냥꾼
        var crit = false
        if stats.critChance > 0, CGFloat.random(in: 0 ..< 1) < stats.critChance {
            dmg *= stats.critMul
            crit = true
        }
        if stats.chillOnHit { e.chill() }
        damageEnemy(e, dmg, knockback: stats.knockback * (s.isPower ? 3 : 1), crit: crit)

        if stats.splash {
            splashRing(at: CGPoint(x: e.position.x, y: e.position.y + e.hitH / 2))
            for o in enemies where o !== e && !o.dying && abs(o.position.x - e.position.x) < 60 {
                damageEnemy(o, dmg * 0.5, knockback: 0, crit: false)
            }
        }
        if stats.chainRatio > 0 {
            let others = enemies.filter { $0 !== e && !$0.dying }
            if let o = others.min(by: { abs($0.position.x - e.position.x) < abs($1.position.x - e.position.x) }),
               abs(o.position.x - e.position.x) < 170 {
                chainBolt(from: CGPoint(x: e.position.x, y: e.position.y + e.hitH / 2),
                          to: CGPoint(x: o.position.x, y: o.position.y + o.hitH / 2))
                damageEnemy(o, dmg * stats.chainRatio, knockback: 0, crit: false)
            }
        }
    }

    private func damageEnemy(_ e: Enemy, _ dmg: CGFloat, knockback: CGFloat, crit: Bool) {
        guard !e.dying else { return }
        e.hp -= dmg
        if e.hp > 0, stats.executeAt > 0, e.hp <= e.maxHP * stats.executeAt {
            e.hp = 0   // 처형자
        }
        if crit {
            popText("CRIT", at: CGPoint(x: e.position.x, y: e.position.y + e.hitH + 22), size: 13)
        }
        if e.hp <= 0 {
            e.die()
            enemies.removeAll { $0 === e }
            if stats.lifesteal > 0 {
                stats.hp = min(stats.maxHP, stats.hp + stats.lifesteal)
                hpBar.xScale = max(0, stats.hp / stats.maxHP)
            }
            combo += 1
            comboTimer = Tuning.comboWindow + stats.comboWindowBonus
            if combo >= 2 {
                popText("\(combo) COMBO", at: CGPoint(x: e.position.x, y: e.position.y + e.hitH + 8), size: 11)
            }
        } else {
            e.fig.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeAlpha(to: 1, duration: 0.12)]))
            e.position.x += (e.position.x > playerX ? 1 : -1) * knockback * e.kind.knockbackMul
        }
    }

    // MARK: - 이펙트

    private func popText(_ text: String, at p: CGPoint, size: CGFloat) {
        let pop = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pop.text = text
        pop.fontSize = size
        pop.fontColor = themeColor
        pop.position = p
        addChild(pop)
        pop.run(.sequence([
            .group([.moveBy(x: 0, y: 26, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent(),
        ]))
    }

    private func splashRing(at p: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 60)
        ring.strokeColor = themeColor.withAlphaComponent(0.7)
        ring.lineWidth = 2
        ring.position = p
        ring.setScale(0.25)
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                            .removeFromParent()]))
    }

    private func chainBolt(from a: CGPoint, to b: CGPoint) {
        let path = CGMutablePath()
        path.move(to: a)
        // 지그재그 번개
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + 12)
        path.addLine(to: mid)
        path.addLine(to: b)
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = themeColor
        bolt.lineWidth = 1.5
        addChild(bolt)
        bolt.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }

    private func playerHit(_ damage: CGFloat) {
        guard state == .playing else { return }   // 같은 프레임 다중 공격이 gameOver를 중복 호출하는 것 방지
        stats.hp -= damage
        combo = 0
        player.fig.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.06), .fadeAlpha(to: 1, duration: 0.15)]))
        hpBar.alpha = 1
        hpBar.xScale = max(0, stats.hp / stats.maxHP)
        if stats.hp <= 0 {
            if stats.hasRevive {   // 불사조: 1회 부활 + 적 밀쳐내기
                stats.hasRevive = false
                stats.hp = stats.maxHP * 0.5
                hpBar.xScale = 0.5
                for e in enemies { e.position.x += (e.position.x >= playerX ? 1 : -1) * 130 }
                player.fig.run(.sequence([.fadeOut(withDuration: 0.1), .fadeIn(withDuration: 0.35)]))
                popText("REVIVE", at: CGPoint(x: playerX, y: groundY + 90), size: 14)
            } else {
                gameOver()
            }
        }
    }

    // MARK: - 업그레이드 / 게임오버 오버레이

    // 등급 롤: 일반 65 / 레어 28 / 유니크 7(웨이브 5부터 +1%p/웨이브, 상한 15).
    // 웨이브 5+에서 유니크 미보유면 첫 카드를 유니크로 보장.
    private func rollCards() -> [UpgradeDef] {
        var picks: [UpgradeDef] = []
        var used = Set<String>()
        let uniqueP = wave >= 5 ? min(0.15, 0.07 + 0.01 * Double(wave - 4)) : 0.07
        let hasUniqueLeft = Upgrades.pool.contains { $0.tier == .unique && !uniquesTaken.contains($0.id) }
        let forceUnique = wave >= 5 && uniquesTaken.isEmpty && hasUniqueLeft
        for i in 0 ..< 3 {
            let r = Double.random(in: 0 ..< 1)
            let tier: Tier = (i == 0 && forceUnique) ? .unique
                : r < uniqueP ? .unique
                : r < uniqueP + 0.28 ? .rare
                : .common
            var candidates = Upgrades.pool.filter {
                $0.tier == tier && !used.contains($0.id)
                    && !($0.tier == .unique && uniquesTaken.contains($0.id))
            }
            if candidates.isEmpty {   // 유니크 소진 등 → 일반으로 폴백
                candidates = Upgrades.pool.filter { $0.tier == .common && !used.contains($0.id) }
            }
            if let pick = candidates.randomElement() {
                used.insert(pick.id)
                picks.append(pick)
            }
        }
        return picks
    }

    // 스냅샷 검증용: 등급별 카드 하나씩 강제 표시
    func debugShowUpgradeCards() {
        showUpgradeChoices(cards: [
            Upgrades.pool.first { $0.tier == .common }!,
            Upgrades.pool.first { $0.tier == .rare }!,
            Upgrades.pool.first { $0.tier == .unique }!,
        ])
        // 스냅샷은 SKAction이 돌지 않으므로 등장 연출 결과 상태를 강제 적용
        overlay?.children.forEach { $0.alpha = 1; $0.setScale(1) }
    }

    private func showUpgradeChoices(cards: [UpgradeDef]? = nil) {
        state = .choosing
        pendingUpgrades = cards ?? rollCards()
        let node = SKNode()
        node.zPosition = 50
        for (i, u) in pendingUpgrades.enumerated() {
            let card = SKShapeNode(rectOf: CGSize(width: 166, height: 100), cornerRadius: 12)
            card.fillColor = SKColor(white: 0.08, alpha: 0.88)
            card.strokeColor = SKColor(white: 1, alpha: u.tier == .unique ? 0.95 : 0.55)
            card.lineWidth = u.tier == .unique ? 2.5 : 1.2
            card.name = "card\(i)"
            card.position = CGPoint(x: size.width / 2 + CGFloat(i - 1) * 186, y: size.height / 2 + 10)

            if u.tier == .rare {   // 이중 테두리
                let inner = SKShapeNode(rectOf: CGSize(width: 156, height: 90), cornerRadius: 9)
                inner.strokeColor = SKColor(white: 1, alpha: 0.4)
                inner.lineWidth = 1
                inner.name = card.name
                card.addChild(inner)
            }
            if let tierText = u.tier.label {
                let tag = SKLabelNode(fontNamed: "AvenirNext-Bold")
                tag.text = u.tier == .unique ? "◆ \(tierText) ◆" : tierText
                tag.fontSize = 9
                tag.fontColor = SKColor(white: 1, alpha: 0.85)
                tag.position = CGPoint(x: 0, y: 34)
                tag.name = card.name
                card.addChild(tag)
            }
            let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
            title.text = u.title
            title.fontSize = 16
            title.position = CGPoint(x: 0, y: 8)
            title.name = card.name
            card.addChild(title)
            let desc = SKLabelNode(fontNamed: "AvenirNext-Regular")
            desc.text = u.desc
            desc.fontSize = 11
            desc.fontColor = SKColor(white: 1, alpha: 0.75)
            desc.position = CGPoint(x: 0, y: -24)
            desc.name = card.name
            card.addChild(desc)

            card.setScale(0.7)
            card.alpha = 0
            node.addChild(card)
            var entrance: [SKAction] = [.group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.22)])]
            if u.tier == .unique {   // 펄스 연출
                entrance.append(.repeatForever(.sequence([.scale(to: 1.03, duration: 0.5),
                                                          .scale(to: 1.0, duration: 0.5)])))
            }
            card.run(.sequence(entrance))
        }
        addChild(node)
        overlay = node
        onInteractive?(true)
    }

    private func gameOver() {
        guard state != .gameover else { return }   // 오버레이 중복 생성 방지
        state = .gameover
        overlay?.removeFromParent()                // 혹시 남은 오버레이(카드 등) 정리
        let node = SKNode()
        node.zPosition = 50
        let box = SKShapeNode(rectOf: CGSize(width: 260, height: 90), cornerRadius: 12)
        box.fillColor = SKColor(white: 0.05, alpha: 0.9)
        box.strokeColor = SKColor(white: 1, alpha: 0.6)
        box.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        box.name = "restart"
        let l1 = SKLabelNode(fontNamed: "AvenirNext-Bold")
        l1.text = "GAME OVER — WAVE \(wave)"
        l1.fontSize = 16
        l1.position = CGPoint(x: 0, y: 10)
        l1.name = "restart"
        box.addChild(l1)
        let l2 = SKLabelNode(fontNamed: "AvenirNext-Regular")
        l2.text = "클릭하면 다시 시작"
        l2.fontSize = 12
        l2.fontColor = SKColor(white: 1, alpha: 0.7)
        l2.position = CGPoint(x: 0, y: -18)
        l2.name = "restart"
        box.addChild(l2)
        node.addChild(box)
        addChild(node)
        overlay = node
        onInteractive?(true)
    }

    private func selectUpgrade(_ i: Int) {
        guard state == .choosing, i < pendingUpgrades.count else { return }
        let pick = pendingUpgrades[i]
        stats.apply(pick)
        if pick.tier == .unique { uniquesTaken.insert(pick.id) }   // 유니크는 1회 한정
        hpBar.xScale = max(0, stats.hp / stats.maxHP)   // heal/toughen 반영
        overlay?.removeFromParent(); overlay = nil
        state = .playing
        onInteractive?(false)
        wave += 1
        startWave()
    }

    override func mouseDown(with event: NSEvent) {
        let loc = event.location(in: self)
        let names = nodes(at: loc).compactMap(\.name)
        if state == .choosing, let name = names.first(where: { $0.hasPrefix("card") }),
           let i = Int(name.dropFirst(4)) {
            selectUpgrade(i)
        } else if state == .gameover, names.contains("restart") {
            restart()
        } else if state == .playing {
            requestThrow(at: loc)
        }
    }
}

// --selftest: 조준 풀이와 포즈 보간 검증
func runSelfTest() {
    // 포물선 조준이 실제 시뮬레이션(오일러 적분)으로 목표 근처에 도달하는가
    let from = CGPoint(x: 100, y: 90)
    let to = CGPoint(x: 620, y: 68)
    let v = aimVelocity(from: from, to: to, speed: Tuning.spearSpeed)
    var p = from, vel = v
    let dt: CGFloat = 1.0 / 240
    var steps = 0
    while p.x < to.x, steps < 5000 {
        vel.dy -= Tuning.gravity * dt
        p.x += vel.dx * dt
        p.y += vel.dy * dt
        steps += 1
    }
    assert(abs(p.y - to.y) < 20, "ballistic miss: y=\(p.y) target=\(to.y)")

    // 반전(적이 왼쪽) 방향도 부호가 맞는가
    let vl = aimVelocity(from: CGPoint(x: 600, y: 90), to: CGPoint(x: 100, y: 68), speed: Tuning.spearSpeed)
    assert(vl.dx < 0, "mirrored aim should fly -x")

    // 포즈 보간 중간값
    let mid = Pose.lerp(.idle, .windup, 0.5)
    assert(abs(mid.lean - (Pose.idle.lean + Pose.windup.lean) / 2) < 0.0001, "pose lerp broken")

    print("selftest ok")
}

// MARK: - 시뮬레이션 API (밸런스 자동 테스트: main.swift --simulate)

extension GameScene {
    var simState: (wave: Int, hp: CGFloat, choosing: Bool, over: Bool) {
        (wave, stats.hp, state == .choosing, state == .gameover)
    }

    // 업그레이드 자동 선택: 화력 우선 휴리스틱
    func simChooseBest() {
        guard state == .choosing else { return }
        let priority = ["trident", "multi", "damage", "haste", "master", "crit", "power",
                        "splash", "chain", "pierce", "double", "combo", "giant", "execute",
                        "hone", "focus", "slow", "chill", "leech", "velocity", "heal", "tough", "knock"]
        let best = pendingUpgrades.indices.min {
            (priority.firstIndex(of: pendingUpgrades[$0].id) ?? 99)
                < (priority.firstIndex(of: pendingUpgrades[$1].id) ?? 99)
        }
        selectUpgrade(best ?? 0)
    }

    // 가장 가까운 적을 리드샷 조준 (accuracy 0~1: 낮을수록 조준 오차 큼)
    func simAimPoint(accuracy: CGFloat) -> CGPoint? {
        guard let e = enemies.filter({ !$0.dying })
            .min(by: { abs($0.position.x - playerX) < abs($1.position.x - playerX) }) else { return nil }
        let chestY = e.position.y + (e.kind.hitYMin + e.hitH) * 0.55
        let tFly = abs(e.position.x - playerX) / stats.spearSpeed
        let dir: CGFloat = playerX >= e.position.x ? 1 : -1
        let lead = e.position.x + dir * e.moveSpeed * tFly
        let errX = CGFloat.random(in: -1 ... 1) * (1 - accuracy) * 120
        let errY = CGFloat.random(in: -1 ... 1) * (1 - accuracy) * 45
        return CGPoint(x: lead + errX, y: chestY + errY)
    }
}
