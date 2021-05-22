---create an instance of RunAfter (so tests are independent of each other)
---@return RunAfter
local function makeRunAfter()
  ---@class RunAfter
  local RunAfter = {}

  local private = {}
  if EXPOSE_PRIVATE_FOR_TESTING then
    RunAfter.private = private
  end

  --#region type definitions

  ---@class Options
  ---@field immoName string
  ---@field axisName string

  ---@class UserOptions
  ---@field axisName string
  ---@field immoName number | string

  ---@class ScheduledTask
  ---@field time number @absolute time this task should run at
  ---@field func string|function @the function to execute (if this is a string, the task will be stored in a slot or tag text; if it's a function, it won't)

  --#endregion type definitions

  --#region private members

  ---@type Options
  private.options = {
    axisName = 'Timer'
  }

  ---List of all scheduled tasks, sorted by time ascending.
  ---
  ---The task that will be executed first is at the start of the list, like this:
  ---```
  ---{
  ---  {time = 1, ...},
  ---  ...
  ---  {time = 50, ...},
  ---}
  ---```
  ---@type ScheduledTask[]
  private.scheduledTasks = {}

  --#endregion private members

  --#region private functions

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

  ---Returns the current time (based on the axis position)
  ---@return number currentTime @current time in seconds
  function private.getCurrentTime()
    local _, axisPosition = EEPStructureGetAxis(private.options.immoName, private.options.axisName)
    return axisPosition
  end

  function private.resetTimerAxis()
    local resetInterval = 60
    local shouldInsertResetTask = true
    local _, axisPosition = EEPStructureGetAxis(private.options.immoName, private.options.axisName)
    local newAxisPosition = axisPosition - resetInterval
    if newAxisPosition >= 0 then
      EEPStructureSetAxis(private.options.immoName, private.options.axisName, newAxisPosition)
      for _, task in ipairs(private.scheduledTasks) do
        if task.func == private.resetTimerAxis then
          shouldInsertResetTask = false
        else
          task.time = task.time - resetInterval
        end
      end
    end
    if shouldInsertResetTask then
      private.insertTask({time = resetInterval, func = private.resetTimerAxis})
    end
  end

  ---inserts a task at the right place into the list of all scheduled tasks
  ---@param task ScheduledTask
  function private.insertTask(task)
    local index = #private.scheduledTasks
    while index >= 1 and private.scheduledTasks[index].time > task.time do
      private.scheduledTasks[index + 1] = private.scheduledTasks[index]
      index = index - 1
    end
    private.scheduledTasks[index + 1] = task
  end

  --#endregion private functions

  --#region public functions

  ---@param newOptions UserOptions
  function RunAfter.setOptions(newOptions)
    if type(newOptions) ~= 'table' then
      newOptions = {immoName = newOptions}
    end

    if newOptions.axisName then
      local axisName = newOptions.axisName
      assert(type(axisName) == 'string', 'axisName muss ein String sein, aber ist vom Typ ' .. type(axisName))
      private.options.axisName = axisName
    end
    if newOptions.immoName then
      local immoName = private.toImmoName(newOptions.immoName)
      assert(
        type(immoName) == 'string',
        'immoName muss eine Zahl oder ein String sein, aber ist vom Typ ' .. type(immoName)
      )
      local CONTINUOUS_MOVEMENT = 1000
      local ok = EEPStructureAnimateAxis(immoName, private.options.axisName, CONTINUOUS_MOVEMENT)
      assert(
        ok,
        string.format(
          'Die Immobilie %s existiert nicht oder hat keine Achse namens %s',
          immoName,
          private.options.axisName
        )
      )
      private.options.immoName = immoName
    end
  end

  ---Executes due tasks.
  ---This function needs to be called periodically.
  function RunAfter.tick()
    local currentTime = private.getCurrentTime()
    while private.scheduledTasks[1] ~= nil and private.scheduledTasks[1].time < currentTime do
      local task = private.scheduledTasks[1]
      table.remove(private.scheduledTasks, 1)
      if type(task.func) == 'function' then
        task.func()
      else
        local func, errMsg = load(task.func)
        if func then
          func()
        else
          error(errMsg)
        end
      end
    end
  end

  ---Registers a task that is executed in the future
  ---@param seconds number @relative time when the function should be called
  ---@param func string|function @function to be called or name of the function
  ---@param params any[] @table of paramaters for the function call, if the function is given as a string
  function RunAfter.runAfter(seconds, func, params)
    local time = private.getCurrentTime() + seconds
    --TODO: use params
    if type(func) == 'string' then
      func = string.format('%s()', func)
    end
    private.insertTask({time = time, func = func})
  end

  --#endregion public functions

  return setmetatable(
    RunAfter,
    {
      ---@see RunAfter.runAfter
      __call = function(self, ...)
        return RunAfter.runAfter(...)
      end
    }
  )
end

--#region module metadata
return setmetatable(
  {
    _VERSION = {0, 0, 1},
    _DESCRIPTION = 'Zeitverzögerte Auführung von Funktionen',
    _URL = 'https://github.com/EEP-Benny/RunAfter',
    _LICENSE = 'MIT'
  },
  {
    ---returns an instance of RunAfter, configured with the given options
    ---@param options UserOptions
    ---@return RunAfter
    __call = function(self, options)
      local RunAfter = makeRunAfter()
      RunAfter.setOptions(options)
      return RunAfter
    end
  }
)
--#endregion module metadata
