# Ada Malef Diary

Ada 2022와 Malef로 만든 로컬 TUI 일기장입니다. 월별 달력에서 날짜를 선택하고, 날짜마다 한 편의 일기를 작성·조회·수정·삭제합니다.

## 실행

Linux, UTF-8 터미널, Alire, GNAT 16.1, GPRbuild가 필요합니다. 빌드 보조 도구와 테스트도 Ada로 작성되어 Python 설치 없이 빌드·실행·테스트·릴리스할 수 있습니다. Bash와 PowerShell 스크립트는 플랫폼별 실행 절차를 연결합니다. 터미널은 최소 80열 × 27행이어야 합니다. 이 환경의 검증 도구 체인은 GNAT 16.1.0 / GPRbuild 26.0.1 / Alire 2.1.1입니다.

```bash
make build
alr run
```

별도 저장 경로를 지정할 수 있습니다.

```bash
alr run --args="--data-dir /tmp/my-diary"
./bin/diary --data-dir /tmp/my-diary
./bin/diary --help
```

키바인딩은 Emacs(기본)와 Helix 중에서 고릅니다.

```bash
./bin/diary --keymap helix
alr run --args="--keymap helix"
DIARY_KEYMAP=helix ./bin/diary
```

`--keymap`이 `DIARY_KEYMAP` 환경 변수보다 우선하며, 값은 `emacs` 또는 `helix`입니다. 실행 중에는 달력 화면에서 `M`으로 전환합니다. 전환한 키맵은 저장하지 않으므로 계속 쓰려면 환경 변수를 설정하세요.

포맷팅부터 실행까지 한 번에 수행하려면 GNATformat을 설치하고 아래 스크립트를 사용합니다.

```bash
alr install gnatformat_bin
export PATH="$HOME/.alire/bin:$PATH"
./scripts/run.sh
./scripts/run.sh --data-dir "/tmp/my diary"
```

PowerShell에서는 다음과 같이 실행합니다.

```powershell
./scripts/run.ps1
./scripts/run.ps1 --data-dir "/tmp/my diary"
```

`run.ps1`은 Linux에서는 Bash를, Windows에서는 기본 WSL 배포판의 Bash를 호출합니다. Windows에서는 WSL 안에 저장소와 Linux용 Alire, GNAT, GPRbuild, GNATformat을 준비하고, Alire와 GNATformat을 WSL 로그인 셸의 `PATH`에 추가해야 합니다. 앱 인자에 지정하는 저장 경로도 Linux 경로를 사용합니다.

두 스크립트는 호출 위치와 관계없이 프로젝트 루트에서 Ada 소스 포맷팅 → GNAT 구문·의미 및 전체 경고 검사 → 앱·테스트 빌드 → Ada·저장소·TUI 테스트 → 앱 실행 순서로 진행합니다. 포맷팅은 `apps/`, `packages/*/src/`, `tests/`의 Ada 소스를 직접 수정하며 외부 의존성은 제외합니다. 린트 경고는 오류로 처리하며 검사 산출물은 별도 `lint/` 하위 디렉터리에 생성합니다. 어느 단계든 실패하면 즉시 종료하고, 스크립트에 전달한 인자는 앱에 그대로 전달합니다. 실제 화면을 사용하려면 UTF-8 대화형 터미널이 필요하며, 마지막 실행을 도움말로 확인하려면 `./scripts/run.sh --help`를 사용합니다.

처음 빌드할 때 인터넷으로 Malef를 내려받습니다. Malef는 Alire 인덱스에 등록되어 있지 않아 [공식 저장소](https://github.com/joseaverde/Malef)의 `79b20b6bab88ef2d66528d77fe7ec1a1f4ee4638` 커밋을 고정합니다. `scripts/prepare.sh`가 Alire pre-build 단계에서 독립적인 `tools.gpr`로 Ada 도구 `bin/diary_tools`를 빌드하고 GNAT 16의 이름 해석·타입 추론 호환성 수정을 적용합니다. 이 도구는 Malef에 의존하지 않습니다. 수정은 프로젝트 내부 의존성 캐시에만 적용되며 반복 실행이 가능합니다. 컴파일 호환성 외에 표준 입력 파일 디스크립터, 저장 단축키의 흐름 제어, 터미널 크기 조회도 보정합니다. 또한 `Ctrl+V`, `Ctrl+D`, `Ctrl+Space`가 터미널이나 Malef에서 가로채이지 않고 키 입력으로 전달되도록 합니다. 이에 따라 `Ctrl+D`는 더 이상 앱을 종료하지 않습니다. 이 과정은 원본의 라이선스 고지를 보존합니다.

## 릴리스와 설치파일

릴리스는 대상 OS에서 직접 빌드합니다. `scripts/release.sh`는 Linux와 macOS에서, `scripts/release.ps1`은 Windows 11에서 실행합니다. x86-64와 ARM64를 지원하며 한 번 실행할 때 현재 호스트 아키텍처의 결과물을 만듭니다.

두 스크립트 모두 Ada 소스 포맷팅 → 경고를 오류로 취급하는 린팅 → 최적화 빌드 → 도메인·편집기·코덱·저장소·PTY 테스트 → 번들링 → 설치파일 생성 순서로 진행합니다. 포맷팅은 저장소 소스를 직접 수정합니다. 외부 의존성은 포맷팅하지 않으며, 실패한 단계가 있으면 설치파일을 만들지 않습니다. 릴리스 바이너리는 Ada와 GCC 런타임을 정적으로 링크하고, 패키징 전에 남은 동적 의존성이 OS 기본 라이브러리인지 검사합니다.

### Linux

기존 빌드 도구 외에 `tar`, `strip`, `ldd`, `getconf`, `dpkg-deb`, `rpmbuild`가 필요합니다. Debian/Ubuntu에서는 `dpkg-dev`, `rpm`, `binutils`, Fedora 계열에서는 `dpkg`, `rpm-build`, `binutils` 패키지를 준비합니다. 두 설치 형식을 모두 생성하므로 두 패키징 도구가 모두 있어야 합니다.

```bash
export PATH="$HOME/.alire/bin:$PATH"
./scripts/release.sh
./scripts/release.sh --version 1.0.0 --output "/tmp/diary releases"
./scripts/release.sh --bundle-only
```

기본 버전은 `alire.toml`의 `version`이고 출력 폴더는 프로젝트의 `dist/`입니다. `--version`은 `1.0.0`, `1.0.0-rc.1` 형식을 받습니다. `--output`의 상대 경로는 호출한 디렉터리 기준입니다. `--bundle-only`도 모든 품질 검사를 실행하며 OS 설치파일만 생략합니다. 어느 위치에서든 스크립트를 호출할 수 있습니다.

기본 버전과 ARM64 호스트에서는 다음 파일을 만듭니다.

```text
dist/diary-0.1.0-dev-linux-arm64.tar.gz
dist/diary-0.1.0-dev-linux-arm64.deb
dist/diary-0.1.0-dev-linux-arm64.rpm
dist/diary-0.1.0-dev-linux-arm64-source.tar.gz
dist/diary-0.1.0-dev-linux-arm64-SHA256SUMS
```

`.deb`와 `.rpm`은 `/usr/bin/diary`와 `/usr/share/doc/ada-diary/`를 설치합니다. 소스 버전 `0.1.0-dev`는 Debian에서 `0.1.0~dev`, RPM에서 버전 `0.1.0`과 릴리스 `0.dev`로 변환합니다. Linux 번들은 호환되는 glibc가 필요하며, Debian 패키지는 빌드 호스트의 glibc 버전 이상을 요구합니다. 배포할 가장 오래된 glibc 환경에서 빌드하는 것을 권장합니다. RPM은 바이너리에서 런타임 요구 사항을 자동 계산합니다.

```bash
sudo apt install ./dist/diary-0.1.0-dev-linux-arm64.deb
sudo dnf install ./dist/diary-0.1.0-dev-linux-arm64.rpm
diary --help
```

위 설치 명령 중 배포판에 맞는 하나를 사용합니다. 설치파일 대신 `.tar.gz`를 풀고 내부의 `bin/diary`를 실행할 수도 있습니다.

### macOS

macOS용 Alire, GNAT, GPRbuild, GNATformat과 Xcode Command Line Tools의 `pkgbuild`, `otool`, `strip`이 필요합니다. 같은 명령을 macOS 터미널에서 실행합니다.

```bash
./scripts/release.sh --version 1.0.0
sudo installer -pkg ./dist/diary-1.0.0-macos-arm64.pkg -target /
/usr/local/bin/diary --help
```

macOS에서는 `macos-amd64` 또는 `macos-arm64` 이름의 실행 번들과 `.pkg`를 생성합니다. 설치 위치는 `/usr/local/bin/diary`와 `/usr/local/share/doc/ada-diary/`입니다. 릴리스 스크립트는 Malef의 `unix`/ANSI 구현을 선택하며 의존성 캐시에 호스트의 터미널 크기 상수와 macOS 표준 입력 심볼을 적용합니다. 현재 `run.sh`는 기존 Linux 전용 실행 경로를 유지하므로 macOS에서는 릴리스 번들의 실행파일을 사용합니다. `.pkg`는 서명·공증하지 않은 로컬 설치파일입니다.

### Windows 11

현재 앱은 POSIX 터미널과 파일시스템을 사용하므로 Windows 설치파일은 **WSL에서 Linux 바이너리를 실행하는 형태**입니다. Windows 네이티브 PE 바이너리를 생성하지 않습니다. 빌드 PC에는 다음이 필요합니다.

- 사용자 설정을 완료한 WSL 배포판과 그 안의 Linux용 Alire, GNAT, GPRbuild, GNATformat
- WSL 로그인 셸의 `PATH`에 등록된 Alire와 GNATformat
- Windows PowerShell 5.1 이상, Windows 기본 `tar.exe`, [Inno Setup 6.3 이상](https://jrsoftware.org/isinfo.php)
- WSL에서 접근 가능한 드라이브에 놓인 저장소

```powershell
./scripts/release.ps1
./scripts/release.ps1 -Version 1.0.0 -Distribution Ubuntu -OutputDirectory 'C:\diary releases'
./scripts/release.ps1 -InnoSetupCompiler 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
```

`-Distribution`을 생략하면 기본 WSL 배포판에서 빌드합니다. PowerShell의 `-Help`, Bash의 `--help`로 옵션을 볼 수 있습니다. Windows 스크립트는 WSL 안에서 `release.sh --bundle-only`를 실행하므로 WSL에 Debian/RPM 패키징 도구는 필요하지 않습니다. 결과물은 `diary-VERSION-windows-ARCH-setup.exe`, 실행 가능한 파일들을 담은 `.zip`, 소스 `.tar.gz`, `SHA256SUMS`입니다. Inno Setup 설치파일은 사용자별로 설치하며 시작 메뉴 실행기와 제거 프로그램을 등록합니다. 코드 서명은 수행하지 않습니다.

설치받는 PC에도 WSL 배포판과 호환되는 glibc가 필요하지만 Ada 빌드 도구는 필요하지 않습니다. 기본 WSL 배포판은 패키지와 같은 CPU 아키텍처여야 합니다. 실행할 배포판을 바꾸려면 `DIARY_WSL_DISTRIBUTION` 환경 변수를 설정합니다. 시작 메뉴의 Ada Diary 또는 설치 폴더의 `diary.cmd`로 실행하며, 인자의 `--data-dir`은 WSL 경로를 받습니다. 일기 데이터도 WSL 사용자 디렉터리에 저장합니다. [Microsoft WSL 명령 안내](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)를 참고하세요.

### 배포 결과 검증

번들에는 앱·Malef 라이선스와 실행 의존성 목록을 넣습니다. 소스 번들은 워크스페이스 코드, 릴리스 스크립트, 패치가 적용된 고정 Malef 소스를 `dependencies/malef/`에 포함합니다. 번들의 `alire.toml`은 포함된 Malef 소스를 직접 참조하므로 압축을 푼 프로젝트에서 `alr build`할 수 있습니다. 빌드용 호환성 스크립트도 이 로컬 소스를 우선 사용합니다. 플랫폼별 소스 번들은 이름이 달라 같은 출력 폴더에 모아도 서로 덮어쓰지 않습니다.

```bash
cd dist
sha256sum -c diary-0.1.0-dev-linux-arm64-SHA256SUMS
```

macOS에서는 `shasum -a 256 -c FILE`을 사용합니다. Windows에서는 목록의 해시와 `Get-FileHash -Algorithm SHA256 FILE`의 결과를 비교합니다. 기존 출력 폴더는 지우지 않으며 같은 이름의 결과물은 성공한 릴리스로 덮어씁니다. 여러 플랫폼을 같은 폴더에 모을 때 각 플랫폼의 체크섬 목록은 해당 실행에서 만든 파일만 기록합니다.

릴리스 스크립트 자체의 회귀 검사는 다음과 같습니다. Ada 회귀 검사는 Linux에서 실행하며, Ada 빌드 명령은 테스트 더블로 대체하고 실제 패키징과 Ada 릴리스 보조 도구를 검사합니다.

```bash
make test-build
./bin/release_tests
pwsh -NoProfile -File tests/release_windows_tests.ps1
```

현재 Linux ARM64에서 전체 파이프라인과 실제 `.deb`·`.rpm` 생성 및 번들 실행을 검증했습니다. PowerShell 구문·프로세스 인자 처리도 검사했습니다. macOS 네이티브 빌드와 Windows 설치파일의 실제 설치·실행은 해당 OS에서 추가 검증이 필요합니다.

## 기본 기능

- 월별 달력, 선택 날짜 강조, 오늘 표시, 일기가 있는 날짜의 `*` 표시
- 방향키로 날짜 이동, 이전·다음 달 이동, 오늘로 복귀
- 하루 한 편의 제목과 여러 줄 본문
- 앱 내부 편집기, 커서 이동, 줄바꿈, 백스페이스
- Emacs / Helix 키맵 선택, 단어 이동, 잘라내기·복사·붙여넣기, 실행 취소
- 한글 UTF-8 저장·복원, 한글·CJK 두 칸 문자 배치
- 저장 실패 시 편집 내용 유지
- 삭제 확인 및 수정 내용 버리기 확인
- 재실행 후 데이터 복원, 중복 실행 방지
- 작은 화면에서는 크기 조정 안내

```text
 ADA DIARY      A little space for every day

 2026-11                              2026-11-18

 Mo   Tu   We   Th   Fr   Sa   Su       오늘의 기록
                                1
  2    3    4    5    6    7    8       첫 번째 줄
  9   10   11   12   13   14   15       두 번째 줄
 16   17  [18*] 19   20   21   22
 23   24   25   26   27   28   29
 30

 Arrows date  [/] month  T today  N new  E/Enter edit  D delete
```

화면 안내는 영문이고 일기 내용은 한글을 지원합니다. 문자 폭은 한글·CJK와 일반적인 이모지 범위를 처리합니다. 결합 문자, ZWJ 이모지, 탭 정렬 등 전체 Unicode grapheme 처리는 지원하지 않습니다. 커서는 코드 포인트 단위로 이동합니다.

## 단축키

달력 화면 아래에 현재 키맵이 표시됩니다. 아래 공통 키는 두 키맵에서 모두 동작합니다.

| 화면 | 키 | 동작 |
| --- | --- | --- |
| 달력 | 방향키 | 하루 / 일주일 이동 |
| 달력 | `[` / `]` | 이전 / 다음 달, 월말 날짜 보정 |
| 달력 | `T` | 오늘로 이동 |
| 달력 | `N` | 선택한 날짜에 새 일기 |
| 달력 | `E` / `Enter` | 선택한 일기 수정, 비어 있으면 새 일기 |
| 달력 | `D` | 삭제 확인 |
| 달력 | `M` | Emacs / Helix 키맵 전환 |
| 달력 | `Q` | 종료 |
| 편집 | `Tab` | 제목 / 본문 전환 |
| 편집 | 방향키, `Home` / `End` | 커서 이동, 줄 처음 / 끝 |
| 확인 | `Y` / `N` / `Esc` | 실행 / 취소 / 취소 |

달력의 공통 단축키는 대소문자를 모두 지원합니다. 제목은 공백만으로 저장할 수 없습니다. 기존 일기에 `N`을 누르면 `E`로 수정하도록 안내합니다.

### Emacs 키맵 (기본)

`C-`는 Ctrl, `M-`은 Alt(또는 `Esc`를 누른 직후 해당 키)입니다.

| 화면 | 키 | 동작 |
| --- | --- | --- |
| 달력 | `C-b` / `C-f` / `C-p` / `C-n` | 하루 전 / 후, 일주일 전 / 후 |
| 달력 | `M-{` / `M-}` | 이전 / 다음 달 |
| 달력 | `.` | 오늘로 이동 |
| 달력 | `J` 또는 `C-v` / `K` 또는 `M-v` | 본문 아래 / 위 스크롤 |
| 편집 | `C-b` / `C-f` / `C-p` / `C-n` | 커서 왼쪽 / 오른쪽 / 위 / 아래 |
| 편집 | `C-a` / `C-e` | 줄 처음 / 끝 |
| 편집 | `M-b` / `M-f` | 이전 / 다음 단어 |
| 편집 | `M-<` / `M->` | 필드 처음 / 끝 |
| 편집 | `Backspace` / `C-d` | 커서 앞 / 뒤 문자 삭제 |
| 편집 | `M-d` / `M-Backspace` | 뒤 / 앞 단어 잘라내기 |
| 편집 | `C-k` | 줄 끝까지 잘라내기 |
| 편집 | `C-Space`, `C-w` / `M-w` | 마크 설정, 영역 잘라내기 / 복사 |
| 편집 | `C-y` | 붙여넣기 |
| 편집 | `C-/` 또는 `C-x u` | 실행 취소 |
| 편집 | `Enter` | 제목에서 본문으로 이동, 본문에서 줄바꿈 |
| 편집 | `Ctrl+S` | 저장하고 달력으로 |
| 편집 | `C-x C-s` | 저장하고 계속 편집 |
| 편집 | `Esc` 또는 `C-x k` | 닫기, 변경이 있으면 확인 |
| 편집 | `C-g` | 마크 / 접두 키 취소 |

`C-c`와 `C-z`는 터미널 신호로 처리되므로 `C-x C-c`는 지원하지 않습니다. 종료는 달력에서 `Q`를 사용합니다. 다시 실행(redo)은 없습니다.

### Helix 키맵

편집기는 Helix처럼 Normal 모드로 시작하며, 제목 줄 옆에 `NOR` / `INS` / `SEL`로 현재 모드를 표시합니다. 선택 영역을 먼저 만들고 동작을 적용합니다.

| 화면 | 키 | 동작 |
| --- | --- | --- |
| 달력 | `h` / `l` / `k` / `j` | 하루 전 / 후, 일주일 전 / 후 |
| 달력 | `i` | 선택한 일기 수정 |
| 달력 | `Ctrl+D` / `Ctrl+U` | 본문 아래 / 위 스크롤 |
| 달력 | `:q` | 종료 |
| Normal | `h` / `j` / `k` / `l` | 커서 이동 |
| Normal | `w` / `e` / `b` | 다음 단어 시작 / 끝, 이전 단어 시작까지 선택 |
| Normal | `gg` / `ge` / `gh` / `gl` | 필드 처음 / 끝, 줄 처음 / 끝 |
| Normal | `x` | 줄 선택, 반복하면 다음 줄까지 확장 |
| Normal | `%` / `;` | 전체 선택 / 선택을 커서 한 칸으로 축소 |
| Normal | `v` | Select 모드 전환, 이동 키가 선택을 확장 |
| Normal | `i` / `a` | 선택 앞 / 뒤에서 Insert 모드 |
| Normal | `I` / `A` | 줄 처음 / 끝에서 Insert 모드 |
| Normal | `o` / `O` | 아래 / 위에 새 줄을 열고 Insert 모드 |
| Normal | `d` / `c` | 선택 삭제 / 삭제 후 Insert 모드 |
| Normal | `y`, `p` / `P` | 선택 복사, 선택 뒤 / 앞에 붙여넣기 |
| Normal | `u` / `U` | 실행 취소 / 다시 실행 |
| Normal | `:w` | 저장하고 계속 편집 |
| Normal | `:wq` 또는 `:x` | 저장하고 달력으로 |
| Normal | `:q` / `:q!` | 닫기(변경이 있으면 거부) / 변경을 버리고 닫기 |
| Insert | `Esc` | Normal 모드로 |
| Insert | `Backspace` / `Enter` | 커서 앞 문자 삭제 / 제목에서 본문으로 이동, 본문에서 줄바꿈 |

Helix의 일부만 구현합니다. 다중 선택, 횟수 접두(`3w`), `f`/`t` 찾기, 텍스트 객체, 레지스터 지정, 검색은 지원하지 않습니다. 단어는 영숫자·밑줄·한글 등 비ASCII 문자, 문장 부호, 공백의 세 종류로 구분합니다. Helix 키맵의 달력에서는 `J`/`K`가 날짜 이동이므로 스크롤은 `Ctrl+D`/`Ctrl+U`를 사용합니다. 편집 내용을 버리는 `Esc` 확인 창은 Emacs 키맵에만 있고 Helix에서는 `:q!`를 사용합니다.

잘라내거나 복사한 텍스트는 앱 내부에만 보관하며 시스템 클립보드와 연동하지 않습니다. 제목에 붙여넣을 때는 줄바꿈을 제거합니다. 실행 취소 기록은 제목과 본문이 각각 따로 가지며 편집 화면을 닫으면 사라집니다.

## 데이터 저장

저장 경로의 우선순위는 다음과 같습니다.

1. `--data-dir PATH`
2. `$XDG_DATA_HOME/ada-diary`
3. `$HOME/.local/share/ada-diary`

각 일기는 `YYYY-MM-DD.diary` 파일에 UTF-8로 저장합니다. 첫 줄은 `ADA-DIARY-1`, 다음 줄은 제목, 나머지는 본문입니다. 본문의 마지막 줄바꿈까지 보존합니다. 앱 종료 후 저장 폴더를 복사하면 백업할 수 있습니다. 파일은 암호화하지 않습니다.

저장은 동일 폴더의 `.tmp` 파일에 기록한 뒤 Linux의 파일 이름 교체 연산으로 반영합니다. 이는 저장 실패로 원본이 부분적으로 덮어써지는 것을 막지만, 정전 시 디스크 동기화까지 보장하는 방식은 아닙니다. 잘못된 형식의 파일은 오류로 표시하며 편집으로 덮어쓰지 않습니다.

실행 중에는 저장 폴더의 `.lock` 디렉터리로 다른 세션을 차단합니다. 정상 종료는 `Q`를 사용합니다. 강제 종료나 Malef가 처리하는 종료 신호로 끝나면 `.lock`이 남을 수 있습니다. 실행 중인 일기장 프로세스가 없는지 확인한 뒤 **저장 폴더의 빈 `.lock` 디렉터리만** `rmdir`로 지우면 다시 실행할 수 있습니다. 직접 파일을 바꿀 때도 앱을 먼저 종료하세요.

## 워크스페이스 구조

```text
apps/diary/src/          실행 진입점, 화면 상태, 컨트롤러, Malef 어댑터
packages/domain/        순수 날짜 계산, 일기 엔티티와 검증
packages/application/   저장소 포트, CRUD 유스케이스, 순수 편집기·문자 배치
packages/storage/       UTF-8 파일 코덱, 파일 저장소와 잠금
scripts/                고정 Malef 버전의 컴파일러 호환성 처리
apps/tools/src/         Ada 빌드·릴리스 보조 도구 진입점
packages/tooling/       순수 소스 변환·릴리스 정책과 파일·호스트 어댑터
tests/                  Ada 단위·통합·PTY·릴리스 테스트
```

의존성은 `application → domain`, `storage → application + domain`, `app → application + storage + Malef`입니다. 각 공유 패키지는 별도 Alire crate와 GPR 프로젝트로 경계를 유지합니다. 파일·환경 변수·시계·터미널 접근은 어댑터에서만 수행합니다.

## 검증

```bash
make test
make smoke
```

`make test`는 날짜 계산, 일기 검증, 편집기, 문자 배치 및 임시 폴더에서의 CRUD·재실행·잠금·저장 실패·손상 데이터 처리와 빌드 보조 도구·릴리스 회귀를 검사합니다. `make smoke`는 Ada로 작성된 실제 PTY 테스트로 한글 작성·저장·재실행·수정·삭제·확인 창·화면 크기 변경, Emacs·Helix 키맵별 편집과 키맵 선택, 작은 화면에서 명령 차단, 터미널 모드 복원과 비대화형 도움말도 검사합니다.

## 추천 확장 기능

| 우선순위 | 기능 | 기대 효과 |
| --- | --- | --- |
| 1 | 제목·본문 검색 | 오래된 기록을 키워드로 찾기 |
| 2 | 태그와 기분 기록 | 주제별 분류와 감정 변화 살펴보기 |
| 3 | 월별 작성 통계·연속 작성일 | 기록 습관 확인 |
| 4 | Markdown 내보내기·백업 복원 | 다른 도구로 이동하고 데이터 보관 |
| 5 | 일기 템플릿 | 감사 일기·회고 등 반복 형식 작성 |

이 항목들은 후속 기능 제안이며 현재 구현 범위는 달력과 일기 CRUD입니다.

Malef는 GPL-3.0-or-later이며, 이 앱의 Alire 패키지 메타데이터도 같은 라이선스를 사용합니다.
