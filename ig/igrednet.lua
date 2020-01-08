-- Dependencies. --
assert(ig, "igrednet API requires ig API")

-- Message enums --
msgTypes = {
  MESSAGE = 0,
  GENERATOR_STATUS = 1,
  COMMAND = 2
}
commands = {
  START_GENERATORS = 0,
  STOP_GENERATORS = 1
}
-- Message class --
Message = {}
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
