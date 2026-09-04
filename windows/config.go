package main

// 밸런스 수치 — macOS판 Config.swift(v0.2.6)와 1:1 대응. 수치 변경 시 양쪽 동기화할 것.

const (
	sceneW = 900.0
	sceneH = 280.0

	playerMaxHP  = 140.0
	playerMargin = 70.0

	spearSpeed    = 760.0
	spearDamage   = 12.0
	gravity       = 650.0
	throwCooldown = 0.9
	spearLen      = 74.0

	enemyBaseHP         = 10.0
	enemyHPGrowth       = 0.18
	enemyHPExpo         = 1.05
	enemySpeedBase      = 50.0
	enemySpeedGrowth    = 0.04
	enemyDamageBase     = 8.0
	enemyDmgGrowth      = 0.03
	enemyAttackInterval = 1.0
	waveBaseCount       = 5
	waveCountGrowth     = 1
	spawnIntervalMin    = 0.35
	spawnIntervalMax    = 1.7

	bossEvery          = 10
	bossSummonInterval = 4.5
	bossAttackInterval = 1.4

	comboWindow   = 3.0
	waveClearHeal = 22.0

	windupDur  = 0.28
	throwDur   = 0.10
	followDur  = 0.22
	recoverDur = 0.20

	enemyHitYMinWyvern = 40.0
	groundY            = 26.0
)

// ── 난이도 모드 (적 스탯에만 배율) ──

type difficulty int

const (
	dEasy difficulty = iota
	dNormal
	dHard
)

func (d difficulty) title() string {
	switch d {
	case dEasy:
		return "이지"
	case dHard:
		return "하드"
	}
	return "노멀"
}

func (d difficulty) hpMul() float64 {
	switch d {
	case dEasy:
		return 0.7
	case dHard:
		return 1.3
	}
	return 1.0
}

func (d difficulty) dmgMul() float64 { return d.hpMul() }

func (d difficulty) countMul() float64 {
	switch d {
	case dEasy:
		return 0.85
	case dHard:
		return 1.15
	}
	return 1.0
}

// ── 적 유형 ──

type enemyKind int

const (
	kGrunt enemyKind = iota // 구울
	kRunner                 // 하운드
	kBrute                  // 브루트
	kWyvern                 // 와이번 (정예, 공중)
	kReaper                 // 리퍼 (정예, 순간이동)
	kJugger                 // 저거너트 (정예, 넉백 면역)
	kBoss                   // 콜로서스 (보스, 10웨이브마다)
)

type kindSpec struct {
	hpMul, speedMul, dmgMul   float64
	lineWidth, gaitFreq       float64
	hitHalfW, hitH, hitYMin   float64
	knockbackMul              float64
	unlockWave                int
	elite                     bool
}

var kinds = map[enemyKind]kindSpec{
	kGrunt:  {1.0, 1.0, 1.0, 3.2, 6.5, 14, 48, 0, 1.0, 1, false},
	kRunner: {0.45, 2.3, 0.7, 3.2, 9.5, 18, 34, 0, 1.0, 2, false},
	kBrute:  {3.5, 0.55, 2.2, 5.5, 4.2, 19, 70, 0, 1.0, 4, false},
	kWyvern: {1.8, 1.25, 1.5, 3.0, 9.0, 20, 100, enemyHitYMinWyvern, 1.0, 6, true},
	kReaper: {4.0, 0.95, 2.5, 3.4, 5.0, 13, 62, 0, 0.8, 7, true},
	kJugger: {6.5, 0.42, 3.2, 5.0, 3.5, 22, 76, 0, 0.15, 9, true},
	kBoss:   {20.0, 0.5, 4.0, 6.5, 2.8, 34, 150, 0, 0, 999, false},
}

// ── 업그레이드 (등급제) ──

type tier int

const (
	tCommon tier = iota
	tRare
	tUnique
)

func (t tier) label() string {
	switch t {
	case tRare:
		return "RARE"
	case tUnique:
		return "UNIQUE"
	}
	return ""
}

type effectKind int

const (
	eDamage effectKind = iota
	eCooldown
	eSpearSpeed
	eToughen
	eHeal
	eKnockback
	eCritChance
	eCritMul
	ePierce
	eDoubleThrow
	eMultishot
	ePowershot
	eLifesteal
	eComboMaster
	eChill
	eSplash
	eExecute
	eGlobalSlow
	eBruteHunter
	eChain
	eRevive
	eMaster
	eHitCombo
)

type upgradeDef struct {
	id, title, desc string
	tier            tier
	effect          effectKind
	v               float64
	n               int
}

var upgradePool = []upgradeDef{
	// 일반 (65%)
	{"damage", "강한 창", "공격력 +20%", tCommon, eDamage, 1.2, 0},
	{"haste", "빠른 손", "공격속도 +15%", tCommon, eCooldown, 0.87, 0},
	{"velocity", "강속구", "창 속도 +10%", tCommon, eSpearSpeed, 1.1, 0},
	{"tough", "단련", "최대 체력 +20", tCommon, eToughen, 20, 0},
	{"heal", "회복", "체력 40% 회복", tCommon, eHeal, 0.4, 0},
	{"knock", "넉백", "명중 넉백 강화", tCommon, eKnockback, 6, 0},
	{"focus", "집중", "치명타 확률 +5%p", tCommon, eCritChance, 0.05, 0},
	{"hone", "급소 연마", "치명타 피해 +25%p", tCommon, eCritMul, 0.25, 0},
	// 레어 (28%)
	{"crit", "크리티컬", "치명타 확률 +15%p", tRare, eCritChance, 0.15, 0},
	{"power", "파워샷", "매 4번째 투척 2배 강화", tRare, ePowershot, 0, 0},
	{"pierce", "관통", "창이 적 1마리를 더 뚫음", tRare, ePierce, 0, 0},
	{"double", "연속 투척", "2연속 투척 확률 +25%p", tRare, eDoubleThrow, 0.25, 0},
	{"multi", "쌍창", "동시 투척 창 +1", tRare, eMultishot, 0, 1},
	{"leech", "흡혈", "처치 시 체력 +2", tRare, eLifesteal, 2, 0},
	{"combo", "콤보 마스터", "콤보당 공격력 +1%, 유지 +1초", tRare, eComboMaster, 0, 0},
	{"chill", "냉기 창", "명중한 적 2초간 30% 감속", tRare, eChill, 0, 0},
	// 유니크 (7%, 1회 한정)
	{"splash", "폭발창", "명중 지점 주변 50% 피해", tUnique, eSplash, 0, 0},
	{"execute", "처형자", "체력 25% 이하 적 즉사", tUnique, eExecute, 0.25, 0},
	{"slow", "시간 왜곡", "모든 적 이동속도 -20%", tUnique, eGlobalSlow, 0.8, 0},
	{"giant", "거인 사냥꾼", "브루트에게 +80% 피해", tUnique, eBruteHunter, 1.8, 0},
	{"chain", "번개 창", "명중 시 근처 적에게 50% 연쇄", tUnique, eChain, 0.5, 0},
	{"phoenix", "불사조", "죽음을 1회 무시하고 부활", tUnique, eRevive, 0, 0},
	{"master", "명장의 창", "치명타 확률 +25%p, 피해 +50%p", tUnique, eMaster, 0, 0},
	{"trident", "삼지창", "동시 투척 창 +2", tUnique, eMultishot, 0, 2},
	{"hitcombo", "질풍 연격", "콤보가 명중마다 쌓이고 콤보당 공격력 +1%", tUnique, eHitCombo, 0, 0},
}

// ── 플레이어 스탯 ──

type stats struct {
	damage, cooldown, spearSpd     float64
	pierce                         int
	doubleThrowChance              float64
	hp, maxHP                      float64
	critChance, critMul, knockback float64
	multishot, powershotEvery      int
	lifesteal, comboDmgPer         float64
	comboWindowBonus               float64
	chillOnHit, splash             bool
	executeAt, globalSlow          float64
	bruteMul, chainRatio           float64
	hasRevive, hitCombo            bool
}

func newStats() stats {
	return stats{
		damage: spearDamage, cooldown: throwCooldown, spearSpd: spearSpeed,
		hp: playerMaxHP, maxHP: playerMaxHP,
		critMul: 2.0, knockback: 3, globalSlow: 1, bruteMul: 1,
	}
}

func (s *stats) apply(u upgradeDef) {
	switch u.effect {
	case eDamage:
		s.damage *= u.v
	case eCooldown:
		s.cooldown *= u.v
	case eSpearSpeed:
		s.spearSpd *= u.v
	case eToughen:
		s.maxHP += u.v
		s.hp = min(s.maxHP, s.hp+u.v)
	case eHeal:
		s.hp = min(s.maxHP, s.hp+s.maxHP*u.v)
	case eKnockback:
		s.knockback += u.v
	case eCritChance:
		s.critChance = min(1, s.critChance+u.v)
	case eCritMul:
		s.critMul += u.v
	case ePierce:
		s.pierce++
	case eDoubleThrow:
		s.doubleThrowChance = min(1, s.doubleThrowChance+u.v)
	case eMultishot:
		s.multishot = minInt(4, s.multishot+u.n)
	case ePowershot:
		if s.powershotEvery == 0 {
			s.powershotEvery = 4
		} else {
			s.powershotEvery = maxInt(2, s.powershotEvery-1)
		}
	case eLifesteal:
		s.lifesteal += u.v
	case eComboMaster:
		s.comboDmgPer += 0.01
		s.comboWindowBonus += 1
	case eChill:
		s.chillOnHit = true
	case eSplash:
		s.splash = true
	case eExecute:
		s.executeAt = max(s.executeAt, u.v)
	case eGlobalSlow:
		s.globalSlow *= u.v
	case eBruteHunter:
		s.bruteMul *= u.v
	case eChain:
		s.chainRatio = max(s.chainRatio, u.v)
	case eRevive:
		s.hasRevive = true
	case eMaster:
		s.critChance = min(1, s.critChance+0.25)
		s.critMul += 0.5
	case eHitCombo:
		s.hitCombo = true
		s.comboDmgPer += 0.01
	}
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
