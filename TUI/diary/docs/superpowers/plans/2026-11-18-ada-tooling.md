# Ada Tooling Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or superpowers:subagent-driven-development task by task.

**Goal:** Build, run, test, and package the diary without Python.

**Architecture:** A standalone Ada tooling executable uses a workspace tooling package containing pure transformations and infrastructure adapters. Ada integration executables replace Python harnesses. Shell and PowerShell retain platform orchestration.

**Tech Stack:** Ada 2022, GNAT, GPRbuild, Alire, POSIX, Bash, PowerShell.

**Spec:** `docs/superpowers/specs/2026-11-18-ada-tooling-design.md`

## Global Constraints

- No source comments, Python execution, or cross-package relative source imports.
- Keep domain/application free of concrete side-effect dependencies.
- Preserve Linux/macOS and Windows-through-WSL release behavior.
- Preserve behavior coverage and deterministic cleanup; bound subprocess waits.
- Preserve the existing uncommitted .gitignore work; do not commit or alter unrelated work.

## Review Focus

- Bootstrap without existing tooling artifacts and without recursion.
- Idempotent patches and local source precedence, including Darwin terminal constants.
- PTY process cleanup on assertion failures and terminal mode restoration.
- Spaces in checkout/output paths and malformed manifests or dependency listings.
- Source bundles include all Ada tooling needed for rebuilding.

### Task 1: Ada preparation and release utilities

**Files:** `packages/tooling/`, `apps/tools/`, `tools.gpr`, `tests/tooling/`, `tests/tooling.gpr`, `scripts/prepare.sh`, `alire.toml`, `scripts/release.sh`.

**Interfaces:** `bin/diary_tools prepare ROOT [linux|macos]`, `version MANIFEST`, `pin-manifest MANIFEST`, `validate-dependencies PLATFORM FILE`, `license DIRECTORY`, `checksums DIRECTORY MANIFEST_NAME`. Standalone `tools.gpr` builds `diary_tools` without Malef; `tests/tooling.gpr` builds its tests. Named project imports resolve through the local Alire tooling pin or the bootstrap project search path.

- [x] Write and run failing pure transformation/validation tests using literal fixtures.
- [x] Implement pure transformations plus filesystem/hashing adapters and CLI.
- [x] Replace pre-build and inline release Python with Ada commands.
- [x] Verify patch idempotence, dependency checks, version/pin validation, known SHA-256 values, and clean bootstrap.

### Task 2: Ada storage and terminal integration harness

**Files:** `tests/support/`, `tests/integration.gpr`, `tests/run_storage_tests.adb`, `tests/tui_smoke.adb`.

**Interfaces:** `bin/run_storage_tests` invokes existing `bin/storage_tests` with an isolated temporary directory and FIFO fixture. `bin/tui_smoke` exercises `bin/diary`. `tests/integration.gpr` builds these independently of Malef using GNAT runtime and POSIX bindings.

- [x] Port behavior assertions from existing Python tests, preserving coverage.
- [x] Implement isolated filesystem/process/PTY helpers and failure cleanup.
- [x] Build and run storage and terminal integration tests.

### Task 3: Ada release regression harness

**Files:** `tests/release_tests.adb`, `tests/release_support/`, `tests/release.gpr`.

**Interfaces:** `bin/release_tests` runs `scripts/release.sh` against controlled fixture toolchains, using the real `bin/diary_tools`. `tests/release.gpr` independently builds release regressions.

- [x] Port existing release behaviors to Ada tests, including archive content and independent checksum verification.
- [x] Verify invalid arguments, missing prerequisites, early failures, paths with spaces, source local pin, permissions, and native package prereleases where tools exist.
- [x] Run regressions without Python.

### Task 4: Workflow integration and final validation

**Files:** `Makefile`, `scripts/run.sh`, `scripts/release.sh`, `README.md`, `.gitignore`, former Python files.

- [x] Wire Ada test builds/executables into make/run/release and update requirements/documentation.
- [x] Delete superseded Python source and remove obsolete Python-specific ignore rules.
- [ ] Run the complete test suite, formatting and lint checks, Python-free build, release regressions, and actual bundle pipeline.
- [ ] Review the full change and fix correctness/coverage gaps before reporting evidence.
