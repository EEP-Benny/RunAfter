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
  ---@field funcAsStr string @the function to execute in string form (this is stored in a slot or tag text)
  ---@field func function @the function to execute (parsed from funcAsStr)

  --#endregion type definitions

  --#region private members

  ---@type Options
  private.options = {
    axisName = 'Timer'
  }

  ---List of all scheduled tasks, sorted by time descending.
  ---
  ---The task that will be executed first is at the end of the list, like this:
  ---```
  ---{
  ---  {time = 50, ...},
  ---  ...
  ---  {time = 1, ...},
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
    local indexOfLastTask = #private.scheduledTasks
    while indexOfLastTask > 0 and private.scheduledTasks[indexOfLastTask].time < currentTime do
      local task = private.scheduledTasks[indexOfLastTask]
      private.scheduledTasks[indexOfLastTask] = nil
      indexOfLastTask = indexOfLastTask - 1
      task.func()
    end
  end

  --#endregion public functions

  return RunAfter
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
