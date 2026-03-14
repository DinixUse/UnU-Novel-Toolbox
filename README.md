<div align="center">
  <img src="https://github.com/DinixUse/UnU-Novel-Toolbox/blob/main/assets/img/Cirno.png" alt="UnU Novel Toolbox Logo" width="120" />
  <h1>UnU Novel Toolbox</h1>
  <p>小説解析・ダウンロードツール（Flutter Windowsデスクトップアプリ）</p>
</div>

UnU Novel Toolbox 是一個 Flutter Windows 桌面應用，針對小說下載與解析做優化。主要功能如下：

1) 從刺猬貓（ciweimao）解析書籍目錄與章節列表。
2) 用內建 WebView 模擬使用者操作（頁面加載、點擊展開）取得章節 HTML。
3) 清理並格式化章節正文，批量寫入 TXT（未來可擴展 EPUB）。

## 🚀 核心功能

- 桌面多標籤頁面：起始頁、下載器、轉換工具、設定、測試頁。
- 無邊框與自定義標題欄控制（最小化、最大化、關閉）。
- 下載守護進程（`DownloadManager`）支援：
  - 並發限制（`_maxConcurrent`）
  - 多任務隊列
  - 任務狀態/進度（pending/downloading/completed/failed）
- 刺猬貓解析：先嘗試 API 抓取，再 fallback WebView DOM 提取。
- 章節提取器 `cwm_NovelExtractor`：WebView 讀取完整 HTML、DOM 過濾、清理干擾標籤。
- 本地設定 `appData/settings.json`：保存背景、透明度、下載根目錄、主題色。

## 🧪 當前工作流程

1. 在刺猬貓頁面輸入 `https://www.ciweimao.com/book/<id>`。
2. 點擊「解析目錄」，先透過 API 抓取書名/作者/章節檔案，若 API 失敗再用 WebView 提取。
3. 將解析後的 `List<cwm_NovelVolume>` 顯示為章節清單，支援單章提取預覽。
4. 點擊「添加到下載列表」，建立 `TaskModel` 並加入 `DownloadManager.tasks`。
5. 下載守護進程依據並發限制執行，對每章使用 `cwm_NovelExtractor.getNovelContent`（WebView 模擬瀏覽器）抓取正文。
6. 章節抓取成功後，寫入 TXT 文件。

## ⚙️ 下載邏輯

目前實作已在單進程內並發控制，未來應規劃「並發 + 多進程」下載：

- 主進程管理任務隊列與 UI，啟動多個子進程（或 Isolate）執行單個任務（不與 UI 競爭）。
- 子進程中使用 WebView 模擬用戶操作（例如頁面加載、展開按鈕點擊、滾動）確保成功抓取。
- 任務狀態由主進程透過 IPC 或共享 `StreamController` 回報，並更新 UI。

> 這樣能把網絡與解析壓力分散到獨立進程，提高穩定性，避免 WebView 與主 UI 卡頓。

## ⚙️ 本地運行

```bash
git clone https://github.com/DinixUse/UnU-Novel-Toolbox.git
cd UnU-Novel-Toolbox
flutter pub get
flutter run -d windows
```

## 📦 發行構建

```bash
flutter build windows
```

## 🧩 設定檔與檔案位置

- `appData/settings.json`：樣式、背景與下載根目錄等
- 默认下载目录：`C:\UnUDownloads`（可在 `lib/preferences.dart` `defaultSettingsMap` 修改）


## 🧾 貢獻指南

1. Fork 本倉庫
2. 新分支：`git checkout -b feature/xxx`
3. 開發+測試
4. 發 PR 並附上重現步驟

## 📜 授權

本專案採用 GNU GENERAL PUBLIC LICENSE v3（GPL-3.0）。

> 本軟體「按原樣提供」，不含任何明示或暗示保固。轉載或修改後發佈時須遵守 GPLv3，並公開對應原始碼。
