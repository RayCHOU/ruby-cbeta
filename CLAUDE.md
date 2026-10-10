# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

`cbeta` gem：存取與轉換 CBETA（中華電子佛典協會）佛典資源的 Ruby 工具庫。純 library，無 executable。
主要功能是把 CBETA XML P5a（來源：https://github.com/cbeta-git/xml-p5a）轉為純文字，以及檢查 XML 體例、查詢缺字資料庫、統計字數字頻。HTML / PDF / EPUB 相關的轉檔器已全數移除。

## 常用指令

```bash
bundle install
rake test                              # 或 rake（default task 就是 test）
ruby -Ilib -Itest test/test_cbeta.rb                        # 跑單一測試檔
ruby -Ilib -Itest test/test_cbeta.rb -n test_canon_id       # 跑單一測試方法
ruby -Ilib -Itest test/test_cbeta.rb -n /Canon/             # 用 regexp 篩選

gem build cbeta.gemspec                # 會用 ~/.ssh/gem-private_key.pem 簽章（certs/zhoubx.pem）
gem push cbeta-X.Y.Z.gem
```

測試框架是 minitest。Ruby 版本由 `.tool-versions` 指定（3.4.2），gemspec 要求 >= 3.4.2。

發版流程（參考 git log）：改 `cbeta.gemspec` 的 `s.version` → `gem build` → commit（產出的 `.gem` 檔會留在 repo 根目錄，但 `.gitignore` 有 `*.gem`）。

## 架構

### 入口與命名空間

`lib/cbeta.rb` 定義 `CBETA` class 本身（藏經 ID 常數、identifier 轉換的 class methods、藏經名稱查詢的 instance methods），檔尾 `require` 所有 `lib/cbeta/*.rb`。每個子檔案在 `CBETA::` 底下開一個 class，所以**它們依賴 `lib/cbeta.rb` 先載入**，不能單獨 require。

### Identifier 正則（改動時最需要小心的地方）

`CBETA::CANON` 與 `CBETA::WORK_PART` 是 alternation，**本身已包在 non-capturing group 裡**。插值到 regexp 時不要再包一層 group；要取出藏經 ID 才用 capturing group 包在外面。若拿掉 non-capturing group，`^`/`$` 只會綁到第一個/最後一個選項，雙字母藏經編號（CC DA GA GB LC TX YP ZS ZW）會退化成「任意位置比對」。`test/test_cbeta.rb` 的 `CanonRegexpTest` 就是釘住這件事的迴歸測試。

CBETA 的識別字階層：藏經 ID（`T`、`GA`）→ 冊號 vol（`T01`、`GA009`，部分藏經是三碼，見 `VOL3`）→ 典籍編號 work（`T0001`、`ZWa073`）→ XML 主檔名（`T01n0001`）→ 行首資訊 linehead（`T01n0001_p0001a01`）。`lib/cbeta.rb` 提供各層之間互轉的 class methods。

特例散落在 `lib/cbeta.rb`，改邏輯時要留意：`T0220`（大般若經，跨多冊多檔，一律歸併為 `T0220`）、`work_juan_vol_range` / `juan_across_vol`（`GA0037`、`L1557`、`X0714` 有卷跨冊）。

### 轉檔器的共同結構

`P5aToText`、`XMLDocument`、`CharCount`、`CharFrequency`、`P5aChecker` 全部是同一個模式的變體：

- `initialize(xml_root, out_root, opts={})` → `convert(target)`，`target` 可以是 `nil`（全部）、藏經 ID（`'T'`）、冊號（`'T01'`）、冊號範圍（`'T05..T07'`）。
- 遞迴走訪 Nokogiri DOM：`traverse` → `handle_node` → 依 element name 分派到 `e_xxx(e)`。`handle_node` 開頭統一跳過 comment、處理 text node、跳過 `PASS` 清單（通常是 `back`、`teiHeader`）。
- 每個 handler 回傳字串，往上串接。狀態放在 instance variables（`@juan`、`@back`、`@pass` stack 等）。
- **新增 element 支援時要同時改 `handle_node` 的 case 分派和新的 handler 方法**；各轉檔器彼此獨立、沒有共用 base class。
- `XMLDocument` 是例外：用 `send("e_#{e.name}", e)` 動態分派，沒有 case 表，缺 handler 會直接 NoMethodError。

`CbetaShare` module（`each_canon`、`to_html`）是共用 mixin，目前只有 `P5aChecker` `include` 它（也只有它 `require_relative 'cbeta_share'`；`lib/cbeta.rb` 並未 require 該檔）。

### 資料檔（`lib/data/`）

- `cbeta_gaiji.json`（約 3.1 萬筆 CB 缺字）、`cbeta_sanskrit.json`（悉曇 SD / 蘭札 RJ）：由 CBETA 定期釋出的資料更新（git log 中的 "update gaiji 20XX.RX"）。`CBETA::Gaiji` 載入後合併兩者，並建立 組字式→CB碼、Unicode字元→CB碼 的反查表。
- `canons.csv`：藏經 metadata（id、chinese_name、nickname、abbreviation…），`CBETA#initialize` 與 `CBETA::Canon` 都會讀。
- `categories.json`：經號 → 部類。

缺字呈現的優先序在 `Gaiji#to_s`，預設 `uni_2 → norm_uni_2 → norm_big5_char → uni_char → norm_uni_char → composition`；`uni_2`/`norm_uni_2` 的判斷透過 `CBETA::UnicodeService`（用 Ruby regexp 的 `\p{Age=...}` 判斷 Unicode 版本：level1 = Unicode 3.0 以內，level2 = 10.0 以內；4.2.0 起不再依賴 `unihan2` gem）。

`CBETA::Gaiji.new(gaiji_path:, sanskrit_path:)` 可改讀外部缺字資料（格式須同 https://github.com/cbeta-org/cbeta_gaiji ），nil 時用 `lib/data/` 內建檔。

### 檢查工具

`CBETA::P5aChecker` 檢查 CBETA XML 編輯體例，錯誤/警告代碼（E01–E16、W01–W03）列在檔案開頭註解；新增檢查時要同時更新該註解表。
`CBETA::P5aValidator` 則是用 RelaxNG schema 做 validation，schema 檔不在本 repo。

## 文件慣例

程式碼註解與 API 文件用繁體中文（台灣），YARD 格式（`@param`、`@return`、`@example`）。文件發布於 https://www.rubydoc.info/gems/cbeta 。
