--#region test setup

local lu = require('luaunit')
-- LuaUnit searches in the global scopes for all functions starting with "Test" or "test".
-- I prefer tests with speaking names that aren't reordered, so let's monkey-patch this mechanism.
local tests = {}

---@param name string @name of the test
---@param fun fun() @test function to run
local function test(name, fun)
  name = string.gsub(name, '%.', ': ') -- LuaUnit treats a dot as nesting, which makes things more complicated
  _ENV[name] = fun
  table.insert(tests, name)
end

lu.LuaUnit.collectTests = function()
  return tests
end

---@class Spy
---@field calls table[] @an array of calls to the function, each containing an array of all arguments
---@field revoke fun() @remove the spy / restore the original function

---Wraps a function so that we can spy on it (= record how often and with which arguments it was called)
---@param target table @table that holds the function to spy on
---@param name string @name of the function to spy on
---@return Spy spy @a spy object containing the call history and a method to remove the spy
local function spy(target, name)
  assert(type(target) == 'table', 'spy target must be a table')
  local originalFunction = target[name]
  assert(type(originalFunction) == 'function', "can't spy on target[" .. name .. '], must be a function')

  local calls = {}
  target[name] = function(...)
    table.insert(calls, {...})
    return originalFunction(...)
  end

  return {
    calls = calls,
    revoke = function()
      target[name] = originalFunction
    end
  }
end

local function withChangedGlobals(replacements, fun)
  return function(...)
    local savedValues = {}
    for varname, value in pairs(replacements) do
      savedValues[varname] = _ENV[varname]
      _ENV[varname] = value
    end
    local returnValue = fun(...)
    for varname, _ in pairs(replacements) do
      _ENV[varname] = savedValues[varname]
    end
    return returnValue
  end
end

local function functionReturning(...)
  local returnValues = {...}
  return function()
    return table.unpack(returnValues)
  end
end

require('EEPGlobals')

---@param options UserOptions
---@return RunAfter
local function getRunAfter(options)
  return require('RunAfter_BH2')(options)
end
---@type fun(options:UserOptions): RunAfter
local getRunAfterWithPrivate = withChangedGlobals({EXPOSE_PRIVATE_FOR_TESTING = true}, getRunAfter)

--#endregion test setup

test(
  'RunAfter_BH2.should import correctly',
  function()
    local module = require('RunAfter_BH2')
    lu.assertTable(module)
    lu.assertNotNil(module._DESCRIPTION)
    lu.assertNotNil(module._LICENSE)
    lu.assertNotNil(module._URL)
    lu.assertNotNil(module._VERSION)
    lu.assertTable(module())
  end
)

test(
  'RunAfter_BH2.should not expose private variables normally',
  function()
    local RunAfter = getRunAfter()
    lu.assertNil(RunAfter.private)
  end
)

test(
  'RunAfter_BH2.should expose private variables for testing',
  function()
    local RunAfter = getRunAfterWithPrivate()
    lu.assertTable(RunAfter.private)
  end
)

--#region private functions
--#region toImmoName()
test(
  'toImmoName.should convert a number to a string',
  function()
    local toImmoName = getRunAfterWithPrivate().private.toImmoName
    lu.assertEquals(toImmoName(10), '#10')
  end
)

test(
  'toImmoName.should pass through a string',
  function()
    local toImmoName = getRunAfterWithPrivate().private.toImmoName
    lu.assertEquals(toImmoName('#11'), '#11')
    lu.assertEquals(toImmoName('#11_ImmoName'), '#11_ImmoName')
  end
)

test(
  'toImmoName.should not check that the id is valid',
  function()
    local toImmoName = getRunAfterWithPrivate().private.toImmoName
    lu.assertEquals(toImmoName('invalid ID'), 'invalid ID')
    lu.assertEquals(toImmoName(false), false)
  end
)
--#endregion toImmoName()

--#region getCurrentTime()
test(
  'getCurrentTime.should return the current time for a given axis position',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 45)},
    function()
      local getCurrentTime = getRunAfterWithPrivate().private.getCurrentTime
      lu.assertEquals(getCurrentTime(), 45)
    end
  )
)
--#endregion getCurrentTime()
--#endregion private functions

--#region public functions
--#region RunAfter.setOptions()
test(
  'setOptions.should treat a single value as the immoName',
  function()
    local RunAfter = getRunAfterWithPrivate('#1')
    lu.assertEquals(RunAfter.private.options.immoName, '#1')
  end
)

test(
  'setOptions.immoName.should be copied using toImmoName',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local toImmoNameSpy = spy(RunAfter.private, 'toImmoName')
    RunAfter.private.options = {}
    RunAfter.setOptions({immoName = '#123'})
    lu.assertEquals(toImmoNameSpy.calls, {{'#123'}})
    lu.assertEquals(RunAfter.private.options, {immoName = '#123'})
    toImmoNameSpy.revoke()
  end
)

test(
  'setOptions.immoName.should start axis movement',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local EEPStructureAnimateAxisSpy = spy(_ENV, 'EEPStructureAnimateAxis')
    RunAfter.private.options = {axisName = 'Achse'}
    RunAfter.setOptions({immoName = '#123'})
    lu.assertEquals(EEPStructureAnimateAxisSpy.calls, {{'#123', 'Achse', 1000}})
    EEPStructureAnimateAxisSpy.revoke()
  end
)

test(
  'setOptions.immoName.should throw an error if immo or axis does not exist',
  withChangedGlobals(
    {EEPStructureAnimateAxis = functionReturning(false)},
    function()
      local RunAfter = getRunAfter()
      local expectedErrorMsg = 'Die Immobilie #123 existiert nicht oder hat keine Achse namens Timer'
      lu.assertErrorMsgContentEquals(expectedErrorMsg, RunAfter.setOptions, {immoName = '#123'})
    end
  )
)

test(
  'setOptions.immoName.should throw an error if immoName has the wrong type',
  function()
    local RunAfter = getRunAfter()
    local expectedErrorMsg = 'immoName muss eine Zahl oder ein String sein, aber ist vom Typ boolean'
    lu.assertErrorMsgContentEquals(expectedErrorMsg, RunAfter.setOptions, {immoName = true})
  end
)
--#endregion RunAfter.setOptions()

--#region RunAfter.tick()
test(
  'tick.should not crash if there are no scheduled tasks',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {}
    RunAfter.tick()
  end
)

test(
  'tick.should execute only tasks that are due and remove them from the list',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.getCurrentTime = functionReturning(20)
    local task1 = {time = 10, func = functionReturning(nil)}
    local task2 = {time = 15, func = functionReturning(nil)}
    local task3 = {time = 30, func = functionReturning(nil)}
    local task1FuncSpy = spy(task1, 'func')
    local task2FuncSpy = spy(task2, 'func')
    local task3FuncSpy = spy(task3, 'func')
    RunAfter.private.scheduledTasks = {task3, task2, task1}

    RunAfter.tick()

    lu.assertEquals(task1FuncSpy.calls, {{}}) -- 1 call
    lu.assertEquals(task2FuncSpy.calls, {{}}) -- 1 call
    lu.assertEquals(task3FuncSpy.calls, {}) -- 0 calls
    lu.assertEquals(RunAfter.private.scheduledTasks, {task3})
  end
)
--#endregion RunAfter.tick()
--#endregion public functions

os.exit(lu.LuaUnit.run())
