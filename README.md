<div align="center">
  <img src="Sources/OpenClip/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" alt="Qutran" width="96" height="96" />
  <h1>Qutran</h1>
  <p>Offline translation and text tools for macOS.</p>
  <p>macOS 選字翻譯與文字工具，支援離線翻譯、繁簡轉換及生字簿。</p>
  <p>macOS 26+ · Swift 6 · <a href="LICENSE">AGPL-3.0</a></p>
</div>

[English](#english) · [繁體中文](#繁體中文)

## English

Qutran is a macOS menu bar app that turns selected text into translation and text actions. Built on [OpenClip](https://github.com/ganeshmshetty/openclip), it adds offline translation, a vocabulary book, and a cream interface with bronze accents.

### Features

- **Translate selected text** with automatic language detection, an automatic or locked target language, favorite target languages, and translation replacement in supported editable fields.
- **Translate offline** with Apple's Translation framework after downloading the required language packs.
- **Convert Simplified and Traditional Chinese** using the system ICU libraries.
- **Quick translation and vocabulary**: open the translation window with `⌥⌘T`; search, star, and export vocabulary entries as CSV.
- **Text tools**: fix line breaks, count text, change case, convert naming styles, format JSON, and encode or decode Base64 and URLs.
- **Optional actions**: read text aloud, search the web, open maps, or use Apple Intelligence, local models, and configured cloud AI providers.

### Download and install

**[Download Qutran v0.1.2 for macOS (DMG)](https://github.com/iamfinethanks123/qutran/releases/download/v0.1.2/Qutran-v0.1.2-universal.dmg)** · [ZIP and release notes](https://github.com/iamfinethanks123/qutran/releases/tag/v0.1.2)

Requires **macOS 26.0 or later**. The Universal download includes both Apple silicon (`arm64`) and Intel (`x86_64`).

1. Open the DMG and drag **Qutran** into **Applications**.
2. Open Qutran from Applications and look for its menu bar icon.
3. Grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility** to enable selected text actions.
4. Download the required translation language packs from Qutran's language page before using offline translation.

The v0.1.2 app and DMG are **Developer ID signed and notarized by Apple**, with notarization tickets attached. Under the default macOS security settings, an **Open Anyway** override is not required. macOS may still show its normal first-open confirmation and request Accessibility permission.

### Privacy and local data

Offline translation and Chinese script conversion run on your device. Language pack downloads, web searches, and optional cloud AI features need an internet connection. Cloud AI sends the relevant text to the provider you configure.

Local data uses `~/.openclip/`; vocabulary is stored in `~/.openclip/personal/history.json`. Your settings, vocabulary, and private credentials are not included in the repository or release packages.

### Build from source

Requires macOS 26+, Xcode 26+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The development launcher currently targets Apple silicon. The first build downloads Swift package dependencies.

```bash
git clone https://github.com/iamfinethanks123/qutran.git
cd qutran
brew install xcodegen
xcodegen generate
./scripts/dev_run.sh
```

The launcher installs the app at `~/Applications/Qutran.app`. Source builds default to ad-hoc signing; see the [signing and notarization guide](docs/developer-guide/signing-and-notarization.md) for distribution builds. The Xcode project and some internal paths retain the OpenClip name; the app's bundle identifier is `com.qutran.Qutran`.

### License and credits

Qutran is a modified version of OpenClip, released under **AGPL-3.0**. Credits to Ganesh M, OpenClip Contributors, and third-party authors are retained. See [LICENSE](LICENSE), [NOTICE.md](NOTICE.md), and the [Qutran development notes](PERSONAL.md).

---

## 繁體中文

Qutran 基於 [OpenClip](https://github.com/ganeshmshetty/openclip) 開發，以奶油白與古銅色介面整合選字工具列、快速翻譯視窗及語言設定。原始碼、修改歷史與上游作者署名一併保留。

### 主要功能

- **選字翻譯**：自動辨識原文語言，可自動選擇或鎖定翻譯目標，亦可從常用語言選單指定目標。支援翻譯後取代原文。
- **離線翻譯**：透過 Apple Translation framework 在裝置上處理；使用前須下載對應語言包。
- **繁簡轉換**：透過系統 ICU 轉換簡體及繁體中文。
- **快速翻譯與生字簿**：以 `⌥⌘T` 開啟翻譯視窗；生字簿支援搜尋、收藏及 CSV 匯出。
- **文字與編碼工具**：修復斷行、字數統計、大小寫及命名格式轉換、JSON 格式化、Base64 和 URL 編解碼。
- **實用動作**：朗讀、搜尋、地圖及撥打電話，依選取內容顯示適用選項。
- **可選 AI 功能**：沿用 OpenClip 的 Apple Intelligence、本機模型及雲端服務整合，並加入港式口語等提示。

離線翻譯和繁簡轉換可在裝置上執行。下載語言包、網頁搜尋及選用的雲端 AI 服務需要網絡連線；雲端功能會把相關內容傳送至你設定的服務。

### 下載安裝

**[下載 Qutran v0.1.2 安裝包（DMG）](https://github.com/iamfinethanks123/qutran/releases/download/v0.1.2/Qutran-v0.1.2-universal.dmg)** · [版本說明與其他下載](https://github.com/iamfinethanks123/qutran/releases/tag/v0.1.2)

需要 macOS 26 或以上。安裝包為 Universal 版本，包含 Apple silicon（arm64）及 Intel（x86_64）。

1. 開啟下載的 DMG，把 **Qutran** 拖至 **Applications**。
2. 從「應用程式」開啟 Qutran；它會顯示在選單列。
3. 在「系統設定 → 私隱與保安 → 輔助使用」授予權限，並在 Qutran 的語言頁面下載所需翻譯語言包。

**v0.1.2 已使用 Developer ID 簽署並通過 Apple 公證，App 及 DMG 均附有公證票證。** 在 macOS 預設安全設定下可正常開啟，毋須到設定按「仍要開啟／Open Anyway」。首次開啟仍可能出現一般的網上下載確認；輔助使用權限亦需自行授予。詳細說明見 [Apple 官方指引](https://support.apple.com/en-hk/102445)。

舊版 v0.1.0 未公證測試版及其校驗碼保留於 Releases。

### 從原始碼建置

需要 macOS 26 或以上、Xcode 26 或以上及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。以下啟動腳本以 Apple silicon（arm64）為目標。首次建置會下載 Swift 套件相依項目。

```bash
git clone https://github.com/iamfinethanks123/qutran.git
cd qutran
brew install xcodegen
xcodegen generate
./scripts/dev_run.sh
```

腳本會建置並安裝至 `~/Applications/Qutran.app`，然後啟動應用程式。預設使用 ad-hoc 簽署；如需 Developer ID 簽署及公證，請參閱[簽署文件](docs/developer-guide/signing-and-notarization.md)。

首次使用選字工具時，請在「系統設定 → 私隱與保安 → 輔助使用」授予 Qutran 權限。離線翻譯所需的語言包可在應用程式的語言頁面下載。

Xcode 專案及部分原始碼目錄沿用 `OpenClip` 名稱；應用程式名稱為 **Qutran**，bundle identifier 為 `com.qutran.Qutran`。

### 測試

```bash
# Core 測試
./scripts/test.sh core

# 完整 Swift 測試
./scripts/test.sh

# 文字工具的 JavaScript 測試（需要 Node.js）
node --test Tests/PersonalExtensionsJS/tools.test.js
```

### 文件與本機資料

- [Qutran 功能與開發筆記](PERSONAL.md)
- [文件索引](docs/index.md)
- [架構概覽](docs/architecture/overview.md)
- [開發指南](docs/developer-guide/overview.md)

Qutran 沿用 `~/.openclip/` 儲存本機資料；生字簿位於 `~/.openclip/personal/history.json`，擴充套件位於 `~/.openclip/extensions/`。這些執行時資料不包含在本儲存庫內。

執行 `./scripts/package_app.sh` 可產生 `build/Qutran.dmg` 及 `build/Qutran.zip`。預設為 ad-hoc 簽署；正式簽署與公證的設定見[簽署文件](docs/developer-guide/signing-and-notarization.md)。

本機備好 Developer ID 憑證及 `qutran-notary` 鑰匙圈登入後，可執行 `OPENCLIP_SIGN_IDENTITY=auto OPENCLIP_NOTARIZE=1 NOTARY_PROFILE=qutran-notary ./scripts/package_app.sh`，完成簽署、公證、票證附加及 Gatekeeper 檢查。

GitHub Actions 目前停用；其餘上游發布流程仍保留 OpenClip 的設定。Qutran 發布版本透過本機封裝、簽署及公證後上傳至 Releases；簽署金鑰與公證登入資料不包含在儲存庫內。

### 授權與致謝

Qutran 是 [OpenClip](https://github.com/ganeshmshetty/openclip) 的修改版本，沿用 **GNU Affero General Public License v3（AGPL-3.0）** 開源授權。

感謝 Ganesh M、OpenClip Contributors 及相關第三方套件作者。完整授權見 [LICENSE](LICENSE)，原作者署名及第三方聲明見 [NOTICE.md](NOTICE.md)。Qutran 的修改記錄可在本儲存庫的 Git 歷史中查看。
