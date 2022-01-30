--#region test setup

local lu = require('luaunit')
local testSetup = require('testSetup')
local test = testSetup.test
local functionReturning = testSetup.functionReturning
local finish = testSetup.finish

local SerializationHelper = require('SerializationHelper_BH2')
local serialize = SerializationHelper.serialize
local deserialize = SerializationHelper.deserialize
--#endregion test setup

--#region serialize()
test(
  'serialize.should correctly serialize nil, booleans and numbers',
  function()
    lu.assertEquals(serialize(nil), 'nil')
    lu.assertEquals(serialize(true), 'true')
    lu.assertEquals(serialize(false), 'false')
    lu.assertEquals(serialize(1), '1')
    lu.assertEquals(serialize(-1.5), '-1.5')
  end
)

test(
  'serialize.should correctly serialize strings',
  function()
    lu.assertEquals(serialize('simple string'), '"simple string"')
    lu.assertEquals(serialize('new\nline'), '"new\\nline"')
    lu.assertEquals(serialize("\"double\" and 'single' quotes"), "\"\\\"double\\\" and 'single' quotes\"")
  end
)

test(
  'serialize.should serialize tables with numeric indices in array form',
  function()
    lu.assertEquals(serialize({1, 2, 3, 4, 5}), '{1,2,3,4,5}')
    lu.assertEquals(serialize({'a', 'b', 'c'}), '{"a","b","c"}')
  end
)

test(
  'serialize.should serialize tables with non-continuous numeric indices',
  function()
    lu.assertEquals(serialize({[1] = 1, [2] = 2, [4] = 4}), '{1,2,[4]=4}')
  end
)

test(
  'serialize.should serialize tables with simple string indices using shorthand notation',
  function()
    lu.assertEquals(serialize({a = 1}), '{a=1}')
    lu.assertEquals(serialize({['B_1'] = 1}), '{B_1=1}')
  end
)

test(
  'serialize.should serialize tables with non-identifier-indices using bracket notation',
  function()
    lu.assertEquals(serialize({['nil'] = 1}), '{["nil"]=1}')
    lu.assertEquals(serialize({['with spaces'] = 2}), '{["with spaces"]=2}')
  end
)

test(
  'serialize.should serialize tables with numeric indices before string indices',
  function()
    lu.assertEquals(serialize({1, a = 2}), '{1,a=2}')
  end
)

test(
  "serialize.should serialize tables with multiple references to the same table as long as they don't recurse",
  function()
    local tbl1 = {1}
    local tbl2 = {tbl1, tbl1, [tbl1] = tbl1}
    lu.assertEquals(serialize(tbl2), '{{1},{1},[{1}]={1}}')
  end
)

test(
  'serialize.should throw an error for recursive tables',
  function()
    local tbl = {}
    tbl.tbl = tbl
    lu.assertErrorMsgContentEquals('cannot serialize recursive tables', serialize, tbl)
  end
)

test(
  'serialize.should throw an error for unsupported types',
  function()
    local expectedMessage = 'serializing values of type function is not supported'
    lu.assertErrorMsgContentEquals(expectedMessage, serialize, functionReturning(nil))
  end
)
--#endregion serialize()

--#region deserialize()
test(
  'deserialize.should correctly deserialize nil, booleans and numbers',
  function()
    lu.assertEquals(deserialize('nil'), nil)
    lu.assertEquals(deserialize('true'), true)
    lu.assertEquals(deserialize('false'), false)
    lu.assertEquals(deserialize('1'), 1)
    lu.assertEquals(deserialize('-1.5'), -1.5)
  end
)

test(
  'deserialize.should correctly deserialize strings',
  function()
    lu.assertEquals(deserialize('"simple string"'), 'simple string')
    lu.assertEquals(deserialize('"new\\nline"'), 'new\nline')
    lu.assertEquals(deserialize("\"\\\"double\\\" and 'single' quotes\""), "\"double\" and 'single' quotes")
  end
)

test(
  'deserialize.should deserialize tables',
  function()
    lu.assertEquals(deserialize('{1,2,3,4,5}'), {1, 2, 3, 4, 5})
    lu.assertEquals(deserialize('{"a","b","c"}'), {'a', 'b', 'c'})
    lu.assertEquals(deserialize('{a=1,["b"]=2,c=3}'), {a = 1, b = 2, c = 3})
  end
)

test(
  'deserialize.should throw an error for invalid strings',
  function()
    lu.assertError(deserialize, '"invalid')
  end
)

--#endregion deserialize()

finish()
