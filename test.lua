local lust = require('lust')
local describe, it, expect, before = lust.describe, lust.it, lust.expect, lust.before

require('EEPGlobals')

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

local function returnFalse()
  return false
end

---@param options UserOptions
---@return RunAfter
local function getRunAfter(options)
  return require('RunAfter_BH2')(options)
end
---@type fun(options:UserOptions): RunAfter
local getRunAfterWithPrivate = withChangedGlobals({EXPOSE_PRIVATE_FOR_TESTING = true}, getRunAfter)

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

    --#region private functions

    describe(
      'toImmoName',
      function()
        it(
          'should convert a number to a string',
          function()
            local toImmoName = getRunAfterWithPrivate().private.toImmoName
            expect(toImmoName(10)).to.be('#10')
          end
        )
        it(
          'should pass through a string',
          function()
            local toImmoName = getRunAfterWithPrivate().private.toImmoName
            expect(toImmoName('#11')).to.be('#11')
            expect(toImmoName('#11_ImmoName')).to.be('#11_ImmoName')
          end
        )
        it(
          'should not check that the id is valid',
          function()
            local toImmoName = getRunAfterWithPrivate().private.toImmoName
            expect(toImmoName('invalid ID')).to.be('invalid ID')
            expect(toImmoName(false)).to.be(false)
          end
        )
      end
    )

    --#endregion private functions

    --#region public functions

    describe(
      'setOptions',
      function()
        it(
          'should treat a single value as the immoName',
          function()
            local RunAfter = getRunAfterWithPrivate('#1')
            expect(RunAfter.private.options.immoName).to.be('#1')
          end
        )

        describe(
          'immoName',
          function()
            it(
              'should be copied using toImmoName',
              function()
                local RunAfter = getRunAfterWithPrivate()
                local toImmoNameSpy = lust.spy(RunAfter.private, 'toImmoName')
                RunAfter.private.options = {}
                RunAfter.setOptions({immoName = '#123'})
                expect(toImmoNameSpy).to.equal({{'#123'}})
                expect(RunAfter.private.options).to.equal({immoName = '#123'})
              end
            )
            it(
              'should start axis movement',
              function()
                local RunAfter = getRunAfterWithPrivate()
                local EEPStructureAnimateAxisSpy = lust.spy(_ENV, 'EEPStructureAnimateAxis')
                RunAfter.private.options = {axisName = 'Achse'}
                RunAfter.setOptions({immoName = '#123'})
                expect(EEPStructureAnimateAxisSpy).to.equal({{'#123', 'Achse', 1000}})
              end
            )
            it(
              'should throw an error if immo or axis does not exist',
              withChangedGlobals(
                {EEPStructureAnimateAxis = returnFalse},
                function()
                  local RunAfter = getRunAfter()
                  expect(pcall(RunAfter.setOptions, {immoName = '#123'})).to.be(false)
                end
              )
            )
            it(
              'should throw an error if immoName has the wrong type',
              function()
                local RunAfter = getRunAfter()
                expect(pcall(RunAfter.setOptions, {immoName = true})).to.be(false)
              end
            )
          end
        )
      end
    )

    --#endregion public functions
  end
)
