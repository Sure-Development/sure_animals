---@class Animals.server.parent
lib.parent = {}
---@class Animals.server.data : Animals.shared.data.list
---@field lifeHours integer
---@field timeout integer?
---@type table<string, Animals.server.data[]>
lib.parent.data = {}
---@type table<string, string<string, string>>
lib.parent.friends = {}
lib.parent.public = require('config.shared.public')
lib.parent.framework = require('config.framework.server')
lib.parent.compresser = require('modules.compresser.shared')
lib.parent.storage = require('modules.storage.server')

local request = lib.callback.await
local registerCallback = lib.callback.register
local app = promise.new()

---@param source integer
---@return string
local function getIdentifier(source)
  return GetPlayerIdentifierByType(source --[[@as string]], 'steam')
end

local function saveFriendsInternal()
  SaveResourceFile(cache.resource, 'db/friends.json', json.encode(lib.parent.friends), -1)
end

local function compress(data)
  local result = lib.parent.compresser:CompressZlib(json.encode(data))
  if not result then
    return ''
  end
  return result
end

local function createTracer(source)
  return function(...)
    if source == 0 then
      lib.print.info(...)
    else
      TriggerClientEvent('cfx-sure_animals:trace', source, ...)
    end
  end
end

---@param tbl table
---@param prop any
---@param value any
local function getTarget(tbl, prop, value)
  if tbl and next(tbl) then
    for k, v in ipairs(tbl) do
      if (prop and value and v[prop]) and v[prop] == value then
        return v, k
      end
    end
  end
end

---@param source integer
---@param targetIdentifier string
---@return boolean
lib.parent.validateFriend = function(source, targetIdentifier)
  local myIdentifier = getIdentifier(source)
  return
    (lib.parent.friends[myIdentifier] ~= nil and lib.parent.friends[targetIdentifier] ~= nil)
    or myIdentifier == targetIdentifier
end

AddEventHandler('onResourceStart', function(resource)
  if resource == cache.resource then
    app:resolve()
  end
end)

app:next(function()
  if not LoadResourceFile(cache.resource, 'db/friends.json') then SaveResourceFile(cache.resource, 'db/friends.json', '{}', -1) end
  
  lib.parent.storage.initial()
  lib.parent.framework.initial()
  lib.parent.friends = lib.loadJson('db.friends')

  ---@type table<string, OxTimer>
  local cooldown = {}
  local targetHoursArray = lib.array:from(lib.parent.public.egg.target_hours)

  CreateThread(function()
    while true do
      Wait((60 * 1000) * 24)

      for identifier, data in pairs(lib.parent.data) do
        local egg = lib.parent.public.egg

        for pedIndex, ped in ipairs(data) do
          local pedData = lib.parent.public.egg.list[ped.name]

          if ped.lifeHours == nil then ped.lifeHours = 0 end
          if ped.growth == nil then ped.growth = 0 end
          if ped.currentNet == nil then ped.currentNet = 0 end

          if ped.growth == 0 then
            if ped.timeout == nil then
              ped.timeout = egg.timeout_on_growth_are_zero_in_hour
            end

            if ped.timeout == 0 then
              table.remove(lib.parent.data[identifier], pedIndex)
            end

            ped.timeout -= 1

            local player = lib.parent.framework.get_player_from_identifier(identifier)
            if player then
              TriggerClientEvent('cfx-sure_animals:notify', lib.parent.framework.get_source(player), 'warning', 'ped_is_missing_growth')
            end
          else
            ped.growth = math.max(ped.growth - egg.growth_decrease_by_hour, 0)
            ped.lifeHours = math.min(ped.lifeHours + 1, egg.target_hours[#egg.target_hours])

            if ped.lifeHours and targetHoursArray:includes(ped.lifeHours) then
              local hourIndex = targetHoursArray:findIndex(function(hour) return hour == ped.lifeHours end)
              if hourIndex then ped.currentNet = pedData.net_by_hours[hourIndex] end
            end
          end
        end

        pcall(lib.parent.storage.update_peds, identifier, lib.parent.data[identifier])
      end
    end
  end)

  ---@param source integer
  ---@param targetIdentifier string?
  ---@return string | false, string?
  registerCallback('cfx-sure_animals:getFarmData', function(source, targetIdentifier)
    local validate = true
    if not targetIdentifier then
      targetIdentifier = getIdentifier(source)
      validate = false
    end

    if validate then
      local result = lib.parent.validateFriend(source, targetIdentifier)
      if not result then
        return false, 'not_friend'
      end
    end

    local player = lib.parent.framework.get_player_from_identifier(targetIdentifier)

    if lib.parent.data[targetIdentifier] == nil then
      pcall(lib.parent.storage.insert_peds, targetIdentifier, {})
    end

    local retval, name = pcall(lib.parent.framework.get_name, player)
    if not retval then
      local myIdentifier = getIdentifier(source)
      name = lib.parent.friends[myIdentifier][targetIdentifier]
    end

    return compress({ targetIdentifier, name, lib.parent.data[targetIdentifier] or {} })
  end)

  ---@param source integer
  ---@param targetIdentifier string
  ---@param item string
  ---@return string | false, string?
  registerCallback('cfx-sure_animals:addPedToFarm', function(source, targetIdentifier, item)
    if not lib.parent.public.egg.list[item] then return false, 'egg_not_found' end

    local player = lib.parent.framework.get_player(source)
    if not player then return false, 'player_error' end

    local eggData = lib.parent.public.egg.list[item]

    lib.parent.framework.remove_item(player, item, 1)

    if lib.parent.data[targetIdentifier] == nil then lib.parent.data[targetIdentifier] = {} end
    lib.parent.data[targetIdentifier][#lib.parent.data[targetIdentifier] + 1] = {
      key = lib.string.random('.........'),
      name = item,
      label = eggData.label,
      currentNet = 0,
      lifeHours = 0,
      ped = eggData.ped,
      growth = 100
    }

    local name
    local myIdentifier = getIdentifier(source)
    if myIdentifier == targetIdentifier then
      name = lib.parent.framework.get_name(player)
    else
      name = lib.parent.friends[myIdentifier][targetIdentifier]
    end

    pcall(lib.parent.storage.update_peds, targetIdentifier, lib.parent.data[targetIdentifier])

    return compress({ targetIdentifier, name, lib.parent.data[targetIdentifier] or {} })
  end)

  ---@param source integer
  ---@param targetIdentifier string
  ---@param pedKey string
  ---@param item string
  ---@return table<string, any> | false, string?, number?
  registerCallback('cfx-sure_animals:feedAnimal', function(source, targetIdentifier, pedKey, item)
    if not lib.parent.public.item.feed.list[item] then return false, 'feed_not_found' end
    local feedAmount = lib.parent.public.item.feed.list[item]

    local pedData, pedIndex = getTarget(lib.parent.data[targetIdentifier], 'key', pedKey)
    if not pedData then return false, 'ped_key_not_found' end

    local keyCache = ('%s-%s'):format(targetIdentifier, pedKey)
    if cooldown[keyCache] then return false, 'ped_on_cooldown', cooldown[keyCache]:getTimeLeft('s') --[[@as number]] end
    
    local player = lib.parent.framework.get_player(source)
    if not player then return false, 'player_error' end
  
    lib.parent.framework.remove_item(player, item, 1)
    if not lib.parent.data[targetIdentifier][pedIndex] then return false, 'ped_index_not_found' end
  
    lib.parent.data[targetIdentifier][pedIndex].growth = math.min(lib.parent.data[targetIdentifier][pedIndex].growth + feedAmount, 100)
    lib.parent.data[targetIdentifier][pedIndex].timeout = nil

    pcall(lib.parent.storage.update_peds, targetIdentifier, lib.parent.data[targetIdentifier])

    cooldown[keyCache] = lib.timer(lib.parent.public.item.feed.cooldown_each_ped * 1000, function()
      cooldown[keyCache] = nil
    end, true)

    return {
      growth = lib.parent.data[targetIdentifier][pedIndex].growth
    }
  end)

  ---@param source integer
  ---@param targetIdentifier string
  ---@param pedKey string
  ---@return string | false, string?
  registerCallback('cfx-sure_animals:sellAnimal', function(source, targetIdentifier, pedKey)
    local pedData, pedIndex = getTarget(lib.parent.data[targetIdentifier], 'key', pedKey)
    if not pedData then return false, 'ped_key_not_found' end

    local player = lib.parent.framework.get_player(source)
    if not player then return false, 'player_error' end

    if pedData.currentNet > 0 then
      lib.parent.framework.add_account(player, 'money', pedData.currentNet)
    end
    table.remove(lib.parent.data[targetIdentifier], pedIndex)

    pcall(lib.parent.storage.update_peds, targetIdentifier, lib.parent.data[targetIdentifier])

    return compress({ targetIdentifier, lib.parent.framework.get_name(player), lib.parent.data[targetIdentifier] or {} })
  end)

  ---@param source integer
  ---@return string
  registerCallback('cfx-sure_animals:getFriends', function(source)
    local identifier = getIdentifier(source)
    if lib.parent.friends[identifier] == nil then
      lib.parent.friends[identifier] = {}
      saveFriendsInternal()
    end

    local data = {}
    for k, v in pairs(lib.parent.friends[identifier]) do
      data[#data + 1] = { k, v }
    end

    return compress(data)
  end)

  RegisterNetEvent('cfx-sure_animals:requestFriend', function(targetServerId)
    local playerId = source --[[@as integer]]
    local player = lib.parent.framework.get_player(playerId)
    if playerId and player then
      local myName = lib.parent.framework.get_name(player)
      local isConfirmed = request('cfx-sure_animals:requestFriend', targetServerId, myName)
      if isConfirmed then
        local targetPlayer = lib.parent.framework.get_player(targetServerId)
        local targetName = lib.parent.framework.get_name(targetPlayer)
        local myIdentifier = getIdentifier(playerId)
        local targetIdentifier = getIdentifier(targetServerId)

        if lib.parent.friends[myIdentifier] == nil then lib.parent.friends[myIdentifier] = {} end
        if lib.parent.friends[targetIdentifier] == nil then lib.parent.friends[targetIdentifier] = {} end

        lib.parent.friends[myIdentifier][targetIdentifier] = targetName
        lib.parent.friends[targetIdentifier][myIdentifier] = myName

        saveFriendsInternal()

        TriggerClientEvent('cfx-sure_animals:notify', playerId, 'friend_request_accepted')
      else
        TriggerClientEvent('cfx-sure_animals:notify', playerId, 'friend_request_unaccepted')
      end
    end
  end)

  RegisterNetEvent('cfx-sure_animals:removeFriend', function(targetIdentifier)
    local playerId = source --[[@as integer]]
    if playerId then
      local identifier = getIdentifier(playerId)
      
      if lib.parent.friends[identifier][targetIdentifier] then
        local name = lib.parent.friends[identifier][targetIdentifier]
        lib.parent.friends[identifier][targetIdentifier] = nil
        TriggerClientEvent('cfx-sure_animals:notify', playerId, 'info', 'friend_has_removed', name)
      end
      
      if lib.parent.friends[targetIdentifier][identifier] then
        local name = lib.parent.friends[targetIdentifier][identifier]
        lib.parent.friends[targetIdentifier][identifier] = nil
        local targetPlayer = lib.parent.framework.get_player_from_identifier(targetIdentifier)
        if targetPlayer then
          TriggerClientEvent('cfx-sure_animals:notify', lib.parent.framework.get_source(targetPlayer), 'info', 'friend_has_removed', name)
        end
      end

      saveFriendsInternal()
    end
  end)

  local commands = {}
  commands.get = {
    helper = '[string: Target identifier]',
    ref = function(trace, identifier)
      if not identifier then return end
      trace('Farm of ' .. identifier)
      trace(json.encode(lib.parent.data[identifier] or {}, { indent = true }))
    end
  }

  RegisterCommand('sure_animal', function(source, args)
    local isAdmin = lib.parent.framework.is_admin(source)
    local trace = createTracer(source)
    if isAdmin then
      local subCommand = args[1]
      if not subCommand then
        return trace('Missing sub-command /sure_animal [string: Sub-command]')
      end

      if subCommand == 'help' or not subCommand then
        trace(('There\'s no sub-command %s'):format(subCommand))
        trace('-------------- Sub-commands --------------')
        local index = 1
        for command, data in pairs(commands) do
          trace(('[%s] : /%s %s'):format(index, command, data.helper))
          index += 1
        end
      elseif commands[subCommand] then
        table.remove(args, 1)
        table.remove(args, 2)

        local retval = pcall(commands[subCommand].ref, trace, table.unpack(args))
        if not retval then
          trace(('Error while executing sub-command %s'):format(subCommand))
        end
      end
    else
      trace('Invalid permission sufficiency!')
    end
  end, false)
end, function()
  lib.print.error('Detected invalid resource using.')
  lib.print.error('Stop inside heartbeat!')
  lib.parent = nil
end)