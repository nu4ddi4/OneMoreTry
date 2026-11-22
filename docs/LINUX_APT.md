# Linux 설치와 업데이트

Debian·Ubuntu의 amd64 패키지입니다. 데스크톱 메뉴의 **한 번만 더!** 또는 터미널의 `onemoretry`로 실행합니다.

## 내려받은 파일로 설치

```sh
sudo apt install ./onemoretry_0.8.1-2_amd64.deb
```

실제 받은 파일명을 사용합니다. PR에서 내려받은 빌드는 Debian 버전명에 `~preview`가 들어가므로 같은 버전의 정식 패키지로 자동 업그레이드할 수 있습니다.

### GNOME 소프트웨어 앱 정보

로컬 DEB에는 실행용 데스크톱 항목과 아이콘, 한국어 이름과 요약을 포함한 AppStream 메타데이터가 들어 있습니다. 다른 앱에도 같은 구성을 적용하려면 데스크톱 항목을 `/usr/share/applications`에, 아이콘을 `/usr/share/icons/hicolor`에, `.metainfo.xml`을 `/usr/share/metainfo`에 설치하세요. AppStream의 `launchable`은 실제 데스크톱 항목 파일명을 가리켜야 합니다.

## 이전 APT 등록 및 서명키 삭제

기존 저장소를 등록한 PC에서는 아래 스크립트를 실행해 소스 목록과 해당 APT 공개키를 삭제하세요.

```sh
sh ./installer/linux/remove-apt-registration.sh
sudo apt update
```

APT를 배포하던 PC에서 GPG로 직접 만든 OneMoreTry 기본키와 하위키도 삭제하려면, GPG 키를 만들었던 사용자 계정으로 아래 명령을 실행하고 삭제를 확인하세요.

```sh
sh ./installer/linux/remove-apt-registration.sh --delete-signing-key
```

키를 별도 파일이나 비밀번호 관리자에 내보냈다면 보관 위치에서 해당 사본도 삭제할 수 있습니다.

새 Linux 버전은 [GitHub Releases](https://github.com/nu4ddi4/OneMoreTry/releases/latest)에서 DEB 또는 공통 스크립트를 받아 설치합니다.
