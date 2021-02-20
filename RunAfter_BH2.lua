local function makeRunAfter()
  local RunAfter = {}

  local private = {}
  if EXPOSE_PRIVATE_FOR_TESTING then
    RunAfter.private = private
  end

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
    __call = function()
      local RunAfter = makeRunAfter()
      return RunAfter
    end
  }
)
--#endregion module metadata
