# oh-my-orchestra

Claude Code 개인 설정 묶음. 역할을 나눈 멀티 에이전트 개발 파이프라인(`/orchestra`), 전역 지침, 차단 규칙을 여러 PC에 똑같이 설치한다.

## 포함 내용

| 경로 | 설치 위치 | 내용 |
|---|---|---|
| `claude/CLAUDE.oh-my-orchestra.md` | `~/.claude/CLAUDE.oh-my-orchestra.md` | 공통 지침 (작업 원칙, 코드 스타일, 스킬, 한국어 출력, 행동 원칙). `~/.claude/CLAUDE.md`에 import 줄만 추가 |
| `claude/agents/orc-*.md` | `~/.claude/agents/` | 오케스트라 에이전트 6개 |
| `claude/skills/orchestra/` | `~/.claude/skills/orchestra/` | `/orchestra` 스킬, 산출물 검사 스크립트, `.ai/` 템플릿 |
| `claude/skills/design-taste-frontend/` | `~/.claude/skills/design-taste-frontend/` | UI 작업용 스킬 (출처: [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill)) |
| `claude/settings.json` | `~/.claude/settings.json`에 **병합** | 차단 규칙(`permissions.deny`), 플러그인, 언어 등 |

### 에이전트

| 이름 | 모델 | 코드 수정 | 역할 |
|---|---|---|---|
| `orc-planner` | opus | 불가 | 계획 수립 → `plan.json` |
| `orc-implementer` | sonnet | 가능 | 계획에서 승인된 파일만 수정 |
| `orc-tester` | sonnet | 불가 | 테스트 직접 실행으로 증명 |
| `orc-reviewer` | opus | 불가 | 실제 diff만 보고 검토 |
| `orc-security-reviewer` | opus | 불가 | 보안 관련 작업일 때만 호출 |
| `orc-final-judge` | opus | 불가 | 테스트 재실행 후 최종 판정 |

## 설치 (새 PC)

설치하면 clone한 폴더가 아니라 **사용자 전역 폴더(`~/.claude`)**에 복사되므로, 그 PC의 모든 프로젝트에 적용된다. clone한 폴더는 원본 보관용이다.

전제: Claude Code 설치 및 로그인 완료. Node.js (맥 설치 스크립트의 settings 병합, `/orchestra` 검사 스크립트에 필요).

### Windows (PowerShell)
```powershell
git clone https://github.com/minseungki/oh-my-orchestra.git $HOME\dev\00_oh-my-orchestra
cd $HOME\dev\00_oh-my-orchestra
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun   # 무엇이 바뀌는지 미리 보기
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### macOS / Linux (bash)
```bash
git clone https://github.com/minseungki/oh-my-orchestra.git ~/dev/00_oh-my-orchestra
cd ~/dev/00_oh-my-orchestra
bash install.sh --dry-run   # 무엇이 바뀌는지 미리 보기
bash install.sh
```

두 스크립트는 같은 동작을 한다.

- `~/.claude/CLAUDE.md`는 덮어쓰지 않는다. 끝에 `@~/.claude/CLAUDE.oh-my-orchestra.md` 한 줄만 추가한다(이미 있으면 그대로 둔다). 회사 브랜치·커밋 규칙처럼 PC마다 다른 규칙은 `~/.claude/CLAUDE.md`에 직접 둔다.
- 덮어쓰기 전에 기존 파일을 `~/.claude/backups/oh-my-orchestra-<날짜시간>/`에 백업한다.
- `settings.json`은 덮어쓰지 않고 병합한다. 객체는 재귀 병합, 배열은 합집합, 값은 저장소 쪽이 우선이다.
- 링크로 연결된 기존 스킬 폴더(예: `npx skills`로 설치한 것)는 건드리지 않는다.
- 설치 후 Claude Code를 다시 시작한다. 처음 실행할 때 플러그인(`ui-ux-pro-max`, `impeccable`) 설치를 묻는 안내가 뜨면 승인한다.

## 업데이트

| 상황 | 방법 |
|---|---|
| 다른 PC에서 바뀐 내용을 받기 | `git pull` → `install.ps1` (맥: `bash install.sh`) |
| 이 PC에서 바꾼 내용을 올리기 | `export.ps1` (맥: `bash export.sh`) → `git diff` 확인 → 커밋·푸시 |

내보내기 스크립트는 저장소에 이미 있는 항목만 가져온다. 새 에이전트나 스킬을 관리 대상에 넣으려면 `claude/` 아래에 먼저 복사해 둔다.

## 옮기지 않는 것
`~/.claude/CLAUDE.md`(PC별 규칙), `.credentials.json`(로그인 정보), `history.jsonl`, `projects/`(프로젝트별 메모리), `sessions/`, `cache/`

## 사용법 요약
- `/orchestra <작업 설명>` 또는 "하네스로 돌려줘"
- git 저장소인 프로젝트에서만 동작한다. 처음 쓰는 프로젝트에는 `.ai/context`, `.ai/policies`가 만들어진다.
- 요구사항 정의서·RTM은 요청할 때만 만들어 파이프라인에 연결한다.
- 커밋·푸시는 하지 않는다 (`git commit`/`git push`는 `permissions.deny`로 차단됨).
