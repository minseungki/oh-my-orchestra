#!/usr/bin/env bash
# 이 PC의 ~/.claude 에서 수정한 내용을 저장소(claude/)로 가져온다 (macOS / Linux). export.ps1 과 같은 동작.
#
# 저장소에 이미 있는 항목만 가져온다 (관리 대상 = 저장소에 있는 파일).
# - claude/CLAUDE.oh-my-orchestra.md (~/.claude/CLAUDE.md 는 PC별 규칙이라 가져오지 않는다)
# - claude/agents/ 에 있는 파일
# - claude/skills/ 에 있는 폴더
# - claude/settings.json 의 최상위 키 (값을 이 PC 기준으로 갱신, node 필요)
# 새 에이전트·스킬을 관리 대상에 추가하려면 claude/ 아래에 같은 이름으로 먼저 복사해 둔다.
# 끝나면 git diff 로 변경을 확인한 뒤 직접 커밋한다.
#
# 사용법:
#   bash export.sh
#   bash export.sh --claude-home <폴더>

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CLAUDE="$REPO_DIR/claude"
CLAUDE_HOME="$HOME/.claude"

while [ $# -gt 0 ]; do
    case "$1" in
        --claude-home) shift; CLAUDE_HOME="$1" ;;
        *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
    esac
    shift
done

pull_item() {
    local rel="$1"
    local src="$CLAUDE_HOME/$rel"
    local dest="$REPO_CLAUDE/$rel"
    if [ ! -e "$src" ]; then
        echo "  [없음] $rel (이 PC에 없어 건너뜀)"
        return 0
    fi
    if [ -d "$src" ]; then
        # 저장소 claude/skills/ 아래 폴더만 교체한다
        case "$dest" in
            "$REPO_CLAUDE"/skills/?*) ;;
            *) echo "  [중단] 예상 밖 경로: $dest" >&2; exit 1 ;;
        esac
        rm -r "$dest"
        mkdir -p "$dest"
        cp -R "$src/." "$dest/"
    else
        cp "$src" "$dest"
    fi
    echo "  [가져옴] $rel"
}

echo "oh-my-orchestra 내보내기: $CLAUDE_HOME → $REPO_CLAUDE"

pull_item 'CLAUDE.oh-my-orchestra.md'
for f in "$REPO_CLAUDE"/agents/*; do
    [ -f "$f" ] || continue
    pull_item "agents/$(basename "$f")"
done
for d in "$REPO_CLAUDE"/skills/*/; do
    d="${d%/}"
    pull_item "skills/$(basename "$d")"
done

if [ -f "$CLAUDE_HOME/settings.json" ]; then
    if ! command -v node >/dev/null 2>&1; then
        echo "  [건너뜀] settings.json (node가 없음)"
    else
        node -e '
            const fs = require("fs");
            const [repoPath, localPath] = process.argv.slice(1);
            const repo = JSON.parse(fs.readFileSync(repoPath, "utf8"));
            const local = JSON.parse(fs.readFileSync(localPath, "utf8").replace(/^﻿/, ""));
            for (const k of Object.keys(repo)) {
                if (k in local) repo[k] = local[k];
            }
            fs.writeFileSync(repoPath, JSON.stringify(repo, null, 2) + "\n");
        ' "$REPO_CLAUDE/settings.json" "$CLAUDE_HOME/settings.json"
        echo "  [갱신] settings.json (관리 키만)"
    fi
fi

echo "완료. git diff 로 변경을 확인한 뒤 커밋하세요."
