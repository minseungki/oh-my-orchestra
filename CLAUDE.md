# oh-my-orchestra 저장소 작업 규칙

## 회사 PC(현재 작업 PC)에서의 사용
- 이 PC의 `~/.claude`에는 회사 규칙(커밋 메시지 형식, `MEDIAADI2-` 브랜치 확인 등)이 들어간 별도 버전이 설치되어 있다. 이 저장소는 다른 PC 배포용이다.
- 이 PC에서는 `install.ps1`, `export.ps1`을 **실행하지 않는다.**
  - `install.ps1` 실행 시: 이 PC의 orc 에이전트·스킬이 저장소 버전으로 바뀌어 제안 커밋 메시지 기능이 사라진다.
  - `export.ps1` 실행 시: 이 PC의 회사 버전 내용(제안 커밋 메시지 등)이 저장소로 들어온다.
- 저장소 내용을 바꿀 때는 이 폴더의 파일(`claude/` 아래)을 **직접 수정**한다.
- 저장소에는 회사 전용 규칙(커밋 메시지 형식, 지라번호, `MEDIAADI2-` 브랜치 규칙)을 넣지 않는다.

## 파일 수정 시 주의
- `install.ps1`, `export.ps1`은 **UTF-8 BOM + CRLF**로 저장한다. BOM이 없으면 Windows PowerShell 5.1에서 한글이 깨진다.
- 스크립트를 고친 뒤에는 실제 `~/.claude`가 아닌 임시 폴더로 확인한다:
  `powershell -ExecutionPolicy Bypass -File .\install.ps1 -ClaudeHome $env:TEMP\omo-test`
