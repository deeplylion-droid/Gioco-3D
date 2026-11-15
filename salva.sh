#!/bin/bash
# Salva questa cartella sul branch orfano lavoro/coordinatore del repository (solo questi file, nessun workflow).
# Uso: bash /home/user/coordinatore/salva.sh "messaggio"
set -e
REPO=/home/user/Gioco-3D
DIR=/home/user/coordinatore
MSG="${1:-Registro del coordinatore}"
IDX=$(mktemp)
rm -f "$IDX"
export GIT_INDEX_FILE="$IDX"
git -C "$REPO" --work-tree="$DIR" add -A . >/dev/null
ALBERO=$(git -C "$REPO" write-tree)
unset GIT_INDEX_FILE
rm -f "$IDX"
PADRE=$(git -C "$REPO" rev-parse -q --verify refs/remotes/origin/lavoro/coordinatore || true)
if [ -n "$PADRE" ] && [ "$(git -C "$REPO" rev-parse "$PADRE^{tree}")" = "$ALBERO" ]; then echo "niente di nuovo"; exit 0; fi
CODA=$'\n\nCo-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Ub9Z8mJaiFbdfRfYi8QhGz'
if [ -n "$PADRE" ]; then SHA=$(printf '%s%s\n' "[skip ci] $MSG" "$CODA" | git -C "$REPO" commit-tree "$ALBERO" -p "$PADRE" -F -); else SHA=$(printf '%s%s\n' "[skip ci] $MSG" "$CODA" | git -C "$REPO" commit-tree "$ALBERO" -F -); fi
for i in 1 2 3 4; do
  if git -C "$REPO" push -q origin "$SHA:refs/heads/lavoro/coordinatore"; then git -C "$REPO" update-ref refs/remotes/origin/lavoro/coordinatore "$SHA"; echo "salvato $SHA"; exit 0; fi
  sleep $((i * 15))
done
echo "push fallito"; exit 1
