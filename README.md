# TTALGAK (딸각)

macOS 데스크탑 위, 독(Dock) 바로 위에 떠 있는 투명 플로팅 창에서 즐기는 스틱맨 창던지기 웨이브 디펜스 게임.

순수 네이티브 — Swift + AppKit + SpriteKit, 외부 의존성 0.

## 특징

- **스켈레톤 절차 애니메이션**: 스프라이트가 아닌 관절 뼈대 + 키포즈 보간. 창은 손에서 릴리즈되는 순간부터 전체 궤적을 그리며 날아감
- **클릭 조준 투척**: 클릭한 지점으로 포물선 조준. 쿨다운제
- **크리처 6종**: 하급(구울/하운드/브루트) + 정예(와이번·공중/리퍼·순간이동/저거너트·넉백면역)
- **등급제 업그레이드 24종**: 일반/레어/유니크(1회 한정) — 크리티컬, 파워샷, 쌍창, 폭발창, 불사조 등
- **흑백 실루엣 아트**: 기본 검정, 상태바 메뉴에서 흰색 테마 전환
- **헤드리스 밸런스 시뮬레이터** 내장

## 실행

```bash
swift build
.build/debug/ttalgak
```

독 위에 게임 밴드가 뜨고, 상태바 🎯 메뉴에서 좌우 반전 / 흰색 테마 / 다시 시작 / 종료.

## 개발 도구

```bash
.build/debug/ttalgak --selftest          # 조준 풀이·포즈 보간 검증
.build/debug/ttalgak --snapshot <dir>    # 오프스크린 렌더 PNG (모션 육안 검증)
.build/debug/ttalgak --simulate 30       # 봇 자동 플레이로 난이도 곡선 출력
```

밸런스 수치는 전부 `Sources/ttalgak/Config.swift`에 모여 있음.

## 요구 사항

- macOS 13+
- Xcode Command Line Tools (Swift 5.9+)
