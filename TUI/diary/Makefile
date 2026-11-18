.PHONY: build test smoke run clean

build:
	alr build

test:
	alr exec -- gprbuild -P tests/tests.gpr -j0
	./bin/domain_tests
	./bin/editor_tests
	./bin/codec_tests
	python3 tests/run_storage_tests.py

smoke: build
	python3 tests/tui_smoke.py

run:
	alr run

clean:
	alr exec -- gprclean -P diary.gpr
	alr exec -- gprclean -P tests/tests.gpr
