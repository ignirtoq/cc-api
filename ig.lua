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

-- GitHub URLs. --
local _urlbase = "https://raw.githubusercontent.com/ignirtoq/cc-api/master/"
local _urls = {}
_urls["igrednet"] = _urlbase .. "igrednet.lua"
_urls["igpower"]  = _urlbase .. "igpower.lua"
_urls["igturtle"] = _urlbase .. "igturtle.lua"
_urls["igfarm"]   = _urlbase .. "igfarm.lua"

-- Local paths. --
local _pathbase = "/ig/"
local _paths = {}
_paths["igrednet"] = _pathbase .. "igrednet"
_paths["igpower"]  = _pathbase .. "igpower"
_paths["igturtle"] = _pathbase .. "igturtle"
_paths["igfarm"]   = _pathbase .. "igfarm"

local function _writeApiFile(url, path)
  assert(type(url)=="string", "First argument must be a valid URL")
  assert(type(path)=="string", "Second argument must be a valid file path")
  if fs.exists(path) then fs.delete(path) end
  local f = fs.open(path, "w")
  f.write(http.get(url).readAll())
  f.close()
end

local _requiresTurtle = {}
_requiresTurtle["igturtle"] = true
_requiresTurtle["igfarm"]   = true

-- Check that an API is loaded.  Download and load the API if it is not. --
function require(apiname)
  assert(_paths[apiname] and _urls[apiname], "Unknown API '"..apiname.."'")
  if _requiresTurtle[apiname] then
    assert(turtle, apiname .. " can only be loaded for turtles.")
  end
  -- Check if the API is loaded. --
  if not _G[apiname] then
    _writeApiFile(_urls[apiname], _paths[apiname])
    assert(os.loadAPI(_paths[apiname]), "Error loading "..apiname.." API.")
  end
end

-- Loads the other API components. --
function loadAPI()
  local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for API")
  -- Get igrednet. --
  require("igrednet")
  -- Get igpower. --
  require("igpower")
  -- Check if this is a turtle. --
  if turtle then
    -- Get igturtle. --
    require("igturtle")
    -- Get igfarm. --
    require("igfarm")
  end
end

loadAPI()
