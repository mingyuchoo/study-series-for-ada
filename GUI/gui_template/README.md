# Ada/SPARK GUI 템플릿

Windows에서는 GWindows로, Linux와 macOS에서는 Tcl/Tk로 카운터 창을 엽니다. 세 플랫폼에서 같은 Ada/SPARK 코어를 사용합니다. **Increment**는 값을 999까지 올리고, **Reset**은 0으로 초기화합니다.

## 구조

| 경로 | 역할 |
| --- | --- |
| `packages/counter_domain` | 카운터 범위와 포화 증가 규칙을 정의하는 순수 SPARK 도메인 |
| `packages/counter_application` | 초기값과 증가·초기화 유스케이스를 제공하는 순수 SPARK 애플리케이션 |
| `apps/counter_windows` | 실행 진입점과 GWindows 위젯·이벤트 어댑터 |
| `apps/counter_tk` | 실행 진입점, Ada 표준 입출력 어댑터, Tcl/Tk 화면 |

의존 방향은 `앱 → counter_application → counter_domain`입니다. 각 패키지는 자체 Alire 매니페스트와 GPR 프로젝트를 가지며, 로컬 Alire 핀으로 연결됩니다. Ada 소스는 유닛 이름으로, GPR은 프로젝트 이름으로 의존성을 가져옵니다.

`Counter_Actions.Apply`는 현재 값과 동작을 받아 다음 값을 반환하는 입력 포트입니다. 각 어댑터가 현재 값을 보관하고 GUI 이벤트 또는 표준 입력을 동작으로 변환합니다. 위젯 갱신, 프로세스 실행, 입출력은 앱에 속합니다. 이 예제의 유스케이스에 필요한 외부 서비스는 없습니다.

## 실행

[Alire](https://alire.ada.dev/)와 네이티브 Ada 컴파일러 및 GPRbuild가 필요합니다. 아래 명령은 이 README가 있는 디렉터리에서 시작합니다.

### 검사 후 실행

PATH에 `alr`를 준비하고 Alire에 GNAT 및 GPRbuild를 설정합니다. Linux와 macOS에서는 `gnatformat`과 Tcl/Tk도 필요합니다.

- Linux 및 macOS에서 `./scripts/run.sh`를 실행합니다.
- Windows 11 PowerShell에서 `.\scripts\run.ps1`을 실행합니다.

Linux와 macOS 스크립트는 작업 트리의 Ada 소스를 직접 포맷팅하며, Windows 스크립트는 포맷팅을 건너뜁니다. GNAT 경고 검사, 앱 빌드, 도메인과 애플리케이션 테스트를 모두 통과하면 카운터 창을 엽니다.

### Windows (PowerShell)

```powershell
cd apps/counter_windows
alr run
```

Alire가 [GWindows](https://alire.ada.dev/crates/gwindows) 의존성을 가져옵니다.

### Linux 및 macOS

Tk의 `wish`가 필요합니다. Debian/Ubuntu는 `sudo apt install tk`, macOS의 Homebrew는 `brew install tcl-tk`로 설치할 수 있습니다. Linux에서는 그래픽 세션의 터미널에서 실행합니다. [Tcl/Tk 설치 안내](https://www.tcl-lang.org/software/tcltk/), [Homebrew 패키지](https://formulae.brew.sh/formula/tcl-tk)

```sh
cd apps/counter_tk
alr build
wish ui/counter.tcl bin/counter_tk
```

macOS에서 Homebrew가 설치한 `wish`를 직접 지정하려면 다음 명령을 사용합니다.

```sh
"$(brew --prefix tcl-tk)/bin/wish" ui/counter.tcl bin/counter_tk
```

## 테스트 및 SPARK 증명

이 README가 있는 디렉터리에서 패키지별 테스트를 실행합니다.

```sh
(cd packages/counter_domain && alr exec -- gprbuild -P counter_tests.gpr && ./bin/test_counter)
(cd packages/counter_application && alr exec -- gprbuild -P counter_tests.gpr && ./bin/test_counter)
```

Windows에서는 각 패키지로 이동해 같은 `alr exec` 명령을 실행한 뒤 `.\bin\test_counter.exe`를 실행합니다. 도메인 테스트는 범위 전체의 증가와 999에서의 포화를, 애플리케이션 테스트는 초기값과 이벤트에 따른 상태 전이를 확인합니다.

[GNATprove](https://alire.ada.dev/crates/gnatprove)를 설치해 PATH에 추가한 뒤 아래 명령을 실행합니다.

```sh
(cd packages/counter_domain && alr exec -- gnatprove -P counter_domain.gpr --mode=prove --checks-as-errors=on --report=all)
(cd packages/counter_application && alr exec -- gnatprove -P counter_application.gpr --mode=prove --checks-as-errors=on --report=all)
```

## 설치 파일 만들기

릴리스 스크립트는 소스를 임시 디렉터리에 복사한 뒤 Ada 포맷팅, GNAT 경고 검사, 릴리스 빌드, 패키지 테스트, 번들링, 설치 파일 생성을 순서대로 실행합니다. GNAT 경고는 오류로 처리하며, 성공한 설치 파일은 앱의 Alire 버전과 대상 아키텍처를 포함한 이름으로 `dist/`에 저장합니다.

공통 준비물은 PATH의 `alr`, `gnatformat`, 그리고 Alire에 설정된 네이티브 GNAT 및 GPRbuild입니다. GNATformat은 `alr install gnatformat`으로 설치할 수 있습니다. [GNATformat](https://alire.ada.dev/crates/gnatformat)

| 대상 | 실행 | 추가 준비물 및 결과 |
| --- | --- | --- |
| Debian·Ubuntu | `./release.sh` | `dpkg-dev` 필요. `.deb`를 `sudo apt install ./dist/<파일명>.deb`로 설치하고 앱 메뉴의 **Counter**를 엽니다. Tk 의존성은 패키지에 선언됩니다. |
| macOS | `./release.sh` | `productbuild`, `plutil`, `lipo` 필요. `.pkg`를 열면 `/Applications/Counter.app`에 설치됩니다. 실행 시 Homebrew 기본 경로의 Tcl/Tk 또는 시스템 `wish`를 사용합니다. |
| Windows 11 | `.\release.ps1` | [Inno Setup](https://jrsoftware.org/isinfo.php) 6.3 이상 필요. 설치 위치가 기본 경로와 다르면 `ISCC.exe`를 PATH에 추가합니다. 설치 `.exe`를 실행하면 현재 사용자의 시작 메뉴에 **Counter**가 추가됩니다. |

macOS와 Windows 설치 파일은 서명 없이 생성됩니다.

## 라이선스

이 디렉터리의 자체 코드와 문서는 MINGYUCHOO (mingyuchoo@gmail.com) 개인 사용 조건을 따릅니다. 제3자 의존성에는 각자의 라이선스가 적용됩니다. [라이선스 전문](LICENSE)
