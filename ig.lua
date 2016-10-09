---------------------------------------------------
--         Ignirtoq's ComputerCraft API          --
--                                               --
-- This file defines a basic collection of       --
-- functions and objects useful to the other     --
-- components of the API and development in      --
-- general.  After defining these functions,     --
-- the other components of the API compatible    --
-- with this computer are downloaded and         --
-- installed automatically.                      --
---------------------------------------------------

-- Common basic functions. --

-- Executes a function once per second until its output is not false or nil.  --
function waitFor(myfun, args)
  assert(type(myfun) == "function", "Can only wait for functions.")
  if args then
    assert(type(args) == "table",
           "Second argument must be array of arguments to function.")
  end
  args = args or {}
  local retval = {myfun(unpack(args))}
  while not retval[1] do
    os.sleep(1)
    retval = {myfun(unpack(args))}
  end
  return unpack(retval)
end

-- Prints out the content of a table when Lua won't. --
function printTable(tab)
  assert(type(tab) == "table", "Argument must be a table.")
  for key, val in pairs(tab) do
    print(tostring(key)..": "..tostring(val))
  end
end

-- Load in other API components. --

-- Pastebin URL stubs. --
local igrednetpaste = "PFSW7p9w"
local igpowerpaste  = "cVPjDFpM"
local igturtlepaste = "1icJ9QFM"
local igfarmpaste   = "LZ3r5WAg"

-- Loads the other API components. --
function loadAPI()
  local apiLoaded = false
  -- Get igrednet. --
  if not igrednet then
    os.run({}, "/rom/programs/shell", "/rom/programs/http/pastebin",
           "get", igrednetpaste, "igrednet")
    apiLoaded = os.loadAPI("igrednet")
    assert(apiLoaded, "Error loading igrednet API.")
  end
  -- Get igpower. --
  if not igpower then
    os.run({}, "/rom/programs/shell", "/rom/programs/http/pastebin",
           "get", igpowerpaste, "igpower")
    apiLoaded = os.loadAPI("igpower")
    assert(apiLoaded, "Error loading igpower API.")
  end
  -- Check if this is a turtle. --
  if turtle then
    -- Get igturtle. --
    if not igturtle then
      os.run({}, "/rom/programs/shell", "/rom/programs/http/pastebin",
             "get", igturtlepaste, "igturtle")
      apiLoaded = os.loadAPI("igturtle")
      assert(apiLoaded, "Error loading igturtle API.")
    end
    -- Get igfarm. --
    if not igfarm then
      os.run({}, "/rom/programs/shell", "/rom/programs/http/pastebin",
             "get", igfarmpaste, "igfarm")
      apiLoaded = os.loadAPI("igfarm")
      assert(apiLoaded, "Error loading igfarm API.")
    end
  end
end

loadAPI()
