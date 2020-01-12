--- @classmod ProgrammableFn
--- Creates an easily programmable function for testing purposes.
-- Multiple behaviours can be defined.
-- A behaviour consists of a set of arguments and a set of return values.
-- If the function is called with these arguments it will return the programmed
-- return values.


local ValueMatcher = require 'test.mock.ValueMatcher'


local ProgrammableFn = {}
ProgrammableFn.__index = ProgrammableFn


local function behaviourSideEffect( behaviour )
    local next = behaviour.nextReturnSet
    return behaviour.sideEffects[next]
end

local function behaviourReturnValues( behaviour )
    local next = behaviour.nextReturnSet

    local returnSet = behaviour.returnSets[next]

    if next < #behaviour.returnSets then
        next = next + 1
    else
        next = 1
    end
    behaviour.nextReturnSet = next

    return unpack(returnSet)
end

function ProgrammableFn:__call( ... )
    local behaviour = self:_findMatchingBehaviour({...})
    if not behaviour then
        error('No matching behaviour for call.', 2)
    end
    local sideEffect = behaviourSideEffect(behaviour)
    local retval = behaviourReturnValues(behaviour)
    -- Call side effect after getting return value so that the return set index
    -- increments before the side effect is called in case it throws an error.
    sideEffect(...)
    return retval
end

function ProgrammableFn:_findMatchingBehaviour( arguments )
    for _,behaviour in ipairs(self.behaviours) do
        if ValueMatcher.matches(arguments, behaviour.arguments) then
            return behaviour
        end
    end
    return nil
end

--- Creates a new behaviour entry or extends to one.
--
-- @param specification
-- The specification is a table, that contains the arguments that must match to
-- trigger this behaviour and the values that will be returned then.
-- Both are optional and can be passed like this:
-- `whenCalled{with={1,2}, thenReturn={3}}`
function ProgrammableFn:whenCalled( specification )
    local arguments = specification.with or {}
    local returnSet = specification.thenReturn or {}
    local sideEffect = specification.sideEffect or function() end

    local behaviour = self:_findMatchingBehaviour(arguments)
    if behaviour then
        table.insert(behaviour.returnSets, returnSet)
        table.insert(behaviour.sideEffects, sideEffect)
    else
        behaviour = {
            arguments = arguments,
            returnSets = { returnSet },
            nextReturnSet = 1,
            sideEffects = { sideEffect }
        }
        table.insert(self.behaviours, behaviour)
    end

    return self
end

function ProgrammableFn:reset()
    self.behaviours = {}
    return self
end


return function()
    local self = {
        behaviours = {}
    }
    return setmetatable(self, ProgrammableFn)
end
