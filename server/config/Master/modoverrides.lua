-- World: newconstant
-- Lấy từ bộ mod của world dang-tien, BỎ 登仙 (workshop-3235319974),
-- THÊM 3 mod NewConstant bản Việt hoá + 4 mod tiện ích.
-- ⚠ Master và Caves phải GIỐNG HỆT nhau.
return {

  -- ── NewConstant (bản Việt hoá, Unlisted) ─────────────────────────────────
  -- Thứ tự nạp do priority trong modinfo quyết định: Core(0) → Base(-512)
  -- → Nightmare(-1024). Ba mod này KHÔNG khai báo mod_dependencies (khai báo đó
  -- làm client sập ở GetModDependencies — xem tools/build.py của mod), nên phải
  -- liệt kê đủ cả ba ở đây.
  ["workshop-3778107626"]={          -- NewConstant Core
    configuration_options={
      ncvi_language="vi",            -- DST không có locale tiếng Việt → phải chọn tay
      charge_control="KEY_X",
      skill_control="KEY_V",
      charge_mode=true
    },
    enabled=true
  },
  ["workshop-3778108141"]={          -- NewConstant Base
    configuration_options={
      ruins=true, worldgen=true, firefall=true, poison=true, gestalt=true,
      twin=true, alter=true, pig=true, rook=true, klaus=true, chess=true,
      stalker=true, toad=true, portal=true, wardrobe=true, ruinsbat=true
    },
    enabled=true
  },
  ["workshop-3778108374"]={          -- NewConstant Nightmare (nội dung Vực Sâu)
    configuration_options={ twin=true, ruins=true, worldgen=true },
    enabled=true
  },

  -- ── Mod nội dung thêm ────────────────────────────────────────────────────
  ["workshop-1392778117"]={          -- [DST] Legion
    configuration_options={ Language="english" },
    enabled=true
  },

  -- ── Tiện ích mới ─────────────────────────────────────────────────────────
  ["workshop-3353852416"]={          -- Fast Travel (skined home sign)
    configuration_options={
      TeleportEnable=true, HomesignEnable=false, LightEnable=true,
      ResurrectEnable=true, HungerCost=1, SanityCost=1,
      CountdownEnable=false, TextEnable=false
    },
    enabled=true
  },
  ["workshop-1207269058"]={ configuration_options={  }, enabled=true },  -- Simple Health Bar
  ["workshop-666155465"]={           -- Show Me (Origin)
    configuration_options={ chestR=-1, chestG=-1, chestB=-1 },
    enabled=true
  },

  -- ── Giữ nguyên từ world dang-tien ────────────────────────────────────────
  ["workshop-3774466732"]={ configuration_options={  }, enabled=true },  -- Food Buff (tự viết)
  ["workshop-1780476441"]={ configuration_options={  }, enabled=true },  -- Fast Pigking
  ["workshop-375850593"]={  configuration_options={  }, enabled=true },  -- Extra Equip Slots
  ["workshop-1803285852"]={          -- Auto Stack and Pick Up
    configuration_options={
      [""]=0,
      AutoPickupAsh=false,
      AutoPickupEnabled=false,
      AutoPickupPoop=false,
      AutoPickupRange=10,
      AutoPickupSeeds=false,
      AutoStackAsh=true,
      AutoStackEnabled=true,
      AutoStackMakeNewStackMainStack=false,
      AutoStackManuallyDroppedItems=true,
      AutoStackPoop=true,
      AutoStackRange=10,
      AutoStackSeeds=true,
      AutoStackTwiggyTreeTwigs=true,
      ManualDropStackRange=10,
      ManualStackAsh=true,
      ManualStackMakeNewStackMainStack=true,
      ManualStackPoop=true,
      ManualStackSeeds=true,
      PlayerMustHaveOneOfItemToAutoPickup=false,
      SmokePuffOnStacking=true,
      StackDuringPopulation=false
    },
    enabled=true
  },
  ["workshop-374550642"]={           -- Increased Stack size
    configuration_options={
      FORCE_STACKSIZES=false,
      STACK_SIZE_LARGEITEM=99,
      STACK_SIZE_MEDITEM=99,
      STACK_SIZE_PELLET=250,
      STACK_SIZE_SMALLITEM=99,
      STACK_SIZE_TINYITEM=120
    },
    enabled=true
  },
  ["workshop-380423963"]={           -- Mineable Gems
    configuration_options={
      [""]=0,
      boulder_blue=0.75,
      boulder_purple=0.75,
      change_cave_loot=false,
      common_loot_charcoal=0,
      common_loot_flint=0.35,
      common_loot_rocks=0.35,
      cutlichen=0,
      durian=0,
      flintless_blue=0.75,
      flintless_purple=0.75,
      flintless_red=0.75,
      foliage=0,
      gears=0,
      goldvein_purple=0.75,
      goldvein_red=0.75,
      guano=0,
      ice=0,
      lightbulb=0,
      moon_green=0.5,
      moon_orange=0.5,
      moon_yellow=0.5,
      pinecone=0,
      rare_loot_bluegem=0.3,
      rare_loot_marble=0.3,
      rare_loot_redgem=0.3,
      rottenegg=0,
      seeds=0,
      spoiled_food=0,
      stalagmite_green=0.5,
      stalagmite_orange=0.5,
      stalagmite_yellow=0.5,
      uncommon_loot_goldnugget=0.2,
      uncommon_loot_mole=0.2,
      uncommon_loot_nitre=0.2,
      uncommon_loot_rabbit=0.2
    },
    enabled=true
  },
  ["workshop-501385076"]={           -- Quick Pick
    configuration_options={
      quick_cook_on_fire=true,
      quick_harvest=true,
      quick_pick_cactus=true,
      quick_pick_plant_normal_ground=true
    },
    enabled=true
  }
}
