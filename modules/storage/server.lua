---@class Animals.modules.storage
local M = {}

local tbl = 'sure_animals'

---@param ref function
local function wrapper(ref)
  return function(...)
    return ref(nil, ...)
  end
end

local mysql = exports.oxmysql
local update = wrapper(mysql.update_async)
local insert = wrapper(mysql.insert_async)
local query = wrapper(mysql.query_async)
local awaitConnection = wrapper(mysql.awaitConnection)

local encode = json.encode
local parent = lib.parent
local sql = function(text) return tostring(text):format(tbl) end

M.initial = function()
  awaitConnection()

  query(sql([[
    CREATE TABLE IF NOT EXISTS %s (
      id INT(20) PRIMARY KEY AUTO_INCREMENT,
      owner VARCHAR(100) UNIQUE,
      animals LONGTEXT DEFAULT '{}'
    )
  ]]))

  local result = query(sql('SELECT * FROM %s'))
  if result then
    for _, v in ipairs(result) do
      parent.data[v.owner] = json.decode(v.animals)
    end
  else
    lib.print.error('Error while loading previous data from database!')
  end
end

M.insert_peds = function(identifier, peds)
  insert(sql('INSERT INTO %s (owner, animals) VALUES (?, ?)'), { identifier, encode(peds) })
end

M.update_peds = function(identifier, peds)
  update(sql('UPDATE %s SET animals = ? WHERE owner = ?'), { encode(peds), identifier })
end

return M