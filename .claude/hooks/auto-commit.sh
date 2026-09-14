#!/usr/bin/env bash
#
# Stop hook: sweep up anything left uncommitted when a turn ends, then push.
#
# It does NOT replace deliberate commits. When the turn already ended in a real
# commit the tree is clean, this finds nothing to do, and it only pushes. The
# generic message below is a safety net for work that would otherwise sit
# uncommitted - it is not meant to be how this repo normally gets its history,
# and a run of these in the log means commits are being left unwritten.
#
# Never fails the turn: every path exits 0.

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

note=""

#--- Anything uncommitted? Tracked edits, or untracked files not gitignored.
if ! git diff --quiet HEAD 2>/dev/null \
   || [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then

   git add -A 2>/dev/null || exit 0

   if git commit -q -F - <<'MSG' 2>/dev/null
Sweep up uncommitted session changes

Left behind by a session that ended without an explicit commit. Written
by the auto-commit Stop hook, so this message is generic by construction
- see .claude/hooks/auto-commit.sh. If these are piling up in the log,
the commits that should have been written by hand are not being written.
MSG
   then
      note="committed"
   fi
fi

#--- Push only when there is an upstream and something unpushed to send.
if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
   if [ -n "$(git log --oneline "$up"..HEAD 2>/dev/null)" ]; then
      if git push -q 2>/dev/null; then
         note="${note:+$note, }pushed"
      else
         note="${note:+$note, }PUSH FAILED - push by hand"
      fi
   fi
else
   [ -n "$note" ] && note="$note (no upstream - not pushed)"
fi

[ -n "$note" ] && printf '{"systemMessage":"auto-commit: %s"}\n' "$note"
exit 0
