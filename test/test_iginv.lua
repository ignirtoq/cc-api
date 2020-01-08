ig = require "ig.ig"
iginv = require "ig.iginv"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"
local utils = require "test.testutils"


local function test_ItemType_new()
    local firstType = iginv.ItemType:new("type")
    local firstTypeCopy = iginv.ItemType:new("type")
    local secondType = iginv.ItemType:new("other type")

    assert(firstType == firstTypeCopy,
           "expected two item type instances to be the same object")
    assert(firstType ~= secondType,
           "expected two different item types to be different objects")
end


local function test_ItemType_clone()
    local itype = iginv.ItemType:new("type")
    local clone = iginv.ItemType:clone(itype)

    assert(itype == clone, "expected clone to be same instance")
    assert(iginv.ItemType:clone("type") == itype,
           "expected clone of string to be same instance")
end


local function test_ItemStack_new()
    local stack = iginv.ItemStack:new()

    assert(stack.type.name == '', string.format(
        'expected "%s", got "%s"', '', stack.type.name
    ))
    assert(stack.size == 1, string.format(
        'expected %d, got %d', 1, stack.size
    ))
end


local function test_ItemStack_clone()
    local itype = 'test_ItemStack_clone'
    local isize = 3
    local clone = iginv.ItemStack:clone{type=itype, size=isize}

    assert(clone.type.name == itype, string.format(
        'expected "%s", got "%s"', 'test', clone.type.name
    ))
    assert(clone.size == isize, string.format(
        'expected %d, got %d', isize, clone.size
    ))

    clone = iginv.ItemStack:clone({
        type=iginv.ItemType:new(itype),
        size=isize
    })

    assert(clone.type == iginv.ItemType:new(itype), string.format(
        'expected "%s", got "%s"', itype, clone.type.name
    ))
    assert(clone.size == isize, string.format(
        'expected %d, got %d', isize, clone.size
    ))
end


local function test_ItemStack_copy()
    local itype = 'test_ItemStack_copy'
    local stack = iginv.ItemStack:clone{type=itype, size=3}
    local copy = stack:copy()

    assert(stack.type.name == copy.type.name, string.format(
        'expected "%s", got "%s"', stack.type.name, copy.type.name
    ))
    assert(stack.type == copy.type, 'expected type fields to be same object')
    assert(stack.size == copy.size, string.format(
        'expected %d, got %d', stack.size, copy.size
    ))

    assert(stack ~= copy, 'expected different objects, got same objects')
end


local function test_ItemStack_setType()
    local stack = iginv.ItemStack:new():setType('test')
    local itype = iginv.ItemType:new('test')

    assert(stack.type.name == 'test', string.format(
        'expected "%s", got "%s"', 'test', stack.type.name
    ))
    assert(stack.type == itype,
           'expected stack type to be same object as itype')
end


local function test_Inventory_new()
    local inv = iginv.Inventory:new()

    assert(inv.size == 27, string.format('expected %d, got %d', 27, inv.size))
    assert(#inv == 0, string.format('expected %d, got %d', 0, #inv))
end


local function test_Inventory_setSlot()
    local slot_index = 7
    local itype = iginv.ItemType:new 'test_Inventory_setSlot'
    local stack_size = 4
    local stack = {type=itype, size=stack_size}
    local inv = iginv.Inventory:new()

    assert(not pcall(inv.setSlot, inv, nil),
           'expected assertion error when called with nil index')

    inv:setSlot(slot_index, stack)
    assert(inv[slot_index].type == stack.type, string.format(
        'expected "%s", got "%s"', stack.type.name, inv[slot_index].type.name
    ))
    assert(inv[slot_index].size == stack_size, string.format(
        'expected %d, got %d', stack.size, inv[slot_index].size
    ))

    assert(not pcall(inv.setSlot, inv, -1),
           'expected assertion error when called with negative index')
    assert(not pcall(inv.setSlot, inv, 27),
           'expected assertion error when called with too large index')
end


local function test_Inventory_getSlot()
    local slot_index = 0
    local inv = iginv.Inventory:new()

    local slot = inv:getSlot(slot_index)
    assert(slot == nil, string.format('expected nil, got %s', tostring(slot)))

    local itype = 'test_Inventory_getSlot'
    local size = 1
    slot_index = 12
    inv[slot_index] = iginv.ItemStack:clone{type=itype, size=size}
    slot = inv:getSlot(slot_index)
    assert(inv[slot_index] == slot,
           'expected result and item to be same object')
    assert(slot.type.name == itype, string.format(
        'expected "%s", got "%s"', itype, slot.type.name
    ))
    assert(slot.size == size, string.format(
        'expected %d, got %d', size, slot.size
    ))

    assert(not pcall(inv.getSlot, inv, -1),
           'expected assertion error when called with negative index')
    assert(not pcall(inv.getSlot, inv, 27),
           'expected assertion error when called with too large index')
end


local function test_Inventory_getSlotsWithItemType()
    local itype = 'test_Inventory_getSlotsWithItemType'
    local isize = 3
    local testSlots = {3, 6, 9}
    local istack = iginv.ItemStack:clone{type=itype, size=isize}
    local inv = iginv.Inventory:new()

    local slots = inv:getSlotsWithItemType(itype)
    local expArr = {}
    utils.assertArraysEqual(expArr, slots)

    inv:setSlot(testSlots[1], istack)
    slots = inv:getSlotsWithItemType(itype)
    expArr = {testSlots[1]}
    utils.assertArraysEqual(expArr, slots)

    inv:setSlot(testSlots[2], istack)
    slots = inv:getSlotsWithItemType(itype)
    expArr = {testSlots[1], testSlots[2]}
    utils.assertArraysEqual(expArr, slots)

    inv:setSlot(testSlots[3], istack)
    slots = inv:getSlotsWithItemType(itype)
    expArr = testSlots
    utils.assertArraysEqual(expArr, slots)
end


local function test_Inventory_getFirstEmptySlot()
    local size = 3
    local itype = 'test_Inventory_getFirstEmptySlot'
    local inv = iginv.Inventory:clone{size=size}

    local slot = inv:getFirstEmptySlot()
    local expected = 0
    assert(type(slot) == 'number', string.format(
        'expected number, got %s', type(slot)
    ))
    assert(slot == expected, string.format(
        'expected %d, got %d', expected, slot
    ))

    slot = inv:getFirstEmptySlot(1)
    expected = 1
    assert(type(slot) == 'number', string.format(
        'expected number, got %s', type(slot)
    ))
    assert(slot == expected, string.format(
        'expected %d, got %d', expected, slot
    ))

    inv:setSlot(0, {type=itype, size=1})
    slot = inv:getFirstEmptySlot()
    expected = 1
    assert(type(slot) == 'number', string.format(
        'expected number, got %s', type(slot)
    ))
    assert(slot == expected, string.format(
        'expected %d, got %d', expected, slot
    ))
end


local function test_Inventory_getEmptySlots()
    local invsize = 3
    local itype = 'test_Inventory_getEmptySlots'
    local stacksize = 10
    local inv = iginv.Inventory:clone{size=invsize}

    local emptySlots = inv:getEmptySlots()
    local expArray = {0, 1, 2}
    utils.assertArraysEqual(expArray, emptySlots)

    inv:setSlot(0, iginv.ItemStack:clone{type=itype, size=stacksize})
    emptySlots = inv:getEmptySlots()
    expArray = {1, 2}
    utils.assertArraysEqual(expArray, emptySlots)

    inv:setSlot(2, iginv.ItemStack:clone{type=itype, size=stacksize})
    emptySlots = inv:getEmptySlots()
    expArray = {1}
    utils.assertArraysEqual(expArray, emptySlots)
end


test_ItemType_new()
test_ItemType_clone()
test_ItemStack_new()
test_ItemStack_clone()
test_ItemStack_copy()
test_ItemStack_setType()
test_Inventory_new()
test_Inventory_setSlot()
test_Inventory_getSlot()
test_Inventory_getSlotsWithItemType()
test_Inventory_getFirstEmptySlot()
test_Inventory_getEmptySlots()
