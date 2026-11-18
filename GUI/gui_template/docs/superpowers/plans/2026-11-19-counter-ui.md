# Counter UI Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution.

**Goal:** Apply the approved desktop UI refresh to both platform adapters.

**Architecture:** Keep domain and application packages pure and unchanged. Presentation, widget state and process errors remain in apps.

**Tech Stack:** Existing Ada/GWindows and Tcl/Tk; no new runtime dependencies.

**Spec:** ../specs/2026-11-19-counter-ui-design.md

## Global Constraints

- No source comments or cross-package relative source imports.
- Preserve count range 0 through 999 and existing backend protocol.
- Work in the user's current checkout; leave the changes reviewable and uncommitted.

## Review Focus

- Increment disables at 999 and Reset restores it.
- Keyboard users keep a usable focus after reaching the limit.
- Backend failures disable both actions and display an error.
- Long errors wrap without clipping the controls.
- Font and window scaling keep all controls visible.

## Tasks

- [x] Add a real Tk integration test using the Ada backend; run it against the old UI to demonstrate the missing maximum-state behavior.
- [x] Refresh `apps/counter_tk/ui/counter.tcl`, preserving its process lifecycle and errors; run the integration test.
- [x] Refresh `apps/counter_windows/src/adapters/counter_window.adb` with existing GWindows font and drawing APIs, native keyboard semantics and limit feedback; compile and smoke-test startup.
- [x] Document the UI test command in README, rerun both package suites and warning checks, and review the final diff.

Baseline: both existing package suites and both apps build on Windows. The dependency build reports an existing casing style diagnostic in GWindows contrib. Graft does not index the Ada adapter; callers and packaging references were checked with rg instead.

## Verification results

- Windows app build and startup smoke test passed; the app's Ada warning checks passed with `-gnatwa -gnatwe`.
- Both package suites and their warning checks passed.
- Four Tk integration tests passed against the real Ada executable: maximum/reset, error disablement, reset focus below maximum, and keyboard shortcuts.
- The maximum-state test failed before implementation. Independent review found reset focus below maximum inconsistent between adapters; its regression test failed before the fix and passed afterward.
- `git diff --check` passed. No new source comments, runtime dependencies, core changes or package boundary changes.
- Visual capture and native Windows click/keyboard inspection were unavailable because the Computer Use native pipe could not connect. Linux/macOS and Tk 8.6 were not executed; Tk tests ran on Windows with Tk 9.0.
