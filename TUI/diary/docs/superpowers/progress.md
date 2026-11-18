# Execution ledger: 2026-11-18-diary

The user delegated implementation choices with “알아서 진행해”. Work stays in the supplied directory, and changes remain uncommitted for review. There is no existing app or test baseline.

Preflight: task 1 date and entry types feed task 2 ports/use cases; task 3 consumes those same package names. No conflicting interfaces found.

Task 1: complete. Tests first failed with missing domain packages, then passed for Gregorian arithmetic, clamping, parsing and entry validation.
Task 2: complete. Tests first failed with missing application/storage/editor packages, then domain, editor and storage suites passed. Storage tests cover restart, Unicode, duplicate creation, locking, corrupt data and a failed temporary-file write preserving the original.

Task 3: integration tests first failed because no diary executable existed. Domain, editor, text layout and storage tests pass.
Compatibility decision: pinned Malef 0.4.0 fails under installed GNAT 16.1.0 because private inherited Put_Image names change aspect resolution and Last_Index has an ambiguous reduction index type. A deterministic pre-build adapter script removes four optional debug Put_Image aspects, replaces problematic reductions and a generic expression with equivalent loop bodies, and makes observer access conversions explicit. It also corrects the upstream stdin descriptor, disables software flow control during the session, and safely handles failed terminal-size queries. Global toolchain settings are unchanged.

Final review: a fresh reviewer inspected the complete working tree and reproduced material PTY defects. Fixed findings with regression coverage: Ctrl+S delivery and stdin descriptor, small-screen command blocking, complete unsupported CSI consumption, unrelated malformed-path isolation and FIFO rejection, leading field BOM preservation and invalid UTF-8 rejection, full-width blank titles, and full-line newline layout. Regression tests were observed failing before the corresponding fixes. No material findings were deferred.

Task 3: complete. Final `make test smoke` passed: domain, editor/text layout, codec, storage integration, full app build, and PTY CRUD/confirmations/resize. PTY also checks blank-title validation, unsupported CSI keys, small-screen reading/editing command blocking, write-only stdout, normal terminal-mode restoration, redirected help and invalid CLI exit status. Compatibility patches reproduced byte-for-byte from a fresh upstream copy and a second application left hashes unchanged. Source comment, inward dependency and whitespace checks passed.

Delivery: Linux executable `bin/diary`, Alire workspace sources, README and GPL license remain in the supplied directory, uncommitted. No push, merge, global toolchain change or deployment was performed. Limitations documented: 80×27 minimum, code-point editing rather than full Unicode grapheme handling, plaintext local files and stale-lock recovery after forced termination.
