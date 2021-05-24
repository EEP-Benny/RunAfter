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
  ---@field loadFn fun(): string
  ---@field saveFn fun(content: string)

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

  ---Parses a time value given as a string or number.
  ---
  ---All the following time values return `5420` seconds:
  ---* `5420` (number)
  ---* `"5420"` (numeric string)
  ---* `"5420s"` (explicit seconds)
  ---* `"1h30m20s"` (mix of units)
  ---* `"1h 30m 20s"` (with spaces)
  ---* `"1.5h20s"` (with decimals)
  ---* `"90m20s"` (with "overflow")
  ---@param timeValue string | number
  ---@return number @the time in seconds
  function private.toNumberOfSeconds(timeValue)
    if type(timeValue) == 'number' then
      return timeValue
    elseif type(timeValue) == 'string' then
      local seconds = 0
      local numberPattern, unitPattern = '%d+%.?%d*', '[hms]?'
      for match in string.gmatch(timeValue, numberPattern .. unitPattern) do
        local _, _, numeric, unit = string.find(match, string.format('(%s)(%s)', numberPattern, unitPattern))
        local number = tonumber(numeric)
        local multiplier = ({h = 60 * 60, m = 60, s = 1})[unit] or 1
        seconds = seconds + (number * multiplier)
      end
      -- print(timeValue, '-', string.find(timeValue, '(%d+[hms])'))
      return seconds
    end
  end

  ---Returns a string representation of the given `value`, which is parsable by Lua
  ---@param value any
  ---@return string
  function private.serialize(value)
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

    return serializeRecursively(value, {})
  end

  ---Returns the current time (based on the axis position)
  ---@return number currentTime @current time in seconds
  function private.getCurrentTime()
    local _, axisPosition = EEPStructureGetAxis(private.options.immoName, private.options.axisName)
    return axisPosition
  end

  function private.loadFromStorage()
    local stringFromStorage = private.options.loadFn and private.options.loadFn() or ''
    local fun, errorMessage = load('return ' .. stringFromStorage, stringFromStorage)
    if fun == nil then
      error('data from storage is incomplete: ' .. errorMessage)
    end
    local compressedTaskList = fun()
    for index, value in ipairs(compressedTaskList or {}) do
      private.scheduledTasks[index] = {time = value[1], func = value[2]}
    end
    private.resetTimerAxis()
  end

  function private.saveToStorage()
    if type(private.options.saveFn) ~= 'function' then
      return
    end
    local compressedTaskList = {}
    for _, task in ipairs(private.scheduledTasks) do
      if type(task.func) == 'string' then
        table.insert(compressedTaskList, {task.time, task.func})
      end
    end
    private.options.saveFn(private.serialize(compressedTaskList))
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
      private.saveToStorage()
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
    if type(task.func) == 'string' then
      -- if task.func is a function, it won't get saved anyway
      private.saveToStorage()
    end
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

    private.loadFromStorage()
  end

  ---Executes due tasks.
  ---This function needs to be called periodically.
  function RunAfter.tick()
    local currentTime = private.getCurrentTime()
    local someTaskWasExecuted = false
    while private.scheduledTasks[1] ~= nil and private.scheduledTasks[1].time < currentTime do
      someTaskWasExecuted = true
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
    if someTaskWasExecuted then
      private.saveToStorage()
    end
  end

  ---Registers a task that is executed in the future
  ---@param delay string|number @delay after which the function should be called, either as a number (in seconds) or as a string like "1m20s"
  ---@param func string|function @function to be called or name of the function
  ---@param params? any[] @table of paramaters for the function call, if the function is given as a string
  function RunAfter.runAfter(delay, func, params)
    local time = private.getCurrentTime() + private.toNumberOfSeconds(delay)
    if type(func) == 'string' then
      local serializedParams = {}
      for i, param in ipairs(params or {}) do
        serializedParams[i] = private.serialize(param)
      end
      func = string.format('%s(%s)', func, table.concat(serializedParams, ','))
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
