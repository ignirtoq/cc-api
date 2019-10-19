---------------------------------------------------
--         Ignirtoq's ComputerCraft API          --
--                                               --
-- This file defines a basic collection of       --
-- functions and objects useful to the other     --
-- components of the API and development in      --
-- general.                                      --
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

-- Convert an array of items to a set (table mapping items to true).          --
function arrayToSet(array)
    set = {}
    for _, i in ipairs(array) do
        set[i] = true
    end
    return set
end

-- Prints out the content of a table when Lua won't. --
function printTable(tab)
  assert(type(tab) == "table", "Argument must be a table.")
  for key, val in pairs(tab) do
    print(tostring(key)..": "..tostring(val))
  end
end

-- API versions --
local _ver = {last = "0"}
_ver["0"] = {last = "0"}
_ver["0"]["0"] = {last = "0"}
_ver["0"]["0"]["0"] = true

local function _verFromStr(s)
  assert(type(s) == "string", "Must be a string.")
  -- If the version is a word (i.e. branch name), return it. --
  if s:find("%a") then return s end
  -- Otherwise version must start with a number. --
  assert(s:find("%d")==1, "Invalid version string.")
  -- Extract the major, minor, patch version from string. --
  ver = {s:match("(%d*)%.?(%d*)%.?(%d*)")}
  assert(ver[1]:len() > 0, "Must supply major version.")
  if not _ver[ver[1]] then return "Invalid major version number." end
  -- Pattern will return empty minor version if only major given. --
  if ver[2]:len() < 1 then
    ver[2] = _ver[ver[1]].last
  end
  if not _ver[ver[2]] then return "Invalid minor version number." end
  -- Pattern will return empty patch version if only major or only major and  --
  -- minor given. --
  if ver[3]:len() < 1 then
    ver[3] = _ver[ver[2]].last
  end
  if not _ver[ver[3]] then return "Invalid patch version number." end
  return "v"..ver[1].."."..ver[2].."."..ver[3]
end

-- GitHub URLs. --
local _urlbase = "https://raw.githubusercontent.com/ignirtoq/cc-api/"
local _urls = {}
_urls["igrednet"] = "/igrednet.lua"
_urls["igpower"]  = "/igpower.lua"
_urls["igturtle"] = "/igturtle.lua"
_urls["igfarm"]   = "/igfarm.lua"

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
  local req = http.get(url)
  assert(req, "Invalid version.")
  local f = fs.open(path, "w")
  f.write(http.get(url).readAll())
  f.close()
end

local _requiresTurtle = {}
_requiresTurtle["igturtle"] = true
_requiresTurtle["igfarm"]   = true

-- Check that an API is loaded.  Download and load the API if it is not. --
function require(apiname,version)
  assert(_paths[apiname] and _urls[apiname], "Unknown API '"..apiname.."'")
  if _requiresTurtle[apiname] then
    assert(turtle, apiname .. " can only be loaded for turtles.")
  end
  -- Check if the API is loaded. --
  if not _G[apiname] then
    version = version or "master"
    -- Convert version string to tag/branch name. --
    version = _verFromStr(version)
    _writeApiFile(_urlbase..version.._urls[apiname], _paths[apiname])
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
  return true
end
