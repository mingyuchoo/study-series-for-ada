.PHONY: build tools test-build test smoke run clean

build:
	alr build

tools:
	alr exec -- gprbuild -P tools.gpr -j0
	alr exec -- gprbuild -P tests/tooling.gpr -j0
	alr exec -- gprbuild -P tests/patches.gpr -j0

test-build: tools
	alr exec -- gprbuild -P tests/tests.gpr -j0
	alr exec -- gprbuild -P tests/presentation.gpr -j0
	alr exec -- gprbuild -P tests/integration.gpr -j0
	alr exec -- gprbuild -P tests/release.gpr -j0

test: test-build
	./bin/domain_tests
	./bin/editor_tests
	./bin/calendar_commands_tests
	./bin/codec_tests
	./bin/tooling_tests
	./bin/tooling_file_tests
	./bin/patch_tests
	./bin/run_storage_tests
	./bin/release_tests

smoke: build test-build
	./bin/tui_smoke

run:
	alr run

clean:
	alr exec -- gprclean -P diary.gpr
	alr exec -- gprclean -P tests/tests.gpr
	alr exec -- gprclean -P tests/presentation.gpr
	alr exec -- gprclean -P tools.gpr
	alr exec -- gprclean -P tests/tooling.gpr
	alr exec -- gprclean -P tests/patches.gpr
	alr exec -- gprclean -P tests/integration.gpr
	alr exec -- gprclean -P tests/release.gpr
