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

`Godot Windows` 워크플로가 PR의 방향을 검사하고, 자동 회귀 검사·전체 스테이지 통과·Windows 내보내기·Windows 네이티브 실행을 검증합니다. 실제 GitHub 보호 설정 여부는 `docs/VALIDATION.md`에 기록합니다.

## 실행 및 검사

Godot에서 `project.godot`을 열고 F6이 아닌 F5로 메인 씬을 실행합니다.

```bash
godot --headless --editor --import --quit
godot --headless --fixed-fps 120 --script tests/run_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/playthrough.gd -- --test
```

테스트는 별도 기록 파일을 사용해 실제 플레이 기록을 바꾸지 않습니다. 단위·시스템 검사는 상태 전이를 위해 위치를 직접 설정합니다. `playthrough.gd`는 시작 지점부터 실제 이동과 점프 입력만으로 노데스 클리어, 체크포인트 2개, 비밀 별 획득을 확인합니다.

## Windows 내보내기

Godot 4.6.3의 공식 Export Templates를 설치합니다. `python3 tools/fetch_templates.py`로 Windows 템플릿만 선택 설치할 수도 있습니다. 공식 배포 ZIP의 Range 요청을 사용하고 압축 파일에 기록된 크기와 CRC를 확인합니다.

```bash
mkdir -p build/windows
godot --headless --export-release 'Windows Desktop' build/windows/OneMoreTry.exe
```

리소스는 실행 파일에 포함됩니다. 배포 시 실행 안내와 폰트·Godot 라이선스를 함께 전달합니다. GitHub Actions의 `OneMoreTry-Windows-x64` artifact가 이 구성을 자동 생성합니다.

## 구조와 확장

`scripts/player.gd`: 이동, 100ms 코요테 타임, 120ms 점프 버퍼, 가변 점프. 물리 120Hz.

`scripts/trap.gd`: 붕괴·돌출·낙하·고정 가시. 경고와 충돌 영역을 분리합니다. 난수는 장식 효과에만 사용합니다.

`scripts/world.gd`: 스테이지 지형, 배경, 체크포인트와 출구의 시각화.

`scripts/game.gd`: 메뉴, HUD, 사망·복귀, 체크포인트, 클리어, 일시정지.

`scripts/records.gd`: 버전 검사와 형식 검증, 임시 파일을 통한 기록 교체.

`scripts/sound.gd`, `tools/make_audio.py`: 자체 제작 칩튠 BGM과 효과음. `OneMoreSans.otf`는 SIL OFL의 Noto Sans CJK KR에서 한국어와 사용 문자를 추출한 폰트입니다.

다음 작업은 스테이지 정보를 리소스로 분리하고 2~5 스테이지를 확장하는 것입니다. 이후 이동 장애물, 가짜 코인과 출구, 조건부 심리전 함정을 추가합니다. 현재 MVP의 기록은 스테이지 1개 기준입니다.
