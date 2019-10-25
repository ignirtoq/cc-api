-- Dependencies --
assert(ig, "igfarm API requires ig API")
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
        length=assert(tonumber(args.length), "length required"),
        width=tonumber(args.width) or tonumber(args.length),
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

-- Faces the next direction the turtle should travel along a route.           --
-- Returns true if the turtle is ready to move forward and false if it has    --
-- reached the end of the route.                                              --
function Harvest:faceForward()
    local length, width = self.length, self.width
    -- Check if we're at the end of the route. --
    local endy = (width % 2 == 1) and length or 1
    local _pos = igturtle.getPos()
    if _pos.x >= width-1 and _pos.y == endy then
        return false
    end
    -- Determine the direction we should face to progress. --
    -- If we're at home or otherwise y < 1, go forward.    --
    if _pos.y < 1 then
        log:debug("at or behind minimum y value, turning to face forward")
        igturtle.turnToFace(igturtle.FORWARD)
    elseif _pos.x % 2 == 0 then
        -- If we're at the end of a row, face right. --
        if _pos.y >= length then
            log:debug("at end of row, facing right")
            igturtle.turnToFace(igturtle.RIGHT)
        -- Otherwise, face forward. --
        else
            log:debug("in middle of even row, facing forward")
            igturtle.turnToFace(igturtle.FORWARD)
        end
    else
        -- If we're at the start of a row, face right. --
        if _pos.y <= 1 then
            log:debug("at start of row, facing right")
            igturtle.turnToFace(igturtle.RIGHT)
        -- Otherwise, face backward. --
        else
            log:debug("in middle of odd row, facing backward")
            igturtle.turnToFace(igturtle.BACKWARD)
        end
    end
    return true
end

function Harvest:forward()
    -- Check to make sure we have enough fuel to harvest a tree. --
    local _pos = igturtle.getPos()
    local necessaryFuel = math.abs(_pos.x) + math.abs(_pos.y) + 2 + self.minfuel
    if turtle.getFuelLevel() < necessaryFuel then
        log:info("not enough fuel to continue route, returning to fuel")
        self:refuel()
        return
    end
    -- Check that our inventory isn't full. --
    if turtle.getItemCount(16) > 0 then
        log:info("inventory full, returning to dump inventory")
        self:dump()
        return
    end
    -- Face the direction we should move. --
    -- If false, return to home and dump harvest. --
    if self:faceForward() then
        -- Move forward. --
        igturtle.forward()
    else
        log:info("reached end of patrol, returning home to dump inventory")
        self:dump()
        os.sleep(self.waittime)
    end
end

function Harvest:dump()
    igturtle.goHome()
    turtle.select(1)
    igturtle.emptyInventoryDown(self:findSaplingSlots())
end

function Harvest:refuel()
    self:dump()
    igturtle.refuel()
end

-- Harvests a straight tree. These include birch and pine but NOT oak. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Replants a sapling, if it has one.                                         --
function harvestStraightTree(args)
    args = args or {}
    local height = 0
    local log2sapling = args.saplings or _sapling
    local blockFound, blockData = turtle.inspectDown()
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
        -- Go back to z = 0. --
        log:debug("returning to patrol height")
        while igturtle.getPos().z > 0 do igturtle.down() end
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

-- Generic farming function to be used for custom farms. --
-- Assumes the turtle is sitting in the tree, one block above the lowest log. --
-- Controls a turtle to patrol a region defined by length and width.  At each --
-- block in the patrol, the turtle stops and executes the farmBlockCb         --
-- callback function.  When the turtle reaches the end of the region, or its  --
-- fuel is too low to continue, or its inventory is full, it returns home and --
-- dumps its harvest into the inventory below itself.  It uses an inventory   --
-- just to the right of home to refuel.                                       --
function farmGeneric(args)
    -- Check for required callback function. --
    cb = args.callback
    assert(type(cb) == "function", "farmGeneric() missing farm block callback")
    -- Optional parameters. --
    initFuelSlot = tonumber(args.initFuelSlot) or 1
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
    while true do
        if igturtle.getPos().y > 0 then
            turtle.suckDown()
            cb(args)
            -- Update any parameters modified by the callback. --
            th:updateParams(args)
        end
        log:debug("moving forward")
        th:forward()
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
function harvestTrees(args)
    args = args or {}
    args.callback = harvestStraightTree
    farmGeneric(args)
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

function farm(args)
    args = args or {}
    args.waittime = args.waittime or 1800
    args.callback = _farmPlant
    farmGeneric(args)
end
