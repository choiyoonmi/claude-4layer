# 클로드 4층 구조 — 웨비나 실습 플러그인

공감에듀테크 바이브코딩 웨비나 부교재. **md · 스킬 · 플러그인 · 메모리** 네 층을 설명한 자료를, 그 자료에서 설명한 방법 그대로 배포한 것입니다. 설치하는 순간이 곧 실습입니다.

## 설치 (클로드 코드 / CLI)

```bash
/plugin marketplace add choiyoonmi/claude-4layer
```

```bash
/plugin install claude-4layer@gonggam-edutech
```

```bash
/reload-plugins
```

설치가 끝나면 `/` 를 쳤을 때 아래 세 개가 보입니다.

## 들어 있는 것

| 명령어 | 하는 일 |
|---|---|
| `/claude-4layer:layer-map` | 이건 md인가 스킬인가 — 무엇을 어디에 둘지 판단해 줍니다. 환경별(웹·데스크톱·코워크·CLI) 차이와 자주 나오는 증상별 원인도 함께. |
| `/claude-4layer:md-init` | 지금 폴더를 살펴보고 그 폴더에 맞는 `CLAUDE.md` 초안을 만듭니다. 150줄 한계선을 지키고, 학원 행정 / 교재 제작 / 앱 개발 템플릿 중에서 고릅니다. |
| `/claude-4layer:skill-path` | **스킬이 안 먹힐 때.** 지금 읽히는 `CLAUDE.md`, 설치된 스킬·플러그인을 훑고 `.claude/skills` 밖에 방치된 스킬을 찾아 제자리로 옮깁니다. |

## 점검 스크립트만 따로 쓰기

플러그인을 설치하지 않고 진단만 돌려도 됩니다. Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\plugins\claude-4layer\skills\skill-path\scripts\check-skills.ps1
```

한 화면에 다섯 가지가 나옵니다.

1. 지금 읽히는 `CLAUDE.md` (개인 + 폴더 계층, 줄 수와 200줄 초과 경고)
2. 개인 스킬 — `description` 없음·프론트매터 없음·폴더명 불일치를 `[!]`로 표시
3. 이 폴더의 프로젝트 스킬
4. 설치된 플러그인과 그 안의 스킬 이름
5. **`.claude/skills` 밖에 방치된 스킬** — 인식 안 되는 이유 1순위

기본은 보기만 합니다. 옮기려면 `-Fix`를 붙입니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\...\check-skills.ps1 -Fix
```

느리면 범위를 좁힙니다: `-Roots 'C:\내작업폴더' -Depth 6`

## 배포용 치트시트 (A4 한 장)

[`docs/cheatsheet.html`](docs/cheatsheet.html) — 브라우저로 열고 **인쇄 / PDF로 저장** 버튼을 누르면 A4 한 장이 그대로 나옵니다. 여백 없이 꽉 차게 설계했으니 인쇄 설정에서 **배율 100%, 배경 그래픽 켜기**로 두세요.

담긴 것: 4층 정의 · 설치 경로 5줄 · 판단 5질문 · 증상별 원인 6가지 · 환경 매트릭스 · 설치 명령 3줄.

## 웹 · 데스크톱 · 코워크에서 쓰려면

이 세 환경은 폴더가 아니라 ZIP 업로드입니다. `plugins/claude-4layer/skills/` 안의 **스킬 폴더 하나를 각각 압축**해서 **Customize → Skills → +** 에 올리세요. 계정에 붙어서 웹·데스크톱·코워크 모두에 뜹니다.

단, 점검 스크립트는 내 컴퓨터 파일을 읽어야 하므로 **CLI나 데스크톱 앱에서만** 의미가 있습니다.

## 한 줄 요약

> md는 무조건 읽히고, 스킬은 필요할 때 불려오고, 플러그인은 그 둘을 담아 나르는 상자이고, 메모리는 내가 안 적어도 쌓입니다.

헷갈릴 땐 **"이건 매번 지켜야 하나?"** 만 물어보세요. 그렇다 → md, 아니다 → 스킬.

## 깃허브에 올리기 전에 — 로컬에서 먼저 테스트

푸시하지 않고도 지금 그대로 돌려 볼 수 있습니다.

```bash
claude --plugin-dir ./plugins/claude-4layer
```

이렇게 띄운 세션에서 `/claude-4layer:layer-map` 을 쳐 보면 됩니다. 고친 뒤에는 재시작 없이 `/reload-plugins` 로 반영합니다.

구조가 맞는지 공식 검사기로 확인하려면:

```bash
claude plugin validate ./plugins/claude-4layer
```

`✔ Validation passed` 가 나오면 올려도 됩니다.

## 저장소 구조

```
claude-4layer/
├── .claude-plugin/
│   └── marketplace.json          # 마켓 카탈로그
├── docs/
│   └── cheatsheet.html           # A4 한 장 치트시트 (인쇄용)
└── plugins/
    └── claude-4layer/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── layer-map/SKILL.md
            ├── md-init/
            │   ├── SKILL.md
            │   └── templates/    # CLAUDE.md 템플릿 3종
            └── skill-path/
                ├── SKILL.md
                └── scripts/check-skills.ps1
```

`source`의 상대경로(`./plugins/claude-4layer`)는 **마켓 루트 기준**으로 풀립니다. `.claude-plugin/` 기준이 아닙니다.

## 라이선스

MIT. 수업·연수에 자유롭게 쓰시고, 고쳐서 각자 학원 이름으로 배포하셔도 됩니다.
