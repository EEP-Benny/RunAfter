local SerializationHelper = require('SerializationHelper_BH2')

--#region module metadata

local StorageHelper = {
  _VERSION = {0, 0, 1},
  _DESCRIPTION = 'Hilfsfunktionen zum Speicher und Laden von (potenziell großen) Objekten',
  _URL = 'https://github.com/EEP-Benny/RunAfter',
  _LICENSE = 'MIT'
}

--#endregion module metadata

--#region type definitions

---@alias SaveFn fun(value: any)
---@alias LoadFn fun():any

---@class StorageOptions
---@field numberOfChunks number
---@field chunkSize number
---@field saveChunk fun(index: number, substring: string)
---@field loadChunk fun(index: number): string

--#endregion type definitions

--#region private functions

local private = {}
if EXPOSE_PRIVATE_FOR_TESTING then
  StorageHelper.private = private
end

---Formats a string or a number into a immoName (string starting with `'#'`).
---This function doesn't check whether the resulting immoName is valid
---@param immoName string | number
---@return string immoName @in the format `'#123'`
function private.toImmoName(immoName)
  if type(immoName) == 'number' then
    return '#' .. immoName
  else
    return immoName
  end
end

---creates storage functions based on options
---@param options StorageOptions
---@return SaveFn saveFn function to save data to storage
---@return LoadFn loadFn function to load data from storage
function private.makeStorageFunctions(options)
  local function saveFn(value)
    local serializedValue = SerializationHelper.serialize(value)
    for i = 1, options.numberOfChunks do
      local substring = string.sub(serializedValue, options.chunkSize * (i - 1) + 1, options.chunkSize * i)
      options.saveChunk(i, substring)
    end
  end

  local function loadFn()
    local serializedValue = ''
    for i = 1, options.numberOfChunks do
      local substring = options.loadChunk(i)
      serializedValue = serializedValue .. substring
    end
    return SerializationHelper.deserialize(serializedValue)
  end

  return saveFn, loadFn
end

--#endregion privated functions

--#region public functions

---configure storage in structure tag texts
---@param immoNames string[] | number[] where to store the data
---@return SaveFn saveFn function to save data to storage
---@return LoadFn loadFn function to load data from storage
function StorageHelper.structureTagText(immoNames)
  if EEPStructureGetTagText == nil or EEPStructureSetTagText == nil then
    error('Tag texts are only supported by EEP15 or higher')
  end
  for i, immoName in ipairs(immoNames) do
    immoName = private.toImmoName(immoName)
    local ok = EEPStructureGetTagText(immoName)
    if not ok then
      error('Structure ' .. immoName .. ' does not exist')
    end
    immoNames[i] = immoName
  end

  return private.makeStorageFunctions(
    {
      chunkSize = 1024,
      numberOfChunks = #immoNames,
      loadChunk = function(index)
        local _, substring = EEPStructureGetTagText(immoNames[index])
        return substring
      end,
      saveChunk = function(index, substring)
        EEPStructureSetTagText(immoNames[index], substring)
      end
    }
  )
end

--#endregion public functions

return StorageHelper
