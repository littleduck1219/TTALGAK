package main

// 피규어 렌더링 — macOS판 Stickman.swift/Monsters.swift와 동일 지오메트리.
// 게임 좌표는 y-업(지면 groundY), 화면 변환은 frame이 담당.

import (
	"image/color"
	"math"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/vector"
)

// frame: 로컬(y-업, +x 바라봄) → 화면 변환. fx=-1이면 좌우 반전, rot는 원점 기준 회전(사망 낙하)
type frame struct {
	dst    *ebiten.Image
	ox, oy float64 // 게임 좌표 원점 (지면 접점)
	fx     float64
	rot    float64
	col    color.Color
	alpha  float32
}

func (f *frame) pt(lx, ly float64) (float32, float32) {
	x := f.fx * lx
	y := ly
	if f.rot != 0 {
		c, s := math.Cos(f.rot), math.Sin(f.rot)
		x, y = x*c-y*s, x*s+y*c
	}
	return float32(f.ox + x), float32(sceneH - (f.oy + y))
}

func (f *frame) opts(width float64) (*vector.StrokeOptions, *vector.DrawPathOptions) {
	so := &vector.StrokeOptions{Width: float32(width), LineCap: vector.LineCapRound, LineJoin: vector.LineJoinRound}
	dp := &vector.DrawPathOptions{AntiAlias: true}
	dp.ColorScale.ScaleWithColor(f.col)
	dp.ColorScale.ScaleAlpha(f.alpha)
	return so, dp
}

func (f *frame) stroke(p *vector.Path, width float64) {
	so, dp := f.opts(width)
	vector.StrokePath(f.dst, p, so, dp)
}

func (f *frame) fill(p *vector.Path) {
	_, dp := f.opts(1)
	vector.FillPath(f.dst, p, &vector.FillOptions{}, dp)
}

// 관절을 정확히 지나는 quad 곡선 (control = 2*joint - 중점)
func (f *frame) through(p *vector.Path, ax, ay, jx, jy, bx, by float64) {
	x0, y0 := f.pt(ax, ay)
	cx, cy := f.pt(2*jx-(ax+bx)/2, 2*jy-(ay+by)/2)
	x1, y1 := f.pt(bx, by)
	p.MoveTo(x0, y0)
	p.QuadTo(cx, cy, x1, y1)
}

func (f *frame) line(p *vector.Path, ax, ay, bx, by float64) {
	x0, y0 := f.pt(ax, ay)
	x1, y1 := f.pt(bx, by)
	p.MoveTo(x0, y0)
	p.LineTo(x1, y1)
}

func (f *frame) circle(cx, cy, r float64) {
	// 회전/반전 프레임에서도 원은 원이므로 중심만 변환
	x, y := f.pt(cx, cy)
	_, dp := f.opts(1)
	p := &vector.Path{}
	p.Arc(x, y, float32(r), 0, math.Pi*2, vector.Clockwise)
	vector.FillPath(f.dst, p, &vector.FillOptions{}, dp)
}

func (f *frame) ellipse(cx, cy, rx, ry float64) {
	const k = 0.5523
	p := &vector.Path{}
	x0, y0 := f.pt(cx+rx, cy)
	p.MoveTo(x0, y0)
	c1x, c1y := f.pt(cx+rx, cy+ry*k)
	c2x, c2y := f.pt(cx+rx*k, cy+ry)
	ex, ey := f.pt(cx, cy+ry)
	p.CubicTo(c1x, c1y, c2x, c2y, ex, ey)
	c1x, c1y = f.pt(cx-rx*k, cy+ry)
	c2x, c2y = f.pt(cx-rx, cy+ry*k)
	ex, ey = f.pt(cx-rx, cy)
	p.CubicTo(c1x, c1y, c2x, c2y, ex, ey)
	c1x, c1y = f.pt(cx-rx, cy-ry*k)
	c2x, c2y = f.pt(cx-rx*k, cy-ry)
	ex, ey = f.pt(cx, cy-ry)
	p.CubicTo(c1x, c1y, c2x, c2y, ex, ey)
	c1x, c1y = f.pt(cx+rx*k, cy-ry)
	c2x, c2y = f.pt(cx+rx, cy-ry*k)
	ex, ey = f.pt(cx+rx, cy)
	p.CubicTo(c1x, c1y, c2x, c2y, ex, ey)
	p.Close()
	f.fill(p)
}

// 2관절 사지: 시작점 + (각도, 굽힘) → 경로 추가, 끝점/방향 반환
func (f *frame) limb(p *vector.Path, rx, ry, len1, len2, angle, flex float64) (float64, float64, float64) {
	mx := rx + math.Cos(angle)*len1
	my := ry + math.Sin(angle)*len1
	ex := mx + math.Cos(angle+flex)*len2
	ey := my + math.Sin(angle+flex)*len2
	f.through(p, rx, ry, mx, my, ex, ey)
	return ex, ey, angle + flex
}

func (f *frame) claws(p *vector.Path, x, y, dir float64) {
	for k := -1.0; k <= 1.0; k++ {
		a := dir + k*0.38
		f.line(p, x, y, x+math.Cos(a)*4.5, y+math.Sin(a)*4.5)
	}
}

// ── 플레이어 스틱맨 ──

type pose struct {
	lean, shF, elF, shB, elB, hipF, kneeF, hipB, kneeB float64
}

var (
	poseIdle    = pose{0.04, -2.75, 0.5, -3.35, 0.45, -1.45, -0.12, -1.75, -0.28}
	poseWindup  = pose{0.32, 0.45, 1.25, -2.1, 0.5, -1.15, -0.15, -2.05, -0.45}
	poseRelease = pose{-0.35, -0.85, 0.12, -3.6, 0.4, -1.3, -0.4, -2.15, -0.1}
	poseFollow  = pose{-0.5, -2.3, 0.45, -3.7, 0.5, -1.35, -0.45, -2.2, -0.08}
)

func lerpPose(a, b pose, t float64) pose {
	l := func(x, y float64) float64 { return x + (y-x)*t }
	return pose{
		l(a.lean, b.lean), l(a.shF, b.shF), l(a.elF, b.elF), l(a.shB, b.shB), l(a.elB, b.elB),
		l(a.hipF, b.hipF), l(a.kneeF, b.kneeF), l(a.hipB, b.hipB), l(a.kneeB, b.kneeB),
	}
}

const (
	fThigh    = 16.0
	fShin     = 16.0
	fTorso    = 21.0
	fUpper    = 13.5
	fFore     = 12.0
	fHeadR    = 6.0
	fPelvisY  = fThigh + fShin - 4
	stickLine = 3.5
)

// 스틱맨을 그리고 손의 로컬 좌표를 반환 (창 부착/발사용)
func drawStickman(f *frame, p pose) (handX, handY float64) {
	torsoA := math.Pi/2 + p.lean
	neckX := math.Cos(torsoA) * fTorso
	neckY := fPelvisY + math.Sin(torsoA)*fTorso
	shX := math.Cos(torsoA) * fTorso * 0.94
	shY := fPelvisY + math.Sin(torsoA)*fTorso*0.94

	path := &vector.Path{}
	// 척추: 등쪽으로 살짝 굽음
	dx, dy := neckX-0, neckY-fPelvisY
	l := math.Hypot(dx, dy)
	f.through(path, 0, fPelvisY, (0+neckX)/2-dy/l*1.8, (fPelvisY+neckY)/2+dx/l*1.8, neckX, neckY)

	arm := func(sh, el float64) (float64, float64) {
		ua := torsoA + sh
		ex := shX + math.Cos(ua)*fUpper
		ey := shY + math.Sin(ua)*fUpper
		fa := ua + el
		hx := ex + math.Cos(fa)*fFore
		hy := ey + math.Sin(fa)*fFore
		f.through(path, shX, shY, ex, ey, hx, hy)
		return hx, hy
	}
	leg := func(hip, knee float64) {
		kx := math.Cos(hip) * fThigh
		ky := fPelvisY + math.Sin(hip)*fThigh
		sa := hip + knee
		fx := kx + math.Cos(sa)*fShin
		fy := ky + math.Sin(sa)*fShin
		f.through(path, 0, fPelvisY, kx, ky, fx, fy)
	}
	_, _ = arm(p.shB, p.elB)
	leg(p.hipB, p.kneeB)
	leg(p.hipF, p.kneeF)
	hx, hy := arm(p.shF, p.elF)
	f.stroke(path, stickLine)
	f.circle(neckX+math.Cos(torsoA)*(fHeadR+3), neckY+math.Sin(torsoA)*(fHeadR+3), fHeadR)
	return hx, hy
}

// ── 몬스터 (Monsters.swift 지오메트리 이식) ──

func drawGhoul(f *frame, phase, atk float64) {
	oy := 1.2*math.Abs(math.Sin(phase)) - 0.6
	armA := -1.15
	sway := 0.2 * math.Sin(phase)
	walk := math.Sin(phase)
	if atk > 0 {
		oy, armA, sway, walk = 0, -1.15+0.95*atk, 0, 0
	}
	sp := &vector.Path{}
	f.through(sp, 2, 16+oy, -3, 34+oy, 12, 42+oy)
	f.stroke(sp, 9)
	spike := &vector.Path{}
	for _, s := range [][2]float64{{-4, 36}, {1, 40}, {6, 43}} {
		x0, y0 := f.pt(s[0], s[1]+oy)
		x1, y1 := f.pt(s[0]-2.5, s[1]+6+oy)
		x2, y2 := f.pt(s[0]+3, s[1]+1.5+oy)
		spike.MoveTo(x0, y0)
		spike.LineTo(x1, y1)
		spike.LineTo(x2, y2)
		spike.Close()
	}
	f.fill(spike)
	f.ellipse(15.5, 42.5+oy, 5.5, 4.5)
	snout := &vector.Path{}
	x0, y0 := f.pt(19, 41+oy)
	x1, y1 := f.pt(26, 39+oy)
	x2, y2 := f.pt(19, 38+oy)
	snout.MoveTo(x0, y0)
	snout.LineTo(x1, y1)
	snout.LineTo(x2, y2)
	snout.Close()
	f.fill(snout)

	limbs := &vector.Path{}
	ex, ey, dir := f.limb(limbs, 10, 38+oy, 13, 12, armA+sway, 0.45)
	f.claws(limbs, ex, ey, dir-0.5)
	ex, ey, dir = f.limb(limbs, 9, 39+oy, 13, 12, armA-sway-0.25, 0.5)
	f.claws(limbs, ex, ey, dir-0.5)
	f.limb(limbs, 0, 16+oy, 9, 9, -1.57+0.5*walk, -0.3-0.5*math.Max(0, -walk))
	f.limb(limbs, 0, 16+oy, 9, 9, -1.57-0.5*walk, -0.3-0.5*math.Max(0, walk))
	f.stroke(limbs, kinds[kGrunt].lineWidth)
}

func drawHound(f *frame, phase, atk float64) {
	oy := 1.6 * math.Sin(phase*2)
	ox := 0.0
	jaw := -0.18 - 0.08*math.Sin(phase*2)
	if atk > 0 {
		ox, oy = 6*atk, 0
		jaw = -0.18 - 0.85*atk
	}
	body := &vector.Path{}
	f.through(body, ox-15, 24+oy, ox-2, 28+oy, ox+12, 27+oy)
	f.stroke(body, 10)
	head := &vector.Path{}
	x0, y0 := f.pt(ox+11, 33+oy)
	x1, y1 := f.pt(ox+29, 27+oy)
	x2, y2 := f.pt(ox+12, 22+oy)
	head.MoveTo(x0, y0)
	head.LineTo(x1, y1)
	head.LineTo(x2, y2)
	head.Close()
	x0, y0 = f.pt(ox+12, 33+oy)
	x1, y1 = f.pt(ox+15, 40+oy)
	x2, y2 = f.pt(ox+18, 32+oy)
	head.MoveTo(x0, y0)
	head.LineTo(x1, y1)
	head.LineTo(x2, y2)
	head.Close()
	f.fill(head)
	misc := &vector.Path{}
	f.line(misc, ox+13, 23+oy, ox+13+12*math.Cos(jaw), 23+oy+12*math.Sin(jaw))
	f.through(misc, ox-15, 26+oy, ox-22, 30+1.5*math.Sin(phase)+oy, ox-27, 34+2.5*math.Sin(phase)+oy)
	legs := &vector.Path{}
	hips := [][3]float64{{10, 22, 0}, {10, 22, 0.5}, {-13, 22, math.Pi}, {-13, 22, math.Pi + 0.5}}
	for _, h := range hips {
		s := math.Sin(phase + h[2])
		f.limb(legs, ox+h[0], h[1]+oy, 11, 11, -1.57+0.62*s, -0.4-0.5*math.Max(0, -s))
	}
	f.stroke(misc, kinds[kRunner].lineWidth*0.9)
	f.stroke(legs, kinds[kRunner].lineWidth)
}

func drawBrute(f *frame, phase, atk float64) {
	oy := 1.0 * math.Abs(math.Sin(phase))
	armA := -1.2 + 0.14*math.Sin(phase)*btoi(atk == 0)
	flex := 0.3
	if atk > 0 {
		armA = -1.2 + 2.2*atk
		flex = 0.3 - 0.45*atk
	}
	f.ellipse(0, 44+oy, 17, 20)
	f.ellipse(8.5, 65+oy, 5.5, 5)
	arms := &vector.Path{}
	f.limb(arms, 16, 50+oy, 19, 17, armA, flex)
	f.limb(arms, 13, 53+oy, 18, 16, armA-0.2, flex)
	f.stroke(arms, kinds[kBrute].lineWidth*1.1)
	legs := &vector.Path{}
	s := math.Sin(phase)
	f.limb(legs, 4, 27+oy, 14, 13, -1.57+0.34*s, -0.2-0.35*math.Max(0, -s))
	f.limb(legs, -4, 27+oy, 14, 13, -1.57-0.34*s, -0.2-0.35*math.Max(0, s))
	f.stroke(legs, kinds[kBrute].lineWidth)
}

func drawWyvern(f *frame, phase, atk float64) {
	base := 65 + 4*math.Sin(phase*0.6)
	wingF := 0.55*math.Sin(phase) + 0.15
	wingB := -0.45*math.Sin(phase) - 0.1
	if atk > 0 {
		base = 65 - 44*atk
		wingF = 0.9 * atk
		wingB = -0.7 * atk
	}
	wing := func(scale, rot, px, py float64) {
		p := &vector.Path{}
		rp := func(lx, ly float64) (float32, float32) {
			c, s := math.Cos(rot), math.Sin(rot)
			return f.pt(px+(lx*c-ly*s)*scale, py+(lx*s+ly*c)*scale)
		}
		x0, y0 := rp(0, 0)
		p.MoveTo(x0, y0)
		cx, cy := rp(-4, 16)
		x1, y1 := rp(-16, 20)
		p.QuadTo(cx, cy, x1, y1)
		x2, y2 := rp(-26, 12)
		p.LineTo(x2, y2)
		cx, cy = rp(-21, 9)
		x3, y3 := rp(-20, 4)
		p.QuadTo(cx, cy, x3, y3)
		cx, cy = rp(-14, 2)
		x4, y4 := rp(-10, -1)
		p.QuadTo(cx, cy, x4, y4)
		p.Close()
		f.fill(p)
	}
	wing(0.85, wingB, -4, base+3)
	body := &vector.Path{}
	f.through(body, -9, base, 0, base+2, 8, base+1)
	f.stroke(body, 9)
	head := &vector.Path{}
	x0, y0 := f.pt(8, base+6)
	x1, y1 := f.pt(22, base+1)
	x2, y2 := f.pt(9, base-3)
	head.MoveTo(x0, y0)
	head.LineTo(x1, y1)
	head.LineTo(x2, y2)
	head.Close()
	x0, y0 = f.pt(9, base+6)
	x1, y1 = f.pt(7, base+13)
	x2, y2 = f.pt(13, base+5)
	head.MoveTo(x0, y0)
	head.LineTo(x1, y1)
	head.LineTo(x2, y2)
	head.Close()
	f.fill(head)
	misc := &vector.Path{}
	f.through(misc, -9, base, -18, base-4, -26, base+2)
	f.line(misc, 2, base-3, 4, base-11)
	f.line(misc, -3, base-3, -2, base-11)
	f.stroke(misc, kinds[kWyvern].lineWidth*0.8)
	wing(1.0, wingF, -2, base+3)
}

func drawReaper(f *frame, phase, atk float64) {
	oy := 1.5 * math.Sin(phase*0.8)
	scy := 0.08 * math.Sin(phase*0.8)
	if atk > 0 {
		oy = 0
		scy = -1.5 * atk
	}
	cloak := &vector.Path{}
	mv := func(lx, ly float64) (float32, float32) { return f.pt(lx, ly+oy) }
	x0, y0 := mv(-9, 0)
	cloak.MoveTo(x0, y0)
	cx, cy := mv(-12, 22)
	x1, y1 := mv(-6, 40)
	cloak.QuadTo(cx, cy, x1, y1)
	cx, cy = mv(-6, 52)
	x1, y1 = mv(2, 56)
	cloak.QuadTo(cx, cy, x1, y1)
	cx, cy = mv(9, 55)
	x1, y1 = mv(10, 46)
	cloak.QuadTo(cx, cy, x1, y1)
	cx, cy = mv(10, 36)
	x1, y1 = mv(7, 24)
	cloak.QuadTo(cx, cy, x1, y1)
	cx, cy = mv(9, 10)
	x1, y1 = mv(9, 0)
	cloak.QuadTo(cx, cy, x1, y1)
	for _, s := range [][2]float64{{5, 6}, {1, 0}, {-3, 6}, {-6, 0}} {
		x, y := mv(s[0], s[1])
		cloak.LineTo(x, y)
	}
	cloak.Close()
	f.fill(cloak)
	// 낫: (4,26) 피벗 회전
	rp := func(lx, ly float64) (float64, float64) {
		c, s := math.Cos(scy), math.Sin(scy)
		return 4 + lx*c - ly*s, 26 + oy + lx*s + ly*c
	}
	staff := &vector.Path{}
	ax, ay := rp(-5, -16)
	bx, by := rp(7, 32)
	f.line(staff, ax, ay, bx, by)
	f.stroke(staff, kinds[kReaper].lineWidth*0.8)
	blade := &vector.Path{}
	px, py := rp(7, 32)
	x0, y0 = f.pt(px, py)
	blade.MoveTo(x0, y0)
	cxx, cyy := rp(24, 34)
	exx, eyy := rp(28, 22)
	cX, cY := f.pt(cxx, cyy)
	eX, eY := f.pt(exx, eyy)
	blade.QuadTo(cX, cY, eX, eY)
	cxx, cyy = rp(21, 25)
	exx, eyy = rp(8, 28)
	cX, cY = f.pt(cxx, cyy)
	eX, eY = f.pt(exx, eyy)
	blade.QuadTo(cX, cY, eX, eY)
	blade.Close()
	f.fill(blade)
}

func drawJugger(f *frame, phase, atk float64) {
	oy := 1.0 * math.Abs(math.Sin(phase))
	armA := -1.35 + 0.1*math.Sin(phase)*btoi(atk == 0)
	flex := 0.15
	if atk > 0 {
		armA = -1.35 + 2.1*atk
		flex = 0.15 - 0.3*atk
	}
	torso := &vector.Path{}
	pts := [][2]float64{{-14, 24}, {-20, 58}, {20, 58}, {14, 24}}
	x0, y0 := f.pt(pts[0][0], pts[0][1]+oy)
	torso.MoveTo(x0, y0)
	for _, p := range pts[1:] {
		x, y := f.pt(p[0], p[1]+oy)
		torso.LineTo(x, y)
	}
	torso.Close()
	helm := [][2]float64{{-6, 58}, {-4, 70}, {6, 70}, {8, 58}}
	x0, y0 = f.pt(helm[0][0], helm[0][1]+oy)
	torso.MoveTo(x0, y0)
	for _, p := range helm[1:] {
		x, y := f.pt(p[0], p[1]+oy)
		torso.LineTo(x, y)
	}
	torso.Close()
	f.fill(torso)
	f.ellipse(-19, 55.5+oy, 6, 5.5)
	f.ellipse(19, 55.5+oy, 6, 5.5)
	arms := &vector.Path{}
	f.limb(arms, 20, 52+oy, 17, 15, armA, flex)
	f.limb(arms, -18, 52+oy, 16, 14, armA-0.3, flex)
	f.stroke(arms, kinds[kJugger].lineWidth*1.3)
	legs := &vector.Path{}
	s := math.Sin(phase)
	f.limb(legs, 6, 25+oy, 13, 12, -1.57+0.3*s, -0.15-0.3*math.Max(0, -s))
	f.limb(legs, -6, 25+oy, 13, 12, -1.57-0.3*s, -0.15-0.3*math.Max(0, s))
	f.stroke(legs, kinds[kJugger].lineWidth*1.1)
}

func drawCreature(f *frame, k enemyKind, phase, atk float64) {
	switch k {
	case kGrunt:
		drawGhoul(f, phase, atk)
	case kRunner:
		drawHound(f, phase, atk)
	case kBrute:
		drawBrute(f, phase, atk)
	case kWyvern:
		drawWyvern(f, phase, atk)
	case kReaper:
		drawReaper(f, phase, atk)
	case kJugger:
		drawJugger(f, phase, atk)
	case kBoss:
		drawColossus(f, phase, atk)
	}
}

func btoi(b bool) float64 {
	if b {
		return 1
	}
	return 0
}

// 창 그리기: (x,y) 중심, rot 방향. power면 다이아 촉+깃털
func drawSpear(dst *ebiten.Image, x, y, rot float64, power bool, col color.Color, alpha float32) {
	f := &frame{dst: dst, ox: x, oy: y, fx: 1, rot: rot, col: col, alpha: alpha}
	p := &vector.Path{}
	half := spearLen / 2
	if power {
		f.line(p, -half, 0, half-16, 0)
		f.stroke(p, 4.5)
		d := &vector.Path{}
		x0, y0 := f.pt(half+4, 0)
		d.MoveTo(x0, y0)
		for _, q := range [][2]float64{{half - 8, 5.5}, {half - 16, 0}, {half - 8, -5.5}} {
			xx, yy := f.pt(q[0], q[1])
			d.LineTo(xx, yy)
		}
		d.Close()
		f.fill(d)
		misc := &vector.Path{}
		f.line(misc, half-18, 6, half-18, -6)
		for _, dy := range []float64{1, -1} {
			f.line(misc, -half, 0, -half-9, 6*dy)
			f.line(misc, -half+8, 0, -half-1, 6*dy)
		}
		f.stroke(misc, 2)
	} else {
		f.line(p, -half, 0, half-7, 0)
		f.stroke(p, 2.5)
		tip := &vector.Path{}
		x0, y0 := f.pt(half, 0)
		tip.MoveTo(x0, y0)
		x1, y1 := f.pt(half-9, 3.2)
		x2, y2 := f.pt(half-9, -3.2)
		tip.LineTo(x1, y1)
		tip.LineTo(x2, y2)
		tip.Close()
		f.fill(tip)
	}
}


// ── 콜로서스 (보스): 뿔투구 거대 골렘, 키 ~150 ──

func drawColossus(f *frame, phase, atk float64) {
	oy := 2.0 * math.Abs(math.Sin(phase))
	armA := -1.4 + 0.09*math.Sin(phase)*btoi(atk == 0)
	flex := 0.2
	if atk > 0 {
		armA = -1.4 + 2.3*atk
		flex = 0.2 - 0.3*atk
	}
	// 몸통 슬랩 + 투구 + 뿔
	torso := &vector.Path{}
	poly := func(pts [][2]float64) {
		x0, y0 := f.pt(pts[0][0], pts[0][1]+oy)
		torso.MoveTo(x0, y0)
		for _, q := range pts[1:] {
			x, y := f.pt(q[0], q[1]+oy)
			torso.LineTo(x, y)
		}
		torso.Close()
	}
	poly([][2]float64{{-22, 52}, {-40, 128}, {40, 128}, {22, 52}})
	poly([][2]float64{{-12, 128}, {-9, 150}, {9, 150}, {12, 128}})
	poly([][2]float64{{-9, 148}, {-17, 164}, {-4, 152}})
	poly([][2]float64{{9, 148}, {17, 164}, {4, 152}})
	f.fill(torso)
	// 팔 + 주먹
	arm := func(rx, ry, l1, l2, ang, fl, w float64) {
		p := &vector.Path{}
		ex, ey, _ := f.limb(p, rx, ry+oy, l1, l2, ang, fl)
		f.stroke(p, w)
		f.circle(ex, ey, w+1.5)
	}
	arm(-36, 120, 40, 36, armA-0.25, flex, 10)
	arm(38, 120, 42, 38, armA, flex, 11)
	// 기둥 다리
	legs := &vector.Path{}
	s := math.Sin(phase)
	f.line(legs, 16, 54+oy, 16+12*math.Sin(0.22*s), 0)
	f.line(legs, -16, 54+oy, -16-12*math.Sin(0.22*s), 0)
	f.stroke(legs, 9)
}
