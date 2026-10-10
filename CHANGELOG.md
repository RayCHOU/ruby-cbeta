# CHANGELOG

本檔記錄 `cbeta` gem 各版本的變更。版號遵循 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

每個版本都標明「缺字資料」：`Gaiji#to_s` 的輸出取決於內建缺字資料（`lib/data/cbeta_gaiji.json`、`cbeta_sanskrit.json`）與程式邏輯，需要重現結果的使用者請據此釘選版本，或用 `CBETA::Gaiji.new(gaiji_path:, sanskrit_path:)` 自行指定缺字資料。

3.6.13 以前的版本請參考 git log。

## 4.3.0 (2026-10-10)

缺字資料：未變更（CBETA 2026.R2）；`Gaiji#to_s` 輸出與 4.2.0 相同

- 新增 `CBETA::Gaiji::DATA_VERSION` 常數，標示內建缺字資料的期別（目前為 `2026.R2`）。
- 新增 `Gaiji#data_version`：使用內建資料時回傳 `DATA_VERSION`；使用外部資料時回傳 `CBETA::Gaiji.new` 的 `data_version:` 參數（未指定則為 `nil`）。

## 4.2.0 (2026-10-10)

缺字資料：未變更（CBETA 2026.R2）；`Gaiji#to_s` 輸出與 4.1.0 相同

- 移除 runtime dependency `unihan2`。`CBETA::UnicodeService` 改用 Ruby regexp 的 Unicode Age 屬性（`\p{Age=3.0}`、`\p{Age=10.0}`）判斷字元收錄於哪一版 Unicode。
  - 全部 33,893 個缺字碼的 `to_s`、`level1?`、`level2?` 結果與 4.1.0 相同。
  - `level1?`、`level2?` 傳入不在 Unicode 中的字元時回傳 `false`，不再拋出例外。
- `CBETA::Gaiji.new` 新增 `gaiji_path:`、`sanskrit_path:` 參數，可讀取外部缺字資料（格式須同 [cbeta-org/cbeta_gaiji](https://github.com/cbeta-org/cbeta_gaiji)）；未指定時使用內建資料。
- Gemfile 補上 `csv`、`rake`、`minitest`，修正 `bundle exec` 無法載入 csv。

## 4.1.0 (2026-08-29)

缺字資料：未變更（CBETA 2026.R2）

- `P5aChecker` 新增 E17：`list` 下沒有任何有內容的 `item`。

## 4.0.0 (2026-08-28)

缺字資料：未變更（CBETA 2026.R2）

- **BREAKING**：移除 HTML / PDF / EPUB 相關轉檔器：`CBETA::P5aToHTML`、`P5aToSimpleHTML`、`P5aToHTMLForEveryEdition`、`P5aToHTMLForPDF`、`HTMLToText`、`HTMLToPDF`。保留的轉檔功能為 `P5aToText`、`BMToText`、`XMLDocument`。
- 移除 `lib/data/` 的 `html-for-pdf.css`、`pdf-template.htm`、`unicode-1.1.json`。
- `P5aChecker` 圖檔不存在的錯誤訊息補上完整路徑。

## 3.8.0 (2026-08-10)

缺字資料：未變更（CBETA 2026.R2）

- 修正 `CBETA::CANON`、`CBETA::WORK_PART` 未包 non-capturing group，導致插值到 regexp 時 `^`/`$` 只綁到第一個/最後一個選項，雙字母藏經編號（CC DA GA GB LC TX YP ZS ZW）比對錯誤。

## 3.7.10 (2026-07-30)

缺字資料：**更新為 CBETA 2026.R2**

## 3.7.9 (2026-06-30)

缺字資料：未變更（CBETA 2026.R1）

- nokogiri 下限提高為 1.19.4。

## 3.7.8 (2026-05-09)

缺字資料：未變更（CBETA 2026.R1）

- 更新 nokogiri 1.19.3。

## 3.7.7 (2026-04-03)

缺字資料：**更新為 CBETA 2026.R1**

## 3.7.6 (2026-03-31)

缺字資料：未變更（CBETA 2025.R3）

- `P5aChecker` 調整。

## 3.7.5 (2026-03-30)

缺字資料：未變更（CBETA 2025.R3）

- `P5aChecker` 新增 E16：`app/@n` 與 `note/@n` 不一致。

## 3.7.4 (2026-02-25)

缺字資料：未變更（CBETA 2025.R3）

- 更新 nokogiri。

## 3.7.3 (2025-11-24)

缺字資料：**更新為 CBETA 2025.R3**

## 3.7.2 (2025-11-24)

缺字資料：未變更（CBETA 2025.R2）

- 新增藏經 YP（CBETA 2025.R3）。

## 3.7.1 (2025-11-12)

缺字資料：未變更（CBETA 2025.R2）

- `P5aChecker` 新增 E15：`<note>` 的 `corresp` 找不到對應的 `<note>`。

## 3.7.0 (2025-10-13)

缺字資料：未變更（CBETA 2025.R2）

- gem 改為簽章發布（`certs/zhoubx.pem`）。
- 新增 `CBETA::WORK_PART`、`CBETA::BASENAME` 常數與 `CBETA.get_work_id_from_linehead`。

## 3.6.16 (2025-07-29)

缺字資料：**更新為 CBETA 2025.R2**

## 3.6.15 (2025-07-26)

缺字資料：未變更（CBETA 2025.R1）

- 更新 nokogiri。

## 3.6.14 (2025-07-21)

缺字資料：未變更（CBETA 2025.R1）

- `P5aChecker` 檢查 `<anchor type="right">` 不應直接出現在 `div` 或 `body` 下。

## 3.6.13 (2025-06-28)

缺字資料：未變更（CBETA 2025.R1）；**`Gaiji#to_s` 輸出變更**

- `Gaiji#to_s` 預設優先序由 `uni_char → norm_uni_char → norm_big5_char → composition` 改為 `uni_2 → norm_uni_2 → norm_big5_char → uni_char → norm_uni_char → composition`：Unicode 10.0 以內的字元優先，其次才是 Big5 通用字。
