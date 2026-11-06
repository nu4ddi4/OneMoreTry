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

Windows에 Inno Setup 6을 설치하고 위 내보내기 결과에 `docs/PLAY_WINDOWS.txt`를 `README.txt`로, 라이선스를 `licenses` 폴더에 복사한 뒤 컴파일합니다.

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=0.5.0 /DBaseVersion=0.5.0 installer/OneMoreTry.iss
./tools/test_installer.ps1  # 일회용 Windows 테스트 환경에서만 실행: 테스트 기록을 생성합니다.
```

결과는 `build/installer/OneMoreTry-v0.5.0-Windows-x64-Setup.exe`입니다. 고정 AppId와 사용자별 설치 경로를 사용해 다음 버전 설치 시 갱신합니다. 시작 메뉴·선택형 바탕 화면 바로 가기와 제거 프로그램을 제공합니다. 기록은 Godot의 기존 사용자 데이터 폴더에 두고 제거 시에도 삭제하지 않습니다. 설치 프로그램은 Restart Manager로 실행 중인 게임을 감지하며 재부팅이나 자동 게임 재실행을 요구하지 않습니다. 코드 서명은 현재 미적용입니다.

`project.godot`의 숫자 버전과 `export_presets.cfg`의 파일·제품 버전을 함께 올립니다. `main`에 직접 push하면 검증 후 정식 릴리스를 자동 게시합니다. 별도 베타 배포가 필요하면 `beta`에 반영해 검증 후 사전 릴리스를 게시합니다.

- `beta`: `v0.5.0-beta`처럼 `-beta`가 붙은 GitHub 사전 릴리스. 실행 파일 내부 버전과 설치 파일명에도 같은 접미사를 붙입니다.
- `main`: `v0.5.0`처럼 정식 릴리스. GitHub의 latest는 정식만 사용합니다.
- 같은 버전으로 다시 push하면 기존 공개 릴리스를 변경하지 않습니다. 새 배포에는 숫자 버전을 올립니다. PR 검사는 릴리스를 게시하지 않습니다.

`Godot Windows` Actions는 회귀·전체 통과·실제 HTTP 검사, Windows 설치·재설치·실행·제거와 기록 보존을 통과한 동일한 EXE와 설치 파일을 게시합니다. ZIP·Setup 각각 SHA-256 파일을 제공합니다. `tools/release_config.py`가 소스/Windows 버전 일치 여부를 검사하고 빌드 때만 채널 버전을 적용합니다. `release-info` artifact로 버전·채널·원본 커밋을 전달해 베타 파일의 정식 게시를 막습니다.

실패한 배포는 해당 브랜치의 `Godot Windows` 수동 실행으로 재시도합니다. 선택 입력 `release_tag`는 브랜치와 프로젝트 버전에 정확히 맞아야 합니다. `verified_run_id` 복구는 성공한 push/수동 실행의 Windows 검사, 조상 커밋과 동일한 게임 입력, 동일 채널·버전의 manifest를 모두 확인한 뒤 artifact를 재사용합니다. PR 빌드나 다른 채널의 artifact는 사용할 수 없습니다. 로컬 토큰은 앱에 넣지 않습니다.

게임의 **업데이트 → 채널**에서 정식·베타를 선택합니다. 선택은 기록과 별도인 `user://update_settings.cfg`에 저장하며 재실행해도 유지됩니다. 첫 실행 기본값은 설치한 빌드의 채널입니다. Windows 배포본 시작 시 선택 채널을 확인하고 새 버전 설치 파일을 자동 다운로드합니다. 편집기와 `--test`에서는 자동 네트워크 요청을 하지 않습니다. 정식은 GitHub `/releases/latest`, 베타는 `/releases?per_page=100`에서 최신 유효 베타를 고릅니다.

버전은 숫자 세 부분을 먼저 비교하고 같은 숫자에서는 `X.Y.Z-beta < X.Y.Z`로 비교합니다. 채널을 전환해도 현재 버전보다 높은 버전만 받습니다. 예를 들어 `0.5.0-beta`에서 정식 `0.4.9`는 받지 않으며 정식 `0.5.0`이 나오면 받습니다. 정식 `0.5.0`에서 베타로 바꾸면 `0.5.1-beta` 이상을 기다립니다. 채널 변경 시 이전 요청·부분 파일·설치 대기를 취소합니다.

업데이트는 정확한 태그·설치 파일명·크기·GitHub asset digest를 확인하고 `.part`로 내려받습니다. SHA-256과 크기가 맞으면 `.exe`로 바꿉니다. **설치하고 종료**를 선택하면 기록 저장과 파일 재검증 후 설치 UI를 실행하고 게임을 종료합니다. 셸이나 인증 토큰을 사용하지 않습니다. 403·오프라인·타임아웃·손상 파일은 재시도 가능한 상태로 처리하며 취소 시 부분 파일을 지웁니다.

`tools/test_updater.py`는 로컬 HTTP 서버로 버전 비교, 메타데이터, 정상·변조·불완전·과대 다운로드와 취소를 실제 Godot HTTPRequest로 검증합니다. `tools/test_installer.ps1`는 한글·공백 경로에 설치·재설치하고 실제 EXE를 실행한 뒤 제거하며, 각 단계에서 사용자 기록을 확인합니다. 기존 v0.1.0 사용자는 새 설치 파일을 한 번 수동 실행해야 합니다. ZIP 사용자가 업데이트 설치를 선택하면 설치형이 되며 이후에는 시작 메뉴의 설치본을 실행합니다.

## 구조와 확장

`scripts/player.gd`: 이동, 100ms 코요테 타임, 120ms 점프 버퍼, 가변 점프. 물리 120Hz.

`scripts/course.gd`: 40개 구간의 연속 지형·이동 표면·아이템 배치 데이터.

`scripts/encounter.gd`: 구간별 센서·시간표·위험 접촉·스위치와 공유 시계.

`scripts/surface.gd`: 충돌을 가진 이동/붕괴/컨베이어 표면과 운반 변위.

`scripts/device.gd`: 충전 아이템·미끼/열쇠·점프대·사슬의 실제 접촉과 입력.

`scripts/world.gd`: 연속 코스 지형, 배경, 체크포인트와 출구의 시각화.

`scripts/game.gd`: 메뉴, HUD, 사망·복귀, 체크포인트, 클리어, 일시정지.

`scripts/records.gd`: 버전 검사와 형식 검증, 임시 파일을 통한 기록 교체.

`scripts/updater.gd`: GitHub 채널별 버전 확인·다운로드·SHA-256 검증·설치 실행.

`scripts/sound.gd`, `tools/make_audio.py`: 자체 제작 칩튠 BGM과 효과음. `OneMoreSans.otf`는 SIL OFL의 Noto Sans CJK KR에서 한국어와 사용 문자를 추출한 폰트입니다.

v0.5.0은 단일 씬에서 40개 구간을 끊김 없이 진행합니다. 체크포인트 2개 외에 구간 전환이나 자동 저장 지점을 생성하지 않습니다. 구체적인 구현과 검증 범위는 `docs/COURSE_IMPLEMENTATION.md`를 따릅니다.

## 화면 크기 검증

960×540은 기준 설계 크기입니다. `canvas_items`·fractional·expand로 창을 채우며 넓은 화면에서는 가로 영역, 세로 비율이 큰 화면에서는 세로 영역을 확장합니다. 메뉴는 기준 영역을 중앙에 배치하고 HUD는 현재 논리 뷰포트 너비에 맞춥니다. 카메라 경계와 배경·지면 그림도 뷰포트 크기를 사용합니다. 물리 지형과 함정 좌표는 동일합니다.

`tests/display_tests.gd`는 640×360~3840×2160의 10개 창 크기에서 여백·잘림·메뉴/HUD/기록/결과 위치·카메라 경계·업데이트 창 재배치를 검사합니다. 데스크톱 렌더 화면 캡처는 `-- --test --capture`, 창 관리자에서 F11 모드 복귀까지 검사할 때는 `-- --test --capture --window-modes`로 실행합니다. 캡처 폴더는 `build/display-audit`입니다. Windows CI는 설치·재설치·제거 외에 640×360과 3840×1080 크기로 배포 EXE를 기동합니다.

## 검증 도구

구간/좌표 이동과 자유 이동은 [검증 모드](INSPECTION.md)를 참조합니다. 키 조합은 인증 수단이 아니며 일반 배포본에도 기능을 포함합니다. 검증 중에는 별도 기록 파일을 사용하고 프로그램 재실행 전까지 정상 기록으로 돌아가지 않습니다.

## 공통 요소와 Android

요소 종류·그룹·재질·접촉 규칙·머리 공간은 `scripts/elements.gd`와 [요소 규칙](ELEMENT_RULES.md)을 따른다. 지형·발판·장치·위험물을 추가할 때 같은 렌더러와 종류를 사용한다. 플랫폼별 게임 로직을 복제하지 않는다. Android의 추가 입력/기기 검수와 권장 도입 순서는 [Android 검토](ANDROID_PLAN.md)에 정리했다.
