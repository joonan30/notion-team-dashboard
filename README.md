# notion-team-dashboard

팀 Notion 워크스페이스의 주간 활동을 자동으로 수집하여 HTML 대시보드로 생성합니다.
[Claude Code](https://claude.com/claude-code) CLI와 [Notion MCP Server](https://github.com/makenotion/notion-mcp-server)를 활용합니다.

**백엔드 없음. DB 없음. 셸 스크립트 하나로 HTML 파일 하나 생성.**

```
./generate_dashboard.sh
  → Claude Code CLI (claude --print)
    → Notion MCP (검색, 페이지 조회)
      → 멤버별 활동 수집
    → dashboard.html 생성
```

## 결과물 미리보기

> **[라이브 데모 보기](https://joonan30.github.io/notion-team-dashboard/)** (샘플 데이터)

생성되는 대시보드 구성:

- **통계 요약** — 활성 프로젝트, 팀원 수, 마감일, 업데이트된 페이지
- **마감일 트래커** — D-day 카운트다운
- **프로젝트 카드** — 프로젝트별 진행 상황 (완료 / 진행중 / 예정)
- **멤버 카드** — 클릭하면 펼쳐지는 개인별 주간 활동 + Notion 링크
- **활동 타임라인** — 시간순 전체 변경 이력
- **다크 테마** — 반응형 레이아웃, 외부 의존성 없음

## 필요 사항

| 항목 | 비고 |
|---|---|
| [Claude Code CLI](https://claude.com/claude-code) | `claude` 명령어가 PATH에 있어야 함 |
| [Node.js](https://nodejs.org/) 18 이상 | Notion MCP 서버 실행용 (`npx`) |
| Python 3 | 설정 파싱용 (macOS/Linux에 기본 설치됨) |
| Notion 워크스페이스 | [내부 통합(Integration)](#1단계-notion-integration-생성) 필요 |

## 설정 방법

### 1단계: Notion Integration 생성

1. [notion.so/my-integrations](https://www.notion.so/my-integrations) 접속
2. **"+ 새 통합(New integration)"** 클릭
3. 설정:
   - **이름**: 예) `팀 대시보드`
   - **연결된 워크스페이스**: 본인 워크스페이스 선택
   - **기능(Capabilities)**: **콘텐츠 읽기**, **댓글 읽기**, **사용자 정보 읽기** 활성화
4. **제출** → **내부 통합 시크릿** 복사 (`ntn_...`으로 시작)

### 2단계: 페이지에 Integration 연결

대시보드에서 추적할 Notion 페이지마다:

1. 페이지 열기 → 우측 상단 **"..."** → **"연결(Connections)"**
2. 만든 Integration 이름 검색 (예: `팀 대시보드`)
3. **확인** 클릭

> Integration은 명시적으로 공유된 페이지(및 하위 페이지)만 접근할 수 있습니다.

### 3단계: Claude Code에 Notion MCP 설정

`~/.claude/settings.json`에 Notion MCP 서버를 추가합니다:

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer ntn_여기에_토큰_입력\", \"Notion-Version\": \"2022-06-28\"}"
      }
    }
  }
}
```

> `ntn_여기에_토큰_입력`을 1단계에서 복사한 토큰으로 교체하세요.

### 4단계: 설치 및 설정

```bash
# 클론
git clone https://github.com/joonan30/notion-team-dashboard.git
cd notion-team-dashboard

# 설정 파일 생성
cp config.example.json config.json
# config.json을 본인 팀에 맞게 수정
```

`config.json` 수정 예시:

```jsonc
{
  "team_name": "우리 연구실",           // 대시보드 헤더에 표시
  "team_url": "",                        // (선택) 팀 웹사이트 URL
  "output_path": "./dashboard.html",     // 대시보드 출력 경로
  "lookback_days": 7,                    // 며칠 전까지 조회할지

  "workspace": {
    // (선택) Notion에 인턴/학생용 데이터베이스가 있다면 collection ID 입력
    "intern_db_collection": ""
  },

  "members": {
    "graduate": {
      "홍길동": {
        "role": "PhD",
        "focus": "기계학습",
        "notion_page": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "alt_name": "Gildong Hong"    // (선택) 영어 이름 등 대체 이름
      }
    },
    "staff": {
      "김철수": { "role": "연구원" }
    },
    "interns": {
      "이영희": {
        "since": "2026-01",
        "notion_page": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      }
    }
  }
}
```

#### Notion Page ID 찾는 법

Notion 페이지 URL에서 32자리 16진수 문자열이 Page ID입니다:

```
https://www.notion.so/내-페이지-제목-abc123def456...
                                      ^^^^^^^^^^^^^^^^
                                      이 부분이 Page ID
```

또는 Claude Code에서 직접 검색:

```bash
claude
> notion-search로 "홍길동" 검색해줘
```

### 5단계: 실행

```bash
# 대시보드 생성
./generate_dashboard.sh

# 브라우저에서 확인
open dashboard.html      # macOS
xdg-open dashboard.html  # Linux
```

**드라이런 모드** (프롬프트만 출력, Claude 실행 안 함):

```bash
./generate_dashboard.sh --dry-run
```

## 자동 실행 설정 (선택)

### macOS — launchd

1. `com.notion-team-dashboard.plist`에서 스크립트 경로 수정
2. 설치:
   ```bash
   cp com.notion-team-dashboard.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.notion-team-dashboard.plist
   ```
3. 해제:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.notion-team-dashboard.plist
   ```

기본값: 매주 **금요일 오전 9시** 실행. plist의 `StartCalendarInterval`에서 변경 가능.

### Linux / WSL — cron

```bash
crontab -e
# 매주 금요일 오전 9시:
0 9 * * 5 /path/to/notion-team-dashboard/generate_dashboard.sh
```

## 설정 항목 레퍼런스

| 항목 | 필수 | 설명 |
|---|---|---|
| `team_name` | O | 대시보드 헤더에 표시될 팀 이름 |
| `team_url` | X | 팀 웹사이트 URL (입력하면 추가 컨텍스트로 활용) |
| `output_path` | O | 생성될 HTML 파일 경로 (상대/절대 모두 가능) |
| `lookback_days` | X | 조회 기간 (기본값: 7일) |
| `workspace.intern_db_collection` | X | Notion 인턴/학생 DB의 collection ID (`collection://UUID` 형식) |
| `members.graduate` | X | 대학원생 — `{role, focus, notion_page?, alt_name?}` |
| `members.staff` | X | 스태프 — `{role}` |
| `members.interns` | X | 인턴 — `{since, notion_page?}` |

### 멤버 필드

| 필드 | 설명 |
|---|---|
| `role` | 직위: `PhD`, `MS`, `Postdoc`, `연구원` 등 |
| `focus` | 연구 분야 / 팀 (대시보드에 태그로 표시) |
| `notion_page` | 해당 멤버의 최상위 Notion 페이지 UUID (하위 페이지 심층 검색 활성화) |
| `alt_name` | Notion 사용자 검색용 대체 이름 (예: 영어 이름) |
| `since` | 인턴 시작일 (YYYY-MM 형식) |

## 활동 감지 방식

`created_date_range` 필터는 **새로 만든 페이지만** 잡고, 기존 페이지 수정은 놓칩니다. 따라서 **timestamp 기반 전략**을 사용합니다:

1. **데이터베이스 검색** — `intern_db_collection` 설정 시, DB를 조회하고 `timestamp` 필드(= 마지막 수정 시간)로 필터링
2. **하위 페이지 검색** — `notion_page` ID가 있는 멤버는 해당 페이지 트리 내부를 `page_url` 파라미터로 탐색
3. **사용자 기반 검색** — `created_by_user_ids`로 워크스페이스 전체를 검색 후, 수정 시간으로 필터링

이 조합으로 신규 페이지와 기존 페이지 수정 모두를 감지합니다.

## 프로젝트 구조

```
notion-team-dashboard/
├── generate_dashboard.sh            # 메인 스크립트 — 프롬프트 생성 후 Claude 실행
├── config.example.json              # 설정 템플릿 (config.json으로 복사)
├── config.json                      # 내 설정 (gitignore됨)
├── com.notion-team-dashboard.plist  # macOS 스케줄러 템플릿
├── docs/                            # GitHub Pages 웹사이트
├── example/dashboard-demo.html      # 데모 대시보드 (샘플 데이터)
├── LICENSE                          # MIT
└── .gitignore
```

## 문제 해결

### "Invalid API key" 오류
- Claude Code MCP 설정의 Notion 토큰 확인
- 토큰이 `ntn_`으로 시작하는지 확인
- [notion.so/my-integrations](https://www.notion.so/my-integrations)에서 Integration이 활성 상태인지 확인

### 특정 멤버의 활동이 감지되지 않음
- 해당 멤버의 페이지가 **Integration과 공유**되어 있는지 확인 (2단계)
- config의 `notion_page` ID가 정확한지 확인
- 수동 검색: `claude -p "notion-search로 '홍길동' 검색해줘"`

### Claude CLI를 찾을 수 없음
- Claude Code 설치: [claude.com/claude-code](https://claude.com/claude-code)
- `claude`가 PATH에 있는지 확인

### 대시보드가 비어있거나 내용이 적음
- Integration은 명시적으로 공유된 페이지만 접근 가능
- 최상위 워크스페이스 페이지나 팀 페이지를 Integration과 공유하세요

## 라이선스

MIT — [LICENSE](LICENSE) 참조
