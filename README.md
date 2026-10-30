<div align="center">
  <img src="Sources/OpenClip/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" alt="Qutran" width="96" height="96" />
  <h1>Qutran</h1>
  <p>macOS 選字翻譯與文字工具，支援離線翻譯、繁簡轉換及生字簿。</p>
  <p>macOS 26+ · Swift 6 · <a href="LICENSE">AGPL-3.0</a></p>
</div>

Qutran 基於 [OpenClip](https://github.com/ganeshmshetty/openclip) 開發，以奶油白與古銅色介面整合選字工具列、快速翻譯視窗及語言設定。原始碼、修改歷史與上游作者署名一併保留。

## 主要功能

- **選字翻譯**：自動辨識原文語言，翻譯至主要語言，或從常用語言選單指定目標。支援翻譯後取代原文。
- **離線翻譯**：透過 Apple Translation framework 在裝置上處理；使用前須下載對應語言包。
- **繁簡轉換**：透過系統 ICU 轉換簡體及繁體中文。
- **快速翻譯與生字簿**：以 `⌥⌘T` 開啟翻譯視窗；生字簿支援搜尋、收藏及 CSV 匯出。
- **文字與編碼工具**：修復斷行、字數統計、大小寫及命名格式轉換、JSON 格式化、Base64 和 URL 編解碼。
- **實用動作**：朗讀、搜尋、地圖及撥打電話，依選取內容顯示適用選項。
- **可選 AI 功能**：沿用 OpenClip 的 Apple Intelligence、本機模型及雲端服務整合，並加入港式口語等提示。

離線翻譯和繁簡轉換可在裝置上執行。下載語言包、網頁搜尋及選用的雲端 AI 服務需要網絡連線；雲端功能會把相關內容傳送至你設定的服務。

## 從原始碼建置

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

## 測試

```bash
# Core 測試
./scripts/test.sh core

# 完整 Swift 測試
./scripts/test.sh

# 文字工具的 JavaScript 測試（需要 Node.js）
node --test Tests/PersonalExtensionsJS/tools.test.js
```

## 文件與本機資料

- [Qutran 功能與開發筆記](PERSONAL.md)
- [文件索引](docs/index.md)
- [架構概覽](docs/architecture/overview.md)
- [開發指南](docs/developer-guide/overview.md)

Qutran 沿用 `~/.openclip/` 儲存本機資料；生字簿位於 `~/.openclip/personal/history.json`，擴充套件位於 `~/.openclip/extensions/`。這些執行時資料不包含在本儲存庫內。

本儲存庫保留了上游的自動化與封裝腳本，其中部分仍使用 OpenClip 的名稱和發布設定。目前請使用上述原始碼建置方式安裝 Qutran。

## 授權與致謝

Qutran 是 [OpenClip](https://github.com/ganeshmshetty/openclip) 的修改版本，沿用 **GNU Affero General Public License v3（AGPL-3.0）** 開源授權。

感謝 Ganesh M、OpenClip Contributors 及相關第三方套件作者。完整授權見 [LICENSE](LICENSE)，原作者署名及第三方聲明見 [NOTICE.md](NOTICE.md)。Qutran 的修改記錄可在本儲存庫的 Git 歷史中查看。
