# Khảo sát vật phẩm trên mặt đất

Cách biết prefab nào đang nằm nhiều dưới đất, để quyết định thêm gì vào
[`cli/lua/cleanup_prefabs.txt`](../cli/lua/cleanup_prefabs.txt).

## Chạy khảo sát

Hỏi thẳng server, vì nó dùng đúng component `inventoryitem` thật — chính xác hơn
suy đoán từ file save:

```bash
L="$(tr '\n' ' ' < cli/lua/survey_ground.lua)"
dst console "$L"
dst console --caves "$L"
```

Kết quả in ra dạng `prefab=<tổng món>/<số ô>o`, sắp xếp giảm dần.

## ⚠ Sinh vật sống cũng khớp bộ lọc

Bộ lọc của `dst cleanup` là "có component `inventoryitem`, không bị cầm, không ở
limbo". Nhiều **sinh vật sống** bắt được bằng vợt nên chúng cũng có component đó
và sẽ xuất hiện trong bảng khảo sát như một vật phẩm bình thường:

```
fireflies  rabbit  bee  mole  butterfly  lightflier  slurper
carrat  mosquito  bird_mutant  crow  robin  canary
```

Thêm chúng vào danh sách xoá là **giết sạch** chúng. `fireflies` đặc biệt đáng
giữ — đó là nguồn đèn.

## Kết quả mốc — 2026-08-04, world `dang-tien` ngày ~300

Sau khi đã dọn hai lượt. Số là *số ô* (mỗi ô là một entity, không phải số món).

| | Master | Caves |
|---|---|---|
| tổng loại | ~190 | 91 |
| rocks | 211 | 139 |
| flint | 145 | 125 |
| **fireflies** ⚠ sinh vật | 301 | 25 |
| **rabbit** ⚠ sinh vật | 83 | — |
| **lightflier** ⚠ sinh vật | — | 79 |
| nightmarefuel | 63 | 46 |
| gems (đỏ/lam/lục/tím/cam/vàng) | ~88 | ~72 |
| xd_lingshi1 (linh thạch mod) | 59 | 80 |

## Phát hiện quan trọng: dọn rác KHÔNG giảm lag

Đo trên chính server này:

- Xoá **10.049 vật phẩm** (lượt 1) → CPU luồng chính **không đổi** (94–101% → 93–99%)
- Xoá thêm **3.963 vật phẩm** (lượt 2) → tải quanh base **654 → 669 entity**, tức không đổi

Lý do: đếm theo không gian cho thấy **chỉ 2%** (19/1.182 ô) số rác nằm trong bán
kính 60 quanh base. Phần còn lại rải khắp bản đồ, ở những nơi không ai đứng — mà
DST chỉ tốn CPU cho khu vực quanh người chơi.

Thứ thật sự nặng là **cụm dày quanh base**: 80 luống đất, ~70 tường gỗ, và ~290 ô
đồ trong rương. Xem skill [`dst-diagnose`](../.claude/skills/dst-diagnose) để biết cách đo.

**Kết luận:** dùng `dst cleanup` để gọn thế giới và nhẹ file save, đừng kỳ vọng
nó chữa lag.
