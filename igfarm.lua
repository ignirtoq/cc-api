-- Dependencies --
assert(ig, "igfarm API requires ig API")
ig.require("igturtle")

local _log, _sapling = {}, {}
_log["minecraft:log"] = true
_log["MineFactoryReloaded:rubberwood.log"] = true
_sapling["minecraft:log"] = "minecraft:sapling"
_sapling["MineFactoryReloaded:rubberwood.log"] =
  "MineFactoryReloaded:rubberwood.sapling"

-- Harvests a straight tree. These include birch and pine but NOT oak. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Replants a sapling, if it has one.                                         --
function harvestStraightTree()
  local blockFound, blockData = turtle.inspectDown()
  if blockFound and _log[blockData.name] then
    -- Remove the base trunk and replace the sapling. --
    turtle.digDown()
    local saplingSlot = igturtle.findItemSlot(_sapling[blockData.name])
    if saplingSlot then
      turtle.select(saplingSlot)
      turtle.placeDown()
    end
    -- Remove the rest of the tree. --
    blockFound, blockData = turtle.inspectUp()
    while blockFound and blockData.name == "minecraft:log" do
      igturtle.up()
      blockAbove, blockData = turtle.inspectUp()
    end
    -- Go back to z = 0. --
    while igturtle.getPos().z > 0 do igturtle.down() end
    return true
  else return false end
end

-- Harvests a birch tree, which always produces straight trees. --
-- Calls harvestStraightTree.  Provided for backward-compatibility.           --
function harvestBirchTree()
  harvestStraightTree()
end

local function _treeHarvestPrep()
  -- Iterate through the sapling table to find any sapling. --
  local sapKey, sapVal = next(_sapling)
  local saplingSlot = false
  while not saplingSlot and sapKey do
    saplingSlot = igturtle.findItemSlot(sapVal)
    sapKey, sapVal = next(_sapling, sapKey)
  end
  -- Put saplings in slot 1. --
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
    if not item1 or not _sapling[item1.name] then
      igturtle.emptyInventoryDown()
      error("Cannot farm without saplings.  Place saplings in first slot of inventory.")
    end
  end
  igturtle.emptyInventoryDown({1})
end

local function _dumpHarvest(keepslots)
  igturtle.goHome()
  turtle.select(1)
  igturtle.emptyInventoryDown(keepslots)
end

local function _harvestRefuel(keepslots)
  -- Dump inventory to make room for fuel. --
  _dumpHarvest(keepslots)
  -- Refuel. --
  igturtle.refuel()
end

-- Faces the next direction the turtle should travel along a route.           --
-- Returns true if the turtle is ready to move forward and false if it has    --
-- reached the end of the route.                                              --
local function _harvestFaceForward(length, width)
  -- Check if we're at the end of the route. --
  local endy = (width % 2 == 1) and length or 1
  local _pos = igturtle.getPos()
  if _pos.x >= width-1 and _pos.y == endy then
    return false
  end
  -- Determine the direction we should face to progress. --
  -- If we're at home or otherwise y < 1, go forward.    --
  if _pos.y < 1 then
    igturtle.faceOrientation(0)
  elseif _pos.x % 2 == 0 then
    -- If we're at the end of a row, face right. --
    if _pos.y >= length then
      igturtle.faceOrientation(1)
    -- Otherwise, face forward. --
    else
      igturtle.faceOrientation(0)
    end
  else
    -- If we're at the start of a row, face right. --
    if _pos.y <= 1 then
      igturtle.faceOrientation(1)
    -- Otherwise, face backward. --
    else
      igturtle.faceOrientation(2)
    end
  end
  return true
end

local function _harvestForward(length, width, minfuel, keepslots, waittime)
  minfuel = tonumber(minfuel) or 0
  keepslots = keepslots or {}
  waittime = tonumber(waittime) or 60
  -- Check to make sure we have enough fuel to harvest a tree. --
  local _pos = igturtle.getPos()
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
    igturtle.forward()
  else
    _dumpHarvest(keepslots)
    os.sleep(waittime)
    return
  end
end

-- Generic farming function to be used for custom farms. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Controls a turtle to patrol a region defined by length and width.  At each --
-- block in the patrol, the turtle stops and executes the farmBlockCb         --
-- callback function.  When the turtle reaches the end of the region, or its  --
-- fuel is too low to continue, or its inventory is full, it returns home and --
-- dumps its harvest into the inventory below itself.  It uses an inventory   --
-- just to the right of home to refuel.                                       --
function farmGeneric(length, width, options, farmBlockCb)
  assert(length, "Must specify a size to harvest.")
  assert(type(farmBlockCb) == "function",
         "Must supply function to execute on each block.")
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
  igturtle.emptyInventoryDown(keepslots)
  -- Main loop. --
  local blockBelow, blockData, _pos
  while true do
    _pos = igturtle.getPos()
    if _pos.y > 0 then
      turtle.suckDown()
      farmBlockCb()
    end
    _harvestForward(length, width, minfuel, keepslots, waittime)
  end
end

-- Manage an existing tree farm of a specified size. --
-- Controls a turtle to manage a tree farm using two inventories.             --
-- The first must contain birch saplings in the first slot at start.  After   --
-- the turtle has picked up the saplings, this inventory will be used for     --
-- dumping the wood and excess saplings.                                      --
-- The second inventory, which must be right of but not connected to the      --
-- first, will be used for fuel.  Using a barrel or other one-item-only       --
-- inventory is recommended.                                                  --
-- This function can only handle "straight" trees.  These include birch, pine --
-- and rubber trees (from MineFactory Reloaded), but NOT oak or jungle, as    --
-- these may grow into larger forms with complex shapes.                      --
function harvestTrees(length, width, options)
  options = options or {}
  options.minfuel = options.minfuel or 18
  options.keepslots = options.keepslots or {1}
  _treeHarvestPrep()
  farmGeneric(length, width, options, harvestStraightTree)
end

-- Manages a birch tree farm.  Uses harvestTrees(). --
-- Pass-through function for harvestTrees().  Provided for backward-          --
-- compatibility.                                                             --
function harvestBirch(length, width, options)
  harvestTrees(length, width, options)
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
    local slot = igturtle.findItemSlot(_seed[cropName])
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
