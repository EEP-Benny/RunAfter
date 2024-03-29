--#region test setup

local lu = require('luaunit')
local testSetup = require('testSetup')
local test = testSetup.test
local functionReturning = testSetup.functionReturning
local withChangedGlobals = testSetup.withChangedGlobals
local spy = testSetup.spy
local finish = testSetup.finish

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

--#region loadFromStorage()
test(
  'loadFromStorage.should load and parse data from storage',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.options.loadFn = functionReturning('{{10,"do_something()"},{20,"do_something_else()"}}')
    RunAfter.private.resetTimerAxis = functionReturning(nil)

    RunAfter.private.loadFromStorage()

    lu.assertEquals(
      RunAfter.private.scheduledTasks,
      {{time = 10, func = 'do_something()'}, {time = 20, func = 'do_something_else()'}}
    )
  end
)

test(
  'loadFromStorage.should not crash if there is no data to load',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.options.loadFn = functionReturning(nil)
    RunAfter.private.loadFromStorage()
  end
)

test(
  'loadFromStorage.should throw an error if the saved string is incomplete',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.options.loadFn = functionReturning('{{10,"do_something()"}')

    lu.assertErrorMsgContains('data from storage is incomplete', RunAfter.private.loadFromStorage)
  end
)

test(
  'loadFromStorage.should call resetTimerAxis',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local resetTimerAxisSpy = spy(RunAfter.private, 'resetTimerAxis')
    RunAfter.private.loadFromStorage()
    lu.assertEquals(#resetTimerAxisSpy.calls, 1)
  end
)

--#endregion loadFromStorage()

--#region saveToStorage()
test(
  'saveToStorage.should serialize and save data to storage',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.scheduledTasks = {{time = 10, func = 'do_something()'}, {time = 20, func = 'do_something_else()'}}
    RunAfter.private.options.saveFn = functionReturning(nil)
    local saveFnSpy = spy(RunAfter.private.options, 'saveFn')

    RunAfter.private.saveToStorage()

    lu.assertEquals(saveFnSpy.calls, {{'{{10,"do_something()"},{20,"do_something_else()"}}'}})
  end
)
--#endregion saveToStorage()

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
  'resetTimerAxis.should call saveToStorage',
  withChangedGlobals(
    {EEPStructureGetAxis = functionReturning(true, 61)},
    function()
      local RunAfter = getRunAfterWithPrivate()
      local saveToStorageSpy = spy(RunAfter.private, 'saveToStorage')
      RunAfter.private.resetTimerAxis()
      lu.assertEquals(#saveToStorageSpy.calls, 1)
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

test(
  'insertTask.should call saveToStorage for tasks with a string function',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local saveToStorageSpy = spy(RunAfter.private, 'saveToStorage')
    RunAfter.private.insertTask({time = 10, func = 'do_something()'})
    lu.assertEquals(#saveToStorageSpy.calls, 1)
  end
)

test(
  'insertTask.should not call saveToStorage for tasks without a string function',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local saveToStorageSpy = spy(RunAfter.private, 'saveToStorage')
    RunAfter.private.insertTask({time = 10, func = functionReturning(nil)})
    lu.assertEquals(#saveToStorageSpy.calls, 0)
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

test(
  'setOptions.should load data from storage',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local loadFromStorageSpy = spy(RunAfter.private, 'loadFromStorage')
    RunAfter.setOptions()
    lu.assertEquals(#loadFromStorageSpy.calls, 1)
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

test(
  'tick.should call saveToStorage() once if at least one task was executed',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local saveToStorageSpy = spy(RunAfter.private, 'saveToStorage')
    RunAfter.private.getCurrentTime = functionReturning(30)
    local task1 = {time = 10, func = functionReturning(nil)}
    local task2 = {time = 15, func = functionReturning(nil)}
    RunAfter.private.scheduledTasks = {task1, task2}

    RunAfter.tick()

    lu.assertEquals(#saveToStorageSpy.calls, 1)
  end
)

test(
  'tick.should not call saveToStorage() if no task was executed',
  function()
    local RunAfter = getRunAfterWithPrivate()
    local saveToStorageSpy = spy(RunAfter.private, 'saveToStorage')

    RunAfter.tick()

    lu.assertEquals(#saveToStorageSpy.calls, 0)
  end
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
  'RunAfter.should use SerializationHelper.serialize() to serialize parameters',
  function()
    local RunAfter = getRunAfter()
    local serializeSpy = spy(require('SerializationHelper_BH2'), 'serialize')

    RunAfter('10s', 'do_something', {1, '2'})

    lu.assertEquals(serializeSpy.calls, {{1}, {'2'}})

    serializeSpy.revoke()
  end
)

test(
  'RunAfter.should create the correct task without function parameters',
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
test(
  'RunAfter.should create the correct task with function parameters',
  function()
    local RunAfter = getRunAfterWithPrivate()
    RunAfter.private.getCurrentTime = functionReturning(20)
    local insertTaskSpy = spy(RunAfter.private, 'insertTask')

    RunAfter(10, 'do_something', {1, 2})

    lu.assertEquals(#insertTaskSpy.calls, 1)
    local createdTask = insertTaskSpy.calls[1][1]
    lu.assertEquals(createdTask.time, 30)
    lu.assertEquals(createdTask.func, 'do_something(1,2)')
  end
)
--#endregion RunAfter()
--#endregion public functions

finish()
