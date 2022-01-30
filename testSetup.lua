local module = {}

local lu = require('luaunit')
-- LuaUnit searches in the global scopes for all functions starting with "Test" or "test".
-- I prefer tests with speaking names that aren't reordered, so let's monkey-patch this mechanism.
local tests = {}

---@param name string @name of the test
---@param fun fun() @test function to run
function module.test(name, fun)
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
function module.spy(target, name)
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

function module.withChangedGlobals(replacements, fun)
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

function module.functionReturning(...)
  local returnValues = {...}
  return function()
    return table.unpack(returnValues)
  end
end

function module.finish()
  local isTopLevel = debug.getinfo(4) == nil
  if isTopLevel then
    os.exit(lu.LuaUnit.run())
  end
end

return module
