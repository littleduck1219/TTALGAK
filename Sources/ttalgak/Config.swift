import Foundation
import CoreGraphics

// 밸런스/애니메이션 튜닝 값 전부 여기. 수치 밸런싱은 이 파일만 만지면 됨.
enum Tuning {
    // 창(window)
    static let sceneW: CGFloat = 900
    static let sceneH: CGFloat = 280
    static let dockGap: CGFloat = 16          // 독 위로 띄우는 간격

    // 스틱맨
    static let playerMaxHP: CGFloat = 100
    static let playerMargin: CGFloat = 70     // 화면 끝에서 스틱맨까지

    // 창(spear)
    static let spearSpeed: CGFloat = 760   // 최대 사거리 = v²/g. 화면 폭(900)을 커버해야 함
    static let spearDamage: CGFloat = 10
    static let gravity: CGFloat = 650
    static let throwCooldown: TimeInterval = 1.1
    static let spearLen: CGFloat = 74        // 캐릭터 키(~64)보다 길게

    // 적 — 체력은 선형×지수 복합 성장: 플레이어 화력(카드 중첩=지수)과 경쟁하도록
    static let enemyBaseHP: CGFloat = 10
    static let enemyHPGrowth: CGFloat = 0.22      // 선형항: 웨이브당 +22%
    static let enemyHPExpo: CGFloat = 1.07        // 지수항: 웨이브당 ×1.07 (후반 압박 담당)
    static let enemySpeed: CGFloat = 55
    static let enemySpeedGrowth: CGFloat = 0.04
    static let enemyDamage: CGFloat = 8
    static let enemyDmgGrowth: CGFloat = 0.05     // 접촉 데미지도 성장 — 후반 누수가 아프도록
    static let enemyAttackInterval: TimeInterval = 1.0
    static let waveBaseCount = 4
    static let waveCountGrowth = 2                // 웨이브당 +2마리
    static let spawnIntervalMin: TimeInterval = 0.35   // 스폰 간격 불규칙 범위
    static let spawnIntervalMax: TimeInterval = 1.7    // 웨이브당 -0.05씩 조여짐 (하한 0.5)

    // 콤보
    static let comboWindow: TimeInterval = 3.0

    // 던지기 모션 키포즈 타이밍(초) — 모션 튜닝은 여기
    static let windupDur: TimeInterval = 0.28
    static let throwDur: TimeInterval = 0.10
    static let followDur: TimeInterval = 0.22
    static let recoverDur: TimeInterval = 0.20
}

// 적 유형: 흑백 크리처 실루엣과 모션으로 구분
// 하급(grunt/runner/brute)은 물량, 정예(wyvern/reaper/juggernaut)는 저빈도 고위협 (보스 아님)
enum EnemyKind: CaseIterable {
    case grunt       // 구울: 굽은 등, 긴 팔과 발톱, 절뚝이는 걸음
    case runner      // 하운드: 네발 질주, 벌어진 턱, 무리지어 등장
    case brute       // 브루트: 거대한 몸통, 너클 워크, 내려찍기
    case wyvern      // 와이번: 공중 비행 — 높은 조준 강제, 급강하 공격
    case reaper      // 리퍼: 낫 든 그림자 — 주기적 순간이동 전진
    case juggernaut  // 저거너트: 각진 장갑 덩치 — 넉백 면역급, 최고 체력

    var isElite: Bool {
        switch self { case .wyvern, .reaper, .juggernaut: return true; default: return false }
    }
    var unlockWave: Int {
        switch self {
        case .grunt: 1; case .runner: 2; case .brute: 4
        case .wyvern: 6; case .reaper: 7; case .juggernaut: 9
        }
    }
    var hpMul: CGFloat {
        switch self {
        case .grunt: 1.0; case .runner: 0.45; case .brute: 3.5
        case .wyvern: 1.8; case .reaper: 5.0; case .juggernaut: 8.0
        }
    }
    var speedMul: CGFloat {
        switch self {
        case .grunt: 1.0; case .runner: 2.3; case .brute: 0.55
        case .wyvern: 1.25; case .reaper: 0.95; case .juggernaut: 0.42
        }
    }
    var dmgMul: CGFloat {
        switch self {
        case .grunt: 1.0; case .runner: 0.7; case .brute: 2.2
        case .wyvern: 1.5; case .reaper: 2.5; case .juggernaut: 3.2
        }
    }
    var lineWidth: CGFloat {
        switch self {
        case .grunt: 3.2; case .runner: 3.2; case .brute: 5.5
        case .wyvern: 3.0; case .reaper: 3.4; case .juggernaut: 5.0
        }
    }
    var gaitFreq: CGFloat {
        switch self {
        case .grunt: 6.5; case .runner: 9.5; case .brute: 4.2
        case .wyvern: 9.0; case .reaper: 5.0; case .juggernaut: 3.5
        }
    }
    var hitHalfW: CGFloat {
        switch self {
        case .grunt: 14; case .runner: 18; case .brute: 19
        case .wyvern: 20; case .reaper: 13; case .juggernaut: 22
        }
    }
    var hitH: CGFloat {
        switch self {
        case .grunt: 48; case .runner: 34; case .brute: 70
        case .wyvern: 100; case .reaper: 62; case .juggernaut: 76
        }
    }
    // 명중 박스 하한 (지면 기준) — 와이번은 공중이라 낮은 창은 밑으로 지나감
    var hitYMin: CGFloat { self == .wyvern ? 40 : 0 }
    // 넉백 저항 (0 = 면역)
    var knockbackMul: CGFloat {
        switch self { case .juggernaut: 0.15; case .reaper: 0.8; default: 1.0 }
    }
}

// MARK: - 업그레이드 (등급제)

enum Tier {
    case common, rare, unique
    var label: String? {
        switch self { case .common: return nil; case .rare: return "RARE"; case .unique: return "UNIQUE" }
    }
}

enum UpgradeEffect {
    case damage(CGFloat)          // 공격력 배율
    case cooldown(CGFloat)        // 쿨다운 배율
    case spearSpeed(CGFloat)
    case toughen(CGFloat)         // 최대 체력 +
    case heal(CGFloat)            // 최대 체력 비율 회복
    case knockback(CGFloat)
    case critChance(CGFloat)
    case critMul(CGFloat)
    case pierce
    case doubleThrow(Double)
    case multishot(Int)           // 동시 투척 창 +n
    case powershot                // 매 N번째 강화 투척
    case lifesteal(CGFloat)
    case comboMaster
    case chill                    // 명중 시 감속
    case splash                   // 폭발창
    case execute(CGFloat)         // 체력 비율 이하 즉사
    case globalSlow(CGFloat)
    case bruteHunter(CGFloat)
    case chain(CGFloat)           // 번개 연쇄
    case revive
    case master                   // 명장의 창 (크리 복합)
}

struct UpgradeDef {
    let id: String
    let tier: Tier
    let title: String
    let desc: String
    let effect: UpgradeEffect
}

enum Upgrades {
    static let pool: [UpgradeDef] = [
        // 일반 (65%)
        .init(id: "damage", tier: .common, title: "강한 창", desc: "공격력 +20%", effect: .damage(1.2)),
        .init(id: "haste", tier: .common, title: "빠른 손", desc: "공격속도 +15%", effect: .cooldown(0.87)),
        .init(id: "velocity", tier: .common, title: "강속구", desc: "창 속도 +10%", effect: .spearSpeed(1.1)),
        .init(id: "tough", tier: .common, title: "단련", desc: "최대 체력 +20", effect: .toughen(20)),
        .init(id: "heal", tier: .common, title: "회복", desc: "체력 40% 회복", effect: .heal(0.4)),
        .init(id: "knock", tier: .common, title: "넉백", desc: "명중 넉백 강화", effect: .knockback(6)),
        .init(id: "focus", tier: .common, title: "집중", desc: "치명타 확률 +5%p", effect: .critChance(0.05)),
        .init(id: "hone", tier: .common, title: "급소 연마", desc: "치명타 피해 +25%p", effect: .critMul(0.25)),
        // 레어 (28%)
        .init(id: "crit", tier: .rare, title: "크리티컬", desc: "치명타 확률 +15%p", effect: .critChance(0.15)),
        .init(id: "power", tier: .rare, title: "파워샷", desc: "매 4번째 투척 2배 강화", effect: .powershot),
        .init(id: "pierce", tier: .rare, title: "관통", desc: "창이 적 1마리를 더 뚫음", effect: .pierce),
        .init(id: "double", tier: .rare, title: "연속 투척", desc: "2연속 투척 확률 +25%p", effect: .doubleThrow(0.25)),
        .init(id: "multi", tier: .rare, title: "쌍창", desc: "동시 투척 창 +1", effect: .multishot(1)),
        .init(id: "leech", tier: .rare, title: "흡혈", desc: "처치 시 체력 +2", effect: .lifesteal(2)),
        .init(id: "combo", tier: .rare, title: "콤보 마스터", desc: "콤보당 공격력 +1%, 유지 +1초", effect: .comboMaster),
        .init(id: "chill", tier: .rare, title: "냉기 창", desc: "명중한 적 2초간 30% 감속", effect: .chill),
        // 유니크 (7%, 1회 한정)
        .init(id: "splash", tier: .unique, title: "폭발창", desc: "명중 지점 주변 50% 피해", effect: .splash),
        .init(id: "execute", tier: .unique, title: "처형자", desc: "체력 25% 이하 적 즉사", effect: .execute(0.25)),
        .init(id: "slow", tier: .unique, title: "시간 왜곡", desc: "모든 적 이동속도 -20%", effect: .globalSlow(0.8)),
        .init(id: "giant", tier: .unique, title: "거인 사냥꾼", desc: "브루트에게 +80% 피해", effect: .bruteHunter(1.8)),
        .init(id: "chain", tier: .unique, title: "번개 창", desc: "명중 시 근처 적에게 50% 연쇄", effect: .chain(0.5)),
        .init(id: "phoenix", tier: .unique, title: "불사조", desc: "죽음을 1회 무시하고 부활", effect: .revive),
        .init(id: "master", tier: .unique, title: "명장의 창", desc: "치명타 확률 +25%p, 피해 +50%p", effect: .master),
        .init(id: "trident", tier: .unique, title: "삼지창", desc: "동시 투척 창 +2", effect: .multishot(2)),
    ]
}

struct Stats {
    var damage = Tuning.spearDamage
    var cooldown = Tuning.throwCooldown
    var spearSpeed = Tuning.spearSpeed
    var pierce = 0
    var doubleThrowChance = 0.0
    var hp = Tuning.playerMaxHP
    var maxHP = Tuning.playerMaxHP
    var critChance: CGFloat = 0
    var critMul: CGFloat = 2.0
    var knockback: CGFloat = 3
    var multishot = 0                       // 동시 추가 창 (상한 4)
    var powershotEvery = 0                  // 0 = 미보유. 중첩 시 주기 -1 (최소 2)
    var lifesteal: CGFloat = 0
    var comboDmgPer: CGFloat = 0            // 콤보 1당 공격력 보너스 (합산 상한 30%)
    var comboWindowBonus: TimeInterval = 0
    var chillOnHit = false
    var splash = false
    var executeAt: CGFloat = 0
    var globalSlow: CGFloat = 1
    var bruteMul: CGFloat = 1
    var chainRatio: CGFloat = 0
    var hasRevive = false

    mutating func apply(_ u: UpgradeDef) {
        switch u.effect {
        case .damage(let m): damage *= m
        case .cooldown(let m): cooldown *= m
        case .spearSpeed(let m): spearSpeed *= m
        case .toughen(let v): maxHP += v; hp = min(maxHP, hp + v)
        case .heal(let r): hp = min(maxHP, hp + maxHP * r)
        case .knockback(let v): knockback += v
        case .critChance(let v): critChance = min(1, critChance + v)
        case .critMul(let v): critMul += v
        case .pierce: pierce += 1
        case .doubleThrow(let v): doubleThrowChance = min(1, doubleThrowChance + v)
        case .multishot(let n): multishot = min(4, multishot + n)
        case .powershot: powershotEvery = powershotEvery == 0 ? 4 : max(2, powershotEvery - 1)
        case .lifesteal(let v): lifesteal += v
        case .comboMaster: comboDmgPer += 0.01; comboWindowBonus += 1
        case .chill: chillOnHit = true
        case .splash: splash = true
        case .execute(let t): executeAt = max(executeAt, t)
        case .globalSlow(let m): globalSlow *= m
        case .bruteHunter(let m): bruteMul *= m
        case .chain(let r): chainRatio = max(chainRatio, r)
        case .revive: hasRevive = true
        case .master: critChance = min(1, critChance + 0.25); critMul += 0.5
        }
    }
}
