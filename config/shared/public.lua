---@class Animals.shared.friend
---@field identifier string
---@field name string

---@class Animals.shared.data
---@field owner string
---@field name string
---@field list Animals.shared.data.list[]

---@class Animals.shared.data.list
---@field key string                                    - Key unique กำกับแต่ละสัตว์เลี้ยง (ใช้ร่วมกับฐานข้อมูล)
---@field name string                                   - ชื่อตาม M.egg.list
---@field label string                                  - ชื่อกำกับตาม M.egg.list[..].label
---@field ped string                                    - Model ของสัตว์เลี้ยง
---@field growth integer                                - ค่า Progress 0-100
---@field currentNet number                             - มูลค่าปัจจุบัน

--- ตั้งค่าภาษา
lib.locale('th')

---@class Animals.shared.public
local M = {}

---@type SphereZone
M.position = {
  coords = vec3(1450.400757, 1066.786133, 114.333839),
  radius = 40.0,
  debug = true
}

---@class Animals.shared.public.item.feed
---@field cooldown_each_ped integer                     - คูลดาวน์การให้อาหารแต่ละสัตว์เลี้ยง
---@field list table<string, integer>                   - รายชื่อไอเทมที่สามารถให้อาหาร : จำนวนหลอด Progress ที่จะเพิ่มเมื่อใช้งาน

---@class Animals.shared.public.item
---@field feed Animals.shared.public.item.feed
M.item = {
  feed = {
    cooldown_each_ped = 60,
    list = {
      ['item_2'] = 20,
    }
  }
}

---@class Animals.shared.public.egg.list
---@field label string                                  - ชื่อกำกับว่าเป็นสัตว์ประเภทอะไรหรือชื่ออะไร
---@field ped string                                    - ชื่อ Model ของสัตว์เลี้ยงของไอเทมชิ้นนั้น
---@field net_by_hours integer[]                        - มูลค่าของสัตว์เลี้ยงตัวนั้นเมื่อเลี้ยงถึงแต่ละชั่วโมง (อ้างอิงชั่วโมงจาก M.egg.target_hours)

---@class Animals.shared.public.egg
---@field limit_peds integer                            - จำกัดจำนวนตัวที่สามารถเลี้ยงได้
---@field target_hours integer[]                        - จำนวนชั่วโมงที่เลี้ยงสัตว์เลี้ยงถึงแล้วจะสามารถเก็บได้
---@field growth_decrease_by_hour integer               - แต่ละชั่วโมงจะลดหลอด Progress แต่ละตัวด้วยจำนวนเท่าไหร่
---@field timeout_on_growth_are_zero_in_hour integer    - เมื่อโหลด Progress เหลือ 0 มีเวลาเท่าไหร่ที่จะสามารถกลับมาให้อาหารได้ ก่อนจะถูกลบ
---@field list table<string, Animals.shared.public.egg.list>
M.egg = {
  limit_peds = 5,
  target_hours = { 24, 48, 72, 96, 120, 144, 168 },
  growth_decrease_by_hour = 2,
  timeout_on_growth_are_zero_in_hour = 12,
  list = {
    ['item_1'] = {
      label = 'Chicken',
      ped = 'a_c_boar',
      net_by_hours = {
        5000, -- 24hrs
        20000, -- 48hrs
        40000, -- 72hrs
        80000, -- 96hrs
        100000, -- 120hrs
        150000, -- 144hrs
        250000 -- 168hrs
      }
    }
  }
}

---@param model string
---@param coords vector3
---@return integer
M.create_ped = function(model, coords)
  lib.requestModel(model)

  local radiusToWalk = 8.0
  local offsetX = math.random(-4, 4)
  local offsetY = math.random(-4, 4)
  local heading = math.random(0, 360)

  local pedIndex = CreatePed(0, model, coords.x + offsetX, coords.y + offsetY, coords.z, heading, false, true)
  SetBlockingOfNonTemporaryEvents(pedIndex, true)
  SetEntityInvincible(pedIndex, true)
  SetPedCanRagdoll(pedIndex, false)
  TaskWanderInArea(pedIndex, coords.x, coords.y, coords.z, radiusToWalk, 2, 10.0)

  return pedIndex
end

---@param pedIndex integer
M.remove_ped = function(pedIndex)
  DeleteEntity(pedIndex)
end

---@return boolean
M.is_ped_dead = function()
  return LocalPlayer.state.isDead or false
end

---@alias Animals.shared.public.notifyTypes
---| 'info'
---| 'warning'
---| 'error'
---| 'success'

---@alias Animals.shared.public.status
---| 'not_friend'
---| 'ped_on_cooldown'
---| 'ped_is_missing_growth'
---| 'player_error'
---| 'egg_not_found'
---| 'feed_not_found'
---| 'ped_key_not_found'
---@param type Animals.shared.public.notifyTypes
---@param message string
---@param status Animals.shared.public.status
M.notification = function(type, message, status)
  local typesTitle = {
    ['success'] = 'สำเร็จ',
    ['info'] = 'ข้อมูล',
    ['warning'] = 'เกิดข้อผิดพลาด',
    ['error'] = 'ระบบผิดพลาด'
  }

  lib.notify({
    type = type,
    title = typesTitle[type],
    description = message,
    position = 'center-right'
  })
end

return M