package main

// 효과음 — 맥판과 동일한 합성 WAV를 임베드. M키로 켬/끔.

import (
	"bytes"
	"embed"
	"io"

	"github.com/hajimehoshi/ebiten/v2/audio"
	"github.com/hajimehoshi/ebiten/v2/audio/wav"
)

//go:embed assets/sounds/*.wav
var soundFS embed.FS

const soundSR = 22050

var (
	audioCtx  = audio.NewContext(soundSR)
	soundData = map[string][]byte{}
	soundOn   = true
	soundLast = map[string]float64{}
	soundNow  float64 // Game.Update가 dt씩 누적
)

func loadSounds() {
	for _, name := range []string{"throw", "hit", "kill", "crit", "power", "card", "gameover"} {
		raw, err := soundFS.ReadFile("assets/sounds/" + name + ".wav")
		if err != nil {
			continue
		}
		st, err := wav.DecodeWithSampleRate(soundSR, bytes.NewReader(raw))
		if err != nil {
			continue
		}
		pcm, err := io.ReadAll(st)
		if err != nil {
			continue
		}
		soundData[name] = pcm
	}
}

func playSound(name string) {
	if !soundOn {
		return
	}
	b, ok := soundData[name]
	if !ok {
		return
	}
	if t, ok := soundLast[name]; ok && soundNow-t < 0.04 { // 동시 다중 명중 스로틀
		return
	}
	soundLast[name] = soundNow
	audioCtx.NewPlayerFromBytes(b).Play()
}
