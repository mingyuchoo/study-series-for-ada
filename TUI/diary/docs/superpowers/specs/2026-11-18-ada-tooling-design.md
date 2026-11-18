# Ada tooling migration

Replace all executable Python in this workspace with Ada while preserving the diary's behavior and build, test, and release workflows. Bash and PowerShell remain platform orchestration adapters. Python must not be required to build, test, run, or package the application.

## Approach

The diary domain and application are already Ada. Rewriting their behavior is unnecessary. Replacing Python with shell would preserve another implementation language for substantive tooling logic. Instead, add a dependency-free Ada tooling workspace package and standalone tool executable that can bootstrap before Alire builds Malef.

Pure source transformations and release validation live in the tooling package. Filesystem, platform discovery, hashing, and process interaction live in explicit infrastructure modules or executable entry points. Existing domain/application packages gain no infrastructure dependencies.

The tool supports Malef preparation, manifest version lookup and local pin rewriting, runtime dependency validation, license discovery, and SHA-256 manifests. Bootstrap uses the compiler selected by Alire without recursively invoking Alire from a pre-build action. Tooling is a locally pinned Alire workspace dependency, imported by project name; the bootstrap supplies its project search path explicitly. Preserve local dependency precedence, Linux/macOS constants, existing licenses, and idempotence. Preparation normalizes source line endings for matching and preserves the original bytes when no transformation changes them. Native OS discovery calls the OS directly. `prepare ROOT [linux|macos]` defaults to the native host and also supports preparing sources for an explicit target.

Storage, PTY smoke, and release regression tests become Ada executables. Preserve Unicode CRUD, persistence, rejected special files, locking, failed writes, both keymaps, terminal resizing and restoration, release failure propagation, source bundle contents, checksums, paths containing spaces, and prerequisite validation. Unsupported hosts fail clearly. Resource cleanup and bounded subprocess waits are mandatory.

## Verification

Run pure tooling tests, existing Ada tests, Ada integration and PTY tests, and release regressions. Exercise build and bundle creation with Python executables made unavailable. Validate bootstrap from absent tooling binaries and objects. Check no executable Python remains in project source/configuration; historical planning documents may retain descriptions of earlier work.
