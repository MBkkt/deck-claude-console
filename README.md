# Deck Claude Console

Claude Code on a Steam Deck, usable with no keyboard at all — one window with a
real terminal in it and a row of touch buttons underneath, plus voice dictation
and spoken replies.

```
[ ⌘ Commands ] [ ▼ ] [ ▲ ] [ 📋 Paste ] [ ⌫ Word ] [ 🎙 Hold to talk ]
```

Built on SteamOS (KDE, Wayland session) for a Deck with no keyboard attached,
where the only input is the touchscreen, the gamepad and your voice.

## What it is

`deckconsole-vte` is a GTK4 window containing a VTE terminal running Claude Code,
with a touch bar underneath. The buttons write bytes straight into the terminal's
pty — no `xdotool`, no synthetic X events, no window-focus juggling.

* **Voice** — hold the big button to dictate, let go to stop. Uses Claude Code's
  own built-in `/voice`, so there is no extra speech service to install.
* **Spoken replies** — a `Stop` hook speaks Claude's answer with
  [Piper](https://github.com/rhasspy/piper) neural TTS, switching between Russian
  and English voices based on the text. Off by default on the desktop, on in Game
  Mode.
* **One pinned conversation** — the console always reopens the same session, so
  closing the window never loses the thread.
* **Survives everything** — Claude runs inside tmux, so closing the console,
  locking the screen or restarting the desktop leaves it (and any background work)
  running. Reopening re-attaches.

## Install

```sh
git clone https://github.com/MBkkt/deck-claude-console
cd deck-claude-console
./install.sh
```

The installer copies the scripts to `~/.local/bin`, the tmux config to
`~/.config/tmux/deck.conf`, and merges the key bindings into
`~/.claude/keybindings.json` (it will not overwrite bindings you already have).

Requirements, all available in the SteamOS repos
(`sudo steamos-readonly disable` first):

```sh
sudo pacman -S vte4 python-gobject tmux
```

Then run `deckclaude`. To have it in Game Mode, add `~/.local/bin/deckclaude` to
Steam as a non-Steam game.

For spoken replies, Piper lives in its own venv — see `bin/decksay` for the paths
it expects, and `decktts on|off|auto` to switch it (`auto` means Game Mode only).

## Settings this expects

In `~/.claude/settings.json`:

```json
{
  "voice": { "enabled": true, "mode": "hold", "autoSubmit": false },
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command",
                           "command": "~/.local/bin/deck-tts-hook",
                           "timeout": 10 }] }]
  }
}
```

`mode: "hold"` matters — see below.

## Things that took a while to learn

Most of these are not obvious, and several cost a whole afternoon.

**Voice must be hold-to-talk.** In tap mode the second tap *is* the send
("REC · tap to send", regardless of `autoSubmit`, which only ever applied to hold
mode), and dictation refuses to start while the prompt already holds text.
Together those make the button feel broken: it either fires off a half-spoken
message or does nothing at all. Hold mode has neither problem — it records on top
of text already in the prompt and appends to it, so "let me say a bit more" is
just another press.

**A terminal cannot report key release**, which is how hold mode normally knows
you let go — it watches the key's auto-repeat instead. There is no real key here,
so the console produces the repeat itself: the same bytes every 100 ms while the
button is held. A quick tap latches it on, so you do not have to keep your thumb
down.

**Never drive Claude with `meta+<letter>`.** Its input editor takes those as
readline commands: `meta+f` walks a word, `meta+d` kills one, and `meta+r`
searches history and drops a previous prompt *into the input box*. A scroll button
bound that way will silently edit what you are typing. Scrolling here uses
Claude's own chord style (`ctrl+x p` / `ctrl+x n` / `ctrl+x u` / `ctrl+x d`).
`meta+k` for voice is the exception, and only because it is explicitly bound.

**Claude's TUI runs on the alternate screen**, so the terminal has no scrollback
of its own — `tmux display-message -p '#{alternate_on}'` says 1 and the history is
empty. Scrolling can only be *asked of Claude*; moving VTE's own adjustment does
nothing at all.

**Slash commands need the `/` on its own.** Sent in one burst, `/model` is
submitted as an ordinary message and Claude just tells you it is a CLI command.
The leading `/` has to arrive as its own keystroke, followed by a pause, which is
what opens the command menu.

**`claude --continue` is a lottery** when a directory has several sessions: it
takes whichever transcript was written to last, which is as easily a background
session or an empty forked stub. The console pins one UUID instead.

**A GTK `application_id` is shared state.** With the default flags, any other
process starting the app reaches the instance already running and asks it to
activate — which opens a second window onto the same session, on top of the
conversation happening in the first. `Gio.ApplicationFlags.NON_UNIQUE` fixes it.

**tmux needs three settings here**, all in `config/tmux/deck.conf`: its prefix
must move off `ctrl+b` (that is Claude's "run this in the background", and the
menu sends it), `escape-time` must be 0 (or ESC+letter is read as a bare Escape),
and the status bar off (it would steal a row).

**`XTerm*selectToClipboard`, `metaSendsEscape`, `-into`** — all of that is in the
older `deckconsole`, which reparents an xterm into a Tk window. It still works and
`deckclaude` falls back to it when VTE is missing, but the VTE version is better
in every way: native selection, touch scrolling, a real clipboard, and no
synthetic input.

## Layout

```
bin/
  deckclaude          launcher - picks the VTE console, falls back to xterm
  deckclaude-xterm    forces the old xterm console
  deckconsole-vte     the console: GTK4 + VTE 0.84 + touch bar
  deckconsole         the older xterm-in-Tk console (fallback)
  decksay             speak text with Piper, picking ru/en from the text
  decktts             on | off | auto  (auto = Game Mode only)
  deck-tts-hook       Stop hook: speaks the last assistant reply
config/
  tmux/deck.conf      tmux tuned to be invisible
  claude/keybindings.json
```

## Licence

MIT — see [LICENSE](LICENSE).
