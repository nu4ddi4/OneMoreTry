# MVP 검증

## 로컬 자동 검사

Godot 4.6.3, Linux 개발 환경에서 다음 검사를 통과했습니다.

- 회귀 검사 **43개 통과**: 이동·가변 점프·코요테 타임·점프 버퍼·경계 충돌, 함정 경고와 충돌, 0.5초 이내 재시작, 중복 사망 방지, 체크포인트 유지와 역주행, 일시정지, 클리어, 최고 기록과 손상된 저장 파일 처리.
- 일반 이동·점프 입력만 사용하는 전체 스테이지 통과: **14.81초, 실패 0회, 체크포인트 2개 및 비밀 별 획득**. 이 테스트는 플레이어 위치를 직접 바꾸지 않습니다.
- 소프트웨어 OpenGL에서 타이틀·플레이·일시정지·클리어·기록 화면을 캡처하고 한국어 표시와 화면 배치를 확인했습니다.
- Windows x64 release EXE 내보내기 성공. 리소스는 EXE에 포함합니다.

테스트용 기록은 실제 사용자 기록과 분리됩니다. 이 기록은 테스트 경로를 재현하는 결과이며 일반 사용자의 예상 클리어 시간은 아닙니다.

## GitHub 검증

`Godot Windows` 워크플로가 PR마다 `Branch policy`, `Test & export Windows`, `Windows launch` 검사를 실행합니다. Windows 실행 검사는 Windows runner에서 배포 EXE를 headless로 실행하고 종료 코드와 Godot 오류 로그를 확인합니다. 화면 캡처는 Linux OpenGL에서 수행하며 Windows에서의 수동 키보드·오디오·GPU 호환성 확인은 별도 플레이 테스트가 필요합니다.

2026-10-30 [최초 원격 검증](https://github.com/nu4ddi4/side-scroller-game/actions/runs/41019589797)에서 세 작업이 모두 성공했습니다. Windows runner에서 실제 내보낸 `OneMoreTry.exe`의 종료 코드 0과 런타임 오류 없음도 확인했습니다. 이후 커밋과 병합 커밋에도 같은 워크플로가 재실행됩니다.

`main`과 `beta` 브랜치를 생성했고, `feature/godot-mvp → beta → main` PR 흐름으로 최초 배포합니다. CI에서 잘못된 PR 방향을 실패 처리합니다.

서버 측 강제 보호 설정은 연결된 GitHub 앱의 권한 제한으로 적용하지 못했습니다. `PUT /repos/nu4ddi4/side-scroller-game/branches/beta/protection`이 **HTTP 403: Resource not accessible by integration**을 반환했습니다. 따라서 현재 CI 실패 상태라도 관리자가 병합하거나 직접 push하는 동작까지 강제로 차단하지는 못합니다. 관리 권한이 있는 GitHub CLI에서 `python3 tools/configure_branch_protection.py`를 실행하면 두 브랜치의 PR 필수화, 세 CI 검사 필수화, 강제 push·삭제 금지를 적용할 수 있습니다. 승인자 수는 0으로 두어 단독 개발자도 검사 통과 후 병합할 수 있습니다.
