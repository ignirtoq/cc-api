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

-- Convert a table of key-value pairs to just an array of values.             --
function valuesToArray(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        values[#values+1] = v
    end
    return values
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
_ver["0"] = {last = "1"}
_ver["0"]["0"] = {last = "0"}
_ver["0"]["0"]["0"] = true
_ver["0"]["1"] = {last = "0"}
_ver["0"]["1"]["0"] = true

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
  if not _ver[ver[1]][ver[2]] then return "Invalid minor version number." end
  -- Pattern will return empty patch version if only major or only major and  --
  -- minor given. --
  if ver[3]:len() < 1 then
    ver[3] = _ver[ver[1]][ver[2]].last
  end
  if not _ver[ver[1]][ver[2]][ver[3]] then
      return "Invalid patch version number."
  end
  return "v"..ver[1].."."..ver[2].."."..ver[3]
end

-- First-party URLs --
local _urlbase = "https://raw.githubusercontent.com/ignirtoq/cc-api/"

local function _makeUrl(apiname, version)
    return _urlbase .. version .. "/" .. apiname .. ".lua"
end

-- Local paths. --
local _pathbase = "/ig/"

local function _makePath(apiname)
    return _pathbase .. apiname
end

-- Third-party APIs --
local _3rdPartyAPIs = {
    argparse="https://raw.githubusercontent.com/mpeterv/argparse/master/src/argparse.lua",
    json="https://pastebin.com/raw/4nRg9CHU"
}

local function _writeUrlToFile(args)
  if fs.exists(args.path) then fs.delete(args.path) end
  local req = assert(http.get(args.url), "invalid url")
  local f = fs.open(args.path, "w")
  f.write(http.get(args.url).readAll())
  f.close()
end

local _requiresTurtle = {}
_requiresTurtle["igturtle"] = true
_requiresTurtle["igfarm"]   = true

-- Check that an API is loaded.  Download and load the API if it is not. --
function require(apiname, version)
  if _requiresTurtle[apiname] then
    assert(turtle, apiname .. " can only be loaded for turtles.")
  end
  -- Check if the API is loaded. --
  if not _G[apiname] then
    version = version or "master"
    -- Convert version string to tag/branch name. --
    version = _verFromStr(version)
    local path = _makePath(apiname)
    _writeUrlToFile{url=_makeUrl(apiname, version), path=path}
    assert(os.loadAPI(path), "Error loading "..apiname.." API.")
  end
end

function require3rdParty(apiname)
    assert(_3rdPartyAPIs[apiname], "invalid 3rd-party API name")
    if not _G[apiname] then
        local url, path = _3rdPartyAPIs[apiname], _makePath(apiname)
        _writeUrlToFile{url=url, path=path}
        assert(os.loadAPI(path), "Error loading "..apiname.." API.")
    end
end

-- Loads the other API components. --
function loadAPI(args)
  version = args.version or "master"
  local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for API")
  -- Get igrednet. --
  require("igrednet", version)
  -- Get igpower. --
  require("igpower", version)
  -- Check if this is a turtle. --
  if turtle then
    -- Get igturtle. --
    require("igturtle", version)
    -- Get igfarm. --
    require("igfarm", version)
  end
  return true
end
