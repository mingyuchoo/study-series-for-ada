# Ada Malef Diary

Ada 2022와 Malef로 만든 로컬 TUI 일기장입니다. 월별 달력에서 날짜를 선택하고, 날짜마다 한 편의 일기를 작성·조회·수정·삭제합니다.

## 실행

Linux, UTF-8 터미널, Alire, GNAT 16.1, GPRbuild, Python 3이 필요합니다. 터미널은 최소 80열 × 27행이어야 합니다. 이 환경의 검증 도구 체인은 GNAT 16.1.0 / GPRbuild 26.0.1 / Alire 2.1.1입니다.

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

`run.ps1`은 Linux에서는 Bash를, Windows에서는 기본 WSL 배포판의 Bash를 호출합니다. Windows에서는 WSL 안에 저장소와 Linux용 Alire, GNAT, GPRbuild, Python 3, GNATformat을 준비하고, Alire와 GNATformat을 WSL 로그인 셸의 `PATH`에 추가해야 합니다. 앱 인자에 지정하는 저장 경로도 Linux 경로를 사용합니다.

두 스크립트는 호출 위치와 관계없이 프로젝트 루트에서 Ada 소스 포맷팅 → GNAT 구문·의미 및 전체 경고 검사 → 앱·테스트 빌드 → Ada·저장소·TUI 테스트 → 앱 실행 순서로 진행합니다. 포맷팅은 `apps/`, `packages/*/src/`, `tests/`의 Ada 소스를 직접 수정하며 외부 의존성은 제외합니다. 린트 경고는 오류로 처리하며 검사 산출물은 별도 `lint/` 하위 디렉터리에 생성합니다. 어느 단계든 실패하면 즉시 종료하고, 스크립트에 전달한 인자는 앱에 그대로 전달합니다. 실제 화면을 사용하려면 UTF-8 대화형 터미널이 필요하며, 마지막 실행을 도움말로 확인하려면 `./scripts/run.sh --help`를 사용합니다.

처음 빌드할 때 인터넷으로 Malef를 내려받습니다. Malef는 Alire 인덱스에 등록되어 있지 않아 [공식 저장소](https://github.com/joseaverde/Malef)의 `79b20b6bab88ef2d66528d77fe7ec1a1f4ee4638` 커밋을 고정합니다. `scripts/prepare_malef.py`가 Alire pre-build 단계에서 GNAT 16의 이름 해석·타입 추론 호환성 수정을 적용합니다. 수정은 프로젝트 내부 의존성 캐시에만 적용되며 반복 실행이 가능합니다. 컴파일 호환성 외에 표준 입력 파일 디스크립터, 저장 단축키의 흐름 제어, 터미널 크기 조회도 보정합니다. 이 과정은 원본의 라이선스 고지를 보존합니다.

## 기본 기능

- 월별 달력, 선택 날짜 강조, 오늘 표시, 일기가 있는 날짜의 `*` 표시
- 방향키로 날짜 이동, 이전·다음 달 이동, 오늘로 복귀
- 하루 한 편의 제목과 여러 줄 본문
- 앱 내부 편집기, 커서 이동, 줄바꿈, 백스페이스
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

| 화면 | 키 | 동작 |
| --- | --- | --- |
| 달력 | 방향키 | 하루 / 일주일 이동 |
| 달력 | `[` / `]` | 이전 / 다음 달, 월말 날짜 보정 |
| 달력 | `T` | 오늘로 이동 |
| 달력 | `N` | 선택한 날짜에 새 일기 |
| 달력 | `E` / `Enter` | 선택한 일기 수정, 비어 있으면 새 일기 |
| 달력 | `D` | 삭제 확인 |
| 달력 | `J` / `K` | 본문 아래 / 위 스크롤 |
| 달력 | `Q` | 종료 |
| 편집 | `Tab` | 제목 / 본문 전환 |
| 편집 | 방향키 | 커서 이동 |
| 편집 | `Ctrl+A` / `Ctrl+E` | 줄 처음 / 끝 |
| 편집 | `Backspace` | 커서 앞 문자 삭제 |
| 편집 | `Enter` | 제목에서 본문으로 이동, 본문에서 줄바꿈 |
| 편집 | `Ctrl+S` | 저장 |
| 편집 | `Esc` | 취소, 변경이 있으면 확인 |
| 확인 | `Y` / `N` / `Esc` | 실행 / 취소 / 취소 |

대소문자 단축키를 모두 지원합니다. 제목은 공백만으로 저장할 수 없습니다. 기존 일기에 `N`을 누르면 `E`로 수정하도록 안내합니다.

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
tests/                  Ada 단위·통합 테스트와 Python PTY 테스트
```

의존성은 `application → domain`, `storage → application + domain`, `app → application + storage + Malef`입니다. 각 공유 패키지는 별도 Alire crate와 GPR 프로젝트로 경계를 유지합니다. 파일·환경 변수·시계·터미널 접근은 어댑터에서만 수행합니다.

## 검증

```bash
make test
make smoke
```

`make test`는 날짜 계산, 일기 검증, 편집기, 문자 배치 및 임시 폴더에서의 CRUD·재실행·잠금·저장 실패·손상 데이터 처리를 검사합니다. `make smoke`는 실제 PTY에서 한글 작성·저장·재실행·수정·삭제·확인 창·화면 크기 변경, 작은 화면에서 명령 차단, 터미널 모드 복원과 비대화형 도움말도 검사합니다.

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
