# Personal build: offline-first additions

This `personal` branch adds offline features on top of OpenClip. Everything runs on-device.

## What's added

| Area | Feature | Where |
|---|---|---|
| Translate | **翻譯**: detects the language and translates into the primary language (or the secondary language when the text is already in the primary language) | `Sources/OpenClip/Personal/TranslateActions.swift` |
| | **翻譯為…**: a sub-menu with one entry per favourite language | same |
| | **繁簡**: Simplified ⇄ Traditional through system ICU, with an inline preview | same, `ChineseConverter.swift` |
| | Apple Translation framework with no network; one session per call | `OfflineTranslator.swift` |
| Search | **搜尋…**: Google, YouTube, 維基百科, Cambridge 字典, GitHub | `PersonalExtensions/personal-search.openclipext` |
| Text tools | **文字**: 修復斷行, 字數 (inline), 大寫, 小寫, 首字大寫, snake_case, camelCase | `PersonalExtensions/personal-text-tools.openclipext` |
| | **編碼**: JSON 格式化／壓縮, Base64, URL encode/decode | same |
| System | **朗讀** (Cantonese voice for Traditional Chinese), **地圖**, **撥打** | `PersonalUtilityActions.swift` |
| Hub window | 快速翻譯 (⌥⌘T), 生字簿 (search, star, CSV export), 語言 (preferences + language-pack downloads). Cream canvas, ivory cards, serif headings, bronze accent (`HubTheme`) | `PersonalHub*.swift` |
| Popup look | Classic theme's light surface is warm cream; first launch sets the bar to light | `PopupThemeModel.swift`, `PersonalFeatures.seedPopupAppearanceIfNeeded` |
| AI | Extra Apple Intelligence prompts: 輕鬆語氣, 擬回覆, 港式口語 | `PersonalFeatures.extraAIPresets` |

Each action appears only when it fits the selection. For example, **撥打** shows only for phone numbers, **繁簡** only for Chinese text, and **翻譯為英文** never for text that is already English. On first launch the bar order is seeded once, putting Copy and Translate first. You can reorder it in Settings › Customize.

## Build and run

```bash
./scripts/dev_run.sh            # installs ~/Applications/OpenClip Dev.app and launches it
./scripts/test.sh               # full Swift suite
node --test Tests/PersonalExtensionsJS/tools.test.js   # text-tool logic
```

`OPENCLIP_PERSONAL_HUB=translate|history|languages` opens the hub at launch, and
`OPENCLIP_PERSONAL_DEMO_TEXT="some text"` shows the real popup bar for that text. Neither needs a live selection or Accessibility access. Use them to check the UI.

## Notes

- The minimum macOS version is 26.0. `TranslationSession(installedSource:target:)` needs it.
- The bundled extension packages are copied to `~/.openclip/extensions` and trusted on launch. This happens again when their `version` changes. If you edit an installed copy, the trust gate disables it until you re-enable it in Settings.
- The vocabulary book is stored in `~/.openclip/personal/history.json`.
- Upstream changes are confined to these places, which keep `git merge upstream/main` easy:
  - one-line hooks in `AppDelegate.swift` and `StatusBarController.swift`
  - the cream colour in `PopupThemeModel.classicSurfaceBackground`
  - a `personal` log category
  - bundling `PersonalExtensions/` in `project.yml`
