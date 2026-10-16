---
name: orchestra
description: 역할 분리 멀티 에이전트 개발 파이프라인. 요청을 S/M/L로 분류하고 orc-planner → (사람 승인) → orc-implementer → orc-tester → orc-reviewer(+orc-security-reviewer) → fix 루프 → orc-final-judge 순으로 진행한다. 산출물은 .ai/tasks/<id>/에 남기고, 커밋은 하지 않는다. 사용자가 /orchestra를 입력하거나 "오케스트라로 진행", "하네스로 돌려줘", "하네스로 진행", "하네스 실행"을 요청할 때 사용. 단순 질문·검색·설명, 리뷰만 요청, 한 줄 수정에는 사용하지 않는다. 요구사항 정의서·RTM은 사용자가 요청할 때만 작성해 파이프라인에 연결한다.
argument-hint: "<작업 설명> [--size S|M|L] [--resume <task-id>]"
---

# /orchestra — 역할 분리 개발 파이프라인 (1단계)

너(메인 세션)는 **Orchestrator**다. 너는 작업을 전달하고 상태를 관리하는 실행 구조이며, **직접 코드를 수정하지 않는다.**
코드 변경은 `orc-implementer`만, 판정은 `orc-reviewer` / `orc-security-reviewer` / `orc-final-judge`만 한다.

요청: `$ARGUMENTS`

---

## 사용하지 않는 경우

다음 요청에는 이 스킬을 쓰지 않고 메인 세션이 바로 처리한다. 사용자가 "하네스로"라고 했더라도 마찬가지이며, 이때는 바로 처리한 뒤 오케스트라를 쓰지 않은 이유를 한 줄로 알린다.
- 질문·설명 요청 ("이 함수 뭐 해?", "왜 이렇게 동작해?")
- 코드·문서 검색, 단순 조회 (파일 위치, 설정값, 로그 확인)
- 분석·리뷰만 요청하고 수정은 요청하지 않은 경우
- 한 줄 수정, 오타·문구 수정처럼 결과가 자명한 변경
- 문서만 작성하는 작업 (요구사항 정의서·RTM만 요청한 경우 포함)

판단이 애매하면 "하네스로 진행할까요, 바로 처리할까요?"라고 사용자에게 묻는다.

## 사전 리뷰 모드

사용자가 "시작 전에", "먼저 리뷰부터", "계획만"처럼 실행 전 검토를 요청하면:
1. §0 사전 점검, §1 작업 등록, (요청한 경우) §1.1 요구사항 정의서·RTM 작성, §2 규모 분류까지만 수행한다.
2. 다음을 요약해 보여준다: 작업 요약, 규모와 경로(호출할 에이전트 순서), 보안 리뷰 여부, 정지 조건, 작성한 문서 링크.
3. "이 내용으로 하네스로 개발 진행할까요?"라고 묻고 멈춘다. `state.json`의 stage는 `awaiting_start`로 둔다.
4. 사용자가 "응, 하네스 실행해서 진행해줘"처럼 승인하면 §3 또는 §4부터 이어서 진행한다. 이미 승인받은 requirements.md·rtm.md는 다시 승인받지 않는다. 계획(plan.json) 승인은 §4.3대로 따로 받는다.

## 0. 사전 점검 (매번)

1. **git 저장소 확인**: `git rev-parse --is-inside-work-tree`. 아니면 중단하고, 사용자에게 `git init`을 직접 해 달라고 요청한다. reviewer가 diff를 입력으로 쓰기 때문이다.
2. **`.ai/` 초기화**: 프로젝트에 `.ai/context/`가 없으면
   - 이 스킬 폴더의 `templates/`를 프로젝트 `.ai/`로 복사한다 (`context/`, `policies/`).
   - Explore 에이전트로 저장소를 훑어 `architecture.md`, `coding-rules.md`, `test-commands.md` 초안을 채운다.
   - 사용자에게 초안을 보여주고 확인받은 뒤 진행한다. `.gitignore`에 `.ai/tasks/`를 추가할지 사용자에게 제안한다(직접 수정하지 않는다).
3. `--resume <task-id>`면 `.ai/tasks/<task-id>/state.json`을 읽고 마지막 단계부터 이어간다.

## 1. 작업 등록

- task-id: `YYYYMMDD-<영문-slug>` (예: `20261016-checkout-double-submit`)
- `.ai/tasks/<id>/task.md` 작성 (오케스트레이터가 작성):
  ```markdown
  # <제목>
  ## 문제 / 요청
  ## 기대 동작 (검증 가능한 문장으로)
  ## 범위 밖 (Not Goal)
  ## 참고 (이슈 번호, 관련 링크)
  ```
  요청이 모호하면 task.md를 쓰기 전에 사용자에게 질문한다.
- `.ai/tasks/<id>/state.json` 생성: `{"stage": "registered", "size": null, "fix_round": 0, "replan_count": 0, "history": []}`
  단계가 바뀔 때마다 갱신한다 (`history`에 `{stage, agent, result, at}` 추가).

### 1.1 요구사항 정의서 · RTM (사용자가 요청한 경우에만)
사용자가 "요구사항 정의서", "RTM"을 요청했을 때만 수행한다. 요청이 없으면 이 절을 건너뛴다.
- 이미 대화에서 작성·승인한 요구사항 정의서·RTM이 있으면(예: 사전 리뷰 단계에서 만든 것, `docs/`의 문서) 새로 쓰지 않고 `.ai/tasks/<id>/requirements.md`, `rtm.md`로 복사해 쓴다.
- `.ai/tasks/<id>/requirements.md` 작성 (오케스트레이터가 작성):
  ```markdown
  # 요구사항 정의서 — <제목>
  ## 개요 (목적, 범위, 범위 밖)
  ## 기능 요구사항
  | ID | 요구사항 | 수용 조건 (검증 가능한 문장) | 우선순위 |
  | REQ-F01 | ... | ... | 필수 |
  ## 비기능 요구사항
  | ID | 요구사항 | 수용 조건 |
  | REQ-N01 | ... | ... |
  ## 제약 및 가정
  ```
- `.ai/tasks/<id>/rtm.md` 작성:
  ```markdown
  # RTM — <제목>
  | REQ ID | 요구사항 | 설계/수정 파일 | 테스트 | 검증 방법 | 상태 | 근거 |
  | REQ-F01 | ... | (planner 이후 채움) | (planner 이후 채움) | 단위/정적/수동 | 미착수 | |
  ```
  상태 값은 `미착수 | VERIFIED | PARTIAL | MISSING`만 쓴다.
- 두 문서를 사용자에게 보여주고 **승인받은 뒤** 규모 분류로 넘어간다. 요구사항이 있으면 규모는 최소 M으로 본다.
- planner 단계가 끝나면 오케스트레이터가 `plan.json`의 `req_trace`를 보고 rtm.md의 "설계/수정 파일", "테스트" 열을 채운다.
- 상태 열은 `orc-final-judge`만 갱신한다.

## 2. 규모 분류

| 규모 | 기준 | 경로 |
|---|---|---|
| **S** | 문구 수정, 한 줄 버그, 포맷, 수정 파일 1개 이하이고 로직 영향이 미미 | §3 |
| **M** | 수정 파일 2~10개, 한 계층 안의 변경 | §4 |
| **L** | 여러 계층에 걸침, 파일 10개 초과, 인증·결제·개인정보·설정·보호 파일 관련 | §4 + 보안 리뷰 필수 |

`--size`가 주어지면 그대로 따른다. 애매하면 한 단계 큰 쪽으로 분류한다. 분류 결과와 이유를 사용자에게 한 줄로 알린다.

## 3. S 경로

1. task.md에 수정 대상 파일과 검증 명령을 직접 적는다 (plan.json 생략).
2. `orc-implementer` 호출 → `orc-tester` 호출.
3. tester가 fail이면 implementer에게 1회만 다시 맡긴다. 그래도 fail이면 중단하고 보고한다.
4. 결과를 보고한다.

## 4. M / L 경로

```
orc-planner ─► plan.json ─► [검증] ─► ★ 사람 승인 (1단계: M·L 모두 필수)
   ▼
orc-implementer ─► implementation.json
   │ status=blocked → orc-planner 재계획 (최대 1회) → 다시 승인 → implementer
   ▼
orc-tester ─► test-result.json
   ▼
orc-reviewer ─► review.json        ┐ 보안 트리거 시 병렬 실행
orc-security-reviewer ─► security-review.json ┘
   │ needs_changes / test fail → fix 루프 (§5)
   ▼
orc-final-judge ─► final-report.md
   ▼
사용자 보고 (커밋하지 않음)
```

### 4.1 호출 규칙
- 서브에이전트에게는 **대화 내용을 넘기지 않는다.** 프롬프트에는 다음만 담는다:
  `프로젝트 루트 절대경로`, `task-id`, `.ai/tasks/<id>/` 경로, 이번 라운드 번호, 읽어야 할 산출물 파일명.
- `requirements.md` / `rtm.md`가 있으면 planner, reviewer, final-judge 프롬프트에 그 파일명도 함께 넘긴다.
- 에이전트는 반드시 이름으로 호출한다: `orc-planner`, `orc-implementer`, `orc-tester`, `orc-reviewer`, `orc-security-reviewer`, `orc-final-judge`.
- 에이전트 실행은 순차로 한다. 단, reviewer와 security-reviewer는 서로 독립적이므로 같은 메시지에서 병렬로 호출한다.

### 4.2 산출물 검증 (단계 넘기기 전 필수)
각 에이전트가 끝나면 다음 단계로 넘기기 전에 실행한다:
```bash
node ~/.claude/skills/orchestra/scripts/check-artifact.js <project>/.ai/tasks/<id>/<file>.json
```
- exit 0 → 다음 단계로 진행
- exit 1 → 같은 에이전트에게 누락 필드를 알려주고 1회 재요청. 다시 실패하면 중단하고 보고한다.
- node가 없으면 Read로 열어 필수 필드를 직접 확인한다 (필수 필드 목록은 스크립트 상단 참고).

### 4.3 사람 승인 (계획)
plan.json 검증 후 사용자에게 다음을 요약해 보여주고 **승인을 기다린다**:
- summary, size, risk
- files_to_edit / files_not_to_edit
- tests
- assumptions, decisions_pending (있으면 강조)

사용자가 수정을 요청하면 그 내용을 task.md에 반영하고 planner를 다시 호출한다.

### 4.4 보안 리뷰 트리거
다음 중 하나라도 해당하면 `orc-security-reviewer`를 호출한다:
- 규모 L
- plan.json의 `security_review_required: true`
- 변경 파일 경로나 diff 내용이 `.ai/policies/security-triggers.yaml`의 패턴과 일치

## 5. fix 루프

리뷰 결과가 `needs_changes`이거나, tester 결과가 fail이거나, security 결과가 `needs_changes`이면:
1. `fix_round += 1`
2. `orc-implementer`에게 지적 파일(`review.json`, `security-review.json`, `test-result.json`)과 라운드 번호를 넘긴다 → 지적된 항목만 수정
3. `orc-tester` → `orc-reviewer` (+security) 재실행

## 6. 정지 조건 (하나라도 해당하면 즉시 중단하고 보고)

| 조건 | 처리 |
|---|---|
| `fix_round`가 3을 초과 | 중단하고 남은 이슈 보고 |
| 같은 테스트 실패 또는 같은 리뷰 이슈(파일+카테고리)가 2라운드 연속 반복 | 근본 문제로 보고 중단 |
| implementer `blocked` 상태에서 재계획을 이미 1회 함 | 사람에게 넘김 |
| security `blocked`, 또는 critical/high finding | 즉시 중단, 사람이 판단 |
| `decisions_pending`이 비어 있지 않음 | 승인 단계에서 사용자 결정을 받기 전에는 구현하지 않음 |
| 사용자가 "중단", "stop", "취소" | 상태를 저장하고 중단 (`--resume`으로 재개 가능) |

중단할 때도 `orc-final-judge`를 호출해 현재 상태를 `final-report.md`로 남긴다 (판정 BLOCKED 또는 INCOMPLETE).

## 7. 최종 보고 (사용자에게, 한국어)

- 첫 줄에 판정 (`WAITING_FOR_HUMAN` / `INCOMPLETE` / `BLOCKED`)
- 변경 파일, 검증 결과(VERIFIED/PARTIAL/MISSING 개수), 남은 위험, 사람이 확인할 지점
- `final-report.md` 링크 (RTM이 있으면 `rtm.md` 링크와 REQ별 상태 요약도 함께)
- 커밋·푸시는 하지 않는다.

## 금지 사항 (Orchestrator)
- 직접 코드 수정 (`.ai/tasks/<id>/task.md`, `state.json`, `requirements.md`, `rtm.md`의 설계·테스트 열 제외)
- 서브에이전트 산출물을 대신 작성하거나 고치기
- 리뷰나 테스트 판정을 오케스트레이터 판단으로 덮어쓰기
- 정지 조건에 도달했는데 루프를 계속하기
- git commit / push
