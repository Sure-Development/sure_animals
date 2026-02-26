---@class Animals.client.parent
lib.parent = {}
lib.parent.peds = {}
lib.parent.public = require('config.shared.public')
lib.parent.interface = require('config.shared.interface')
lib.parent.framework = require('config.framework.client')
lib.parent.compresser = require('modules.compresser.shared')
---@type Animals.shared.data?
lib.parent.currentFarm = nil

local request = lib.callback.await
local registerCallback = lib.callback.register
local app = promise.new()

local function decompress(data)
  local result = lib.parent.compresser:DecompressZlib(data)
  return json.decode(result --[[@as string]])
end

---@param raw any[]
---@return Animals.shared.data
local function mutateFarmData(raw)
  return {
    owner = raw[1],
    name = raw[2],
    list = raw[3]
  }
end

---@param raw any[]
---@return Animals.shared.friend[]
local function mutateFriendsData(raw)
  local data = {}
  for _, v in ipairs(raw) do
    data[#data + 1] = {
      identifier = v[1],
      name = v[2]
    }
  end

  return data
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

local function createPeds()
  if lib.parent.currentFarm and lib.parent.currentFarm.list then
    for _, v in ipairs(lib.parent.currentFarm.list) do
      if not lib.parent.peds[v.key] then
        local pedIndex = lib.parent.public.create_ped(v.ped, lib.parent.public.position.coords)
        lib.parent.peds[v.key] = pedIndex
      end
    end
  end
end

local function removePeds()
  for key, pedIndex in pairs(lib.parent.peds) do
    lib.parent.public.remove_ped(pedIndex)
    lib.parent.peds[key] = nil
  end
end

---@param pedKey string
local function removePed(pedKey)
  if lib.parent.peds[pedKey] then
    lib.parent.public.remove_ped(lib.parent.peds[pedKey])
    lib.parent.peds[pedKey] = nil
  end
end

lib.parent.openAnimalsContext = function()
  local result, status = request('cfx-sure_animals:getFarmData', false)
  if result then
    result = decompress(result)
    lib.parent.currentFarm = mutateFarmData(result)

    removePeds()
    createPeds()
  end

  if status then
    pcall(lib.parent.public.notification, 'warning', locale(status), status)
  end

  lib.parent.interface.open_menu('animals_context', lib.parent.currentFarm)
end

lib.parent.openFriendsContext = function()
  local result = request('cfx-sure_animals:getFriends', false)
  if result then
    result = decompress(result)
    local data = mutateFriendsData(result)
    lib.parent.interface.open_menu('friends_context', data)
  end
end

---@param pedKey string
lib.parent.openPedContext = function(pedKey)
  if lib.parent.currentFarm.list then
    local pedData = getTarget(lib.parent.currentFarm.list, 'key', pedKey)
    if pedData then
      lib.parent.interface.open_menu('ped_context', pedData, pedKey)
    end
  end
end

---@param pedKey string
---@param item string
lib.parent.feedAnimal = function(pedKey, item)
  if lib.parent.currentFarm.list then
    local result, status, cooldown
    local pedData, pedIndex = getTarget(lib.parent.currentFarm.list, 'key', pedKey)
    if not pedData then
      status = 'ped_key_not_found'
      goto skip
    end

    do
      result, status, cooldown = request('cfx-sure_animals:feedAnimal', false, lib.parent.currentFarm.owner, pedKey, item)

      if result then
        for k, v in pairs(result) do
          if lib.parent.currentFarm.list[pedIndex][k] then
            lib.parent.currentFarm.list[pedIndex][k] = v
          end
        end
      end
    end

    ::skip::

    if status then
      pcall(lib.parent.public.notification, 'warning', locale(status, cooldown), status)
    end

    lib.parent.interface.open_menu('ped_context', lib.parent.currentFarm.list[pedIndex], pedKey)
  end
end

---@param pedKey string
lib.parent.sellAnimation = function(pedKey)
  if lib.parent.currentFarm.list then
    local result, status
    local pedData = getTarget(lib.parent.currentFarm.list, 'key', pedKey)
    if not pedData then
      status = 'ped_key_not_found'
      goto skip
    end

    do
      result, status = request('cfx-sure_animals:sellAnimal', false, lib.parent.currentFarm.owner, pedKey)
      if result then
        result = decompress(result)
        lib.parent.currentFarm = mutateFarmData(result)

        removePed(pedKey)
      end
    end

    ::skip::

    if status then
      pcall(lib.parent.public.notification, 'warning', locale(status), status)
    end

    lib.parent.interface.open_menu('animals_context', lib.parent.currentFarm)
  end
end

---@param targetServerId integer
lib.parent.inviteFriend = function(targetServerId)
  TriggerServerEvent('cfx-sure_animals:requestFriend', targetServerId)
end

lib.parent.openFarmOfFriend = function(targetIdentifier)
  local result, status = request('cfx-sure_animals:getFarmData', false, targetIdentifier)
  if result then
    result = decompress(result)
    lib.parent.currentFarm = mutateFarmData(result)

    removePeds()
    createPeds()
  end

  if status then
    pcall(lib.parent.public.notification, 'warning', locale(status), status)
  end

  lib.parent.interface.open_menu('animals_context', lib.parent.currentFarm)
end

---@param targetIdentifier string
lib.parent.removeFriend = function(targetIdentifier)
  TriggerServerEvent('cfx-sure_animals:removeFriend', targetIdentifier)
end

lib.parent.addPedToFarm = function(item)
  local result, status = request('cfx-sure_animals:addPedToFarm', false, lib.parent.currentFarm.owner, item)

  if result then
    result = decompress(result)
    lib.parent.currentFarm = mutateFarmData(result)

    createPeds()
  end

  if status then
    pcall(lib.parent.public.notification, 'warning', locale(status), status)
  end

  lib.parent.interface.open_menu('animals_context', lib.parent.currentFarm)
end

AddEventHandler('onClientResourceStart', function(resource)
  if resource == cache.resource then
    app:resolve()
  end
end)

app:next(function()
  lib.parent.framework.initial()
  lib.parent.interface.initial()

  local position = lib.parent.public.position
  local zone = lib.zones.sphere(position)
  local isInZone = false

  function zone:onEnter()
    isInZone = true
  end

  function zone:onExit()
    isInZone = false

    removePeds()
  end

  registerCallback('cfx-sure_animals:requestFriend', function(name)
    local isConfirmed = lib.parent.interface.open_menu('friend_acceptable', name)
    if isConfirmed then
      return true
    end

    return false
  end)

  RegisterNetEvent('cfx-sure_animals:notify', function(type, status, ...)
    pcall(lib.parent.public.notification, type, locale(status, ...), status)
  end)

  RegisterNetEvent('cfx-sure_animals:trace', function(...)
    lib.print.info(...)
  end)

  RegisterCommand('cfx-sure_animals', function()
    if lib.parent.public.is_ped_dead() or not isInZone then return end
    lib.parent.interface.open_menu('main_context')
  end, false)
  RegisterKeyMapping('cfx-sure_animals', '(Don\'t change) Open Animals Manager', 'keyboard', 'E')

  AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then
      removePeds()
    end
  end)
end, function()
  lib.print.error('Detected invalid resource using.')
  lib.print.error('Stop inside heartbeat!')
  lib.parent = nil
end)