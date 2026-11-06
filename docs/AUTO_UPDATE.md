# Windows 자동 업데이트 — 0.6.0

게임 로직/코스 ID는 바꾸지 않는다. 설치본과 휴대용 ZIP은 같은 교체 도구를 사용한다. 최초 설치용 Inno Setup은 계속 제공하지만 0.6.0 이후 런타임 업데이트에서 실행하지 않는다. 0.5.1 이하의 기존 EXE에는 이 기능이 없으므로 이번 버전으로 한 번 설치/교체해야 한다.

## 설정과 실행 흐름

`update_settings.cfg`의 `[updates]`에 `channel`과 `automatic`을 함께 저장한다. 기존 채널 설정은 유지하며 자동 업데이트 기본값은 true다. 값이 꺼져 있으면 시작 시 네트워크 요청을 하지 않는다. 업데이트 창의 수동 확인·다운로드·적용은 사용할 수 있다.

Windows 배포본은 실행할 때 선택 채널을 확인한다. 새 ZIP의 크기와 GitHub SHA-256을 확인하고 `.part`로 다운로드한다. 검증을 마친 파일만 READY가 된다. 자동 업데이트가 켜져 있고 타이틀 메뉴가 열려 있을 때만 적용한다. 플레이·일시정지·결과·기록·열린 설정/종료 창은 적용을 미룬다. 수동 적용 버튼은 적용 후 재시작을 명시한다. 기록 저장 실패는 종료 전에 처리한다.

버전 규칙은 숫자 비교 후 동일 숫자에서 beta < stable다. 채널 전환으로 다운그레이드하지 않으며, 최신 태그에 ZIP/유효한 digest가 없으면 오류로 표시한다. 다운로드 중 설정을 끄면 요청/부분 파일을 취소한다. 채널 변경은 이전 채널의 준비 파일 선택을 버리며 자동 설정을 초기화하지 않는다.

## 네이티브 교체

`tools/windows-updater/Updater.cs`는 Windows .NET Framework 컴파일러로 `OneMoreTry.Update.exe`를 만든다. 엔진은 Godot Standard/GDScript를 유지한다. 게임은 도구를 `user://updates/apply-PID-TICKS/`로 복사하고 `handoff.json`을 전달한다. 전달 값은 설치 경로, ZIP 경로/크기/SHA, 현재/목표 버전, 채널과 부모 PID다. 릴리스의 임의 URL이나 명령 문자열을 실행하지 않는다.

1. 설치 폴더의 `.update.lock`으로 중복 적용을 막고 현재 manifest가 전달한 버전과 같은지 확인한다. 목표 버전은 반드시 더 높아야 한다.
2. 다운로드 파일을 쓰기 공유 없이 열어 크기/SHA를 다시 검증한다. 작업 폴더에 전체 추출 후 버전/채널/schema를 확인한다. 원래 게임은 아직 교체하지 않는다.
3. 부모 PID가 해당 설치 경로의 게임인지 확인하고 최대45초 종료를 기다린다. 다른 프로세스를 강제 종료하지 않는다.
4. 파일을 원자적으로 교체하며 백업한다. 리소스를 포함한 게임 EXE는 마지막에 교체한다. 캐시에서 실행하므로 교체 도구 자신도 갱신된다.
5. 새 게임에 무작위 시작 토큰을 전달한다. 게임 UI/월드 초기화를 마치면 캐시에 실제 런타임 버전을 기록한다. 도구는 최대20초 안에 일치하는 토큰/버전을 확인한 뒤 성공으로 확정한다.
6. 복사/재시작/초기화 실패는 역순으로 백업을 복원하고 이전 게임을 다시 연다. 응답하지 않는 새 자식 게임은 도구가 시작한 그 프로세스만 종료한 뒤 복구한다. 실패 결과를 다음 실행에서 한 번 읽어 같은 실행의 자동 재시도를 막는다. 자동 업데이트 설정 자체는 보존한다. 복구 실패 시 백업을 삭제하지 않는다.

설치본은 설치 경로가 일치하는 HKCU 제거 항목의 DisplayVersion도 갱신한다. 휴대용 ZIP은 설치 등록을 만들지 않는다. 기록, 업데이트 설정, 바로가기와 제거 프로그램은 ZIP 파일 허용 목록에 포함하지 않는다.

## ZIP 계약과 CI

허용 파일은 `OneMoreTry.exe`, `OneMoreTry.Update.exe`, `update-manifest.json`, `README.txt`와 `licenses/Godot.txt`, `licenses/Godot-third-party.txt`, `licenses/NotoSansCJK.txt`다. 경로 탈출·링크·대소문자 중복·알 수 없는 파일을 거부한다. 다운로드는256MiB, 추출 전체는512MiB 이하다. manifest는 `{schema:1,version:"X.Y.Z[-beta]",channel:"stable|beta"}`이며 실제 런타임 버전과 일치해야 한다.

Linux 빌드는 Godot EXE/라이선스를 내보낸다. Windows 작업에서 `tools/build_windows_updater.ps1`로 도구를 컴파일하고 manifest를 쓴 뒤 단위 검사와 실제 Godot 재시작/복구를 검사한다. 검사한 전체 폴더를 `OneMoreTry-Windows-ready` artifact로 올린다. 설치 프로그램과 공개 ZIP 모두 이 폴더를 사용한다. 기존 Linux 중간 artifact를 ZIP으로 게시하지 않는다. 설치 EXE와 ZIP 양쪽의 GitHub digest가 있어야 공개한다.

로컬 공통 도구 검사: `dotnet run --project tools/windows-updater/Tests.csproj` (.NET8 SDK는 개발 검사에만 사용). 실제 Windows 파일 잠금과 Godot 시작 토큰/실패 복구는 Windows CI에서 추가 검사한다. Windows 설치·재설치·실행·제거 검사는 별도로 유지한다. 사용자 데이터는 기존 위치를 유지하므로 코스 최고 기록과 설정은 바뀌지 않는다.
