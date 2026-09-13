#!/bin/bash
# Install the Deck Claude Console into $HOME. Nothing here touches /usr, so a
# SteamOS update cannot wipe it - only the packages it depends on.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

missing=()
python3 -c 'import gi; gi.require_version("Vte","3.91")' 2>/dev/null || missing+=(vte4 python-gobject)
command -v tmux >/dev/null || missing+=(tmux)
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing packages: ${missing[*]}"
    echo "On SteamOS:"
    echo "  sudo steamos-readonly disable"
    echo "  sudo pacman -Sy --needed ${missing[*]}"
    echo "  sudo steamos-readonly enable   # optional; it re-locks on update anyway"
    echo
    echo "Continuing - the console falls back to the xterm version without VTE."
fi

install -d "$HOME/.local/bin" "$HOME/.config/tmux" "$HOME/.claude"
install -m 755 "$here"/bin/* "$HOME/.local/bin/"
install -m 644 "$here/config/tmux/deck.conf" "$HOME/.config/tmux/deck.conf"

# Key bindings are merged, never overwritten: people have their own.
python3 - "$here/config/claude/keybindings.json" "$HOME/.claude/keybindings.json" <<'PY'
import json, sys, os
src, dst = sys.argv[1], sys.argv[2]
new = json.load(open(src))
if os.path.exists(dst):
    cur = json.load(open(dst))
    by_ctx = {b["context"]: b for b in cur.get("bindings", [])}
    for block in new["bindings"]:
        ctx = block["context"]
        if ctx in by_ctx:
            # keep whatever the user already bound
            merged = dict(block["bindings"])
            merged.update(by_ctx[ctx].get("bindings", {}))
            by_ctx[ctx]["bindings"] = merged
        else:
            cur.setdefault("bindings", []).append(block)
    cur.setdefault("$schema", new.get("$schema"))
    json.dump(cur, open(dst, "w"), indent=2, ensure_ascii=False)
    print("merged into", dst)
else:
    json.dump(new, open(dst, "w"), indent=2, ensure_ascii=False)
    print("wrote", dst)
PY

cat <<'EOF'

Installed. Two things are left to you:

  1. In ~/.claude/settings.json, set the voice mode and the Stop hook - see the
     "Settings this expects" section of the README. `hold` is not optional.

  2. Run `deckclaude`. For Game Mode, add ~/.local/bin/deckclaude to Steam as a
     non-Steam game.

Spoken replies need Piper in its own venv; `bin/decksay` has the paths, and
`decktts on|off|auto` switches it (auto = Game Mode only).
EOF
