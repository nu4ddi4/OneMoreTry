# 개발 운영

Godot 4.6.3 Standard와 GDScript를 사용합니다. 소스 편집과 로컬 플레이에 .NET은 필요하지 않습니다.

## 브랜치

- `main`: 검증한 Windows 배포본. `beta`에서 올라오는 PR만 허용합니다.
- `beta`: 통합 및 플레이 테스트. `feature/*`, `fix/*`, `chore/*`에서 PR을 올립니다.
- `feature/<기능>`: `beta`의 최신 커밋에서 분기합니다. 예: `feature/stage-02`, `feature/moving-spikes`.

```bash
git switch beta
git pull --ff-only origin beta
git switch -c feature/stage-02
# 구현 및 검증 후 커밋
git push -u origin feature/stage-02
# GitHub에서 base=beta인 PR 생성
```

기능 PR을 `beta`에 병합하고, 통합 검증을 마치면 `beta → main` 배포 PR을 병합합니다. 이력을 보존하는 merge commit을 사용합니다. 배포 후 `main`을 `beta`에 fast-forward로 동기화해 다음 배포 PR에 과거 병합 커밋이 쌓이지 않게 합니다. 이 동기화는 PR이 아닌 브랜치 이동이므로 보호 규칙에서 막히는 경우 `chore/sync-main`을 `main`에서 분기해 `beta`에 PR을 올립니다. 강제 push는 사용하지 않습니다.

`Godot Windows` 워크플로가 PR의 방향을 검사하고, 자동 회귀 검사·전체 스테이지 통과·Windows 내보내기·Windows 네이티브 실행을 검증합니다. 서버 측 강제 보호는 연결 앱의 관리 권한 부족(HTTP 403)으로 미적용 상태입니다. 현재 운영 규칙을 따라 PR로 병합하며, 관리 권한이 있는 CLI에서 `python3 tools/configure_branch_protection.py`를 실행하면 필수 검사와 직접 push 제한을 적용할 수 있습니다. 자세한 결과는 `docs/VALIDATION.md`에 기록합니다.

## 실행 및 검사

Godot에서 `project.godot`을 열고 F6이 아닌 F5로 메인 씬을 실행합니다.

```bash
godot --headless --editor --import --quit
godot --headless --fixed-fps 120 --script tests/run_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/playthrough.gd -- --test
python3 tools/test_updater.py
```

테스트는 별도 기록 파일을 사용해 실제 플레이 기록을 바꾸지 않습니다. 단위·시스템 검사는 상태 전이를 위해 위치를 직접 설정합니다. `playthrough.gd`는 시작 지점부터 실제 이동과 점프 입력만으로 노데스 클리어, 체크포인트 2개, 비밀 별 획득을 확인합니다.

## Windows 내보내기

Godot 4.6.3의 공식 Export Templates를 설치합니다. `python3 tools/fetch_templates.py`로 Windows 템플릿만 선택 설치할 수도 있습니다. 공식 배포 ZIP의 Range 요청을 사용하고 압축 파일에 기록된 크기와 CRC를 확인합니다.

```bash
mkdir -p build/windows
godot --headless --export-release 'Windows Desktop' build/windows/OneMoreTry.exe
```

리소스는 실행 파일에 포함됩니다. 배포 시 실행 안내와 폰트·Godot 라이선스를 함께 전달합니다. GitHub Actions의 `OneMoreTry-Windows-x64` artifact가 이 구성을 자동 생성합니다.

## 설치 및 릴리스

Windows에 Inno Setup 6을 설치하고 위 내보내기 결과에 `docs/PLAY_WINDOWS.txt`를 `README.txt`로, 라이선스를 `licenses` 폴더에 복사한 뒤 컴파일합니다.

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=0.2.0 installer/OneMoreTry.iss
./tools/test_installer.ps1  # 일회용 Windows 테스트 환경에서만 실행: 테스트 기록을 생성합니다.
```

결과는 `build/installer/OneMoreTry-v0.2.0-Windows-x64-Setup.exe`입니다. 고정 AppId와 사용자별 설치 경로를 사용해 다음 버전 설치 시 갱신합니다. 시작 메뉴·선택형 바탕 화면 바로 가기와 제거 프로그램을 제공합니다. 기록은 Godot의 기존 사용자 데이터 폴더에 두고 제거 시에도 삭제하지 않습니다. 설치 프로그램은 Restart Manager로 실행 중인 게임을 감지하며 재부팅이나 자동 게임 재실행을 요구하지 않습니다. 코드 서명은 현재 미적용입니다.

`project.godot`의 버전과 `export_presets.cfg`의 파일·제품 버전을 함께 올리고 `feature/* → beta → main` PR을 병합합니다. `main` push에서 자동 회귀·업데이트 HTTP 검사, Windows 설치·재설치·실행·제거와 기록 보존을 통과한 **동일한** EXE 및 설치 파일을 정식 릴리스로 게시합니다. 설치형 EXE와 포터블 ZIP 각각에 SHA-256 파일을 제공합니다. 이미 게시한 버전은 건드리지 않습니다. 실패한 배포는 `main`의 `Godot Windows` 수동 실행에서 `release_tag=v0.2.0`처럼 프로젝트 버전을 지정해 재시도할 수 있습니다. `beta`에서는 릴리스를 게시하지 않습니다.

Windows runner가 멈춘 경우 수동 배포의 `verified_run_id`에 이전에 성공한 `Godot Windows` 실행 번호를 지정해 검증한 artifact를 재사용할 수 있습니다. 성공 상태와 Windows 검사, 현재 main의 조상 커밋 여부, 게임·리소스·설치 및 배포 안내 파일이 동일한지 확인한 후에만 게시합니다. 배포 자동화 복구만 변경한 커밋도 이 경로를 사용할 수 있으며 게임 입력이 달라지면 거부합니다. 로컬 업로드 토큰을 앱에 넣지 않습니다.

업데이트 공급자는 공개 저장소 `nu4ddi4/side-scroller-game`의 `/releases/latest`입니다. `scripts/updater.gd`는 Windows 배포본 시작 시 한 번 확인하며, 편집기와 `--test`에서는 자동 네트워크 요청을 하지 않습니다. 정식 SemVer 태그와 정확한 설치 파일명·크기·GitHub asset digest를 확인한 뒤 사용자 요청 시 `.part`로 내려받습니다. SHA-256과 크기가 맞으면 `.exe`로 바꾸고, 별도 설치 확인 후 다시 검증해 직접 프로세스로 실행합니다. 셸이나 저장소 인증 토큰을 사용하지 않습니다. 403·오프라인·타임아웃·손상 파일은 재시도 가능한 상태로 처리하며 취소 시 부분 파일을 지웁니다. 게임 기록을 저장한 후 게임이 종료되고 설치 UI가 진행됩니다. 다운로드 파일은 사용자 데이터의 `updates` 폴더에 남습니다.

`tools/test_updater.py`는 로컬 HTTP 서버로 버전 비교, 메타데이터, 정상·변조·불완전·과대 다운로드와 취소를 실제 Godot HTTPRequest로 검증합니다. `tools/test_installer.ps1`는 한글·공백 경로에 설치·재설치하고 실제 EXE를 실행한 뒤 제거하며, 각 단계에서 사용자 기록을 확인합니다. 기존 v0.1.0 사용자는 새 설치 파일을 한 번 수동 실행해야 합니다. ZIP 사용자가 업데이트 설치를 선택하면 설치형이 되며 이후에는 시작 메뉴의 설치본을 실행합니다.

## 구조와 확장

`scripts/player.gd`: 이동, 100ms 코요테 타임, 120ms 점프 버퍼, 가변 점프. 물리 120Hz.

`scripts/trap.gd`: 붕괴·돌출·낙하·고정 가시. 경고와 충돌 영역을 분리합니다. 난수는 장식 효과에만 사용합니다.

`scripts/world.gd`: 스테이지 지형, 배경, 체크포인트와 출구의 시각화.

`scripts/game.gd`: 메뉴, HUD, 사망·복귀, 체크포인트, 클리어, 일시정지.

`scripts/records.gd`: 버전 검사와 형식 검증, 임시 파일을 통한 기록 교체.

`scripts/updater.gd`: GitHub 정식 버전 확인·다운로드·SHA-256 검증·설치 실행.

`scripts/sound.gd`, `tools/make_audio.py`: 자체 제작 칩튠 BGM과 효과음. `OneMoreSans.otf`는 SIL OFL의 Noto Sans CJK KR에서 한국어와 사용 문자를 추출한 폰트입니다.

다음 작업은 스테이지 정보를 리소스로 분리하고 2~5 스테이지를 확장하는 것입니다. 이후 이동 장애물, 가짜 코인과 출구, 조건부 심리전 함정을 추가합니다. 현재 MVP의 기록은 스테이지 1개 기준입니다.
