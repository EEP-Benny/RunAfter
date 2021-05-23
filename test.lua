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

--#region toNumberOfSeconds()
do
  local testValues = {
    -- {"input value", "test description"}
    {5420, 'a number'},
    {'5420', 'a numeric string'},
    {'5420s', 'explicit seconds'},
    {'1h30m20s', 'a mix of units'},
    {'1h 30m 20s', 'a string with spaces'},
    {'1.50h20s', 'decimals'},
    {'90m20s', 'overflowing units'}
  }
  for _, testSpec in ipairs(testValues) do
    test(
      string.format('toNumberOfSeconds.should correctly parse %s', testSpec[2]),
      function()
        local toNumberOfSeconds = getRunAfterWithPrivate().private.toNumberOfSeconds
        lu.assertEquals(toNumberOfSeconds(testSpec[1]), 5420)
      end
    )
  end
end
--#endregion toNumberOfSeconds()

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

--#region resetTimerAxis()
test(
  'resetTimerAxis.should reset the timer axis',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 61)},
    function()
      local EEPStructureSetAxisSpy = spy(_ENV, 'EEPStructureSetAxis')
      getRunAfterWithPrivate().private.resetTimerAxis()
      lu.assertEquals(EEPStructureSetAxisSpy.calls[1][3], 1)
      EEPStructureSetAxisSpy.revoke()
    end
  )
)

test(
  'resetTimerAxis.should reduce the time of all tasks',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 61)},
    function()
      local RunAfter = getRunAfterWithPrivate()
      RunAfter.private.scheduledTasks = {{time = 150}, {time = 65}}
      RunAfter.private.resetTimerAxis()
      lu.assertTableContains(RunAfter.private.scheduledTasks, {time = 90})
      lu.assertTableContains(RunAfter.private.scheduledTasks, {time = 5})
    end
  )
)

test(
  'resetTimerAxis.should add the next reset task',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 61)},
    function()
      local RunAfter = getRunAfterWithPrivate()
      RunAfter.private.resetTimerAxis()
      lu.assertTableContains(RunAfter.private.scheduledTasks, {time = 60, func = RunAfter.private.resetTimerAxis})
    end
  )
)

test(
  'resetTimerAxis.should only add a single reset task, even if called multiple times',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 61)},
    function()
      local RunAfter = getRunAfterWithPrivate()
      RunAfter.private.scheduledTasks = {}
      RunAfter.private.resetTimerAxis()
      RunAfter.private.resetTimerAxis()
      lu.assertEquals(RunAfter.private.scheduledTasks, {{time = 60, func = RunAfter.private.resetTimerAxis}})
    end
  )
)

test(
  'resetTimerAxis.should do nothing except adding the next reset task, if the resetInterval is not yet reached',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 59)},
    function()
      local EEPStructureSetAxisSpy = spy(_ENV, 'EEPStructureSetAxis')
      local RunAfter = getRunAfterWithPrivate()
      RunAfter.private.scheduledTasks = {{time = 50}}
      RunAfter.private.resetTimerAxis()
      lu.assertEquals(
        RunAfter.private.scheduledTasks,
        {{time = 50}, {time = 60, func = RunAfter.private.resetTimerAxis}}
      )
      lu.assertEquals(EEPStructureSetAxisSpy.calls, {})
      EEPStructureSetAxisSpy.revoke()
    end
  )
)
--#endregion resetTimerAxis()

--#region insertTask()
test(
  'insertTask.should insert into an empty list',
  function()
    local newTask = {time = 5}
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {}

    RunAfter.private.insertTask(newTask)

    lu.assertEquals(RunAfter.private.scheduledTasks, {newTask})
  end
)

test(
  'insertTask.should insert at the end of the list',
  function()
    local task1 = {time = 10}
    local task2 = {time = 20}
    local newTask = {time = 30}
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {task1, task2}

    RunAfter.private.insertTask(newTask)

    lu.assertEquals(RunAfter.private.scheduledTasks, {task1, task2, newTask})
  end
)

test(
  'insertTask.should insert at the start of the list',
  function()
    local task1 = {time = 10}
    local task2 = {time = 20}
    local newTask = {time = 5}
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {task1, task2}

    RunAfter.private.insertTask(newTask)

    lu.assertEquals(RunAfter.private.scheduledTasks, {newTask, task1, task2})
  end
)

test(
  'insertTask.should insert in the middle of the list',
  function()
    local task1 = {time = 10}
    local task2 = {time = 20}
    local newTask = {time = 15}
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {task1, task2}

    RunAfter.private.insertTask(newTask)

    lu.assertEquals(RunAfter.private.scheduledTasks, {task1, newTask, task2})
  end
)
--#endregion insertTask()
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
    RunAfter.private.scheduledTasks = {task1, task2, task3}

    RunAfter.tick()

    lu.assertEquals(task1FuncSpy.calls, {{}}) -- 1 call
    lu.assertEquals(task2FuncSpy.calls, {{}}) -- 1 call
    lu.assertEquals(task3FuncSpy.calls, {}) -- 0 calls
    lu.assertEquals(RunAfter.private.scheduledTasks, {task3})
  end
)

test(
  'tick.should execute a function that is stored as a string',
  withChangedGlobals(
    {testFunction = functionReturning(nil)},
    function()
      local RunAfter = getRunAfterWithPrivate()
      RunAfter.private.getCurrentTime = functionReturning(20)
      local task = {time = 10, func = 'testFunction("TestParam")'}
      local testFuncSpy = spy(_ENV, 'testFunction')
      RunAfter.private.scheduledTasks = {task}

      RunAfter.tick()

      lu.assertEquals(testFuncSpy.calls, {{'TestParam'}}) -- 1 call
    end
  )
)

--#endregion RunAfter.tick()

--#region RunAfter()
test(
  'RunAfter.should use toNumberOfSeconds() to parse the delay',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local toNumberOfSecondsSpy = spy(RunAfter.private, 'toNumberOfSeconds')

    RunAfter('10s', 'do_something')

    lu.assertEquals(toNumberOfSecondsSpy.calls, {{'10s'}})
  end
)

test(
  'RunAfter.should insert a task into the task list correctly',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.getCurrentTime = functionReturning(20)
    local insertTaskSpy = spy(RunAfter.private, 'insertTask')

    RunAfter(10, 'do_something')

    lu.assertEquals(#insertTaskSpy.calls, 1)
    local createdTask = insertTaskSpy.calls[1][1]
    lu.assertEquals(createdTask.time, 30)
    lu.assertEquals(createdTask.func, 'do_something()')
  end
)
--#endregion RunAfter()
--#endregion public functions

os.exit(lu.LuaUnit.run())
