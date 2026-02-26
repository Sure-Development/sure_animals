---@class Animals.framework.server
local M = {}

M.initial = function()
  xpcall(function()
    ESX = exports.es_extended:getSharedObject()
  end, function()
    while ESX == nil do
      TriggerEvent('esx:getSharedObject', function(ref) ESX = ref end)
      Wait(50)
    end
  end)
end

---@class Animals.shared.framework.xplayer
---@field getName fun(): string
---@field removeInventoryItem fun(item: string, count: integer)
---@field addAccountMoney fun(name: string, count: integer)
---@field getSource fun(): integer
---@field getGroup fun(): string

---@param source integer
---@return Animals.shared.framework.xplayer
M.get_player = function(source)
  return ESX.GetPlayerFromId(source)
end

---@param identifier string
---@return Animals.shared.framework.xplayer
M.get_player_from_identifier = function(identifier)
  return ESX.GetPlayerFromIdentifier(identifier)
end

---@param xPlayer Animals.shared.framework.xplayer
---@return string
M.get_name = function(xPlayer)
  return xPlayer.getName()
end

---@param xPlayer Animals.shared.framework.xplayer
---@param item string
---@param count integer
M.remove_item = function(xPlayer, item, count)
  xPlayer.removeInventoryItem(item, count)
end

---@param xPlayer Animals.shared.framework.xplayer
---@param name string
---@param count integer
M.add_account = function(xPlayer, name, count)
  xPlayer.addAccountMoney(name, count)
end

---@param xPlayer Animals.shared.framework.xplayer
---@return integer
M.get_source = function(xPlayer)
  return xPlayer.getSource()
end

---@param source integer
---@return boolean
M.is_admin = function(source)
  if source == 0 then return true end
  local player = M.get_player(source)
  if player then
    local group = player.getGroup()
    if group == 'admin' or group == 'superadmin' then
      return true
    end
  end

  return false
end

return M