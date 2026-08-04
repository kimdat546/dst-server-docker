-- Kiểm hồi quy cho cleanup_ground.lua — chạy ngoài máy, không cần server:
--     lua cli/lua/test_cleanup_ground.lua cli/lua/cleanup_ground.lua
--
-- ⚠ Bộ kiểm này CHỈ kiểm logic. Nó không thay được việc chạy thử trên server
-- thật, vì mock do chính mình viết sẽ luôn khớp với giả định của chính mình.
-- Lần đầu viết cleanup_ground.lua, mock báo xanh nhưng server thật ném
-- "variable 'CLEANUP_PREFABS' is not declared" — nên phần giả lập strict bên
-- dưới được thêm vào để bắt đúng loại lỗi đó. Sửa file kia xong vẫn nên chạy
-- lại một lượt trên harness headless.

local script = arg[1] or "cleanup_ground.lua"

-- ── Giả lập strict.lua của DST ────────────────────────────────────────────
-- DST cấm ĐỌC biến toàn cục chưa khai báo (ném lỗi thay vì trả nil).
local declared = {}
setmetatable(_G, {
    __newindex = function(t, k, v) declared[k] = true; rawset(t, k, v) end,
    __index    = function(t, k)
        if not declared[k] then error("variable '" .. tostring(k) .. "' is not declared", 2) end
        return nil
    end,
})

-- ── Giả lập tối thiểu API DST ─────────────────────────────────────────────
local removed = {}
local function ent(prefab, o)
    o = o or {}
    local e = { prefab = prefab, parent = o.parent, inlimbo = o.inlimbo or false,
                components = {}, _label = o.label or prefab }
    if not o.no_item then
        e.components.inventoryitem = { owner = o.owner, IsHeld = function(s) return s.owner ~= nil end }
    end
    if o.stack then
        e.components.stackable = { n = o.stack, StackSize = function(s) return s.n end }
    end
    e.IsInLimbo = function(s) return s.inlimbo end
    e.Remove    = function(s) removed[#removed + 1] = s._label end
    return e
end

local chest     = ent("treasurechest", { no_item = true, label = "rương thường" })
local mod_chest = ent("xd_dbg",        { no_item = true, label = "rương mod Đăng Tiên" })
local backpack  = ent("backpack",      { label = "balo dưới đất" })

Ents = {
    ent("twigs",    { stack = 40, label = "PHAI_MAT cành cây dưới đất" }),
    ent("log",      { stack = 20, label = "PHAI_MAT gỗ dưới đất" }),
    ent("charcoal", { stack = 9,  label = "PHAI_MAT than dưới đất" }),
    ent("twigs",    {             label = "PHAI_MAT cành cây lẻ" }),

    ent("log",      { owner = chest,     stack = 120, label = "gỗ TRONG rương thường" }),
    ent("twigs",    { owner = mod_chest, stack = 120, label = "cành cây TRONG rương mod" }),
    ent("charcoal", { owner = backpack,  stack = 60,  label = "than TRONG balo" }),
    ent("log",      { inlimbo = true,  label = "gỗ ở limbo" }),
    ent("twigs",    { parent = chest,   label = "cành cây bị gắn parent" }),
    ent("goldnugget", { stack = 40, label = "vàng dưới đất (ngoài danh sách)" }),
    ent("flint",      { stack = 30, label = "đá lửa dưới đất (ngoài danh sách)" }),
    backpack, chest, mod_chest,
}

-- ── Trường hợp 1: CHẠY THỬ, và KHÔNG đặt CLEANUP_PREFABS ─────────────────
-- Đây chính là trường hợp từng làm server thật ném lỗi.
CLEANUP_APPLY = false
local ok, err = pcall(assert(loadfile(script)))
local fail = 0
if not ok then
    print("  ✗ chạy thử ném lỗi: " .. tostring(err)); fail = fail + 1
elseif #removed > 0 then
    print("  ✗ chế độ THỬ mà vẫn xoá " .. #removed .. " món"); fail = fail + 1
else
    print("  ✓ chế độ thử: không xoá gì, không lỗi strict")
end

-- ── Trường hợp 2: XOÁ THẬT với danh sách mặc định ───────────────────────
removed = {}
CLEANUP_APPLY = true
ok, err = pcall(assert(loadfile(script)))
if not ok then print("  ✗ xoá thật ném lỗi: " .. tostring(err)); fail = fail + 1 end

local got = {}
for _, l in ipairs(removed) do got[l] = true end
local expected = 0
for _, e in ipairs(Ents) do
    local must = e._label:find("^PHAI_MAT") ~= nil
    if must then expected = expected + 1 end
    if must and not got[e._label] then
        print("  ✗ LẼ RA PHẢI XOÁ nhưng còn: " .. e._label); fail = fail + 1
    elseif not must and got[e._label] then
        print("  ✗✗ XOÁ NHẦM: " .. e._label); fail = fail + 1
    end
end
if fail == 0 then
    print("  ✓ xoá đúng " .. expected .. " món dưới đất; rương/balo/limbo/parent/ngoài-danh-sách đều an toàn")
end

-- ── Trường hợp 3: danh sách tuỳ chọn ────────────────────────────────────
removed = {}
CLEANUP_PREFABS = "log"
ok = pcall(assert(loadfile(script)))
if not ok or #removed ~= 1 then
    print("  ✗ danh sách tuỳ chọn sai: xoá " .. #removed .. " món (mong đợi 1)"); fail = fail + 1
else
    print("  ✓ danh sách tuỳ chọn: chỉ xoá gỗ dưới đất")
end

print(fail == 0 and "\n  TẤT CẢ ĐẠT" or ("\n  HỎNG " .. fail .. " chỗ"))
os.exit(fail == 0 and 0 or 1)
