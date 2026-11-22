# Linux 설치와 업데이트

Debian·Ubuntu의 amd64 패키지입니다. 데스크톱 메뉴의 **한 번만 더!** 또는 터미널의 `onemoretry`로 실행합니다.

## 내려받은 파일로 설치

```sh
sudo apt install ./onemoretry_0.8.1-2_amd64.deb
```

실제 받은 파일명을 사용합니다. 0.8.1부터 패키지 설치 시 APT 소스와 공개키도 등록됩니다. PR에서 내려받은 빌드는 Debian 버전명에 `~preview`가 들어가므로 같은 버전의 정식 패키지로 자동 업그레이드할 수 있습니다.

### GNOME 소프트웨어 앱 정보

로컬 DEB에는 실행용 데스크톱 항목과 아이콘, 한국어 이름과 요약을 포함한 AppStream 메타데이터가 들어 있습니다. 다른 앱에도 같은 구성을 적용하려면 데스크톱 항목을 `/usr/share/applications`에, 아이콘을 `/usr/share/icons/hicolor`에, `.metainfo.xml`을 `/usr/share/metainfo`에 설치하세요. AppStream의 `launchable`은 실제 데스크톱 항목 파일명을 가리켜야 합니다.

## APT 저장소 수동 등록

Pages의 첫 배포가 끝나면 저장소 주소는 `https://nu4ddi4.github.io/OneMoreTry/apt`입니다. 키를 등록하기 전에 아래 명령이 출력한 지문을 프로젝트가 별도 공지한 지문과 비교합니다.

```sh
curl -fL https://nu4ddi4.github.io/OneMoreTry/apt/onemoretry-archive-keyring.asc \
  -o onemoretry-archive-keyring.asc
gpg --show-keys --fingerprint onemoretry-archive-keyring.asc
```

지문이 일치하면 해당 소스에만 키를 등록한 뒤 패키지를 설치합니다.

```sh
sudo install -D -m 644 onemoretry-archive-keyring.asc /etc/apt/keyrings/onemoretry.asc
printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/onemoretry.asc] https://nu4ddi4.github.io/OneMoreTry/apt stable main' |
  sudo tee /etc/apt/sources.list.d/onemoretry.list
sudo apt update
sudo apt install onemoretry
```

다음 버전은 `sudo apt update && sudo apt upgrade` 또는 시스템 업데이트 관리자에서 받습니다.

## 프로젝트 배포 설정

1. 저장소 **Settings → Pages → Build and deployment → Source**에서 **GitHub Actions**를 선택합니다.
2. 관리자가 별도로 보관할 인증용 기본키와, 배포에 쓸 서명용 하위키를 생성합니다. GPG에서 표시하는 기본키 전체 지문을 아래에서 사용합니다.
3. GitHub Actions 저장소 변수 `APT_SIGNING_FINGERPRINT`에 기본키의 전체 지문을 등록합니다. `github-pages` 환경의 비밀값 `APT_SIGNING_SUBKEY`에 서명 하위키를 넣고, 하위키를 암호로 보호하는 경우 같은 환경의 `APT_SIGNING_PASSPHRASE`를 설정합니다. 기본 비밀키는 별도로 보관합니다.
4. 워크플로를 `main`에 반영한 뒤 **Actions → Linux DEB and APT → Run workflow**를 실행합니다. 이후 게임 버전이나 Linux 리비전을 올려 `main`에 반영하면 새 패키지가 배포됩니다. 같은 Debian 버전의 패키지는 교체되지 않습니다.

키를 새로 만드는 경우의 예시입니다. 키를 장기 보관하는 관리자 환경에서 실행합니다.

```sh
gpg --quick-generate-key 'OneMoreTry APT <95563468+nu4ddi4@users.noreply.github.com>' ed25519 cert 0
gpg --list-keys --fingerprint 'OneMoreTry APT'
gpg --quick-add-key '<기본키 전체 지문>' ed25519 sign 1y
gpg --armor --export-secret-subkeys '<기본키 전체 지문>' |
  gh secret set APT_SIGNING_SUBKEY --env github-pages --repo nu4ddi4/OneMoreTry
gh variable set APT_SIGNING_FINGERPRINT --body '<기본키 전체 지문>' --repo nu4ddi4/OneMoreTry
```

서명 하위키의 만료 전에는 같은 기본키에서 새 하위키를 만들고, Linux 리비전을 올려 갱신한 공개키와 함께 배포합니다. 배포 워크플로는 패키지 설치·실행과 별도 CI 키로 서명한 APT 경로를 검사합니다. 실제 배포 키는 `main`의 Pages 배포 작업에서만 사용합니다.

## 로컬 패키지 빌드

Godot 4.6.3, Python과 `dpkg-deb`가 필요합니다.

```sh
python3 tools/fetch_templates.py --platform linux
mkdir -p build/linux
godot --headless --editor --import --quit
godot --headless --export-release 'Linux x86_64' build/linux/onemoretry
python3 tools/build_deb.py --binary build/linux/onemoretry --version 0.8.1-2
```

게임 버전을 유지하면서 Linux 패키지 변경을 배포할 때는 `installer/linux/debian-revision`을 올립니다.
