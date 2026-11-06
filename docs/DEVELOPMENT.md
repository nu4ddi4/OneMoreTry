# 개발 운영

플레이어용 문구는 전역 `plain-product-copy` 스킬을 적용합니다. 제목·동작·상태만 짧게 남기며 기획 의도와 공략은 내부 문서에서 다룹니다.

Godot 4.6.3 Standard와 GDScript를 사용합니다. 소스 편집과 로컬 플레이에 .NET은 필요하지 않습니다.

## 브랜치

현재 0.x 개발은 `main`에서 직접 작업하고 검사 후 push합니다. 기능 브랜치, PR, 베타 선행 병합은 필수가 아닙니다. 사용자 요청이 있으면 별도 브랜치나 PR을 사용할 수 있습니다.

```bash
git switch main
git pull --ff-only origin main
# 구현 및 관련 검사 후 커밋
git push origin main
```

`beta`는 사용자가 별도 미리보기 배포를 원할 때 사용합니다. 메인 변경을 매번 베타와 동기화할 필요는 없습니다. 기존 정식·베타 업데이트 채널과 다운그레이드 방지 규칙은 유지합니다. 강제 push는 사용하지 않습니다.

`Godot Windows`는 main/beta push와 선택적으로 만든 PR에서 자동 회귀·전체 연속 코스 통과·Windows 내보내기·설치·실행을 검사합니다. push/수동 실행의 모든 검사를 통과한 빌드만 릴리스합니다. PR 검사는 게시하지 않습니다. 기존의 베타 선행 PR 제한은 제거했습니다.

서버 측 브랜치 보호는 연결 앱의 관리 권한 부족(HTTP 403)으로 미적용 상태입니다. `tools/configure_branch_protection.py`는 필요할 때 관리 권한이 있는 CLI에서 실행하며, 직접 push를 허용하고 강제 push·브랜치 삭제를 막는 설정입니다. 자세한 검증 결과는 `docs/VALIDATION.md`에 기록합니다.

## 실행 및 검사

Godot에서 `project.godot`을 열고 F6이 아닌 F5로 메인 씬을 실행합니다.

```bash
godot --headless --editor --import --quit
godot --headless --fixed-fps 120 --script tests/run_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/course_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/gameplay_revision_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/fairness_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/elements_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/movement_scope_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/auto_update_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/wrong_routes.gd -- --test
godot --headless --fixed-fps 120 --script tests/playthrough.gd -- --test
godot --headless --fixed-fps 30 --script tests/replay.gd -- --test --pauses
godot --headless --fixed-fps 120 --script tests/playthrough.gd -- --test --fast
godot --headless --fixed-fps 30 --script tests/replay.gd -- --test --fast --pauses
python3 tools/test_updater.py
godot --headless --script tests/display_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/inspection_tests.gd -- --test
```

테스트는 별도 기록 파일을 사용해 실제 플레이 기록을 바꾸지 않습니다. 단위·시스템 검사는 상태 전이를 위해 위치를 직접 설정합니다. `playthrough.gd`는 시작부터 실제 이동·점프·오르내리기 입력만으로 40개 연속 노데스 클리어, 체크포인트 2개, 비밀 별 획득을 확인합니다. `--room=N`은 개발용 개별 구간 재현이며 전체 통과로 집계하지 않습니다.

## Windows 내보내기

Godot 4.6.3의 공식 Export Templates를 설치합니다. `python3 tools/fetch_templates.py`로 Windows 템플릿만 선택 설치할 수도 있습니다. 공식 배포 ZIP의 Range 요청을 사용하고 압축 파일에 기록된 크기와 CRC를 확인합니다.

```bash
mkdir -p build/windows
godot --headless --export-release 'Windows Desktop' build/windows/OneMoreTry.exe
```

리소스는 실행 파일에 포함됩니다. 배포 시 실행 안내와 폰트·Godot 라이선스를 함께 전달합니다. GitHub Actions의 `OneMoreTry-Windows-x64` artifact가 이 구성을 자동 생성합니다.

## 설치 및 릴리스

Windows에 Inno Setup 6을 설치하고 위 내보내기 결과에 `docs/PLAY_WINDOWS.txt`를 `README.txt`로, 라이선스를 `licenses` 폴더에 복사한 뒤 컴파일합니다. 수동 배포 폴더에도 `tools/build_windows_updater.ps1`로 교체 도구와 manifest를 먼저 준비합니다.

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=0.6.0 /DBaseVersion=0.6.0 installer/OneMoreTry.iss
./tools/test_installer.ps1  # 일회용 Windows 테스트 환경에서만 실행: 테스트 기록을 생성합니다.
```

결과는 `build/installer/OneMoreTry-v0.6.0-Windows-x64-Setup.exe`입니다. 고정 AppId와 사용자별 설치 경로를 사용해 다음 버전 설치 시 갱신합니다. 시작 메뉴·선택형 바탕 화면 바로 가기와 제거 프로그램을 제공합니다. 기록은 Godot의 기존 사용자 데이터 폴더에 두고 제거 시에도 삭제하지 않습니다. 설치 프로그램은 Restart Manager로 실행 중인 게임을 감지하며 재부팅이나 자동 게임 재실행을 요구하지 않습니다. 코드 서명은 현재 미적용입니다.

`project.godot`의 숫자 버전과 `export_presets.cfg`의 파일·제품 버전을 함께 올립니다. `main`에 직접 push하면 검증 후 정식 릴리스를 자동 게시합니다. 별도 베타 배포가 필요하면 `beta`에 반영해 검증 후 사전 릴리스를 게시합니다.

- `beta`: `v0.6.0-beta`처럼 `-beta`가 붙은 GitHub 사전 릴리스. 실행 파일 내부 버전과 설치 파일명에도 같은 접미사를 붙입니다.
- `main`: `v0.6.0`처럼 정식 릴리스. GitHub의 latest는 정식만 사용합니다.
- 같은 버전으로 다시 push하면 기존 공개 릴리스를 변경하지 않습니다. 새 배포에는 숫자 버전을 올립니다. PR 검사는 릴리스를 게시하지 않습니다.

`Godot Windows` Actions는 회귀·전체 통과·실제 HTTP 검사, Windows 설치·재설치·실행·제거와 기록 보존을 통과한 동일한 EXE와 설치 파일을 게시합니다. ZIP·Setup 각각 SHA-256 파일을 제공합니다. `tools/release_config.py`가 소스/Windows 버전 일치 여부를 검사하고 빌드 때만 채널 버전을 적용합니다. `release-info` artifact로 버전·채널·원본 커밋을 전달해 베타 파일의 정식 게시를 막습니다.

실패한 배포는 해당 브랜치의 `Godot Windows` 수동 실행으로 재시도합니다. 선택 입력 `release_tag`는 브랜치와 프로젝트 버전에 정확히 맞아야 합니다. `verified_run_id` 복구는 성공한 push/수동 실행의 Windows 검사, 조상 커밋과 동일한 게임 입력, 동일 채널·버전의 manifest를 모두 확인한 뒤 artifact를 재사용합니다. PR 빌드나 다른 채널의 artifact는 사용할 수 없습니다. 로컬 토큰은 앱에 넣지 않습니다.

게임의 **업데이트**에서 정식·베타 채널과 **자동 업데이트**를 고른다. `user://update_settings.cfg`에 두 값을 함께 저장하며 기존 채널 전용 설정도 읽는다. 자동 업데이트 기본값은 켜짐이며 Windows 배포본 실행마다 확인/다운로드한다. 꺼 두면 네트워크 요청 없이 시작하고 업데이트 창에서 수동 확인한다. 편집기와 `--test`는 자동 네트워크/실행을 막는다. 정식은 `/releases/latest`, 베타는 `/releases?per_page=100`에서 선택한다.

숫자 버전을 우선 비교하고 같은 숫자에서는 `X.Y.Z-beta < X.Y.Z`다. 채널을 전환해도 다운그레이드하지 않는다. 채널 변경은 요청·부분 파일·이전 준비 상태를 취소하고 자동 업데이트 설정은 보존한다.

0.6.0부터 설치 EXE 대신 `OneMoreTry-vX.Y.Z-Windows-x64.zip`의 정확한 이름·크기·GitHub SHA-256을 확인해 다운로드한다. 설치 파일은 최초 설치와 구버전 부트스트랩을 위해 계속 배포한다. 0.5.1 이하의 이미 설치된 실행 파일에는 ZIP 교체 코드가 없으므로 0.6.0으로 한 번 설치해야 한다. ZIP 배포본도 같은 폴더에서 업데이트하며 설치형으로 바뀌지 않는다.

다운로드가 끝나면 타이틀 메뉴에서 자동 적용한다. 플레이·일시정지·결과·기록 화면과 열린 업데이트/종료 창에서는 적용하지 않는다. 자동 업데이트를 끄면 **적용하고 다시 시작**으로 수동 적용한다. 기록 저장 실패 시 종료/적용을 차단한다.

`OneMoreTry.Update.exe`는 캐시의 별도 경로로 복사해 실행하며 셸/설치 프로그램/관리자 권한을 사용하지 않는다. 게임 종료를 기다리고 ZIP 크기·SHA·버전·채널을 다시 검증한다. 허용된 파일만 임시 추출하고 게임 EXE는 마지막에 원자적으로 교체한다. 기존 파일은 백업하며 새 게임의 초기화 완료 토큰/버전을 확인한 후 확정한다. 복사/재시작/초기화 실패는 이전 파일로 복구하고 이전 게임을 다시 연다. 실패 결과를 다음 실행에서 한 번 소비해 자동 재시작 루프를 막는다. 고정 저장소의 태그와 SHA-256으로 확인한 파일만 사용한다.

네이티브 교체 도구와 ZIP 형식, Windows 실제 재시작·복구 검사는 [자동 업데이트](AUTO_UPDATE.md)를 따른다. CI는 Windows 기본 .NET Framework 컴파일러로 교체 도구를 만들고 검사한 뒤 같은 도구를 설치본/ZIP에 넣는다. `.NET` Godot 버전으로 엔진을 바꾸지 않는다.

## 구조와 확장

`scripts/player.gd`: 이동, 100ms 코요테 타임, 120ms 점프 버퍼, 가변 점프. 물리 120Hz.

`scripts/course.gd`: 40개 구간의 연속 지형·이동 표면·아이템 배치 데이터.

`scripts/encounter.gd`: 구간별 센서·시간표·위험 접촉·스위치와 공유 시계.

`scripts/surface.gd`: 충돌을 가진 이동/붕괴/컨베이어 표면과 운반 변위.

`scripts/device.gd`: 충전 아이템·미끼/열쇠·점프대·사슬의 실제 접촉과 입력.

`scripts/world.gd`: 연속 코스 지형, 배경, 체크포인트와 출구의 시각화.

`scripts/game.gd`: 메뉴, HUD, 사망·복귀, 체크포인트, 클리어, 일시정지.

`scripts/records.gd`: 버전 검사와 형식 검증, 임시 파일을 통한 기록 교체.

`scripts/updater.gd`: GitHub 채널/자동 설정·ZIP 다운로드·SHA-256 검증·네이티브 교체 도구 인계.

`scripts/sound.gd`, `tools/make_audio.py`: 자체 제작 칩튠 BGM과 효과음. `OneMoreSans.otf`는 SIL OFL의 Noto Sans CJK KR에서 한국어와 사용 문자를 추출한 폰트입니다.

v0.6.0은 단일 씬에서 40개 구간을 끊김 없이 진행합니다. 체크포인트 2개 외에 구간 전환이나 자동 저장 지점을 생성하지 않습니다. 구체적인 구현과 검증 범위는 `docs/COURSE_IMPLEMENTATION.md`를 따릅니다.

## 화면 크기 검증

960×540은 기준 설계 크기입니다. `canvas_items`·fractional·expand로 창을 채우며 넓은 화면에서는 가로 영역, 세로 비율이 큰 화면에서는 세로 영역을 확장합니다. 메뉴는 기준 영역을 중앙에 배치하고 HUD는 현재 논리 뷰포트 너비에 맞춥니다. 카메라 경계와 배경·지면 그림도 뷰포트 크기를 사용합니다. 물리 지형과 함정 좌표는 동일합니다.

`tests/display_tests.gd`는 640×360~3840×2160의 10개 창 크기에서 여백·잘림·메뉴/HUD/기록/결과 위치·카메라 경계·업데이트 창 재배치를 검사합니다. 데스크톱 렌더 화면 캡처는 `-- --test --capture`, 창 관리자에서 F11 모드 복귀까지 검사할 때는 `-- --test --capture --window-modes`로 실행합니다. 캡처 폴더는 `build/display-audit`입니다. Windows CI는 설치·재설치·제거 외에 640×360과 3840×1080 크기로 배포 EXE를 기동합니다.

## 검증 도구

구간/좌표 이동과 자유 이동은 [검증 모드](INSPECTION.md)를 참조합니다. 키 조합은 인증 수단이 아니며 일반 배포본에도 기능을 포함합니다. 검증 중에는 별도 기록 파일을 사용하고 프로그램 재실행 전까지 정상 기록으로 돌아가지 않습니다.

## 공통 요소와 Android

요소 종류·그룹·재질·접촉 규칙·머리 공간은 `scripts/elements.gd`와 [요소 규칙](ELEMENT_RULES.md)을 따른다. 지형·발판·장치·위험물을 추가할 때 같은 렌더러와 종류를 사용한다. 플랫폼별 게임 로직을 복제하지 않는다. Android의 추가 입력/기기 검수와 권장 도입 순서는 [Android 검토](ANDROID_PLAN.md)에 정리했다.

벽타기 허용 지형은 `course.gd`의 `climbable_solids`로 지정하며, 실제 측면 콜라이더가 `climbable_walls`에 속할 때만 오르기/벽 점프/감속을 허용한다. 시각 정리만으로 점프 난이도를 바꾸지 않는 기준은 [요소 규칙](ELEMENT_RULES.md)을 따른다.
