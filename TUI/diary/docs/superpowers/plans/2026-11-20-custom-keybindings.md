# Individual Emacs and Helix bindings

Follow-up requirement: edit each keymap's individual bindings inside the existing
settings screen and persist them in `~/.ada_tui_diary/config.toml`.

## Design and implementation

- A shared action catalogue in `Diary_Bindings` describes calendar, Emacs editing,
  Helix Normal/Select and Helix Insert actions. A key sequence contains up to four
  normalized terminal events. Each supported action has one configurable sequence;
  an empty sequence disables it.
- Use the existing editing implementation by resolving a configured sequence to
  an action and delivering that action's canonical events directly. Canonical
  replay bypasses remapping, preventing recursive mappings and cycles. Prompt,
  confirmation and settings controls, find targets and Helix counts retain their
  existing input semantics.
- Replaced defaults and legacy aliases are suppressed. Explicit custom matches
  take precedence over aliases. Arrow keys may therefore be assigned explicitly.
- Validate duplicates and prefix collisions only in overlapping input contexts.
  Normalize terminal-equivalent C-h/Backspace and C-j/C-m/Enter. Reject unsupported
  terminal signal/escape tokens and cancellation keys inside a sequence.
- Keep a separate settings draft for both keymaps. B opens the action list;
  Enter edits key-name text; C-u clears; R restores one action; D restores the
  selected keymap; S saves both maps. Esc backs out, then cancels the entire draft.
  Save failures retain the draft and do not apply runtime changes.
- Extend config with `[bindings.emacs]` and `[bindings.helix]`. Save differences
  from defaults, including explicit empty values. Parse quoted strings/comments,
  reject unknown/duplicate actions, and validate after loading every entry so
  swapped bindings work. Validate the old file before atomic replacement.
- Keep the old `[editor]` format compatible. CLI/environment override the selected
  preset only; custom bindings still load from the config file.

## Validation

- Real PTY scenarios cover UI edits, duplicate rejection, save failure and retry,
  both maps surviving saves, restart, CLI selection, draft cancellation, single
  and whole-map reset, replaced defaults and uppercase aliases, literal hash
  round-trip, and a remapped Helix insert command.
- Presentation tests cover parsing, terminal aliases, collisions, multi-key prefix
  resolution, disabled defaults, aliases, swapped bindings and reserved tokens.
- Config error cases cover unknown actions, duplicate entries, prefix conflicts,
  terminal-equivalent conflicts and unsupported sequences; original files remain
  unchanged.
- Independent review identified terminal-normalization, cancellation-key,
  reserved Meta-token and legacy-alias issues; regression cases accompany fixes.
- Final checks: GNATformat, warnings-as-errors semantic checks, `make test`,
  `make smoke`, and `git diff --check`.
