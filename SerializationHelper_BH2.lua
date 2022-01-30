--#region module metadata

local SerializationHelper = {
  _VERSION = {0, 0, 1},
  _DESCRIPTION = 'Hilfsfunktionen zum Serialisieren und Deserialisieren von Objekten',
  _URL = 'https://github.com/EEP-Benny/RunAfter',
  _LICENSE = 'MIT'
}

--#endregion module metadata

--#region private functions

---all keywords reserved by Lua, taken from the manual
---@type table<string,boolean|nil>
local reservedKeywords = {
  ['and'] = true,
  ['break'] = true,
  ['do'] = true,
  ['else'] = true,
  ['elseif'] = true,
  ['end'] = true,
  ['false'] = true,
  ['for'] = true,
  ['function'] = true,
  ['goto'] = true,
  ['if'] = true,
  ['in'] = true,
  ['local'] = true,
  ['nil'] = true,
  ['not'] = true,
  ['or'] = true,
  ['repeat'] = true,
  ['return'] = true,
  ['then'] = true,
  ['true'] = true,
  ['until'] = true,
  ['while'] = true
}

---checks whether `key` is an identifier according to the Lua specification (§3.1)
---@param key any
---@return boolean
local function isIdentifier(key)
  if type(key) ~= 'string' then
    return false
  elseif reservedKeywords[key] then
    return false
  elseif string.match(key, '^[_%a][_%d%a]*$') then
    -- "any string of letters, digits, and underscores, not beginning with a digit"
    return true
  else
    return false
  end
end

local function serializeRecursively(valueToSerialize, alreadyVisited)
  local serializers = {
    ['nil'] = tostring,
    boolean = tostring,
    number = tostring,
    string = function(str)
      -- use %q-formatting, and replace escaped linebreaks with \n
      -- extra parentheses to trim the return values of gsub
      return (string.gsub(string.format('%q', str), '\\\n', '\\n'))
    end,
    table = function(tbl)
      if alreadyVisited[tbl] then
        error('cannot serialize recursive tables')
      end
      alreadyVisited[tbl] = true
      local serializedSegments = {}
      local visitedByIpairs = {}
      for i, v in ipairs(tbl) do
        visitedByIpairs[i] = true
        table.insert(serializedSegments, serializeRecursively(v, alreadyVisited))
      end
      for k, v in pairs(tbl) do
        if not visitedByIpairs[k] then
          local serializedValue = serializeRecursively(v, alreadyVisited)
          local segment
          if isIdentifier(k) then
            segment = string.format('%s=%s', k, serializedValue)
          else
            segment = string.format('[%s]=%s', serializeRecursively(k, alreadyVisited), serializedValue)
          end
          table.insert(serializedSegments, segment)
        end
      end
      alreadyVisited[tbl] = nil
      return string.format('{%s}', table.concat(serializedSegments, ','))
    end
  }

  local serializer = serializers[type(valueToSerialize)]
  if serializer == nil then
    error(string.format('serializing values of type %s is not supported', type(valueToSerialize)))
  end
  return serializer(valueToSerialize)
end

--#endregion private functions

--#region public functions

---Returns a string representation of the given `value`, which is parsable by Lua
---* **Supported types**: nil, boolean, number, string, table (nested tables, too)
---* **Not supported**: recursive tables and functions
---@param value any
---@return string
function SerializationHelper.serialize(value)
  return serializeRecursively(value, {})
end

---Deserializes the given string into the original Lua structure
---@param serializedValue string
---@return any
function SerializationHelper.deserialize(serializedValue)
  local fun, errorMessage = load('return ' .. serializedValue, serializedValue)
  if fun == nil then
    error(errorMessage)
  end
  return fun()
end

--#endregion public functions

return SerializationHelper
