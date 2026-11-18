.PHONY: build tools test-build test smoke run clean

test_projects := tests/tooling.gpr tests/patches.gpr tests/integration.gpr tests/release.gpr

build:
	alr build

tools:
	alr exec -- gprbuild -P tools.gpr -j0

test-build: build
	@set -e; for project in $(test_projects); do \
		alr exec -- gprbuild -P "$$project" -j0; \
	done

test: test-build
	./bin/tui_model_tests
	./bin/tooling_tests
	./bin/tooling_file_tests
	./bin/patch_tests
	./bin/release_tests
	./bin/tui_smoke

smoke: test-build
	./bin/tui_smoke

run:
	alr run

clean:
	@set -e; for project in tui_template.gpr tools.gpr $(test_projects); do \
		alr exec -- gprclean -P "$$project"; \
	done
