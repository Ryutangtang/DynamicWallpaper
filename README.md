# DynamicWallpaper

macOS 메뉴바 앱. Metal 셰이더 기반 생성형 애니메이션을 바탕화면에 실시간 렌더링한다.

## 프리셋

| 프리셋 | 설명 |
|--------|------|
| ✦ Particles | 색상 파티클 다중 궤도 |
| 〜 Aurora | 오로라 밴드 + 별빛 |
| ◉ Nebula | FBM 성운 레이어 |
| ≋ Wave | 스펙트럼 파형 |

## 빌드 방법

### Xcode 프로젝트로 빌드 (권장)

1. Xcode에서 새 macOS App 프로젝트 생성
2. `Sources/` 하위 파일 전부 프로젝트에 추가
3. `Sources/Metal/Shaders.metal` → Target Membership 확인
4. Info.plist에서 `LSUIElement = YES` 설정
5. `@main` 타깃 파일: `DynamicWallpaperApp.swift`
6. Build & Run

### 주의사항

- **macOS 13.0 이상** 필요 (Metal 2 + SwiftUI)
- Xcode 15 이상 권장
- `LSUIElement = YES` 가 없으면 Dock에 아이콘이 표시된다
- 멀티 모니터 환경에서 각 디스플레이에 별도 윈도우 생성

## 구조

```
DynamicWallpaper/
├── Sources/
│   ├── App/
│   │   ├── DynamicWallpaperApp.swift   # @main 진입점
│   │   └── AppDelegate.swift           # 메뉴바 + 윈도우 관리
│   ├── Animation/
│   │   └── AnimationController.swift   # 프리셋/속도/상태 공유
│   └── Metal/
│       ├── MetalAnimationView.swift    # MTKView 렌더러
│       └── Shaders.metal               # 4개 프리셋 셰이더
└── Resources/
    └── Info.plist
```

## 확장 포인트

- `Shaders.metal`에 `fragment_mypreset` 함수 추가
- `AnimationPreset` enum에 case 추가
- `AppDelegate.buildMenu()`는 자동으로 메뉴에 반영

## 알려진 제약

- macOS Mission Control에서 바탕화면 레벨 윈도우가 가려질 수 있다
- `NSWindow.Level.desktopIcon - 1` 레벨이 최적이나 macOS 버전에 따라 조정이 필요할 수 있다
- 영상 파일 기반 배경이 필요하면 `AVPlayerLayer`를 `MetalAnimationView` 대신 사용한다
