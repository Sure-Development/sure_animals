---@class Animals.framework.client
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

---@param item string
---@return { label: string, count: integer, [string]: any }?
M.search_inventory = function(item)
  return ESX.SearchInventory(item)
end

return M