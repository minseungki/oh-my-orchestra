#!/usr/bin/env bash
# oh-my-orchestra 설정을 ~/.claude 에 설치한다 (macOS / Linux). install.ps1 과 같은 동작.
#
# - claude/CLAUDE.oh-my-orchestra.md, claude/agents/*, claude/skills/* 를 ~/.claude 로 복사한다 (덮어쓰기 전 백업).
# - ~/.claude/CLAUDE.md 는 덮어쓰지 않는다. import 줄(@~/.claude/CLAUDE.oh-my-orchestra.md)이 없을 때만 끝에 추가한다.
# - claude/settings.json 은 기존 ~/.claude/settings.json 에 병합한다 (node 필요).
#   객체는 재귀 병합, 배열은 합집합(중복 제거), 값은 저장소 쪽이 우선한다.
# - 링크(심볼릭 링크)로 되어 있는 기존 스킬 폴더는 건드리지 않는다.
#
# 사용법:
#   bash install.sh              설치
#   bash install.sh --dry-run    무엇을 할지만 출력
#   bash install.sh --claude-home <폴더>   설치 대상 변경 (기본: ~/.claude)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CLAUDE="$REPO_DIR/claude"
CLAUDE_HOME="$HOME/.claude"
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --claude-home) shift; CLAUDE_HOME="$1" ;;
        *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
    esac
    shift
done

if ! command -v node >/dev/null 2>&1; then
    echo "node가 필요합니다 (settings.json 병합, /orchestra 검사 스크립트). Node.js를 설치한 뒤 다시 실행하세요." >&2
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CLAUDE_HOME/backups/oh-my-orchestra-$STAMP"
IMPORT_LINE='@~/.claude/CLAUDE.oh-my-orchestra.md'

step() { echo "  $1"; }

backup_item() {
    local target="$1"
    [ -e "$target" ] || return 0
    local rel="${target#"$CLAUDE_HOME"/}"
    if [ "$DRY_RUN" -eq 1 ]; then step "[백업 예정] $rel"; return 0; fi
    mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    cp -R "$target" "$BACKUP_DIR/$rel"
}

copy_managed() {
    local src="$1" dest="$2"
    local rel="${dest#"$CLAUDE_HOME"/}"
    if [ -L "$dest" ]; then
        step "[건너뜀] $rel (링크로 연결된 폴더라 그대로 둠)"
        return 0
    fi
    backup_item "$dest"
    if [ "$DRY_RUN" -eq 1 ]; then step "[복사 예정] $rel"; return 0; fi
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        cp -R "$src/." "$dest/"
    else
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
    step "[복사] $rel"
}

install_claude_md_import() {
    local dest="$CLAUDE_HOME/CLAUDE.md"
    if [ -f "$dest" ] && grep -qF "$IMPORT_LINE" "$dest"; then
        step "[유지] CLAUDE.md (import 줄 이미 있음)"
        return 0
    fi
    backup_item "$dest"
    if [ "$DRY_RUN" -eq 1 ]; then step "[추가 예정] CLAUDE.md 끝에 $IMPORT_LINE"; return 0; fi
    if [ -s "$dest" ] && [ -n "$(tail -c 1 "$dest")" ]; then
        printf '\n' >> "$dest"
    fi
    printf '\n# oh-my-orchestra 공통 지침\n%s\n' "$IMPORT_LINE" >> "$dest"
    step "[추가] CLAUDE.md 끝에 $IMPORT_LINE"
}

install_settings() {
    local src="$REPO_CLAUDE/settings.json"
    local dest="$CLAUDE_HOME/settings.json"
    local merged
    merged="$(node -e '
        const fs = require("fs");
        const [patchPath, basePath] = process.argv.slice(1);
        const patch = JSON.parse(fs.readFileSync(patchPath, "utf8"));
        let base = {};
        if (fs.existsSync(basePath)) {
            const text = fs.readFileSync(basePath, "utf8").replace(/^﻿/, "");
            base = text.trim() ? JSON.parse(text) : {};
        }
        const isObj = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
        function merge(b, p) {
            for (const [k, pv] of Object.entries(p)) {
                const bv = b[k];
                if (isObj(bv) && isObj(pv)) {
                    merge(bv, pv);
                } else if (Array.isArray(bv) && Array.isArray(pv)) {
                    const seen = new Set(bv.map((x) => JSON.stringify(x)));
                    for (const x of pv) {
                        if (!seen.has(JSON.stringify(x))) { bv.push(x); seen.add(JSON.stringify(x)); }
                    }
                } else {
                    b[k] = pv;
                }
            }
            return b;
        }
        process.stdout.write(JSON.stringify(merge(base, patch), null, 2) + "\n");
    ' "$src" "$dest")"
    backup_item "$dest"
    if [ "$DRY_RUN" -eq 1 ]; then step "[병합 예정] settings.json"; return 0; fi
    printf '%s' "$merged" > "$dest"
    step "[병합] settings.json"
}

# ---- 실행 ----
if [ "$DRY_RUN" -eq 1 ]; then
    echo "oh-my-orchestra 설치 → $CLAUDE_HOME (DryRun)"
else
    echo "oh-my-orchestra 설치 → $CLAUDE_HOME"
    mkdir -p "$CLAUDE_HOME"
fi

copy_managed "$REPO_CLAUDE/CLAUDE.oh-my-orchestra.md" "$CLAUDE_HOME/CLAUDE.oh-my-orchestra.md"
install_claude_md_import

for f in "$REPO_CLAUDE"/agents/*; do
    [ -f "$f" ] || continue
    copy_managed "$f" "$CLAUDE_HOME/agents/$(basename "$f")"
done

for d in "$REPO_CLAUDE"/skills/*/; do
    d="${d%/}"
    copy_managed "$d" "$CLAUDE_HOME/skills/$(basename "$d")"
done

install_settings

if [ "$DRY_RUN" -eq 0 ] && [ -d "$BACKUP_DIR" ]; then
    echo "기존 파일 백업: $BACKUP_DIR"
fi
echo "완료. 실행 중인 Claude Code 세션은 다시 시작해야 새 에이전트와 설정이 적용됩니다."
