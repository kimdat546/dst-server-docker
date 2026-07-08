# Fairy Tales - Đừng Chết Đói :)

Mod **client-only** việt hoá mod 童话世界 **Fairy Tales** (Steam Workshop `3288149713`) đang dùng trên world `fairy-tales`.

Mod gốc bị mã hoá (không sửa trực tiếp được) và là `all_clients_require_mod` (client tự tải từ Workshop và render tên/mô tả phía client). Vì vậy bản dịch phải là **mod client riêng**, chạy trên máy từng người chơi, load **sau** mod gốc rồi **ghi đè `GLOBAL.STRINGS`** sang tiếng Việt trong `AddSimPostInit`. Không đụng vào mod gốc → sống sót qua mọi bản cập nhật của mod gốc.

## Phạm vi (phiên bản 0.1.0)
Đã dịch **597 chuỗi**: tên vật phẩm (NAMES), mô tả khi kiểm tra (DESCRIBE), công thức chế tạo (RECIPE_DESC), hành động (ACTIONS), nhãn tab chế tạo, cửa hàng, và màn chọn nhân vật Bội Linh.

**Chưa dịch (phase 2 — thoại):** thoại nhân vật (~302KB, bảng `STRINGS.CHARACTERS.<char>` — chưa harvest), Mũ Mồm Thối (`FT_VICIOUSHAT`), `FAIRY_CURSE`, `FAIRY_DISGUST`. Bỏ qua: chuỗi UI vanilla/`PRETRANSLATED` (không phải của mod).

## Cấu trúc
| File | Vai trò |
|---|---|
| `modinfo.lua` | Metadata mod (client_only_mod=true, priority=-100) |
| `modmain.lua` | **Tự sinh** — framework + bảng dịch nhúng. Đừng sửa tay. |
| `vi_translations.tsv` | **Nguồn dịch** (key⇥tiếng Việt). Sửa ở đây. |
| `build.py` | Sinh lại `modmain.lua` từ TSV: `python3 build.py` |
| `_harvest_dump.tsv` | Toàn bộ chuỗi tiếng Trung đã giải mã (916 dòng) lấy từ server — nguồn để dịch tiếp |

## Sửa bản dịch
1. Sửa giá trị trong `vi_translations.tsv` (giữ nguyên key và các `%s`, `\n`).
2. `python3 build.py` → sinh lại `modmain.lua`.
3. (Tuỳ chọn) Kiểm tra cú pháp: `luac5.3 -p modmain.lua`.

## Test thử trên máy chơi (local, trước khi publish)
1. Copy cả thư mục này vào `…/Don't Starve Together/mods/fairy-tales-vi/`.
2. Vào game → **Mods** → bật "Fairy Tales - Đừng Chết Đói :)".
3. Vào server `fairy-tales` → kiểm tra tên/mô tả vật phẩm của mod Fairy Tales đã ra tiếng Việt.
   (Log sẽ in `[Fairy Tales Tiếng Việt] đã áp dụng 597 chuỗi tiếng Việt`.)

## Publish lên Workshop
1. Thêm icon: bỏ `modicon.tex` + `modicon.xml` (256×256) vào thư mục này và bỏ comment 2 dòng `icon`/`icon_atlas` trong `modinfo.lua` (mod tools convert được từ PNG).
2. Dùng mod uploader của DST (như mod "DST Tiếng Việt" trước đây) để publish. Có thể để **unlisted/friends-only** nếu chỉ dùng cho server riêng.
3. Mỗi người chơi subscribe + bật mod là thấy tiếng Việt khi vào server.

## Thêm phase 2 (thoại)
Bảng thoại nằm dưới `STRINGS.CHARACTERS.<char>` — dumper phase 1 đã **bỏ qua** chủ ý. Để harvest:
1. Sửa dumper `../_dumpstrings-tool/modmain.lua` cho duyệt cả `STRINGS.CHARACTERS` (bỏ nhánh SKIP), deploy lại như local server mod 1 lần (xem ghi chú vận hành trong project memory), đọc log, gộp vào `vi_translations.tsv`, dịch, `build.py`.
