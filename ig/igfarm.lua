-- Dependencies --
assert(ig, "igfarm API requires ig API")
ig.require("iggeo")
ig.require("igturtle")
ig.require("iglogging")


local log = iglogging.getLogger("igfarm")
local _sapling = {
    ["minecraft:oak_log"]="minecraft:oak_sapling",
    ["minecraft:birch_log"]="minecraft:birch_sapling",
    ["minecraft:spruce_log"]="minecraft:spruce_sapling",
    ["minecraft:jungle_log"]="minecraft:jungle_sapling"
}

-- Harvest state and functionality class.                                     --
local Harvest = {}


function Harvest:new(args)
    return ig.clone(Harvest, {
        minfuel=tonumber(args.minfuel) or 0,
        waittime=tonumber(args.waittime) or 60,
        saplings=ig.valuesToArray(args.saplings or _sapling)
    })
end


function Harvest:updateParams(args)
    self.minfuel = tonumber(args.minfuel) or self.minfuel
    self.waittime = tonumber(args.waittime) or self.waittime
end


-- Create an array of slots containing known saplings.                        --
function Harvest:findSaplingSlots()
    local keepslots, slot = {}, false
    for _, sapling in pairs(self.saplings) do
        slot = igturtle.findItemSlot(sapling)
        if slot then
            keepslots[#keepslots+1] = slot
            log:debug("found sapling %s in slot %d", sapling, slot)
        end
    end
    return keepslots
end


function Harvest:dump()
    igturtle.goHome()
    turtle.select(1)
    igturtle.emptyInventoryDown(self:findSaplingSlots())
end


function Harvest:refuel()
    log:info("refueling")
    self:dump()
    igturtle.refuel()
end


function Harvest:needsRefuel()
    local minfuel = self.minfuel or 0
    local pos = igturtle.getPos()
    local fuelPos = igturtle.getRefuelPos()
    return turtle.getFuelLevel() <= pos:distanceTo(fuelPos) + minfuel
end


function Harvest:refuelIfNeeded()
    if self:needsRefuel() then self:refuel() end
end


-- Harvests a straight tree. These include birch and pine but NOT oak. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Replants a sapling, if it has one.                                         --
local function _harvestStraightTree(args)
    args = args or {}
    local height = 0
    local log2sapling = args.saplings or _sapling
    local blockFound, blockData = turtle.inspectDown()
    local startPos = igturtle.getPos()
    if blockFound and log2sapling[blockData.name] then
        log:debug("%s found below, harvesting", blockData.name)
        -- Remove the base trunk and replace the sapling. --
        turtle.digDown()
        local saplingSlot = igturtle.findItemSlot(log2sapling[blockData.name])
        if saplingSlot then
            log:debug("found sapling, planting down")
            turtle.select(saplingSlot)
            turtle.placeDown()
        else
            log:warning("no sapling found, cannot replant")
        end
        -- Remove the rest of the tree. --
        blockFound, blockData = turtle.inspectUp()
        while blockFound and log2sapling[blockData.name] do
            log:debug("log found above, moving up to harvest")
            igturtle.up()
            height = height + 1
            blockAbove, blockData = turtle.inspectUp()
        end
        -- Go back to starting point. --
        log:debug("returning to patrol height")
        igturtle.goTo(startPos)
        -- Update minfuel to accomodate tree if it's not already large enough --
        -- First, multiply the height by 2 for moving up and then down. --
        height = 2*height
        if (args.minfuel or 0) < height then
            log:debug("update minfuel to %d accomodate taller tree", height)
            args.minfuel = height
        end
        return true
    else return false end
end


-- Create the farm path from length/width arguments. --
local function _createPathFromSides(length, width)
    local length = length or 3
    local width = math.abs(width or length)
    local turtPos = igturtle.getPos()
    local turtOrient = igturtle.getOrient()

    local start = turtOrient:getForwardPos(turtPos)
    local opposite = turtOrient:getForwardPos(turtPos, width)
    if length >= 0 then
        opposite = turtOrient:getRightPos(opposite, length-1)
    else
        opposite = turtOrient:getLeftPos(opposite, -length-1)
    end
    return iggeo.Path:generateSpaceFilling(start, opposite)
end


local function _isCallable(object)
    if type(object) == "function" then return true end
    if type(object) == "table" then
        local meta = getmetatable(object)
        return type(meta) == "table" and _isCallable(meta.__call)
    end
    return false
end


-- Generic farming function to be used for custom farms. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Controls a turtle to patrol a region defined by length and width.  At each --
-- block in the patrol, the turtle stops and executes the farmBlockCb         --
-- callback function.  When the turtle reaches the end of the region, or its  --
-- fuel is too low to continue, or its inventory is full, it returns home and --
-- dumps its harvest into the inventory below itself.  It uses an inventory   --
-- just to the right of home to refuel.                                       --
local function _farmGeneric(args)
    args = args or {}
    -- Check for required callback function. --
    local cb = args.callback
    assert(_isCallable(cb), "farmGeneric() missing farm block callback")

    -- Optional parameters. --
    local initFuelSlot = tonumber(args.initFuelSlot) or 1

    -- Prep path. --
    local path = args.path or {}
    assert(type(path) == 'table', 'farming path must be an array')
    if #path == 0 then
        -- Create the path from length/width arguments. --
        path = _createPathFromSides(args.length, args.width)
    end
    local last = path[#path]

    -- If the turtle can't move a single block, try to eat the first item. --
    turtle.select(initFuelSlot)
    if turtle.getFuelLevel() < 1 then
        if not turtle.refuel(1) then
            error("Need at least 1 fuel level.  Refuel before starting.")
        end
    end

    -- Create the Harvest instance to manage state. --
    local th = Harvest:new(args)

    -- Main loop. --
    for pos in igturtle.followPath(path, {loop=true}) do
        turtle.suckDown()
        cb(args)
        -- Update any parameters modified by the callback. --
        th:updateParams(args)
        th:refuelIfNeeded()
        if pos == last then
            th:dump()
            if args.once then break end
            os.sleep(args.waittime)
        end
        log:debug("moving to next position")
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
local function _harvestTrees(args)
    args = args or {}
    args.waittime = args.waittime or 60
    args.callback = _harvestStraightTree
    _farmGeneric(args)
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
_ripe["magicalcrops:OsmiumCrop"] = 7
_ripe["magicalcrops:PlatinumCrop"] = 7
_ripe["magicalcrops:RubberCrop"] = 7
_ripe["magicalcrops:SilverCrop"] = 7
_ripe["magicalcrops:TinCrop"] = 7
_ripe["magicalcrops:SulfurCrop"] = 7
_ripe["magicalcrops:YelloriteCrop"] = 7
_ripe["magicalcrops:AlumiteCrop"] = 7
_ripe["magicalcrops:BlizzCrop"] = 7
_ripe["magicalcrops:BronzeCrop"] = 7
_ripe["magicalcrops:ElectrumCrop"] = 7
_ripe["magicalcrops:EnderiumCrop"] = 7
_ripe["magicalcrops:FluixCrop"] = 7
_ripe["magicalcrops:InvarCrop"] = 7
_ripe["magicalcrops:LumiumCrop"] = 7
_ripe["magicalcrops:ManasteelCrop"] = 7
_ripe["magicalcrops:ManyullynCrop"] = 7
_ripe["magicalcrops:SaltpeterCrop"] = 7
_ripe["magicalcrops:SignalumCrop"] = 7
_ripe["magicalcrops:SteelCrop"] = 7
_ripe["magicalcrops:TerrasteelCrop"] = 7
_ripe["magicalcrops:ElectricalSteelCrop"] = 7
_ripe["magicalcrops:EnergeticAlloyCrop"] = 7
_ripe["magicalcrops:VibrantAlloyCrop"] = 7
_ripe["magicalcrops:RedstoneAlloyCrop"] = 7
_ripe["magicalcrops:ConductiveIronCrop"] = 7
_ripe["magicalcrops:PulsatingIronCrop"] = 7
_ripe["magicalcrops:DarkSteelCrop"] = 7
_ripe["magicalcrops:SoulariumCrop"] = 7
_ripe["magicalcrops:DraconiumCrop"] = 7
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
_seed["magicalcrops:OsmiumCrop"] = "magicalcrops:OsmiumSeeds"
_seed["magicalcrops:PlatinumCrop"] = "magicalcrops:PlatinumSeeds"
_seed["magicalcrops:RubberCrop"] = "magicalcrops:RubberSeeds"
_seed["magicalcrops:SilverCrop"] = "magicalcrops:SilverSeeds"
_seed["magicalcrops:SulfurCrop"] = "magicalcrops:SulfurSeeds"
_seed["magicalcrops:TinCrop"] = "magicalcrops:TinSeeds"
_seed["magicalcrops:YelloriteCrop"] = "magicalcrops:YelloriteSeeds"
_seed["magicalcrops:BlizzCrop"] = "magicalcrops:BlizzSeeds"
_seed["magicalcrops:BronzeCrop"] = "magicalcrops:BronzeSeeds"
_seed["magicalcrops:ElectrumCrop"] = "magicalcrops:ElectrumSeeds"
_seed["magicalcrops:EnderiumCrop"] = "magicalcrops:EnderiumSeeds"
_seed["magicalcrops:FluixCrop"] = "magicalcrops:FluixSeeds"
_seed["magicalcrops:InvarCrop"] = "magicalcrops:InvarSeeds"
_seed["magicalcrops:LumiumCrop"] = "magicalcrops:LumiumSeeds"
_seed["magicalcrops:ManasteelCrop"] = "magicalcrops:ManasteelSeeds"
_seed["magicalcrops:ManyullynCrop"] = "magicalcrops:ManyullynSeeds"
_seed["magicalcrops:SaltpeterCrop"] = "magicalcrops:SaltpeterSeeds"
_seed["magicalcrops:SignalumCrop"] = "magicalcrops:SignalumSeeds"
_seed["magicalcrops:SteelCrop"] = "magicalcrops:SteelSeeds"
_seed["magicalcrops:TerrasteelCrop"] = "magicalcrops:TerrasteelSeeds"
_seed["magicalcrops:ElectricalSteelCrop"] = "magicalcrops:ElectricalSteelSeeds"
_seed["magicalcrops:EnergeticAlloyCrop"] = "magicalcrops:EnergeticAlloySeeds"
_seed["magicalcrops:VibrantAlloyCrop"] = "magicalcrops:VibrantAlloySeeds"
_seed["magicalcrops:RedstoneAlloyCrop"] = "magicalcrops:RedstoneAlloySeeds"
_seed["magicalcrops:ConductiveIronCrop"] = "magicalcrops:ConductiveIronSeeds"
_seed["magicalcrops:PulsatingIronCrop"] = "magicalcrops:PulsatingIronSeeds"
_seed["magicalcrops:DarkSteelCrop"] = "magicalcrops:DarkSteelSeeds"
_seed["magicalcrops:SoulariumCrop"] = "magicalcrops:SoulariumSeeds"
_seed["magicalcrops:DraconiumCrop"] = "magicalcrops:DraconiumSeeds"
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


local function _farm(args)
    args = args or {}
    args.waittime = args.waittime or 1800
    args.callback = _farmPlant
    _farmGeneric(args)
end


----------------
-- Public API --
----------------
if ig.isCC() then
    harvestStraightTree = _harvestStraightTree
    createPathFromSides = _createPathFromSides
    farmGeneric = _farmGeneric
    harvestTrees = _harvestTrees
    farmPlant = _farmPlant
    farm = _farm
else
    return {
        harvestStraightTree=_harvestStraightTree,
        createPathFromSides=_createPathFromSides,
        farmGeneric=_farmGeneric,
        harvestTrees=_harvestTrees,
        farmPlant=_farmPlant,
        farm=_farm
    }
end
