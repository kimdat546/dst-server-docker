do
local cnt, qty = {}, {}
for _, e in pairs(Ents) do
local comp = e.components
local ii = comp and comp.inventoryitem
if ii ~= nil and e.prefab ~= nil and not ii:IsHeld() and not e:IsInLimbo() and e.parent == nil then
local n = (comp.stackable ~= nil and comp.stackable:StackSize()) or 1
cnt[e.prefab] = (cnt[e.prefab] or 0) + 1
qty[e.prefab] = (qty[e.prefab] or 0) + n
end
end
local list = {}
for p, k in pairs(cnt) do list[#list+1] = {p, k, qty[p]} end
table.sort(list, function(a,b) return a[3] > b[3] end)
local tote, totq = 0, 0
for i = 1, #list do tote = tote + list[i][2]; totq = totq + list[i][3] end
print("[SURVEY] " .. #list .. " loai | " .. tote .. " o dat | " .. totq .. " mon")
local buf = {}
for i = 1, #list do
buf[#buf+1] = list[i][1] .. "=" .. list[i][3] .. "/" .. list[i][2] .. "o"
if #buf == 12 or i == #list then print("[SURVEY] " .. table.concat(buf, "  ")); buf = {} end
end
end
