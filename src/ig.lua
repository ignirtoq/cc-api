---------------------------------------------------
--         Ignirtoq's ComputerCraft API          --
--                                               --
-- This file defines a basic collection of       --
-- functions and objects useful to the other     --
-- components of the API and development in      --
-- general.                                      --
---------------------------------------------------

-- Common basic functions. --

-- Determine if a table is empty.                                             --
local function _empty(obj)
    return next(obj) == nil
end

-- Executes a function once per second until its output is not false or nil.  --
local function _waitFor(myfun, args)
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
local function _arrayToSet(array)
    set = {}
    for _, i in ipairs(array) do
        set[i] = true
    end
    return set
end


-- Convert a table of key-value pairs to just an array of values.             --
local function _valuesToArray(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end
    return values
end


local function _tableToString(tab, indent)
    assert(type(tab) == "table", "Argument must be a table.")
    indent = indent or 2
    -- Convert indent number to space characters. --
    local sp, i = {}, nil
    for i = 1,indent,1 do
        sp[#sp+1] = " "
    end
    sp = table.concat(sp, "")
    -- Print the fields. --
    local arr = {}
    if indent == 2 then table.insert(arr, "{") end
    for key, val in pairs(tab) do
        if type(val) ~= "table" then
            table.insert(arr, sp..tostring(key)..": "..tostring(val))
        else
            table.insert(arr, sp..tostring(key)..": {")
            table.insert(arr, _tableToString(val, indent+2))
            table.insert(arr, sp.."}")
        end
    end
    if indent == 2 then table.insert(arr, "}") end
    return table.concat(arr, "\n")
end


-- Prints out the content of a table when Lua won't. --
local function _printTable(tab, indent)
    print(_tableToString(tab, indent))
end


-- Extend a table's array portion with another table's array portion.         --
local function _extendTable(orig, ...)
    local i
    local allnew = {...}

    -- Nested repeat-until work-around for lack of "continue" statement.
    -- See https://stackoverflow.com/a/13825260.
    for _, new in pairs(allnew) do repeat
        if type(new) ~= "table" then
            break  -- a.k.a. "continue"
        end
        for i = 1,#new,1 do
            table.insert(orig, new[i])
        end
    until true end

    return orig
end


-- Wrap a function with zero or more arguments to create a new function.      --
local function _partial(func, ...)
    local args = {...}
    return function(...)
        return func(unpack(_extendTable({}, args, {...})))
    end
end


-------------------------
-- Inheritance Helpers --
-------------------------
_mtSpecialKeys = {
    '__add',
    '__sub',
    '__mul',
    '__div',
    '__mod',
    '__unm',
    '__concat',
    '__eq',
    '__lt',
    '__le',
    '__call',
    '__tostring'
}


local function _copyMeta(existing_mt, new_mt)
    for _, key in pairs(_mtSpecialKeys) do
        new_mt[key] = existing_mt[key] or new_mt[key]
    end
    return new_mt
end


-- Set one table to use another table as an attribute lookup.                 --
local function _clone(existing, new)
    new = new or {}
    assert(type(existing) == "table", "clone arguments must be tables")
    assert(type(new) == "table", "clone arguments must be tables")
    local existing_mt = getmetatable(existing) or {}
    local new_mt = getmetatable(new) or {}
    new_mt.__index = existing
    return setmetatable(new, _copyMeta(existing_mt, new_mt))
end


--------------------------------
-- Module Loading Abstraction --
--------------------------------
-- The ig API is broken up into separate modules.  To help script/program
-- writers, the whole API is versioned, and this base API provides loading
-- functions that respect varying levels of version strictness a developer
-- may require.
--
-- Since ComputerCraft and standard Lua provide different base modules,
-- some normally base Lua functionality is abstracted out so that the API
-- can be loaded into a ComputerCraft computer/turtle as well as unit-tested
-- from a standard Lua installation.


-- CC/Lua abstractions --
local function _isCC()
    return type(os.loadAPI) ~= "nil"
end


local function _loadModule(name, path)
    if _isCC() then
        -- ComputerCraft load. --
        return os.loadAPI(path)
    else
        -- Standard Lua load. --
        _G[name] = require(path)
        -- Check that the module isn't empty. --
        return next(_G[name]) ~= nil
    end
end


-- API versions --
local _ver = {last = "0"}
_ver["0"] = {last = "1"}
_ver["0"]["1"] = {last = "0"}
_ver["0"]["1"]["0"] = true
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
    if not _ver[ver[1]] then
        assert("invalid major version number")
    end
    -- Pattern will return empty minor version if only major given. --
    if ver[2]:len() < 1 then
        ver[2] = _ver[ver[1]].last
    end
    if not _ver[ver[1]][ver[2]] then
        assert("invalid minor version number")
    end
    -- Pattern will return empty patch version if only major or only major    --
    -- and minor given. --
    if ver[3]:len() < 1 then
        ver[3] = _ver[ver[1]][ver[2]].last
    end
    if not _ver[ver[1]][ver[2]][ver[3]] then
        assert("invalid patch version number")
    end
    return "v"..ver[1].."."..ver[2].."."..ver[3]
end


-- First-party URLs --
local _urlbase = "https://raw.githubusercontent.com/ignirtoq/cc-api/"


local function _makeUrl(apiname, version)
    return _urlbase .. version .. "/src/" .. apiname .. ".lua"
end


-- Local paths. --
local _pathbase = {cc="/ig/", lua="./ig/"}


local function _makePath(apiname)
    local base = _isCC() and _pathbase.cc or _pathbase.lua
    return base .. apiname
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
local function _require(apiname, version)
    if _requiresTurtle[apiname] then
        assert(turtle, apiname .. " can only be loaded for turtles.")
    end
    -- Check if the API is loaded. --
    if not _G[apiname] then
        -- Convert version string to tag/branch name. --
        version = _verFromStr(version or "master")
        local path = _makePath(apiname)
        local err = "Error loading "..apiname.." API."
        _writeUrlToFile{url=_makeUrl(apiname, version), path=path}
        assert(_loadModule(apiname, path), err)
    end
end


local function _require3rdParty(apiname)
    assert(_3rdPartyAPIs[apiname], "invalid 3rd-party API name")
    if not _G[apiname] then
        local url, path = _3rdPartyAPIs[apiname], _makePath(apiname)
        _writeUrlToFile{url=url, path=path}
        assert(os.loadAPI(path), "Error loading "..apiname.." API.")
    end
end


-- Loads the other API components. --
local function _loadAPI(args)
    args = args or {}
    version = args.version or "master"
    local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
    assert(dirExists, "Error creating directory for API")
    if version ~= "master" then
        os.unloadAPI("ig")
        _require("ig", version)
    end
    _require("iglogging", version)
    _require("iginput", version)
    _require("igrednet", version)
    _require("igpower", version)
    _require("iggeo", version)
    -- Check if this is a turtle. --
    if turtle then
        _require("igturtle", version)
        _require("igfarm", version)
    end
    return true
end


----------------
-- Public API --
----------------
-- Support both standard Lua and ComputerCraft module loading. --
if _isCC() then
    empty = _empty
    waitFor = _waitFor
    arrayToSet = _arrayToSet
    valuesToArray = _valuesToArray
    tableToString = _tableToString
    printTable = _printTable
    extendTable = _extendTable
    clone = _clone
    require = _require
    require3rdParty = _require3rdParty
    loadAPI = _loadAPI
    isCC = _isCC
    partial = _partial
else
    return {
        empty=_empty,
        waitFor=_waitFor,
        arrayToSet=_arrayToSet,
        valuesToArray=_valuesToArray,
        tableToString=_tableToString,
        printTable=_printTable,
        extendTable=_extendTable,
        clone=_clone,
        require=_require,
        require3rdParty=_require3rdParty,
        loadAPI=_loadAPI,
        isCC=_isCC,
        partial=_partial
    }
end
