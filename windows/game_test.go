package main

import (
	"math"
	"testing"
)

// 포물선 조준이 오일러 적분 시뮬레이션으로 목표 근처에 도달하는지
func TestAimVelocity(t *testing.T) {
	px, py := 100.0, 90.0
	tx, ty := 620.0, 68.0
	vx, vy := aimVelocity(px, py, tx, ty, spearSpeed)
	x, y := px, py
	const step = 1.0 / 240
	for i := 0; x < tx && i < 5000; i++ {
		vy -= gravity * step
		x += vx * step
		y += vy * step
	}
	if math.Abs(y-ty) > 20 {
		t.Fatalf("ballistic miss: y=%.1f target=%.1f", y, ty)
	}
	// 반전 방향 부호
	vxl, _ := aimVelocity(600, 90, 100, 68, spearSpeed)
	if vxl >= 0 {
		t.Fatal("mirrored aim should fly -x")
	}
}

// 포즈 보간 중간값
func TestLerpPose(t *testing.T) {
	mid := lerpPose(poseIdle, poseWindup, 0.5)
	want := (poseIdle.lean + poseWindup.lean) / 2
	if math.Abs(mid.lean-want) > 1e-9 {
		t.Fatalf("pose lerp broken: %v != %v", mid.lean, want)
	}
}

// 카드 롤: 3장, 중복 없음, 소진된 유니크 제외
func TestRollCards(t *testing.T) {
	g := NewGame()
	g.wave = 10
	g.uniquesTaken["splash"] = true
	for i := 0; i < 200; i++ {
		cards := g.rollCards()
		if len(cards) != 3 {
			t.Fatalf("want 3 cards, got %d", len(cards))
		}
		seen := map[string]bool{}
		for _, c := range cards {
			if seen[c.id] {
				t.Fatalf("duplicate card %s", c.id)
			}
			seen[c.id] = true
			if c.id == "splash" {
				t.Fatal("consumed unique reappeared")
			}
		}
	}
}

// 업그레이드 적용 스모크: 전 카드 1회씩
func TestApplyAll(t *testing.T) {
	s := newStats()
	for _, u := range upgradePool {
		s.apply(u)
	}
	if s.damage <= spearDamage || s.multishot == 0 || !s.hasRevive || !s.hitCombo {
		t.Fatalf("apply smoke failed: %+v", s)
	}
}
