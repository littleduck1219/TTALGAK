package main

// 설정/기록 영속화: %AppData%\ttalgak\config.json (맥 개발 실행 시 ~/Library/Application Support)

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type appSettings struct {
	White    bool           `json:"white"`
	Mirrored bool           `json:"mirrored"`
	Muted    bool           `json:"muted"`
	Diff     int            `json:"diff"`
	Best     map[string]int `json:"best"` // 난이도별 최고 웨이브
}

var cfg = appSettings{Best: map[string]int{}}

func cfgPath() string {
	d, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(d, "ttalgak", "config.json")
}

func loadCfg() {
	p := cfgPath()
	if p == "" {
		return
	}
	if b, err := os.ReadFile(p); err == nil {
		_ = json.Unmarshal(b, &cfg)
	}
	if cfg.Best == nil {
		cfg.Best = map[string]int{}
	}
}

func saveCfg() {
	p := cfgPath()
	if p == "" {
		return
	}
	_ = os.MkdirAll(filepath.Dir(p), 0o755)
	if b, err := json.MarshalIndent(cfg, "", "  "); err == nil {
		_ = os.WriteFile(p, b, 0o644)
	}
}

func (d difficulty) key() string {
	switch d {
	case dEasy:
		return "easy"
	case dHard:
		return "hard"
	}
	return "normal"
}
