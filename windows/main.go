package main

// TTALGAK Windows 포트 — Go + Ebitengine.
// 투명·테두리 없음·항상 위 창을 작업표시줄 위에 띄운다.
// 조작: 클릭=투척, Space=일시정지, 우클릭=일시정지+최소화, F=좌우반전, T=테마, R=재시작, Esc=종료

import (
	"bytes"
	_ "embed"
	"image/color"
	"log"
	"os"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/text/v2"
)

//go:embed assets/NanumGothic-Regular.ttf
var fontBytes []byte

var fontSrc *text.GoTextFaceSource

func drawTextCenter(dst *ebiten.Image, s string, size, x, gy float64, col color.Color) {
	face := &text.GoTextFace{Source: fontSrc, Size: size}
	op := &text.DrawOptions{}
	op.GeoM.Translate(x, sceneH-gy-size*0.6)
	op.ColorScale.ScaleWithColor(col)
	op.PrimaryAlign = text.AlignCenter
	text.Draw(dst, s, face, op)
}

func main() {
	for _, arg := range os.Args[1:] {
		if arg == "-muted" || arg == "--muted" {
			soundOn = false // 자동 테스트용
		}
	}
	src, err := text.NewGoTextFaceSource(bytes.NewReader(fontBytes))
	if err != nil {
		log.Fatal(err)
	}
	fontSrc = src

	mw, mh := ebiten.Monitor().Size()
	ebiten.SetWindowDecorated(false)
	ebiten.SetWindowFloating(true)
	ebiten.SetWindowSize(sceneW, sceneH)
	ebiten.SetWindowPosition((mw-sceneW)/2, mh-sceneH-56) // 작업표시줄 위
	ebiten.SetWindowTitle("TTALGAK")
	ebiten.SetTPS(60)

	op := &ebiten.RunGameOptions{ScreenTransparent: true}
	if err := ebiten.RunGameWithOptions(NewGame(), op); err != nil && err != ebiten.Termination {
		log.Fatal(err)
	}
}
