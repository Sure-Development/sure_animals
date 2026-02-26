---@class Animals.shared.interface
local M = {}

local parent = lib.parent
local registerMenu = lib.registerMenu
local showMenu = lib.showMenu
local setMenuOptions = lib.setMenuOptions
local inputDialog = lib.inputDialog
local alertDialog = lib.alertDialog

local floor = lib.math.floor
local groupdigits = lib.math.groupdigits

M.initial = function()
  ---@type MenuPosition
  local position = 'bottom-left'

  --- MARK: main_context
  registerMenu({
    id = 'main_context',
    title = 'รายการเมนู',
    position = position,
    options = {
      { label = 'เรียกดูสัตว์เลี้ยง' },
      { label = 'ฟาร์มเพื่อน' }
    },
  }, function(selected)
    if selected == 1 then
      pcall(parent.openAnimalsContext)
    elseif selected == 2 then
      pcall(parent.openFriendsContext)
    end
  end)

  --- MARK: animals_context
  registerMenu(
    {
      id = 'animals_context',
      title = 'สัตว์เลี้ยงทั้งหมด',
      position = position,
      options = {}
    },
    ---@param selected integer
    ---@param args { key: string?, isAnimal: boolean, add: boolean? }
    function(selected, _, args)
      if args.isAnimal and args.key then
        pcall(parent.openPedContext, args.key)
      end

      if args.add then
        ---@type InputDialogRowProps
        local options = { type = 'select', label = 'เลือก', options = {} }
        for eggItem in pairs(lib.parent.public.egg.list) do
          ---@diagnostic disable-next-line: undefined-global
          local item = lib.parent.framework.search_inventory(eggItem)
          if item and item.count > 0 then
            options.options[#options.options + 1] = { label = ('%s (%s)'):format(item.label, groupdigits(item.count)), value = eggItem }
          end
        end

        local result = inputDialog('เลือกไข่สัตว์', { options })
        if result then
          local targetEgg = result[1]
          pcall(parent.addPedToFarm, targetEgg)
        end
      end
    end
  )

  --- MARK: ped_context
  registerMenu(
    {
      id = 'ped_context',
      title = 'จัดการสัตว์เลี้ยง',
      position = position,
      options = {}
    },
    ---@param selected integer
    ---@param args { key: string }
    function(selected, _, args)
      if not args.key then return end

      if selected == 4 then
        ---@type InputDialogRowProps
        local options = { type = 'select', label = 'เลือกอาหาร', options = {} }
        for k in pairs(parent.public.item.feed.list) do
          ---@diagnostic disable-next-line: undefined-global
          local item = lib.parent.framework.search_inventory(k)
          if item and item.count > 0 then
            options.options[#options.options + 1] = { label = ('%s (%s)'):format(item.label, groupdigits(item.count)), value = k }
          end
        end

        local result = inputDialog('ให้อาหาร', { options })
        if result then
          local item = result[1]
          pcall(parent.feedAnimal, args.key, item)
        end
      elseif selected == 5 then
        for _, v in ipairs(lib.parent.currentFarm.list) do
          if v.key == args.key then
            local isConfirmed = alertDialog({
              header = 'คุณกำลังจะขายสัตว์เลี้ยง',
              content = ('ขาย %s ในราคา %s'):format(v.label, groupdigits(v.currentNet)),
              cancel = true,
              centered = true
            })
    
            if isConfirmed then
              pcall(parent.sellAnimation, args.key)
            end
            break
          end
        end
      end
    end
  )

  --- MARK: friends_context
  registerMenu(
    {
      id = 'friends_context',
      title = 'ฟาร์มเพื่อน',
      position = position,
      options = {}
    },
    ---@param selected integer
    ---@param args { invitation: boolean?, identifier: string? }
    function (selected, _, args)
      if args.invitation then
        local result = inputDialog('เชิญเพื่อนเข้าร่วมฟาร์ม', {
          { type = 'number', label = 'ไอดีเพื่อน', icon = 'person' }
        })

        if result then
          pcall(parent.inviteFriend, result[1])
        end
        return
      end

      if args.identifier then
        local result = inputDialog('จัดการฟาร์มเพื่อน', {
          {
            type = 'select',
            label = 'เลือก',
            options = {
              { label = 'ดูฟาร์มเพื่อน', value = 'open' },
              { label = 'ลบเพื่อน', value = 'remove-friend' }
            },
            default = 'open'
          }
        })

        if result then
          if result[1] == 'open' then
            pcall(parent.openFarmOfFriend, args.identifier)
          elseif result[1] == 'remove-friend' then
            local isConfirmed = alertDialog({
              header = 'ยืนยันที่จะลบเพื่อนหรือไม่',
              content = 'กรุณาตรวจสอบข้อมูลและยืนยันอีกครั้ง',
              centered = true,
              cancel = true
            })

            if isConfirmed then
              pcall(parent.removeFriend, args.identifier)
            end
          end
        end
      end
    end
  )
end

---@alias Animals.shared.interface.types
---| 'main_context'         - หน้าแรกเมื่อเปิด UI
---| 'animals_context'      - ดูสัตว์เลี้ยงทั้งหมด
---| 'ped_context'          - ดูสัตว์เลี้ยงรายตัว
---| 'friends_context'      - ฟาร์มเพื่อน
---| 'friend_acceptable'    - ยืนยันการเข้าร่วมฟาร์ม

---@overload fun(menuType: 'main_context')
---@overload fun(menuType: 'animals_context', data: Animals.shared.data)
---@overload fun(menuType: 'ped_context', data: Animals.shared.data.list, key: string)
---@overload fun(menuType: 'friends_context', data: Animals.shared.friend[])
---@overload fun(menuType: 'friend_acceptable', data: string)
M.open_menu = function(menuType, ...)
  local args = { ... }

  if menuType == 'main_context' then
    showMenu(menuType)
  elseif menuType == 'animals_context' then
    local data = args[1] --[[@as Animals.shared.data]]
    local newOptions = {{ label = ('ฟาร์มของ %s'):format(data.name), args = { isAnimal = false } }} --[[@as MenuOptions[] ]]

    if #data.list < lib.parent.public.egg.limit_peds then
      newOptions[#newOptions + 1] = {
        label = 'เพิ่มสัตว์เลี้ยง',
        args = { isAnimal = false, add = true },
        icon = 'plus'
      }
    end

    for k, v in ipairs(data.list) do
      newOptions[#newOptions + 1] = {
        label = ('%s : %s'):format(groupdigits(k), v.label),
        description = ('เจริญเติบโต %s%s | มูลค่าปัจจุบัน %s'):format(floor(v.growth), '%', groupdigits(v.currentNet)),
        args = { isAnimal = true, key = v.key },
        progress = floor(v.growth),
      }
    end

    setMenuOptions(menuType, newOptions)
    showMenu(menuType)
  elseif menuType == 'ped_context' then
    local data = args[1] --[[@as Animals.shared.data.list]]
    local key = args[2] --[[@as string]]
    local newOptions = {
      { label = ('%s'):format(data.label), icon = 'paw' },
      { label = ('เจริญเติบโต %s%s'):format(floor(data.growth), '%'), progress = data.growth, icon = 'arrow-up-right-dots' },
      { label = ('มูลค่าปัจจุบัน %s'):format(groupdigits(data.currentNet)), icon = 'hand-holding-dollar' },
      { label = 'ให้อาหาร', args = { key = key } },
      { label = 'ขาย', args = { key = key } }
    } --[[@as MenuOptions[] ]]

    setMenuOptions(menuType, newOptions)
    showMenu(menuType)
  elseif menuType == 'friends_context' then
    local data = args[1] --[[@as Animals.shared.friend[] ]]
    local newOptions = {
      { label = 'เชิญเพื่อนเข้าร่วมฟาร์ม', args = { invitation = true }, icon = 'plus' }
    } --[[@as MenuOptions[] ]]

    for _, v in ipairs(data) do
      newOptions[#newOptions + 1] = { label = v.name, args = { identifier = v.identifier } }
    end

    setMenuOptions(menuType, newOptions)
    showMenu(menuType)
  elseif menuType == 'friend_acceptable' then
    local data = args[1] --[[@as string]]
    local isConfirmed = alertDialog({
      header = 'มีการเชิญชวนเข้าร่วมฟาร์ม',
      content = ('เชิญโดย %s'):format(data),
      cancel = true,
      centered = true
    })

    return isConfirmed
  end
end

return M