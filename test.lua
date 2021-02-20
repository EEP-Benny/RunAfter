local lust = require('lust')
local describe, it, expect, before = lust.describe, lust.it, lust.expect, lust.before

require('EEPGlobals')

local function getRunAfter(options)
  return require('RunAfter_BH2')(options)
end

local function getRunAfterWithPrivate(options)
  EXPOSE_PRIVATE_FOR_TESTING = true
  local RunAfter = require('RunAfter_BH2')(options)
  EXPOSE_PRIVATE_FOR_TESTING = nil
  return RunAfter
end

describe(
  'RunAfter_BH2',
  function()
    it(
      'should import correctly',
      function()
        local module = require('RunAfter_BH2')
        expect(module).to.be.a('table')
        expect(module._DESCRIPTION).to.exist()
        expect(module._LICENSE).to.exist()
        expect(module._URL).to.exist()
        expect(module._VERSION).to.exist()
        expect(module()).to.be.a('table')
      end
    )

    it(
      'should not expose private variables normally',
      function()
        local RunAfter = getRunAfter()
        expect(RunAfter.private).to_not.exist()
      end
    )

    it(
      'should expose private variables for testing',
      function()
        local RunAfter = getRunAfterWithPrivate()
        expect(RunAfter.private).to.be.a('table')
      end
    )
  end
)
