# Sparse Matrix FPGA

**AI 加速器之稀疏矩陣運算與低功耗硬體架構探討與設計**

《半導體世界》課程報告延伸 Side Project · SystemVerilog / Python / ModelSim / Terasic SoCKit

## 直接體驗，不需要板卡

**[公開互動展示網站](https://sparse-matrix-fpga-jjweng.thoughtfulknoll64.chatgpt.site)**

CSR 編碼與乘加共有 70 個可播放／拖曳步驟；另有真實 ModelSim 取樣、兩版 LED 說明、保存的實板結果及 1080p／4K 影片。手機可以操作，不需登入。這是教學與保存證據，不是遠端 FPGA 控制服務。

原本的 [AI 手寫數字應用 Demo](https://sparse-matrix-fpga-jjweng.thoughtfulknoll64.chatgpt.site/ai/) 也保留：比較不同剪枝設定的辨識結果、MAC、週期與 4×4 排程。使用固定 UCI digits 樣本，不需現場手寫；此頁數值屬保存的 RTL 模擬，實板證據另列。

This public snapshot contains original hardware and verification source, selected real evidence, and the static website. The complete private research archive and its history are preserved separately. Third-party slides, vendor IP binaries and local transport metadata are omitted.

## 我們設計了什麼

- Dense：4×4 signed 8-bit A×B，重複使用一個 MAC，產生 16 個 signed 32-bit 輸出。
- CSR-A：A 以 values / col_idx / row_ptr 表示，B 保持 dense，只排程 A 的非零項；同樣一個 MAC。
- FSM 管理 loader、索引、FETCH／ISSUE、pipeline 退休與寫回；另外統計 busy cycles 與 MAC 交易。
- RAM read-enable 候選只在 FETCH 更新讀取資料；維持單一時脈，沒有組合邏輯閘控 FPGA clock。
- Python Golden、self-checking SystemVerilog TB，以及 SoCKit 實板輸出與 counter 讀回。

## 結果與界線

| 證據層級 | 結果 |
|---|---|
| Gate 4 完整 RTL 回歸 | 131 cases、每個 DUT 2,144 output checks，見 [原始模擬 Log](evidence/gate4/vsim.log) |
| 固定教學 ModelSim | 12 MAC checks＋32 matrix outputs；Dense 178 cycles／64 MAC，CSR 90／16 |
| 保存的實板讀回 A14 | 6 runs、288 tiles、9,216 outputs 符合獨立整數矩陣計算；[公開數值證據](evidence/board/readback.json) |
| 實板 p50 kernel | Dense 8,544 cycles／3,072 MAC；CSR 5,508／1,280；週期比 1.551×，不含 PC／JTAG |
| Power Analyzer | RAM read-enable 同一引擎配對的核心動態估計改善 10.02%–11.30%；不是 CSR 對 Dense，也不是實板瓦數 |
| 尚未完成 | 板卡實際功率量測；外部 JTAG 正式時序 signoff 仍有限制 |

公開的 board JSON 保留實際輸入、兩個引擎的輸出與 counter。它是從保存的真實結果挑選欄位匯出，不是重新計算後假裝成 FPGA 輸出。原 transport/session Log 保留在私人研究庫，公開版不宣稱重新審核了所有電氣或時序條件。

## 自己重現

Python 標準函式庫，不需要板卡：

```text
python -m unittest discover -s tests -v
python scripts/verify_learning_example.py
python verify_saved_board.py
```

真正執行 RTL 模擬需要 ModelSim。既有 runner 測過 Windows／ModelSim Altera Starter 10.1d，預設安裝在 `C:/altera/13.0sp1/modelsim_ase/win32aloem`；其他安裝位置需先調整路徑，不宣稱已測跨平台。

```text
python scripts/run_gate4.py --phase 4D
python learning/circuit_walkthrough/run_simulation.py
python fpga_demo/scripts/run_sim.py
```

執行後另存 timestamped Logs／vectors／source hashes；Python PASS 不等於新 RTL PASS。新模擬原檔以個別 run.json 為準。

網站也可本機執行：

```text
python -m http.server 8000 --directory web_demo
```

瀏覽 `http://localhost:8000/`。網站不含 Programming 介面。本公開快照沒有可直接套用到任意板卡的 Pin Constraints；不要把 RTL demo wrapper 當成已核對的燒錄工程。

## 閱讀程式

| 路徑 | 用途 |
|---|---|
| `rtl/gate4/` | MAC、Dense、CSR 計算核心 |
| `model/` | 獨立 Python Golden |
| `tb/`、`tests/` | SystemVerilog 自動比對與 Python tests |
| `ai_lab/memory_enable/rtl/` | 同步 RAM read-enable 候選 |
| `fpga_demo/rtl/` | 原 ROM Demo controller、loader、同步／debounce、LED display |
| `docs/GATE4_SPEC.md` | signed、reset、start、busy、done、CSR 載入格式與 FSM |
| `learning/circuit_walkthrough/results/` | 真實教學 ModelSim Log、CSV、VCD、Golden 與 frozen sources |
| `web_demo/` | 已公開網站的靜態程式與數值 |
| `PROVENANCE.json` | 公開快照與原始檔 SHA256；機器路徑是否遮罩 |

Original work © 2026 jjweng-ece, [MIT](LICENSE). Third-party rights remain separate; see [NOTICE](NOTICE.md). FPGA CE does not equal ASIC clock gating. Reduced MAC count is not automatically a latency or measured-power improvement.
