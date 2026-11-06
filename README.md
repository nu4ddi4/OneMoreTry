# 한 번만 더!

**[Windows 다운로드](https://github.com/nu4ddi4/side-scroller-game/releases/latest)**

![타이틀 화면](docs/images/title.png)

## 실행

설치 파일을 실행한 뒤 시작 메뉴에서 **One More Try!**를 여세요. ZIP은 압축을 풀고 `OneMoreTry.exe`를 실행하면 됩니다.

Windows 10/11 x64 · OpenGL 3.3

## 조작

| 키 | 동작 |
| --- | --- |
| A / D, ← / → | 이동 |
| Space | 점프 |
| W / S, ↑ / ↓ | 오르내리기 |
| R | 다시하기 |
| ESC | 일시정지 |
| M | 음소거 |
| F11 | 전체 화면 |

![플레이 화면](docs/images/gameplay.png)

## 업데이트

메뉴의 **업데이트**에서 정식·베타 채널과 **자동 업데이트**를 설정합니다. 자동 업데이트가 켜져 있으면 실행할 때 확인하고 새 버전을 적용한 뒤 다시 시작합니다. 플레이 중에는 적용을 미룹니다. 꺼 두면 수동으로 확인하고 **적용하고 다시 시작**을 선택할 수 있습니다. 다운그레이드는 하지 않습니다.

0.5.1 이하에서는 0.6.0을 한 번 설치해 주세요. 이후 업데이트에는 설치 화면이 뜨지 않습니다.

## 개발

Godot 4.6.3에서 `project.godot`을 엽니다.

```bash
godot --headless --editor --import --quit
godot --headless --fixed-fps 120 --script tests/run_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/course_tests.gd -- --test
godot --headless --fixed-fps 120 --script tests/wrong_routes.gd -- --test
godot --headless --fixed-fps 120 --script tests/playthrough.gd -- --test
python3 tools/test_updater.py
```

[개발 문서](docs/DEVELOPMENT.md) · [설계](docs/DESIGN.md) · [검증](docs/VALIDATION.md)

라이선스: `assets/fonts/LICENSE.txt`, `docs/GODOT_LICENSE.txt`, `docs/GODOT_COPYRIGHT.txt`.
