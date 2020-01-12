-- Dependencies. --
local ig = ig or require("ig.ig")
assert(ig, "iginv API requires ig API")

-- Private helper functions. --
local function ring(size, start)
    local end_ = (start - 1) % size
    local value = end_
    return function()
        value = (value + 1) % size
        if value ~= end_ then
            return value
        end
    end
end

-- ItemType abstraction. --
local _ItemType = {}
local _ItemTypeMt = getmetatable(_ItemType) or {}
setmetatable(_ItemType, _ItemTypeMt)
_ItemType._types = {}


-- Create a new ItemType instance. --
-- There should only ever be one instance of each type of item, so this new()
-- method is different from most others where it takes in the item type's name.
function _ItemType:new(name)
    assert(name ~= nil, 'ItemType construction requires name string')
    itype = _ItemType._types[name]
    if itype == nil then
        itype = ig.clone(_ItemType, {
            name=name,
            max_stack_size=64
        })
        _ItemType._types[name] = itype
    end
    return itype
end

function _ItemType:clone(itype)
    if type(itype) == 'string' then
        return _ItemType:new(itype)
    end
    return _ItemType:new(itype.name)
end


-- ItemStack abstraction. --
local _ItemStack = {}
local _ItemStackMt = getmetatable(_ItemStack) or {}
setmetatable(_ItemStack, _ItemStackMt)


function _ItemStack:new()
    return ig.clone(_ItemStack, {
        type=_ItemType:new(''),
        size=1
    })
end

function _ItemStack:clone(i)
    local itype = type(i.type) == "string" and _ItemType:new(i.type) or i.type
    return ig.clone(_ItemStack, {
        type=itype,
        size=i.size
    })
end

function _ItemStack:copy()
    return _ItemStack:clone(self)
end

function _ItemStack:setType(name)
    self.type = _ItemType:new(name)
    return self
end


-- Inventory abstraction. --
local _Inventory = {}
local _InventoryMt = getmetatable(_Inventory) or {}
setmetatable(_Inventory, _InventoryMt)


function _Inventory:new()
    return ig.clone(_Inventory, {
        size=27,
        _itemLookup={}
    })
end

function _Inventory:clone(inv)
    return ig.clone(_Inventory, {
        size=inv.size,
        _itemLookup={}
    })
end

function _Inventory:_updateItemLookup(index, stack)
    -- If the slot already had something, update that item type first.
    if self[index] ~= nil then
        local oldType = self[index].type.name
        local oldTypeTable = self._itemLookup[oldType]
        oldTypeTable[index] = nil
    end

    -- If the new stack is not nil, update item lookup for new item.
    if stack ~= nil then
        local newType = stack.type.name
        local newTypeTable = self._itemLookup[newType]
        if newTypeTable == nil then
            self._itemLookup[newType] = {}
            newTypeTable = self._itemLookup[newType]
        end
        newTypeTable[index] = true
    end
end

function _Inventory:setSlot(index, stack)
    assert(type(index) == "number", "slot index must be a number")
    assert(index >= 0, "slot index must be non-negative")
    assert(index < self.size, "slot index must be smaller than inventory size")
    stack = stack == nil and stack or _ItemStack:clone(stack)
    -- Update lookup before saving to slot to update based on old slot stack.
    self:_updateItemLookup(index, stack)
    self[index] = stack
    return self
end

function _Inventory:getSlot(index)
    assert(type(index) == "number", "slot index must be a number")
    assert(index >= 0, "slot index must be non-negative")
    assert(index < self.size, "slot index must be smaller than inventory size")
    return self[index]
end

function _Inventory:getSlotsWithItemType(itype)
    itype = _ItemType:clone(itype)
    return ig.numericalSetToArray(
        self._itemLookup[itype.name] or {}
    )
end

function _Inventory:getFirstEmptySlot(hint)
    hint = hint or 0
    local slot
    for slot in ring(self.size, hint) do
        if self[slot] == nil then
            return slot
        end
    end
    return nil
end

function _Inventory:getEmptySlots()
    local slot
    local emptySlots = {}
    for slot = 0, self.size-1, 1 do
        if self[slot] == nil then
            table.insert(emptySlots, slot)
        end
    end
    return emptySlots
end


if ig.isCC() then
    ItemType = _ItemType
    ItemStack = _ItemStack
    Inventory = _Inventory
else
    return {
        ItemType=_ItemType,
        ItemStack=_ItemStack,
        Inventory=_Inventory
    }
end
