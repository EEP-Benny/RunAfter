--#region test setup

local lu = require('luaunit')
local testSetup = require('testSetup')
local test = testSetup.test
local withChangedGlobals = testSetup.withChangedGlobals
local functionReturning = testSetup.functionReturning
local spy = testSetup.spy
local finish = testSetup.finish

EXPOSE_PRIVATE_FOR_TESTING = true
local StorageHelper = require('StorageHelper_BH2')
EXPOSE_PRIVATE_FOR_TESTING = nil

local SerializationHelper = require('SerializationHelper_BH2')
require('EEPGlobals')
--#endregion test setup

--#region makeStorageFunctions()

---@param partialOptions StorageOptions
---@return SaveFn, LoadFn
local function makeStorageFunctions(partialOptions)
  partialOptions = partialOptions or {}
  return StorageHelper.private.makeStorageFunctions(
    {
      chunkSize = partialOptions.chunkSize or 10,
      numberOfChunks = partialOptions.numberOfChunks or 1,
      saveChunk = partialOptions.saveChunk or functionReturning(),
      loadChunk = partialOptions.loadChunk or functionReturning('')
    }
  )
end

test(
  'makeStorageFunctions.should return two functions',
  function()
    local saveFn, loadFn = makeStorageFunctions({})
    lu.assertFunction(saveFn)
    lu.assertFunction(loadFn)
  end
)

test(
  'makeStorageFunctions.should serialize data on save',
  function()
    local saveFn, _ = makeStorageFunctions({})
    local serializeSpy = spy(SerializationHelper, 'serialize')
    saveFn({1, 'table'})
    lu.assertEquals(serializeSpy.calls, {{{1, 'table'}}})
    serializeSpy.revoke()
  end
)

test(
  'makeStorageFunctions.should split data into correctly sized chunks on save',
  function()
    local chunksToSave = {}
    local originalSerializeFn = SerializationHelper.serialize
    SerializationHelper.serialize = functionReturning('This is a long string')
    local saveChunk = function(chunkIndex, value)
      chunksToSave[chunkIndex] = value
    end
    local saveFn, _ = makeStorageFunctions({chunkSize = 5, numberOfChunks = 6, saveChunk = saveChunk})
    saveFn({1, 'table'})
    lu.assertEquals(chunksToSave, {'This ', 'is a ', 'long ', 'strin', 'g', ''})
    SerializationHelper.serialize = originalSerializeFn
  end
)

test(
  'makeStorageFunctions.should deserialize data on load',
  function()
    local _, loadFn = makeStorageFunctions({loadChunk = functionReturning('serializedValue')})
    local deserializeSpy = spy(SerializationHelper, 'deserialize')
    loadFn()
    lu.assertEquals(deserializeSpy.calls, {{'serializedValue'}})
    deserializeSpy.revoke()
  end
)

test(
  'makeStorageFunctions.should concatenate data from chunks on load',
  function()
    local loadChunk = function(chunkIndex)
      return ({'con', 'cat', 'ena', 'ted'})[chunkIndex]
    end
    local _, loadFn = makeStorageFunctions({numberOfChunks = 4, loadChunk = loadChunk})
    local deserializeSpy = spy(SerializationHelper, 'deserialize')
    loadFn()
    lu.assertEquals(deserializeSpy.calls, {{'concatenated'}})
    deserializeSpy.revoke()
  end
)

--#endregion makeStorageFunctions()

--#region structureTagText()
test(
  'structureTagText.should warn if EEP version is to low',
  function()
    local originalValue = EEPStructureGetTagText
    EEPStructureGetTagText = nil
    lu.assertErrorMsgContentEquals(
      'Tag texts are only supported by EEP15 or higher',
      StorageHelper.structureTagText,
      {}
    )
    EEPStructureGetTagText = originalValue
  end
)

test(
  'structureTagText.should handle numeric structureNames',
  function()
    local toImmoNameSpy = spy(StorageHelper.private, 'toImmoName')
    StorageHelper.structureTagText({1, 2, 3})
    lu.assertEquals(toImmoNameSpy.calls, {{1}, {2}, {3}})
    toImmoNameSpy.revoke()
  end
)

test(
  'structureTagText.should warn about non-existing structures',
  withChangedGlobals(
    {
      EEPStructureGetTagText = function(structureName)
        return structureName ~= '#2', '' -- pretend that structure #2 does not exist
      end
    },
    function()
      lu.assertErrorMsgContentEquals('Structure #2 does not exist', StorageHelper.structureTagText, {'#1', '#2', '#3'})
    end
  )
)

test(
  'structureTagText.should call makeStorageFunctions with the correct parameters',
  function()
    local makeStorageFunctionsSpy = spy(StorageHelper.private, 'makeStorageFunctions')
    StorageHelper.structureTagText({1, 2, 3})
    lu.assertEquals(makeStorageFunctionsSpy.calls[1][1].chunkSize, 1024)
    lu.assertEquals(makeStorageFunctionsSpy.calls[1][1].numberOfChunks, #{1, 2, 3})
    makeStorageFunctionsSpy.revoke()
  end
)

--#endregion structureTagText()

finish()
