-- Dependencies. --
assert(igrednet, "igpower API requires igrednet API")

-- Power management. --
local function _setOutput(sides, value)
  if sides.back then
    if type(value) == "number" then
      rs.setAnalogOutput("back", value)
    else rs.setOutput("back", value) end
  end
  if sides.bottom then
    if type(value) == "number" then
      rs.setAnalogOutput("bottom", value)
    else rs.setOutput("bottom", value) end
  end
  if sides.left then
    if type(value) == "number" then
      rs.setAnalogOutput("left", value)
    else rs.setOutput("left", value) end
  end
  if sides.right then
    if type(value) == "number" then
      rs.setAnalogOutput("right", value)
    else rs.setOutput("right", value) end
  end
  if sides.top then
    if type(value) == "number" then
      rs.setAnalogOutput("top", value)
    else rs.setOutput("top", value) end
  end
end

local function _broadcast(side, value)
  igrednet.Message.new(
    {side=side, value=value, type=igrednet.msgTypes.GENERATOR_STATUS}
  ):broadcast()
end

-- Checks analog redstone value of all sides in inSides against minRs.        --
-- If all are lower than minRs, returns true, else false.                     --
local function _determineRunState(inSides, minRs, quiet)
  local maxRs = 0
  for side, _ in pairs(inSides) do
    local thisRs = rs.getAnalogInput(side)
    if not quiet then _broadcast(side, thisRs) end
    if thisRs > maxRs then maxRs = thisRs end
  end
  if maxRs <= minRs then return true else return false end
end

-- Regulate extra utilities generator input. --
-- Detect redstone signals from inputSides.  If the analog input from any     --
-- side is above a minimum value (set through options.min, default is 2) then --
-- the outputSides are set to maximum redstone output.                        --
function regulateGenerators(inputSides, outputSides, options)
  -- Make sure we have the minimal input objects we need. --
  if type(inputSides) ~= "table" or type(outputSides) ~= "table" then
    print("Input Error: Regulation requires list of redstone signal input " ..
          "sides AND list of redstone signal output sides.")
    return false
  end
  if not options then options = {} end
  -- Reformat input in variables we can use. --
  local oneIn, oneOut = false, false
  local inSides, outSides = {}, {}
  for _, val in ipairs(inputSides) do
    if val == "back" or val == "bottom" or val == "left" or
       val == "right" or val == "top" then
      oneIn = true
      inSides[val] = true
    end
  end
  if not oneIn then
    print("Input Error: At least one input side must be specified.")
    return false
  end
  for _, val in pairs(outputSides) do
    if val == "back" or val == "bottom" or val == "left" or
       val == "right" or val == "top" then
      oneOut = true
      outSides[val] = true
    end
  end
  if not oneOut then
    print("Input Error: At least one output side must be specified.")
    return false
  end
  -- Get options from options table or use defaults. --
  local minRs = options.min or 2
  -- State variables. --
  local runState, shouldRun = true, true
  -- Setup rednet broadcasting --
  if not options.quiet then
    assert(igrednet.connect(), "Could not find wireless modem.")
  end
  -- Set initial output to off. --
  _setOutput(outSides, false)
  -- Main loop. --
  while true do
    shouldRun = _determineRunState(inSides, minRs, options.quiet)
    if runState ~= shouldRun then
      term.clear()
      term.setCursorPos(1,1)
      if shouldRun then
        print("Starting generators ...")
      else
        print("Stopping generators ...")
      end
    end
    _setOutput(outSides, not shouldRun)
    runState = shouldRun
    sleep(1)
  end
end
