package main

// 게임 로직 — macOS판 GameScene.swift의 immediate-mode 이식. 좌표는 y-업, groundY 지면.

import (
	"fmt"
	"image/color"
	"math"
	"math/rand"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"github.com/hajimehoshi/ebiten/v2/vector"
)

const dt = 1.0 / 60

type enemy struct {
	kind                    enemyKind
	x                       float64
	hp, maxHP, speed, dmg   float64
	attackTimer, walkPhase  float64
	chillTimer, blinkTimer  float64
	atkSwing                float64 // 표시용 공격 스윙 0..1
	inMelee, dying          bool
	bossPhase               int
	bossSummonT             float64
	deathAge, facing        float64
}

type spearShot struct {
	x, y, vx, vy, damage float64
	pierce               int
	power, landed        bool
	didHit               bool
	landAge              float64
	trailTick            int
	hit                  map[*enemy]bool
}

type popup struct {
	text          string
	x, y, age     float64
	size          float64
}

type lineFx struct {
	x0, y0, x1, y1, age, maxAge, width float64
}

type ringFx struct {
	x, y, age float64
}

type shard struct {
	x, y, vx, vy, rot, age float64
}

type gameState int

const (
	stPlaying gameState = iota
	stChoosing
	stGameover
)

type throwAnim struct {
	active   bool
	segIdx   int
	segT     float64
	fromPose pose
	released bool
	heldRot  float64
}

var segTargets = []pose{poseWindup, poseRelease, poseFollow, poseIdle}
var segDurs = []float64{windupDur, throwDur, followDur, recoverDur}

func easeInOut(t float64) float64 { return t * t * (3 - 2*t) }
func easeIn(t float64) float64    { return t * t }
func easeOut(t float64) float64   { return 1 - (1-t)*(1-t) }

var segEases = []func(float64) float64{easeInOut, easeIn, easeOut, easeInOut}

type Game struct {
	st           stats
	state        gameState
	wave         int
	toSpawn      int
	spawnIndex   int
	eliteAt      map[int]enemyKind
	spawnTimer   float64
	throwTimer   float64
	pendAimX     float64
	pendAimY     float64
	hasAim       bool
	combo        int
	comboTimer   float64
	throwCount   int
	mirrored     bool
	white        bool
	paused       bool
	idleTime     float64
	anim         throwAnim
	enemies      []*enemy
	spears       []*spearShot
	popups       []popup
	lines        []lineFx
	rings        []ringFx
	cards        []upgradeDef
	uniquesTaken map[string]bool
	waveLblAge   float64
	hpHurt       bool
	hitstop      float64
	shards       []shard
	diff         difficulty
	runKills     int
	runElites    int
	thrown       int
	hitShots     int
	maxCombo     int
	cardsTaken   int
	newRecord    bool
	prevBest     int
	isBossWave   bool
	bossReward   bool
}

func NewGame() *Game {
	if len(soundData) == 0 {
		loadSounds()
	}
	g := &Game{uniquesTaken: map[string]bool{}, eliteAt: map[int]enemyKind{}}
	g.st = newStats()
	g.wave = 1
	g.anim.heldRot = 0.9
	g.startWave()
	return g
}

func (g *Game) playerX() float64 {
	if g.mirrored {
		return sceneW - playerMargin
	}
	return playerMargin
}

func (g *Game) theme() color.Color {
	if g.white {
		return color.White
	}
	return color.Black
}

// ── 웨이브 ──

func (g *Game) startWave() {
	g.isBossWave = g.wave%bossEvery == 0
	if g.isBossWave {
		g.toSpawn = 1
	} else {
		g.toSpawn = maxInt(1, int(float64(waveBaseCount+waveCountGrowth*(g.wave-1))*g.diff.countMul()+0.5))
	}
	g.spawnTimer = 0.5
	g.throwTimer = 0.6
	g.spawnIndex = 0
	g.waveLblAge = 0.0001
	g.eliteAt = map[int]enemyKind{}
	if g.isBossWave {
		g.eliteAt[0] = kBoss
		return
	}
	if g.wave >= 6 {
		var unlocked []enemyKind
		for _, k := range []enemyKind{kWyvern, kReaper, kJugger} {
			if g.wave >= kinds[k].unlockWave {
				unlocked = append(unlocked, k)
			}
		}
		count := minInt(4, 1+(g.wave-6)/5)
		slots := rand.Perm(maxInt(1, g.toSpawn-1))
		for i := 0; i < count && i < len(slots) && len(unlocked) > 0; i++ {
			g.eliteAt[slots[i]+1] = unlocked[rand.Intn(len(unlocked))]
		}
	}
}

func (g *Game) rollKind() enemyKind {
	pool := []struct {
		k enemyKind
		w float64
	}{{kGrunt, 1.0}}
	if g.wave >= 2 {
		pool = append(pool, struct {
			k enemyKind
			w float64
		}{kRunner, 0.2 + 0.05*float64(g.wave)})
	}
	if g.wave >= 4 {
		pool = append(pool, struct {
			k enemyKind
			w float64
		}{kBrute, 0.1 + 0.03*float64(g.wave)})
	}
	total := 0.0
	for _, p := range pool {
		total += p.w
	}
	r := rand.Float64() * total
	for _, p := range pool {
		r -= p.w
		if r < 0 {
			return p.k
		}
	}
	return kGrunt
}

func (g *Game) spawnEnemy(k enemyKind, offset float64) {
	w := float64(g.wave - 1)
	spec := kinds[k]
	hp := enemyBaseHP * spec.hpMul * (1 + enemyHPGrowth*w) * math.Pow(enemyHPExpo, w) * g.diff.hpMul()
	e := &enemy{
		kind: k, hp: hp, maxHP: hp,
		speed:      enemySpeedBase * spec.speedMul * (1 + enemySpeedGrowth*w),
		dmg:        enemyDamageBase * spec.dmgMul * (1 + enemyDmgGrowth*w) * g.diff.dmgMul(),
		walkPhase:  rand.Float64() * math.Pi * 2,
		blinkTimer: 1.5 + rand.Float64(),
		bossSummonT: 3.0,
		bossPhase:  1,
	}
	if g.mirrored {
		e.x = -30 - offset
	} else {
		e.x = sceneW + 30 + offset
	}
	g.enemies = append(g.enemies, e)
}

// ── 카드 ──

func (g *Game) rollCards() []upgradeDef {
	var picks []upgradeDef
	used := map[string]bool{}
	uniqueP := 0.07
	if g.wave >= 5 {
		uniqueP = math.Min(0.15, 0.07+0.01*float64(g.wave-4))
	}
	forceUnique := g.bossReward || (g.wave >= 5 && len(g.uniquesTaken) == 0)
	g.bossReward = false
	candidates := func(t tier) []upgradeDef {
		var c []upgradeDef
		for _, u := range upgradePool {
			if u.tier == t && !used[u.id] && !(t == tUnique && g.uniquesTaken[u.id]) {
				c = append(c, u)
			}
		}
		return c
	}
	for i := 0; i < 3; i++ {
		var t tier
		r := rand.Float64()
		switch {
		case i == 0 && forceUnique:
			t = tUnique
		case r < uniqueP:
			t = tUnique
		case r < uniqueP+0.28:
			t = tRare
		default:
			t = tCommon
		}
		c := candidates(t)
		if len(c) == 0 {
			c = candidates(tCommon)
		}
		if len(c) > 0 {
			pick := c[rand.Intn(len(c))]
			used[pick.id] = true
			picks = append(picks, pick)
		}
	}
	return picks
}

func (g *Game) selectUpgrade(i int) {
	if g.state != stChoosing || i >= len(g.cards) {
		return
	}
	pick := g.cards[i]
	g.cardsTaken++
	playSound("card")
	g.st.apply(pick)
	if pick.tier == tUnique {
		g.uniquesTaken[pick.id] = true
	}
	g.st.hp = math.Min(g.st.maxHP, g.st.hp+waveClearHeal)
	g.state = stPlaying
	g.wave++
	g.startWave()
}

// ── 투척 ──

func aimVelocity(px, py, tx, ty, v float64) (float64, float64) {
	dx, dy := tx-px, ty-py
	ax := math.Abs(dx)
	disc := v*v*v*v - gravity*(gravity*ax*ax+2*dy*v*v)
	sign := 1.0
	if dx < 0 {
		sign = -1
	}
	if disc > 0 && ax > 1 {
		theta := math.Atan((v*v - math.Sqrt(disc)) / (gravity * ax))
		return math.Cos(theta) * v * sign, math.Sin(theta) * v
	}
	ang := math.Atan2(dy, ax) + 0.35
	return math.Cos(ang) * v * sign, math.Sin(ang) * v
}

func (g *Game) requestThrow(x, y float64) {
	if g.state != stPlaying || g.throwTimer > 0 || g.anim.active {
		return
	}
	g.pendAimX, g.pendAimY = x, y
	g.hasAim = true
	g.anim = throwAnim{active: true, fromPose: g.currentIdlePose(), heldRot: g.anim.heldRot}
	g.throwTimer = g.st.cooldown
}

func (g *Game) currentIdlePose() pose {
	p := poseIdle
	p.lean += 0.03 * math.Sin(g.idleTime*2.2)
	p.shB += 0.05 * math.Sin(g.idleTime*2.2)
	return p
}

func (g *Game) launchVolley() {
	if !g.hasAim {
		return
	}
	g.throwCount++
	isPower := g.st.powershotEvery > 0 && g.throwCount%g.st.powershotEvery == 0
	if isPower {
		playSound("power")
	} else {
		playSound("throw")
	}
	hx, hy := g.handPos()
	offsets := []float64{0, 0.09, -0.09, 0.18, -0.18}
	for i := 0; i <= g.st.multishot; i++ {
		mul := 1.0
		if i > 0 {
			mul = 0.75
		}
		if isPower {
			mul *= 2
		}
		g.fire(hx, hy, offsets[i], mul, isPower)
	}
	if rand.Float64() < g.st.doubleThrowChance {
		// 연속 투척: 같은 조준점, 소폭 각도 오프셋 (맥판의 0.1초 지연 대신 단순화)
		mul := 1.0
		if isPower {
			mul = 2
		}
		g.fire(hx, hy, 0.07, mul, isPower)
	}
	g.hasAim = false
}

func (g *Game) fire(px, py, angleOffset, damageMul float64, power bool) {
	vx, vy := aimVelocity(px, py, g.pendAimX, g.pendAimY, g.st.spearSpd)
	c, s := math.Cos(angleOffset), math.Sin(angleOffset)
	sp := &spearShot{
		x: px, y: py,
		vx: vx*c - vy*s, vy: vx*s + vy*c,
		damage: g.st.damage * damageMul, pierce: g.st.pierce,
		power: power, hit: map[*enemy]bool{},
	}
	g.thrown++
	g.spears = append(g.spears, sp)
}

// 던지기 애니메이션 진행 + 손 위치 계산
func (g *Game) advanceAnim() {
	if !g.anim.active {
		return
	}
	g.anim.segT += dt
	for g.anim.segIdx < len(segDurs) && g.anim.segT >= segDurs[g.anim.segIdx] {
		g.anim.segT -= segDurs[g.anim.segIdx]
		g.anim.fromPose = segTargets[g.anim.segIdx]
		g.anim.segIdx++
		if g.anim.segIdx == 2 && !g.anim.released {
			g.anim.released = true
			g.launchVolley()
		}
	}
	if g.anim.segIdx >= len(segDurs) {
		g.anim = throwAnim{heldRot: 0.9}
	}
}

func (g *Game) currentPose() pose {
	if !g.anim.active {
		return g.currentIdlePose()
	}
	seg := g.anim.segIdx
	t := segEases[seg](g.anim.segT / segDurs[seg])
	return lerpPose(g.anim.fromPose, segTargets[seg], t)
}

func (g *Game) handPos() (float64, float64) {
	p := g.currentPose()
	fx := 1.0
	if g.mirrored {
		fx = -1
	}
	torsoA := math.Pi/2 + p.lean
	shX := math.Cos(torsoA) * fTorso * 0.94
	shY := fPelvisY + math.Sin(torsoA)*fTorso*0.94
	ua := torsoA + p.shF
	ex := shX + math.Cos(ua)*fUpper
	ey := shY + math.Sin(ua)*fUpper
	fa := ua + p.elF
	hx := ex + math.Cos(fa)*fFore
	hy := ey + math.Sin(fa)*fFore
	return g.playerX() + fx*hx, groundY + hy
}

// ── 전투 ──

func (g *Game) bumpCombo(x, y float64, showAlways bool) {
	g.combo++
	if g.combo > g.maxCombo {
		g.maxCombo = g.combo
	}
	g.comboTimer = comboWindow + g.st.comboWindowBonus
	if g.combo >= 2 && (showAlways || g.combo%10 == 0) {
		g.popups = append(g.popups, popup{fmt.Sprintf("%d COMBO", g.combo), x, y, 0, 11})
	}
}

func (g *Game) spearHit(s *spearShot, e *enemy) {
	if !s.didHit {
		s.didHit = true
		g.hitShots++
	}
	if g.st.hitCombo {
		g.bumpCombo(e.x, groundY+kinds[e.kind].hitH+8, false)
	}
	dmg := s.damage * (1 + math.Min(0.3, float64(g.combo)*g.st.comboDmgPer))
	if e.kind == kBrute || e.kind == kJugger || e.kind == kBoss {
		dmg *= g.st.bruteMul
	}
	crit := false
	if g.st.critChance > 0 && rand.Float64() < g.st.critChance {
		dmg *= g.st.critMul
		crit = true
	}
	if g.st.chillOnHit {
		e.chillTimer = 2
	}
	kb := g.st.knockback
	if s.power {
		kb *= 3
	}
	g.damageEnemy(e, dmg, kb, crit)
	if g.st.splash {
		g.rings = append(g.rings, ringFx{e.x, groundY + kinds[e.kind].hitH/2, 0})
		for _, o := range g.enemies {
			if o != e && !o.dying && math.Abs(o.x-e.x) < 60 {
				g.damageEnemy(o, dmg*0.5, 0, false)
			}
		}
	}
	if g.st.chainRatio > 0 {
		var best *enemy
		for _, o := range g.enemies {
			if o != e && !o.dying && (best == nil || math.Abs(o.x-e.x) < math.Abs(best.x-e.x)) {
				best = o
			}
		}
		if best != nil && math.Abs(best.x-e.x) < 170 {
			g.lines = append(g.lines, lineFx{e.x, groundY + kinds[e.kind].hitH/2, best.x, groundY + kinds[best.kind].hitH/2, 0, 0.2, 2})
			g.damageEnemy(best, dmg*g.st.chainRatio, 0, false)
		}
	}
}

func (g *Game) damageEnemy(e *enemy, dmg, kb float64, crit bool) {
	if e.dying {
		return
	}
	e.hp -= dmg
	if e.hp > 0 && g.st.executeAt > 0 && e.kind != kBoss && e.hp <= e.maxHP*g.st.executeAt {
		e.hp = 0
	}
	if crit {
		g.popups = append(g.popups, popup{"CRIT", e.x, groundY + kinds[e.kind].hitH + 22, 0, 13})
	}
	if e.hp <= 0 {
		e.dying = true
		if e.kind == kBoss {
			g.bossReward = true
			g.hitstop = 0.12
			g.popups = append(g.popups, popup{"BOSS DOWN", e.x, groundY + 120, 0, 16})
		}
		g.runKills++
		if kinds[e.kind].elite {
			g.runElites++
		}
		if crit {
			playSound("crit")
			g.hitstop = math.Min(0.08, g.hitstop+0.05)
		} else {
			playSound("kill")
			g.hitstop = math.Min(0.08, g.hitstop+0.03)
		}
		g.spawnShards(e.x, groundY+kinds[e.kind].hitH*0.5)
		if g.st.lifesteal > 0 {
			g.st.hp = math.Min(g.st.maxHP, g.st.hp+g.st.lifesteal)
		}
		if !g.st.hitCombo {
			g.bumpCombo(e.x, groundY+kinds[e.kind].hitH+8, true)
		}
	} else {
		if crit {
			playSound("crit")
		} else {
			playSound("hit")
		}
		dir := 1.0
		if e.x < g.playerX() {
			dir = -1
		}
		e.x += dir * kb * kinds[e.kind].knockbackMul
	}
}

func (g *Game) spawnShards(x, y float64) {
	for i := 0; i < 5; i++ {
		a := rand.Float64() * math.Pi * 2
		sp := 60 + rand.Float64()*80
		g.shards = append(g.shards, shard{x, y, math.Cos(a) * sp, math.Sin(a)*sp*0.7 + 30, rand.Float64() * math.Pi, 0})
	}
}

func (g *Game) playerHit(dmg float64) {
	if g.state != stPlaying {
		return
	}
	g.st.hp -= dmg
	g.combo = 0
	g.hpHurt = true
	if g.st.hp <= 0 {
		if g.st.hasRevive {
			g.st.hasRevive = false
			g.st.hp = g.st.maxHP * 0.5
			for _, e := range g.enemies {
				dir := 1.0
				if e.x < g.playerX() {
					dir = -1
				}
				e.x += dir * 130
			}
			g.popups = append(g.popups, popup{"REVIVE", g.playerX(), groundY + 90, 0, 14})
		} else {
			playSound("gameover")
			g.state = stGameover
			g.prevBest = cfg.Best[g.diff.key()]
			if g.wave > g.prevBest {
				g.newRecord = true
				cfg.Best[g.diff.key()] = g.wave
				saveCfg()
			}
		}
	}
}

// ── 메인 루프 ──

func (g *Game) Update() error {
	// 입력
	if inpututil.IsKeyJustPressed(ebiten.KeySpace) {
		g.paused = !g.paused
	}
	if inpututil.IsKeyJustPressed(ebiten.KeyEscape) {
		return ebiten.Termination
	}
	if inpututil.IsKeyJustPressed(ebiten.KeyF) {
		cfg.Mirrored = !cfg.Mirrored
		saveCfg()
		g.mirrored = !g.mirrored
		for _, e := range g.enemies {
			e.x = sceneW - e.x
		}
		g.spears = g.spears[:0]
	}
	if inpututil.IsKeyJustPressed(ebiten.KeyT) {
		g.white = !g.white
		cfg.White = g.white
		saveCfg()
	}
	if inpututil.IsKeyJustPressed(ebiten.KeyR) {
		g.restart()
	}
	if inpututil.IsMouseButtonJustPressed(ebiten.MouseButtonRight) {
		g.paused = true
		ebiten.MinimizeWindow()
	}
	if inpututil.IsMouseButtonJustPressed(ebiten.MouseButtonLeft) {
		cx, cy := ebiten.CursorPosition()
		gx, gy := float64(cx), sceneH-float64(cy)
		switch {
		case g.paused:
			g.paused = false
		case g.state == stChoosing:
			g.clickCard(gx, gy)
		case g.state == stGameover:
			g.restart()
		default:
			g.requestThrow(gx, gy)
		}
	}
	for key, d := range map[ebiten.Key]difficulty{ebiten.Key1: dEasy, ebiten.Key2: dNormal, ebiten.Key3: dHard} {
		if inpututil.IsKeyJustPressed(key) && g.diff != d {
			g.diff = d
			cfg.Diff = int(d)
			saveCfg()
			g.popups = append(g.popups, popup{"난이도: " + d.title(), sceneW / 2, sceneH - 60, 0, 13})
		}
	}
	if inpututil.IsKeyJustPressed(ebiten.KeyM) {
		soundOn = !soundOn
		cfg.Muted = !soundOn
		saveCfg()
		playSound("card")
	}
	if g.paused {
		return nil
	}
	soundNow += dt
	if g.hitstop > 0 { // 처치 순간 프레임 정지 (타격감)
		g.hitstop -= dt
		return nil
	}

	g.idleTime += dt
	g.advanceAnim()
	g.updateSpears()
	g.updateFx()

	if g.state != stPlaying {
		return nil
	}

	// 스폰
	if g.toSpawn > 0 {
		g.spawnTimer -= dt
		if g.spawnTimer <= 0 {
			k, isElite := g.eliteAt[g.spawnIndex]
			if !isElite {
				k = g.rollKind()
			}
			g.spawnEnemy(k, 0)
			g.spawnIndex++
			g.toSpawn--
			if k == kRunner && g.toSpawn > 0 && rand.Float64() < 0.35 {
				g.spawnEnemy(kRunner, 26)
				g.toSpawn--
			}
			maxGap := math.Max(0.6, spawnIntervalMax-0.03*float64(g.wave-1))
			g.spawnTimer = spawnIntervalMin + rand.Float64()*(maxGap-spawnIntervalMin)
		}
	}

	// 적
	px := g.playerX()
	alive := g.enemies[:0]
	for _, e := range g.enemies {
		if e.kind == kBoss && !e.dying {
			g.updateBoss(e)
		}
		if e.dying {
			e.deathAge += dt
			if e.deathAge < 0.9 {
				alive = append(alive, e)
			}
			continue
		}
		spec := kinds[e.kind]
		facing := 1.0
		if px < e.x {
			facing = -1
		}
		e.facing = facing
		e.chillTimer = math.Max(0, e.chillTimer-dt)
		inRange := math.Abs(e.x-px) < 34+spec.hitHalfW
		e.inMelee = inRange
		if inRange {
			t := math.Min(1, (enemyAttackInterval-e.attackTimer)/0.3)
			e.atkSwing = math.Sin(t * math.Pi)
			e.attackTimer -= dt
			if e.attackTimer <= 0 {
				e.attackTimer = enemyAttackInterval
				if e.kind == kBoss {
					e.attackTimer = bossAttackInterval
				}
				g.playerHit(e.dmg)
			}
		} else {
			e.atkSwing = 0
			mul := g.st.globalSlow
			if e.chillTimer > 0 {
				mul *= 0.7
			}
			if e.kind == kBoss && e.bossPhase >= 3 {
				mul *= 1.7
			}
			e.walkPhase += dt * spec.gaitFreq * mul
			e.x += facing * e.speed * mul * dt
			if e.kind == kReaper {
				e.blinkTimer -= dt
				if e.blinkTimer <= 0 {
					e.blinkTimer = 2.5
					e.x += facing * 70
				}
			}
		}
		alive = append(alive, e)
	}
	g.enemies = alive

	g.throwTimer -= dt
	if g.combo > 0 {
		g.comboTimer -= dt
		if g.comboTimer <= 0 {
			g.combo = 0
		}
	}

	// 웨이브 클리어
	if g.toSpawn == 0 && g.liveCount() == 0 {
		g.cards = g.rollCards()
		g.state = stChoosing
	}
	return nil
}

func (g *Game) liveCount() int {
	n := 0
	for _, e := range g.enemies {
		if !e.dying {
			n++
		}
	}
	return n
}

func (g *Game) updateSpears() {
	keep := g.spears[:0]
	for _, s := range g.spears {
		if s.landed {
			s.landAge += dt
			if s.landAge < 1.1 {
				keep = append(keep, s)
			}
			continue
		}
		if s.power {
			s.trailTick++
			if s.trailTick%3 == 0 {
				rot := math.Atan2(s.vy, s.vx)
				g.lines = append(g.lines, lineFx{s.x, s.y, s.x - math.Cos(rot)*22, s.y - math.Sin(rot)*22, 0, 0.22, 3.5})
			}
		}
		s.vy -= gravity * dt
		s.x += s.vx * dt
		s.y += s.vy * dt
		rot := math.Atan2(s.vy, s.vx)
		tipX := s.x + math.Cos(rot)*spearLen/2
		tipY := s.y + math.Sin(rot)*spearLen/2

		if tipX < -80 || tipX > sceneW+80 {
			continue
		}
		if tipY <= groundY {
			s.landed = true
			keep = append(keep, s)
			continue
		}
		dead := false
		for _, e := range g.enemies {
			if e.dying || s.hit[e] {
				continue
			}
			spec := kinds[e.kind]
			yMin := spec.hitYMin
			if e.inMelee {
				yMin = 0
			}
			hitAt := func(x, y float64) bool {
				return math.Abs(x-e.x) < spec.hitHalfW && y < groundY+spec.hitH && y >= groundY+yMin
			}
			if hitAt(tipX, tipY) || hitAt(s.x, s.y) {
				s.hit[e] = true
				g.spearHit(s, e)
				s.pierce--
				if s.pierce < 0 {
					dead = true
					break
				}
			}
		}
		if !dead {
			keep = append(keep, s)
		}
	}
	g.spears = keep
}

func (g *Game) updateFx() {
	pk := g.popups[:0]
	for i := range g.popups {
		g.popups[i].age += dt
		if g.popups[i].age < 0.7 {
			pk = append(pk, g.popups[i])
		}
	}
	g.popups = pk
	lk := g.lines[:0]
	for i := range g.lines {
		g.lines[i].age += dt
		if g.lines[i].age < g.lines[i].maxAge {
			lk = append(lk, g.lines[i])
		}
	}
	g.lines = lk
	rk := g.rings[:0]
	for i := range g.rings {
		g.rings[i].age += dt
		if g.rings[i].age < 0.35 {
			rk = append(rk, g.rings[i])
		}
	}
	g.rings = rk
	if g.waveLblAge > 0 {
		g.waveLblAge += dt
		if g.waveLblAge > 2 {
			g.waveLblAge = 0
		}
	}
	sk := g.shards[:0]
	for i := range g.shards {
		sh := &g.shards[i]
		sh.age += dt
		sh.vy -= 300 * dt
		sh.x += sh.vx * dt
		sh.y += sh.vy * dt
		sh.rot += 4 * dt
		if sh.age < 0.4 {
			sk = append(sk, *sh)
		}
	}
	g.shards = sk
}

// 보스 페이즈: 1(60%+) 평이동 / 2(60%↓) 부하 소환 / 3(30%↓) 광폭화
func (g *Game) updateBoss(e *enemy) {
	frac := e.hp / e.maxHP
	phase := 1
	if frac <= 0.3 {
		phase = 3
	} else if frac <= 0.6 {
		phase = 2
	}
	if phase >= 3 && e.bossPhase < 3 {
		e.dmg *= 1.5
		g.popups = append(g.popups, popup{"광폭화!", e.x, groundY + 165, 0, 13})
		playSound("power")
	}
	e.bossPhase = phase
	if phase >= 2 {
		rate := 1.0
		if phase == 3 {
			rate = 1.6
		}
		e.bossSummonT -= dt * rate
		if e.bossSummonT <= 0 {
			e.bossSummonT = bossSummonInterval
			k := kGrunt
			if rand.Float64() < 0.5 {
				k = kRunner
			}
			g.spawnEnemy(k, 0)
			g.spawnEnemy(k, 30)
			g.popups = append(g.popups, popup{"소환", e.x, groundY + 160, 0, 11})
		}
	}
}

func (g *Game) restart() {
	d, w, m := g.diff, g.white, g.mirrored
	*g = *NewGame()
	g.diff, g.white, g.mirrored = d, w, m
}

// ── 카드 UI 좌표 ──

func cardRect(i int) (x, y, w, h float64) {
	w, h = 158, 96
	x = sceneW/2 + float64(i-1)*178 - w/2
	y = sceneH/2 + 10 - h/2
	return
}

func (g *Game) clickCard(gx, gy float64) {
	for i := range g.cards {
		x, y, w, h := cardRect(i)
		if gx >= x && gx <= x+w && gy >= y && gy <= y+h {
			g.selectUpgrade(i)
			return
		}
	}
}

func (g *Game) Layout(w, h int) (int, int) { return sceneW, sceneH }

// ── 그리기 ──

func sy(y float64) float32 { return float32(sceneH - y) }

func (g *Game) Draw(dst *ebiten.Image) {
	th := g.theme()
	// 지면
	grd := &vector.Path{}
	grd.MoveTo(20, sy(groundY))
	grd.LineTo(sceneW-20, sy(groundY))
	so := &vector.StrokeOptions{Width: 1.5, LineCap: vector.LineCapRound}
	dp := &vector.DrawPathOptions{AntiAlias: true}
	dp.ColorScale.ScaleWithColor(th)
	dp.ColorScale.ScaleAlpha(0.3)
	vector.StrokePath(dst, grd, so, dp)

	// 플레이어
	fx := 1.0
	if g.mirrored {
		fx = -1
	}
	pf := &frame{dst: dst, ox: g.playerX(), oy: groundY, fx: fx, col: th, alpha: 1}
	p := g.currentPose()
	hx, hy := drawStickman(pf, p)
	// 들고 있는 창
	held := !g.anim.active || (!g.anim.released && g.anim.segIdx <= 1)
	if held {
		rot := 0.9
		if g.anim.active {
			t := segEases[g.anim.segIdx](g.anim.segT / segDurs[g.anim.segIdx])
			if g.anim.segIdx == 0 {
				rot = g.anim.heldRot + (0.12-g.anim.heldRot)*t
			} else {
				rot = 0.12 * (1 - t)
			}
		}
		if g.mirrored {
			rot = math.Pi - rot
		}
		drawSpear(dst, g.playerX()+fx*hx, groundY+hy, rot, false, th, 1)
	}

	// HP 바 (피격 후에만)
	if g.hpHurt {
		frac := math.Max(0, g.st.hp/g.st.maxHP)
		x := g.playerX() - 18
		vector.DrawFilledRect(dst, float32(x), sy(groundY+72), float32(36*frac), 3.5, th, true)
	}

	// 적
	for _, e := range g.enemies {
		spec := kinds[e.kind]
		ef := &frame{dst: dst, ox: e.x, oy: groundY, fx: e.facing, col: th, alpha: 1}
		if e.facing == 0 {
			ef.fx = -1
		}
		if e.dying {
			t := math.Min(1, e.deathAge/0.35)
			ef.rot = -e.facing * (math.Pi / 2) * easeIn(t)
			ef.alpha = float32(math.Max(0, 1-e.deathAge/0.6))
		}
		drawCreature(ef, e.kind, e.walkPhase, e.atkSwing)
		if e.chillTimer > 0 && !e.dying {
			mark := &vector.Path{}
			my := groundY + spec.hitH + 12
			rotA := g.idleTime * 1.6
			for k := 0; k < 3; k++ {
				a := float64(k)*math.Pi/3 + rotA
				mark.MoveTo(float32(e.x-math.Cos(a)*5), sy(my-math.Sin(a)*5))
				mark.LineTo(float32(e.x+math.Cos(a)*5), sy(my+math.Sin(a)*5))
			}
			mso := &vector.StrokeOptions{Width: 1.6, LineCap: vector.LineCapRound}
			mdp := &vector.DrawPathOptions{AntiAlias: true}
			mdp.ColorScale.ScaleWithColor(th)
			vector.StrokePath(dst, mark, mso, mdp)
		}
	}

	// 창(발사체)
	for _, s := range g.spears {
		alpha := float32(1)
		if s.landed {
			alpha = float32(math.Max(0, 1-(s.landAge-0.7)/0.4))
		}
		rot := math.Atan2(s.vy, s.vx)
		drawSpear(dst, s.x, s.y, rot, s.power, th, alpha)
	}

	// 이펙트
	for _, l := range g.lines {
		a := float32(math.Max(0, 1-l.age/l.maxAge)) * 0.5
		lp := &vector.Path{}
		lp.MoveTo(float32(l.x0), sy(l.y0))
		lp.LineTo(float32(l.x1), sy(l.y1))
		lso := &vector.StrokeOptions{Width: float32(l.width), LineCap: vector.LineCapRound}
		ldp := &vector.DrawPathOptions{AntiAlias: true}
		ldp.ColorScale.ScaleWithColor(th)
		ldp.ColorScale.ScaleAlpha(a)
		vector.StrokePath(dst, lp, lso, ldp)
	}
	for _, r := range g.rings {
		t := r.age / 0.35
		vector.StrokeCircle(dst, float32(r.x), sy(r.y), float32(15+45*t), 2, translucent(th, float32(1-t)), true)
	}
	for _, sh := range g.shards {
		a := float32(math.Max(0, 1-sh.age/0.4))
		vector.DrawFilledRect(dst, float32(sh.x)-1.6, sy(sh.y)-1.6, 3.2, 3.2, translucent(th, a), true)
	}
	for _, p := range g.popups {
		a := float32(math.Max(0, 1-p.age/0.7))
		drawTextCenter(dst, p.text, p.size, p.x, p.y+26*p.age/0.7, translucent(th, a))
	}

	// 보스 체력바
	for _, e := range g.enemies {
		if e.kind == kBoss && !e.dying {
			frac := math.Max(0, e.hp/e.maxHP)
			bx, by := float32(sceneW/2-182), sy(sceneH-10)
			vector.DrawFilledRect(dst, bx, by, 364, 8, color.RGBA{13, 13, 13, 165}, true)
			vector.StrokeRect(dst, bx, by, 364, 8, 1, translucent(th, 0.7), true)
			vector.DrawFilledRect(dst, bx+2, by+1.6, float32(360*frac), 4.8, color.White, true)
			break
		}
	}

	// 웨이브 라벨
	if g.waveLblAge > 0 {
		a := float32(1.0)
		if g.waveLblAge < 0.25 {
			a = float32(g.waveLblAge / 0.25)
		} else if g.waveLblAge > 1.45 {
			a = float32(math.Max(0, 1-(g.waveLblAge-1.45)/0.5))
		}
		drawTextCenter(dst, fmt.Sprintf("WAVE %d", g.wave), 15, sceneW/2, sceneH-34, translucent(th, a*0.85))
	}

	// 오버레이
	switch {
	case g.paused:
		g.drawBox(dst, sceneW/2, sceneH/2+10, 190, 52)
		drawTextCenter(dst, "❚❚  일시정지", 15, sceneW/2, sceneH/2+14, color.White)
		drawTextCenter(dst, "Space 또는 클릭으로 재개", 10, sceneW/2, sceneH/2-8, translucent(color.White, 0.7))
	case g.state == stChoosing:
		for i, u := range g.cards {
			x, y, w, h := cardRect(i)
			cx, cy := x+w/2, y+h/2
			g.drawBox(dst, cx, cy, w, h)
			if u.tier == tUnique {
				vector.StrokeRect(dst, float32(x)-3, sy(y+h)-3, float32(w)+6, float32(h)+6, 2.5, translucent(color.White, 0.85), true)
			} else if u.tier == tRare {
				vector.StrokeRect(dst, float32(x)+4, sy(y+h)+4, float32(w)-8, float32(h)-8, 1, translucent(color.White, 0.5), true)
			}
			if lbl := u.tier.label(); lbl != "" {
				if u.tier == tUnique {
					lbl = "◆ " + lbl + " ◆"
				}
				drawTextCenter(dst, lbl, 9, cx, cy+32, translucent(color.White, 0.8))
			}
			drawTextCenter(dst, u.title, 17, cx, cy+8, color.White)
			drawTextCenter(dst, u.desc, 11, cx, cy-22, translucent(color.White, 0.75))
		}
	case g.state == stGameover:
		g.drawBox(dst, sceneW/2, sceneH/2+10, 260, 90)
		acc := 0
		if g.thrown > 0 {
			acc = int(float64(g.hitShots)/float64(g.thrown)*100 + 0.5)
		}
		drawTextCenter(dst, fmt.Sprintf("GAME OVER — WAVE %d · %s", g.wave, g.diff.title()), 16, sceneW/2, sceneH/2+52, color.White)
		if g.newRecord {
			drawTextCenter(dst, fmt.Sprintf("★ 신기록! (이전 %d)", g.prevBest), 13, sceneW/2, sceneH/2+30, color.White)
		} else {
			drawTextCenter(dst, fmt.Sprintf("최고 기록: WAVE %d", g.prevBest), 12, sceneW/2, sceneH/2+30, translucent(color.White, 0.8))
		}
		drawTextCenter(dst, fmt.Sprintf("처치 %d마리 (정예 %d) · 명중률 %d%%", g.runKills, g.runElites, acc), 12, sceneW/2, sceneH/2+6, translucent(color.White, 0.85))
		drawTextCenter(dst, fmt.Sprintf("최대 콤보 %d · 카드 %d장", g.maxCombo, g.cardsTaken), 12, sceneW/2, sceneH/2-14, translucent(color.White, 0.85))
		drawTextCenter(dst, "클릭하면 다시 시작", 12, sceneW/2, sceneH/2-10, translucent(color.White, 0.7))
	}
}

func (g *Game) drawBox(dst *ebiten.Image, cx, cy, w, h float64) {
	x, y := float32(cx-w/2), sy(cy+h/2)
	vector.DrawFilledRect(dst, x, y, float32(w), float32(h), color.RGBA{13, 13, 13, 225}, true)
	vector.StrokeRect(dst, x, y, float32(w), float32(h), 1.2, translucent(color.White, 0.55), true)
}

func translucent(c color.Color, a float32) color.Color {
	r, gg, b, _ := c.RGBA()
	return color.RGBA{uint8(float32(r>>8) * a), uint8(float32(gg>>8) * a), uint8(float32(b>>8) * a), uint8(255 * a)}
}
