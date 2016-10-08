-- Message enums --
local msgTypes = {
  MESSAGE = 0,
  GENERATOR_STATUS = 1,
  COMMAND = 2
}
local commands = {
  START_GENERATORS = 0,
  STOP_GENERATORS = 1
}
-- Message class --
local Message = {}
function Message.new(members)
  local newobj = {}
  -- Inherit passed in values.
  for k,v in pairs(members) do
    newobj[k] = v
  end
  -- Set defaults for needed values.
  newobj.type = newobj.type or msgTypes.MESSAGE
  newobj.value = newobj.value or ""
  newobj.source = newobj.source or os.computerLabel() or os.computerID()
  -- Set methods.
  function newobj:broadcast()
    rednet.broadcast(self,"__igMsg__")
  end
  return newobj
end

-- Rednet utilities. --
local function findWirelessModemCb(name, object)
  if object.isWireless() then
    object._sideName = name
    return true
  else
    return false
  end
end

function connect()
  local obj = peripheral.find("modem", findWirelessModemCb)
  if obj then
    rednet.open(obj._sideName)
    return true
  else
    print("Error: Could not find wireless modem.")
    return false
  end
end

local function sleep1() sleep(1) end

-- Catch all ig messages. --
function receive()
  local allMsgs = {}
  local function getAllMsgs()
    local msg
    while true do
      _, msg = rednet.receive("__igMsg__")
      table.insert(allMsgs, msg)
    end
  end
  parallel.waitForAny(getAllMsgs, sleep1)
  return allMsgs
end

-- Power management. --
local function _setOutput(sides, value)
  if sides.back then if type(value) == "number" then rs.setAnalogOutput("back", value) else rs.setOutput("back", value) end end
  if sides.bottom then if type(value) == "number" then rs.setAnalogOutput("bottom", value) else rs.setOutput("bottom", value) end end
  if sides.left then if type(value) == "number" then rs.setAnalogOutput("left", value) else rs.setOutput("left", value) end end
  if sides.right then if type(value) == "number" then rs.setAnalogOutput("right", value) else rs.setOutput("right", value) end end
  if sides.top then if type(value) == "number" then rs.setAnalogOutput("top", value) else rs.setOutput("top", value) end end
end

local function _broadcast(side, value)
  Message.new({side=side, value=value, type=msgTypes.GENERATOR_STATUS}):broadcast()
end

-- Checks analog redstone value of all sides in inSides against minRs. --
-- If all are lower than minRs, returns true, else false.              --
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
-- Detect redstone signals from inputSides.  If the analog input from any side is above a --
-- minimum value (set through options.min, default is 2) then the outputSides are set to  --
-- maximum redstone output.                                                               --
function regulateGenerators(inputSides, outputSides, options)
  -- Make sure we have the minimal input objects we need. --
  if type(inputSides) ~= "table" or type(outputSides) ~= "table" then
    print("Input Error: Regulation requires list of redstone signal input sides AND list of redstone signal output sides.")
    return false
  end
  if not options then options = {} end
  -- Reformat input in variables we can use. --
  local oneIn, oneOut = false, false
  local inSides, outSides = {}, {}
  for _, val in ipairs(inputSides) do
    if val == "back" or val == "bottom" or val == "left" or val == "right" or val == "top" then
      oneIn = true
      inSides[val] = true
    end
  end
  if not oneIn then
    print("Input Error: At least one input side must be specified.")
    return false
  end
  for _, val in pairs(outputSides) do
    if val == "back" or val == "bottom" or val == "left" or val == "right" or val == "top" then
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
    if not rednet.isOpen(peripheral.find("modem", findWirelessModemCb)._sideName) then
      connect()
    end
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

-- Turtle movement and position functions. --
local _pos = {x = 0, y = 0, z = 0, orient = 0}

function turtle_forward()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspect() then
    turtle.dig()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.forward()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.y = _pos.y + 1
    elseif _pos.orient == 1 then
      _pos.x = _pos.x + 1
    elseif _pos.orient == 2 then
      _pos.y = _pos.y - 1
    elseif _pos.orient == 3 then
      _pos.x = _pos.x - 1
    end
  end
  return unpack(successfulMove)
end

function turtle_back()
  -- Move into position and record movement. --
  local successfulMove = {turtle.back()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.y = _pos.y - 1
    elseif _pos.orient == 1 then
      _pos.x = _pos.x - 1
    elseif _pos.orient == 2 then
      _pos.y = _pos.y + 1
    elseif _pos.orient == 3 then
      _pos.x = _pos.x + 1
    end
  end
  return unpack(successfulMove)
end

function turtle_up()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspectUp() then
    turtle.digUp()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.up()}
  if successfulMove[1] then
    _pos.z = _pos.z + 1
  end
  return unpack(successfulMove)
end

function turtle_down()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspectDown() then
    turtle.digDown()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.down()}
  if successfulMove[1] then
    _pos.z = _pos.z - 1
  end
  return unpack(successfulMove)
end

function turtle_turnRight()
  local successfulMove = {turtle.turnRight()}
  if successfulMove[1] then
    if _pos.orient == 3 then
      _pos.orient = 0
    else
      _pos.orient = _pos.orient + 1
    end
  end
  return unpack(successfulMove)
end

function turtle_turnLeft()
  local successfulMove = {turtle.turnLeft()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.orient = 3
    else
      _pos.orient = _pos.orient - 1
    end
  end
  return unpack(successfulMove)
end

function turtle_faceOrientation(orient)
  if (orient - _pos.orient) % 4 > 2 then
    while _pos.orient ~= orient do
      turtle_turnLeft()
    end
  else
    while _pos.orient ~= orient do
      turtle_turnRight()
    end
  end
  return true
end

function turtle_goTo(x, y, z)
  assert(x and y, "Must supply both x and y coordinates.")
  z = z or _pos.z
  local successfulMove
  -- Move in z-direction first. --
  if _pos.z ~= z then
    local zDirUp = _pos.z > z and 0 or 1
    while _pos.z ~= z do
      successfulMove = zDirUp == 1 and {turtle_up()} or {turtle_down()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Move in y-direction. --
  if _pos.y ~= y then
    if _pos.y > y then turtle_faceOrientation(2) else turtle_faceOrientation(0) end
    while _pos.y ~= y do
      successfulMove = {turtle_forward()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Move in x-direction. --
  if _pos.x ~= x then
    if _pos.x > x then turtle_faceOrientation(3) else turtle_faceOrientation(1) end
    while _pos.x ~= x do
      successfulMove = {turtle_forward()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Face in the starting direction. --
  turtle_faceOrientation(0)
  return true
end

function turtle_goHome()
  turtle_goTo(0,0,0)
end

function turtle_setHome()
  _pos.x = 0
  _pos.y = 0
  _pos.z = 0
  _pos.orient = 0
end

-- Empty a turtle's inventory into an inventory below it. --
-- Optional argument can be an array of slots to ignore.                                  --
-- Restores the selected slot to slot selected when function was called.                  --
function turtle_emptyInventoryDown(keepslots)
  local oldSlot = turtle.getSelectedSlot()
  local slotsToKeep = {}
  -- Pull out the values and use as keys. --
  if keepslots then
    for _, i in ipairs(keepslots) do
      slotsToKeep[i] = true
    end
  end
  for i = 1,16 do
    if not slotsToKeep[i] and turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.dropDown()
    end
  end
  turtle.select(oldSlot)
end

-- Find slot containing to itemName.  Returns false on failure.                        --
function turtle_findItemSlot(itemName, damage)
  local data, found, slot = nil, false, 0
  while slot < 16 and not found do
    slot = slot + 1
    data = turtle.getItemDetail(slot)
    if data then
      found = data.name == itemName
      if damage then found = found and data.damage == damage end
    end
  end
  return found and slot
end

-- Harvests a birch tree. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log.             --
-- Replants a birch sapling, if it has one.                                               --
function turtle_harvestBirch()
  local blockFound, blockData = turtle.inspectDown()
  if blockFound and blockData.name == "minecraft:log" then
    -- Remove the base trunk and replace the sapling. --
    turtle.digDown()
    local saplingSlot = turtle_findItemSlot("minecraft:sapling", 2)
    if saplingSlot then
      turtle.select(saplingSlot)
      turtle.placeDown()
    end
    -- Remove the rest of the tree. --
    blockFound, blockData = turtle.inspectUp()
    while blockFound and blockData.name == "minecraft:log" do
      turtle_up()
      blockAbove, blockData = turtle.inspectUp()
    end
    -- Go back to z = 0. --
    while _pos.z > 0 do turtle_down() end
    return true
  else return false end
end

local function _getSaplings()
  if turtle.getSelectedSlot() ~= 1 then
    turtle.select(1)
  end
  assert(turtle.suckDown(), "Saplings must be in first non-empty slot of inventory below turtle.")
  itemdata = turtle.getItemDetail()
  assert(itemdata.name == "minecraft:sapling", "Saplings must be in first non-empty slot of inventory below turtle.")
end

local function _treeHarvestPrep(damage)
  damage = tonumber(damage) or 2
  -- Find saplings and put them in slot 1. --
  local saplingSlot = turtle_findItemSlot("minecraft:sapling",damage)
  if saplingSlot and saplingSlot ~= 1 then
    if turtle.getItemCount(1) > 0 then
      turtle.select(1)
      turtle.dropDown()
    end
    turtle.select(saplingSlot)
    turtle.transferTo(1)
  elseif not saplingSlot then
    turtle.select(1)
    if turtle.getItemCount(1) > 0 then
      turtle.dropDown()
    end
    turtle.suckDown()
    local item1 = turtle.getItemDetail(1)
    if not item1 or item1.name ~= "minecraft:sapling" or item1.damage ~= damage then
      turtle_emptyInventoryDown()
      error("Cannot farm without saplings.  Place saplings in first slot of inventory.")
    end
  end
  turtle_emptyInventoryDown({1})
end

local function _dumpHarvest(keepslots)
  turtle_goHome()
  turtle.select(1)
  turtle_emptyInventoryDown(keepslots)
end

local function _harvestRefuel(keepslots)
  -- Dump inventory to make room for fuel. --
  _dumpHarvest(keepslots)
  -- Move over fuel inventory. --
  turtle_faceOrientation(1)
  turtle_forward()
  -- Get and consume fuel. --
  turtle.select(16)
  turtle.suckDown(16)
  turtle.refuel()
  turtle.select(1)
  turtle_goHome()
end

-- Faces the next direction the turtle should travel along a route.    --
-- Returns true if the turtle is ready to move forward and false if it --
-- has reached the end of the route.                                   --
local function _harvestFaceForward(length, width)
  -- Check if we're at the end of the route. --
  local endy = (width % 2 == 1) and length or 1
  if _pos.x >= width-1 and _pos.y == endy then
    return false
  end
  -- Determine the direction we should face to progress. --
  -- If we're at home or otherwise y < 1, go forward.    --
  if _pos.y < 1 then
    turtle_faceOrientation(0)
  elseif _pos.x % 2 == 0 then
    -- If we're at the end of a row, face right. --
    if _pos.y >= length then
      turtle_faceOrientation(1)
    -- Otherwise, face forward. --
    else
      turtle_faceOrientation(0)
    end
  else
    -- If we're at the start of a row, face right. --
    if _pos.y <= 1 then
      turtle_faceOrientation(1)
    -- Otherwise, face backward. --
    else
      turtle_faceOrientation(2)
    end
  end
  return true
end

local function _harvestForward(length, width, minfuel, keepslots, waittime)
  minfuel = tonumber(minfuel) or 0
  keepslots = keepslots or {}
  waittime = tonumber(waittime) or 60
  -- Check to make sure we have enough fuel to harvest a tree. --
  local necessaryFuel = math.abs(_pos.x) + math.abs(_pos.y) + 2 + minfuel
  if turtle.getFuelLevel() < necessaryFuel then
    _harvestRefuel(keepslots)
    return
  end
  -- Check that our inventory isn't full. --
  if turtle.getItemCount(16) > 0 then
    _dumpHarvest(keepslots)
    return
  end
  -- Face the direction we should move. --
  -- If false, return to home and dump harvest. --
  if _harvestFaceForward(length, width) then
    -- Move forward. --
    turtle_forward()
  else
    _dumpHarvest(keepslots)
    os.sleep(waittime)
    return
  end
end

-- Generic farming function to be used for custom farms. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log.             --
-- Controls a turtle to patrol a region defined by length and width.  At each block in    --
-- the patrol, the turtle stops and executes the farmBlockCb callback function.           --
-- When the turtle reaches the end of the region, or its fuel is too low to continue, or  --
-- its inventory is full, it returns home and dumps its harvest into the inventory below  --
-- itself.  It uses an inventory just to the right of home to refuel.                     --
function farmGeneric(length, width, options, farmBlockCb)
  assert(length, "Must specify a size to harvest.")
  assert(type(farmBlockCb) == "function", "Must supply function to execute on each block.")
  -- Convert length to a number. --
  length = tonumber(length)
  -- Convert width to number, or assume square if not given. --
  width = tonumber(width) or length
  -- Pull out any options. --
  options = options or {}
  minfuel = options.minfuel or 2
  keepslots = options.keepslots
  waittime = options.waittime or 60
  -- If the turtle can't move a single block, try to eat the first item. --
  turtle.select(1)
  if turtle.getFuelLevel() < 1 then
    if not turtle.refuel(1) then error("Need at least 1 fuel level.  Refuel before starting.") end
  end
  turtle_emptyInventoryDown(keepslots)
  -- Main loop. --
  local blockBelow, blockData
  while true do
    if _pos.y > 0 then
      turtle.suckDown()
      farmBlockCb()
    end
    _harvestForward(length, width, minfuel, keepslots, waittime)
  end
end

-- Manage an existing birch tree farm of a specified size. --
-- Controls a turtle to manage a birch tree farm using two inventories.                   --
-- The first must contain birch saplings in the first slot at start.  After the turtle    --
-- has picked up the saplings, this inventory will be used for dumping the wood and       --
-- excess saplings.                                                                       --
-- The second inventory, which must be right of but not connected to the first, will be   --
-- used for fuel.  Using a barrel or other one-item-only inventory is recommended.        --
function harvestBirch(length, width, options)
  options = options or {}
  options.minfuel = options.minfuel or 18
  options.keepslots = options.keepslots or {1}
  _treeHarvestPrep()
  farmGeneric(length, width, options, turtle_harvestBirch)
end

local _ripe, _seed = {}, {}
-- Vanilla Minecraft crops --
_ripe["minecraft:wheat"] = 7
_ripe["minecraft:potatoes"] = 7
_ripe["minecraft:carrots"] = 7
_ripe["minecraft:pumpkin"] = true
_ripe["minecraft:melon_block"] = true
_seed["minecraft:wheat"] = "minecraft:wheat_seeds"
_seed["minecraft:potatoes"] = "minecraft:potato"
_seed["minecraft:carrots"] = "minecraft:carrot"
-- Magical crops --
_ripe["magicalcrops:AirCrop"] = 7
_ripe["magicalcrops:CoalCrop"] = 7
_ripe["magicalcrops:DyeCrop"] = 7
_ripe["magicalcrops:EarthCrop"] = 7
_ripe["magicalcrops:FireCrop"] = 7
_ripe["magicalcrops:MinicioCrop"] = 7
_ripe["magicalcrops:NatureCrop"] = 7
_ripe["magicalcrops:WaterCrop"] = 7
_ripe["magicalcrops:RedstoneCrop"] = 7
_ripe["magicalcrops:GlowstoneCrop"] = 7
_ripe["magicalcrops:ObsidianCrop"] = 7
_ripe["magicalcrops:NetherCrop"] = 7
_ripe["magicalcrops:IronCrop"] = 7
_ripe["magicalcrops:GoldCrop"] = 7
_ripe["magicalcrops:LapisCrop"] = 7
_ripe["magicalcrops:ExperienceCrop"] = 7
_ripe["magicalcrops:QuartzCrop"] = 7
_ripe["magicalcrops:DiamondCrop"] = 7
_ripe["magicalcrops:EmeraldCrop"] = 7
_ripe["magicalcrops:BlazeCrop"] = 7
_ripe["magicalcrops:CreeperCrop"] = 7
_ripe["magicalcrops:EndermanCrop"] = 7
_ripe["magicalcrops:GhastCrop"] = 7
_ripe["magicalcrops:SkeletonCrop"] = 7
_ripe["magicalcrops:SlimeCrop"] = 7
_ripe["magicalcrops:SpiderCrop"] = 7
_ripe["magicalcrops:WitherCrop"] = 7
_ripe["magicalcrops:ChickenCrop"] = 7
_ripe["magicalcrops:CowCrop"] = 7
_ripe["magicalcrops:PigCrop"] = 7
_ripe["magicalcrops:SheepCrop"] = 7
_ripe["magicalcrops:AluminiumCrop"] = 7
_ripe["magicalcrops:ArditeCrop"] = 7
_ripe["magicalcrops:CobaltCrop"] = 7
_ripe["magicalcrops:CopperCrop"] = 7
_ripe["magicalcrops:CertusQuartzCrop"] = 7
_ripe["magicalcrops:LeadCrop"] = 7
_ripe["magicalcrops:NickelCrop"] = 7
_ripe["magicalcrops:PlatinumCrop"] = 7
_ripe["magicalcrops:SilverCrop"] = 7
_ripe["magicalcrops:TinCrop"] = 7
_ripe["magicalcrops:SulfurCrop"] = 7
_ripe["magicalcrops:YelloriteCrop"] = 7
_ripe["magicalcrops:BlizzCrop"] = 7
_ripe["magicalcrops:FluixCrop"] = 7
_ripe["magicalcrops:SaltpeterCrop"] = 7
_ripe["magicalcrops:AirshardCrop"] = 7
_ripe["magicalcrops:WatershardCrop"] = 7
_ripe["magicalcrops:FireshardCrop"] = 7
_ripe["magicalcrops:EarthshardCrop"] = 7
_ripe["magicalcrops:EntropyshardCrop"] = 7
_ripe["magicalcrops:OrdershardCrop"] = 7
_ripe["magicalcrops:AmberCrop"] = 7
_ripe["magicalcrops:QuicksilverCrop"] = 7
_seed["magicalcrops:AirCrop"] = "magicalcrops:AirSeeds"
_seed["magicalcrops:CoalCrop"] = "magicalcrops:CoalSeeds"
_seed["magicalcrops:DyeCrop"] = "magicalcrops:DyeSeeds"
_seed["magicalcrops:EarthCrop"] = "magicalcrops:EarthSeeds"
_seed["magicalcrops:FireCrop"] = "magicalcrops:FireSeeds"
_seed["magicalcrops:MinicioCrop"] = "magicalcrops:MinicioSeeds"
_seed["magicalcrops:NatureCrop"] = "magicalcrops:NatureSeeds"
_seed["magicalcrops:WaterCrop"] = "magicalcrops:WaterSeeds"
_seed["magicalcrops:RedstoneCrop"] = "magicalcrops:RedstoneSeeds"
_seed["magicalcrops:GlowstoneCrop"] = "magicalcrops:GlowstoneSeeds"
_seed["magicalcrops:ObsidianCrop"] = "magicalcrops:ObsidianSeeds"
_seed["magicalcrops:NetherCrop"] = "magicalcrops:NetherSeeds"
_seed["magicalcrops:IronCrop"] = "magicalcrops:IronSeeds"
_seed["magicalcrops:GoldCrop"] = "magicalcrops:GoldSeeds"
_seed["magicalcrops:LapisCrop"] = "magicalcrops:LapisSeeds"
_seed["magicalcrops:ExperienceCrop"] = "magicalcrops:ExperienceSeeds"
_seed["magicalcrops:QuartzCrop"] = "magicalcrops:QuartzSeeds"
_seed["magicalcrops:DiamondCrop"] = "magicalcrops:DiamondSeeds"
_seed["magicalcrops:EmeraldCrop"] = "magicalcrops:EmeraldSeeds"
_seed["magicalcrops:BlazeCrop"] = "magicalcrops:BlazeSeeds"
_seed["magicalcrops:CreeperCrop"] = "magicalcrops:CreeperSeeds"
_seed["magicalcrops:EndermanCrop"] = "magicalcrops:EndermanSeeds"
_seed["magicalcrops:GhastCrop"] = "magicalcrops:GhastSeeds"
_seed["magicalcrops:SkeletonCrop"] = "magicalcrops:SkeletonSeeds"
_seed["magicalcrops:SlimeCrop"] = "magicalcrops:SlimeSeeds"
_seed["magicalcrops:SpiderCrop"] = "magicalcrops:SpiderSeeds"
_seed["magicalcrops:WitherCrop"] = "magicalcrops:WitherSeeds"
_seed["magicalcrops:ChickenCrop"] = "magicalcrops:ChickenSeeds"
_seed["magicalcrops:CowCrop"] = "magicalcrops:CowSeeds"
_seed["magicalcrops:PigCrop"] = "magicalcrops:PigSeeds"
_seed["magicalcrops:SheepCrop"] = "magicalcrops:SheepSeeds"
_seed["magicalcrops:AluminiumCrop"] = "magicalcrops:AluminiumSeeds"
_seed["magicalcrops:ArditeCrop"] = "magicalcrops:ArditeSeeds"
_seed["magicalcrops:CobaltCrop"] = "magicalcrops:CobaltSeeds"
_seed["magicalcrops:CopperCrop"] = "magicalcrops:CopperSeeds"
_seed["magicalcrops:CertusQuartzCrop"] = "magicalcrops:CertusQuartzSeeds"
_seed["magicalcrops:LeadCrop"] = "magicalcrops:LeadSeeds"
_seed["magicalcrops:NickelCrop"] = "magicalcrops:NickelSeeds"
_seed["magicalcrops:PlatinumCrop"] = "magicalcrops:PlatinumSeeds"
_seed["magicalcrops:SilverCrop"] = "magicalcrops:SilverSeeds"
_seed["magicalcrops:TinCrop"] = "magicalcrops:TinSeeds"
_seed["magicalcrops:SulfurCrop"] = "magicalcrops:SulfurSeeds"
_seed["magicalcrops:YelloriteCrop"] = "magicalcrops:YelloriteSeeds"
_seed["magicalcrops:BlizzCrop"] = "magicalcrops:BlizzSeeds"
_seed["magicalcrops:FluixCrop"] = "magicalcrops:FluixSeeds"
_seed["magicalcrops:SaltpeterCrop"] = "magicalcrops:SaltpeterSeeds"
_seed["magicalcrops:AirshardCrop"] = "magicalcrops:AirshardSeeds"
_seed["magicalcrops:WatershardCrop"] = "magicalcrops:WatershardSeeds"
_seed["magicalcrops:FireshardCrop"] = "magicalcrops:FireshardSeeds"
_seed["magicalcrops:EarthshardCrop"] = "magicalcrops:EarthshardSeeds"
_seed["magicalcrops:EntropyshardCrop"] = "magicalcrops:EntropyshardSeeds"
_seed["magicalcrops:OrdershardCrop"] = "magicalcrops:OrdershardSeeds"
_seed["magicalcrops:AmberCrop"] = "magicalcrops:AmberSeeds"
_seed["magicalcrops:QuicksilverCrop"] = "magicalcrops:QuicksilverSeeds"

local function _replant(cropName)
  if _seed[cropName] then
    local slot = turtle_findItemSlot(_seed[cropName])
    if slot then
      turtle.select(slot)
      turtle.placeDown()
      turtle.select(1)
    end
  end
end

local function _farmPlant()
  local blockBelow, blockData = turtle.inspectDown()
  local slot = false
  if blockBelow then
    if _ripe[blockData.name] == true or blockData.metadata == _ripe[blockData.name] then
      turtle.digDown()
      _replant(blockData.name)
    end
  end
end

function farm(length, width, options)
  options = options or {}
  options.waittime = options.waittime or 1800
  farmGeneric(length, width, options, _farmPlant)
end
