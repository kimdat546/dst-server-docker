-- cleanup_ground.lua — dọn vật phẩm rác NẰM TRÊN MẶT ĐẤT của shard hiện tại.
--
-- Chạy được ở hai nơi, cùng một đoạn mã:
--   1. Console trong game (admin, Ctrl+` để bật chế độ remote → chạy trên server)
--   2. `dst cleanup` gửi qua stdin của container (cần stdin_open, xem cli/compose.yml)
--
-- ⚠ AN TOÀN — vì sao đồ trong rương KHÔNG bao giờ bị đụng tới:
--   Trong DST, vật phẩm bỏ vào rương/túi/Chester vẫn là entity, nhưng bị
--   `RemoveFromScene()` và có `inventoryitem.owner` trỏ tới vật chứa. Ba lớp
--   kiểm tra dưới đây đều phải đúng thì mới xoá:
--     • ii:IsHeld() == false   → owner == nil, tức không nằm trong bất kỳ vật
--                                chứa nào (kể cả rương của mod Đăng Tiên, vì
--                                chúng cũng dùng component container chuẩn)
--     • e:IsInLimbo() == false → đang thật sự hiện diện trong thế giới
--     • e.parent == nil        → không bị gắn vào entity khác
--   Đồ trong balo đang nằm dưới đất cũng an toàn: balo mới là thứ trên mặt đất,
--   còn đồ bên trong có owner = balo.
--
-- Cấu hình qua biến toàn cục (do bên gọi đặt trước):
--   CLEANUP_APPLY    = true  → xoá thật. Thiếu hoặc false → chỉ đếm (mặc định).
--   CLEANUP_PREFABS  = "twigs,log,..." → danh sách prefab. Thiếu → dùng mặc định.
--
-- Mặc định CỐ Ý không có flint/rocks/gold/nitre — chúng là tài nguyên có giá trị.

-- ⚠ Phải dùng rawget: DST nạp strict.lua, ĐỌC một biến toàn cục chưa được khai
-- báo là ném lỗi ngay ("variable 'X' is not declared"), chứ không trả nil như
-- Lua thường. Viết `CLEANUP_PREFABS or "..."` sẽ chạy ngon ở lua ngoài máy
-- nhưng chết trên server thật — đã dính đúng lỗi này khi chạy thử.
local APPLY = (rawget(_G, "CLEANUP_APPLY") == true);
local LIST  = rawget(_G, "CLEANUP_PREFABS")
              or "twigs,log,charcoal,cutgrass,petals,ash,spoiled_food";

local WANT = {};
for p in string.gmatch(LIST, "[^,%s]+") do WANT[p] = true; end

-- Hai lượt: gom trước, xoá sau. Xoá ngay trong vòng pairs(Ents) là sửa bảng
-- đang duyệt — nguồn lỗi khó tìm.
local doomed, count, brk = {}, 0, {};
for _, e in pairs(Ents) do
    local c  = e.components;
    local ii = c and c.inventoryitem;
    if ii ~= nil and e.prefab ~= nil and WANT[e.prefab]
       and not ii:IsHeld() and not e:IsInLimbo() and e.parent == nil then
        local q = (c.stackable ~= nil and c.stackable:StackSize()) or 1;
        doomed[#doomed + 1] = e;
        count = count + q;
        brk[e.prefab] = (brk[e.prefab] or 0) + q;
    end
end

local parts = {};
for p, q in pairs(brk) do parts[#parts + 1] = p .. "=" .. q; end
table.sort(parts);

print("[CLEANUP] " .. (APPLY and "DA XOA" or "THU (chua xoa)")
      .. ": " .. #doomed .. " o dat / " .. count .. " mon | "
      .. (#parts > 0 and table.concat(parts, ", ") or "khong co gi"));

if APPLY then
    for _, e in ipairs(doomed) do e:Remove(); end
    print("[CLEANUP] Hoan tat. Do trong ruong khong bi dung toi.");
else
    print("[CLEANUP] Chay lai voi --apply de xoa that.");
end
