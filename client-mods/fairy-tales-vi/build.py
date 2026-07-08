import re, os
# Regenerate modmain.lua from vi_translations.tsv.  Run:  python3 build.py
MOD=os.path.dirname(os.path.abspath(__file__))
vi=f"{MOD}/vi_translations.tsv"

order=['NAMES.','RECIPE_DESC.','CHARACTERS.GENERIC.DESCRIBE.','ACTIONS.','UI.','TRADINGSTORE.','CHARACTER_']
def rank(k):
    for i,p in enumerate(order):
        if k.startswith(p): return i
    return 99

entries=[]
for l in open(vi,encoding='utf-8'):
    l=l.rstrip('\n')
    if not l.strip() or '\t' not in l: continue
    k,v=l.split('\t',1)
    entries.append((k,v))

# sanity checks
bad=[(k,v) for k,v in entries if re.search(r'\\(?!n)', v)]
assert not bad, f"stray backslash: {bad[:5]}"
cjk=[(k,v) for k,v in entries if any(0x4e00<=ord(c)<=0x9fff or 0x3000<=ord(c)<=0x303f or 0xff00<=ord(c)<=0xffef for c in v)]
assert not cjk, f"CJK left: {cjk[:5]}"

def esc(s):
    return s.replace('"','\\"')

entries.sort(key=lambda kv:(rank(kv[0]), kv[0]))

header = '''-- Fairy Tales Tiếng Việt — client-side translation overlay for Workshop mod 3288149713.
-- AUTO-GENERATED from vi_translations.tsv — do not hand-edit; edit the TSV and regenerate.
--
-- How it works: this is a client_only mod that loads AFTER the Fairy Tales mod (priority -100),
-- then overrides its Chinese GLOBAL.STRINGS entries with Vietnamese inside AddSimPostInit
-- (by which point every mod's modmain has run, so the original strings already exist).
-- Item names/descriptions/recipes are looked up live from STRINGS, so overriding here applies.

local STRINGS = GLOBAL.STRINGS
local pairs   = GLOBAL.pairs        -- DST's mod sandbox does not expose these as bare globals
local type    = GLOBAL.type
local string  = GLOBAL.string
local print   = GLOBAL.print

-- key path under STRINGS  ->  Vietnamese text
local VI = {'''

footer_tbl = '}'

apply = '''
-- Set STRINGS by a dotted path (e.g. "CHARACTERS.GENERIC.DESCRIBE.FT_BREAD"),
-- creating any missing intermediate tables along the way.
local function setpath(root, path, value)
    local segs = {}
    for seg in string.gmatch(path, "[^.]+") do
        segs[#segs + 1] = seg
    end
    local t = root
    for i = 1, #segs - 1 do
        local s = segs[i]
        if type(t[s]) ~= "table" then t[s] = {} end
        t = t[s]
    end
    t[segs[#segs]] = value
end

local function applyVI()
    local n = 0
    for path, vitext in pairs(VI) do
        setpath(STRINGS, path, vitext)
        n = n + 1
    end
    print("[Fairy Tales Tiếng Việt] đã áp dụng " .. n .. " chuỗi tiếng Việt")
end

-- AddSimPostInit runs after every mod's modmain, so the Fairy Tales strings already exist.
AddSimPostInit(applyVI)
'''

lines=[header]
cur=None
for k,v in entries:
    cat = k.split('.')[0] if not k.startswith('CHARACTERS') else 'CHARACTERS.GENERIC.DESCRIBE'
    if cat!=cur:
        lines.append(f'  -- {cat}')
        cur=cat
    lines.append(f'  ["{k}"] = "{esc(v)}",')
lines.append(footer_tbl)
lines.append(apply)

open(f"{MOD}/modmain.lua","w",encoding='utf-8').write('\n'.join(lines)+'\n')
print("wrote modmain.lua with",len(entries),"inline entries")
