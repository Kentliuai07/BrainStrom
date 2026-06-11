# iOS 指紋樣本（跨端一致性比對 · 2026-06-11）

> 用途：後端線拿這份跟網頁版 `fnvHash` / `fnv1a` 輸出逐欄比對，確認兩端指紋一致。
> 演算法：FNV-1a 32bit，**UTF-16 碼元**（對齊 web `charCodeAt`），輸出 8 位小寫 hex。
> `normalizeText` = trim + 連續空白折成一格；`fnvHash(s) = fnv1a(normalizeText(s))`。
> 來源：`ios-app/BrainStrom/Domain/Algorithms/TextHashing.swift`；由 `AlgorithmTests.testPrintFingerprintSamples` 實機（iPhone 13 Pro / iOS 26.5 模擬器）輸出。

## FNV-1a 標準向量（錨點，已斷言通過）
| 輸入 | fnv1a |
|---|---|
| `""` | `811c9dc5` |
| `"a"` | `e40c292c` |
| `"foobar"` | `bf9cf968` |

## 樣本（含 CJK 與空白折疊）
| # | 樣本字串（用 `\|` 夾住看邊界） | fnv1a（原字串） | fnvHash（normalize 後） |
|---|---|---|---|
| 1 | `\|\|`（空字串） | `811c9dc5` | `811c9dc5` |
| 2 | `\|a\|` | `e40c292c` | `e40c292c` |
| 3 | `\|Hello\|` | `f55c314b` | `f55c314b` |
| 4 | `\|測試 Hello  世界\|`（Hello 後兩個空格） | `c43a4209` | `291748bb` |
| 5 | `\|  前後空白  trim 測試  \|`（前後＋中間多空白） | `090357c9` | `6e0e16df` |

說明：
- 樣本 1~3 純 ASCII/無多餘空白，`fnv1a == fnvHash`。
- 樣本 4、5 有「連續空白／前後空白」，所以 `fnvHash`（先 normalize）與 `fnv1a`（原字串）不同——這正是要驗 normalize 行為是否兩端一致的點。
- **請後端用網頁版同樣 5 個字串跑 `fnvHash` 與 `fnv1a`，逐格對照。** 任一格不同即兩端指紋不一致，回報我修。

## 待後端確認的組裝口徑（非單字串，無法用上表涵蓋）
- `fullHash(blocks)`：未軟刪塊按 position 排序 → 各塊 `normalizeText(blockContent)` → 以 `\n\n` 串接 → **fnv1a（不再 normalize 整串）**。
- `nudgeHash(title,blocks)`：同上但只取 DIFF_TYPES 塊，前面接 `normalizeText(title) + "\n\n"` → **fnv1a**。
- 契約 §3.6 寫的是「→ fnvHash」，但若對整串再 normalize 會把 `\n\n` 分隔折成空格、破壞邊界，故我採「組裝後 fnv1a」與 fullHash 一致。**請後端確認網頁版 nudgeHash 是 `fnv1a(assembled)` 還是 `fnvHash(assembled)`**，若不同我立即改。
