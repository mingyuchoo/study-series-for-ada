# Ada TUI Template

Ada 2022와 Malef로 터미널 앱을 시작할 수 있는 워크스페이스입니다. 기본 화면에서 Space를 누르면 상태가 바뀌고, Q를 누르면 종료합니다. 터미널 크기가 바뀌면 화면을 다시 그립니다.

## 빠른 시작

Linux 또는 macOS의 UTF-8 터미널에서 Alire, GNAT 16.1 이상, GPRbuild를 사용합니다. Windows에서 개발할 때는 WSL 안에 같은 도구를 준비하세요. 첫 빌드에서는 Alire가 고정된 Malef 리비전을 내려받고 프로젝트 내부의 의존성 캐시에 호환성 패치를 적용합니다.

```sh
make build
make run
make test
```

`./bin/tui_template --help`로 실행 옵션을 확인할 수 있습니다. `make test`는 상태 전이, 빌드 도구, 릴리스 스크립트 회귀 및 가상 터미널에서의 입력·리사이즈·종료를 검사합니다. `make smoke`는 가상 터미널 검사만 실행합니다.

## 새 앱 만들기

1. [tui_model.ads](packages/presentation/src/tui_model.ads)와 [tui_model.adb](packages/presentation/src/tui_model.adb)에서 앱 상태와 입력에 따른 상태 전이를 정의합니다. [tui_input.ads](packages/presentation/src/tui_input.ads)에 터미널 라이브러리와 독립적인 입력 타입이 있습니다.
2. [tui_renderer.adb](apps/tui_template/src/tui_renderer.adb)에서 상태를 화면으로 그립니다. 예제의 `Put`은 한 글자가 한 칸을 차지하는 텍스트를 표시합니다. 한글이나 이모지 등 폭이 가변적인 문자열을 추가할 때는 터미널 셀 너비를 반영하세요.
3. [tui_template.adb](apps/tui_template/src/tui_template.adb)에서 앱 시작 시 필요한 의존성을 구성합니다. 비즈니스 로직이 필요하면 `packages/` 아래에 순수 도메인 패키지와 유스케이스 패키지를 추가하고, 파일이나 네트워크는 포트 뒤에 어댑터로 연결합니다. 패키지끼리는 GPR 프로젝트와 Ada 패키지 이름을 통해 참조합니다.
4. [상태 전이 테스트](tests/tui_model_tests.adb)와 [가상 터미널 테스트](tests/tui_smoke.adb)를 앱 동작에 맞게 수정합니다.
5. 배포 이름을 정하면 `alire.toml`의 이름과 실행 파일, `tui_template.gpr`의 프로젝트와 메인 유닛, `apps/tui_template/`의 경로를 함께 바꿉니다. Makefile, 테스트, `scripts/`의 실행 파일명과 설치 메타데이터도 같은 이름으로 맞춥니다.

`packages/presentation`은 순수 입력 타입과 상태 전이를 제공합니다. `apps/tui_template`은 이벤트 루프, Malef 터미널 세션과 렌더링을 담당합니다. `packages/tooling_policy`는 빌드·릴리스 변환 규칙을, `packages/tooling`은 호스트 및 파일 시스템 어댑터를 제공합니다.

## 개발과 배포

GNATformat이 설치되어 있다면 `./scripts/run.sh --help`로 포맷팅, 전체 경고 검사, 빌드, 테스트, 실행을 순서대로 확인할 수 있습니다. 스크립트는 Ada 소스 파일을 직접 포맷합니다. PowerShell에서는 `./scripts/run.ps1 --help`를 사용합니다.

```sh
./scripts/release.sh --bundle-only
./scripts/release.sh --help
```

릴리스 스크립트는 최적화한 바이너리, 대응하는 소스 번들, SHA-256 체크섬을 기본적으로 `dist/`에 만듭니다. 네이티브 설치 파일도 생성하려면 Linux에서 `dpkg-deb`와 `rpmbuild`를, macOS에서 Xcode Command Line Tools를 준비합니다. WSL 기반 Windows 설치 파일은 `./scripts/release.ps1 -Help`에서 옵션을 확인할 수 있습니다.
