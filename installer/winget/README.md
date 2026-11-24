# WinGet 등록

패키지 ID는 `Nu4ddi4.OneMoreTry`입니다. 매니페스트는 GitHub Releases에 공개된 x64 Inno Setup 설치 파일을 사용합니다. Windows 설치 파일의 SHA-256과 기존 설치 식별자를 유지합니다.

## 최초 등록

Windows에서 프로젝트를 내려받아 PowerShell을 엽니다. 레지스트리 등록은 Microsoft의 공개 `microsoft/winget-pkgs` 저장소에 제출하는 PR로 진행합니다.

```powershell
winget install --id Microsoft.WingetCreate --exact
$manifest = '.\installer\winget\manifests\n\Nu4ddi4\OneMoreTry\0.8.0'
winget validate --manifest $manifest
wingetcreate submit --prtitle 'New package: Nu4ddi4.OneMoreTry version 0.8.0' $manifest
```

로그인이 필요하면 WinGet Create의 GitHub 인증 안내를 따릅니다. Microsoft의 검증과 병합이 끝나면 공식 소스에서 설치할 수 있습니다.

```powershell
winget install --id Nu4ddi4.OneMoreTry --exact --source winget
```

## 이후 버전

정식 Windows 릴리스를 먼저 게시합니다. 새 설치 EXE의 URL과 버전을 WinGet Create에 전달하고, 생성한 매니페스트를 검토한 뒤 같은 제출 명령으로 PR을 엽니다.

```powershell
$version = '<새 정식 버전>'
$installer = "https://github.com/nu4ddi4/OneMoreTry/releases/download/v$version/OneMoreTry-v$version-Windows-x64-Setup.exe"
wingetcreate update Nu4ddi4.OneMoreTry --version $version --urls "$installer|x64" --out .\installer\winget
```

[매니페스트 문서](https://learn.microsoft.com/windows/package-manager/package/manifest) · [WinGet Create 제출 명령](https://github.com/microsoft/winget-create/blob/main/doc/submit.md)
