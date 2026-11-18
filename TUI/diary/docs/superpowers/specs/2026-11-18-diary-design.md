# Ada Malef Diary

Build a keyboard-operated, local diary with a month calendar and one entry per date. The user delegated unspecified choices and requested additional feature recommendations.

Use Ada 2022 and Malef's drawing and event APIs. Pin Malef to upstream commit `79b20b6bab88ef2d66528d77fe7ec1a1f4ee4638`. Use Alire local workspace packages: domain, application, storage, and the executable under apps. Ada imports use package names, and GPR imports resolve through Alire dependencies.

The domain owns validated Gregorian dates and diary entries. Application ports expose read, write, delete, and month membership; use cases enforce create/update semantics and validation. The storage adapter writes UTF-8 files via a temporary file and atomic replacement on Linux. The Malef adapter owns rendering, keyboard events, current time, and environment access.

Calendar navigation supports arrows, previous/next month, and today. Existing entries are marked. The reading pane displays the selected date's title and body with scrolling. New/edit opens an internal multiline editor with a title field, navigation, save, and cancel. Deletion and abandoning edits require confirmation. Errors remain visible without discarding the draft. Small terminals display a resize prompt. UI labels use English for terminal portability; content supports Korean UTF-8. Malef's glyph model does not implement grapheme-aware terminal layout, so document wide-character rendering limitations.

Prefer individual dated files over SQLite: they avoid a database dependency and make backup straightforward. SQLite would simplify advanced indexed searching but adds unnecessary scope for calendar CRUD. Default data location is XDG_DATA_HOME/ada-diary or HOME/.local/share/ada-diary, with --data-dir override. Concurrent sessions on the same data directory are rejected using an exclusive lock directory. Lock recovery is documented.

Do not add source comments. Keep framework, file, environment, time, and terminal concerns out of domain/application. Domain and editor behavior receive deterministic unit tests; storage receives temporary-directory integration tests; calendar CRUD receives a real PTY smoke test.

Future recommendations: full-text search, tags and mood, writing statistics, Markdown export. These are recommendations, not part of this implementation.
