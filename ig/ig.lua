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
local function empty(obj)
    return next(obj) == nil
end

-- Executes a function once per second until its output is not false or nil.  --
local function waitFor(myfun, args)
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


local function reverseArray(arr)
    assert(type(arr) == 'table', 'argument must be a table')
    local reversed = {}
    local i
    for i = #arr, 1, -1 do
        reversed[#arr-i+1] = arr[i]
    end
    return reversed
end


-- Convert an array of items to a set (table mapping items to true).          --
local function arrayToSet(array)
    local set = {}
    for _, i in ipairs(array) do
        set[i] = true
    end
    return set
end


-- Convert a set of numbers to an array.                                      --
local function numericalSetToArray(set)
    local array = {}
    for k, _ in pairs(set) do
        table.insert(array, k)
    end
    table.sort(array)
    return array
end


-- Convert a table of key-value pairs to just an array of values.             --
local function valuesToArray(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end
    return values
end


local function tableToString(tab, indent)
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
            table.insert(arr, tableToString(val, indent+2))
            table.insert(arr, sp.."}")
        end
    end
    if indent == 2 then table.insert(arr, "}") end
    return table.concat(arr, "\n")
end


-- Prints out the content of a table when Lua won't. --
local function printTable(tab, indent)
    print(tableToString(tab, indent))
end


-- Extend a table's array portion with another table's array portion.         --
local function extendTable(orig, ...)
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
local function partial(func, ...)
    local args = {...}
    return function(...)
        return func(unpack(extendTable({}, args, {...})))
    end
end


-- Ensure an iterator is a self-contained, stateful iterator.                 --
local function iter(...)
    local iterFields = {...}
    -- Case: iterator (stateful or stateless) passed inside table
    if type(iterFields[1]) == 'table' then
        iterFields = iterFields[1]
    end
    -- Case: stateful iterator
    if #iterFields == 1 then
        return iterFields[1]
    end
    -- Case: stateless iterator not in table
    func, seq, control = unpack(iterFields)
    return function()
        local controlVal
        if control ~= nil then
            controlVal = control
            control = control + 1
        end
        return func(seq, controlVal)
    end
end


-- Combine multiple iterators into a single iterator that yields a collection --
-- of one element from each of the constituent iterators.                     --
local function zip(...)
    local iterators = {...}
    -- No iterators case.
    if #iterators == 0 then
        return function() end
    end
    return function()
        local values = {}
        for _, func in ipairs(iterators) do
            local val = {func()}
            if #val == 0 then return end
            for _, v in ipairs(val) do
                values[#values+1] = v
            end
        end
        return unpack(values)
    end
end


-- Create a new iterator that provides a count alongside provided iterator.   --
local function enumerate(iterator, start)
    assert(type(iterator) == 'function', 'iterator must be a function')
    start = start ~= nil and start or 1
    local index = start - 1
    return function()
        local values = {iterator()}
        if #values == 0 then return end
        index = index + 1
        return unpack(extendTable({index}, values))
    end
end


function basename(path)
    return path:match('([^/]*)$')
end


function dirname(path)
    return path:match('(.*/)[^/]*$')
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


local function _getmetatable(obj)
    if type(obj) ~= 'table' then return {} end
    return getmetatable(obj) or {}
end


local function getmro(obj)
    return _getmetatable(obj).__mro or {obj}
end


local function _index(inst, key)
    local mro = _getmetatable(inst).__mro or {}
    local _, parent, value
    for _, parent in ipairs(mro) do
        value = rawget(parent, key)
        if value ~= nil then return value end
    end
    return value
end


local function _copyMeta(existing_mt, new_mt)
    for _, key in pairs(_mtSpecialKeys) do
        new_mt[key] = existing_mt[key] or new_mt[key]
    end
    return new_mt
end


-- Set one table to use another table as an attribute lookup.                 --
local function clone(existing, new)
    new = new or {}
    assert(type(existing) == "table", "clone arguments must be tables")
    assert(type(new) == "table", "clone arguments must be tables")
    local existing_mt = _getmetatable(existing)
    local new_mt = _getmetatable(new)
    new_mt.__index = _index
    new_mt.__mro = extendTable({}, {new}, getmro(existing))
    return setmetatable(new, _copyMeta(existing_mt, new_mt))
end


local function super(object)
    return getmro(object)[2]  -- 1 is the object, 2 is the immediate parent
end


-- Determine if an object is an instance of a parent class through clone().   --
local function instanceOf(object, candidateParent)
    if type(object) ~= 'table' or type(candidateParent) ~= 'table' then
        return false
    end
    local mro = arrayToSet(getmro(object))
    return mro[candidateParent]
end


local function _reverseArrays(...)
    local a
    local copies = {}
    for _, a in ipairs{...} do
        table.insert(copies, reverseArray(a))
    end
    return copies
end


local function _arraysNotEmpty(arrays)
    local a
    for _, a in ipairs(arrays) do
        if not empty(a) then return true end
    end
    return false
end


local function _checkHead(head, clsArrays, clsSets)
    local arr, i, set, valid
    if head == nil then
        return false
    end
    for i, set in ipairs(clsSets) do
        arr = clsArrays[i]
        -- If the class is in the MRO but not the head, it's invalid.
        if set[head] and arr[#arr] ~= head then
            return false
        end
    end
    return true
end


local function _getNextHead(clsArrays, clsSets)
    local arr, head, innerarr
    for _, arr in ipairs(clsArrays) do
        head = arr[#arr]
        if _checkHead(head, clsArrays, clsSets) then
            -- Pop off the end of all lists it appears.
            for _, innerarr in ipairs(clsArrays) do
                if innerarr[#innerarr] == head then
                    table.remove(innerarr, #innerarr)
                end
            end
            return head
        end
    end
end


local function mergeLinearizations(...)
    local arr, head
    local arrays = _reverseArrays(...)
    local sets, merged = {}, {}
    for _, arr in ipairs(arrays) do
        table.insert(sets, arrayToSet(arr))
    end
    while _arraysNotEmpty(arrays) do
        table.insert(merged, _getNextHead(arrays, sets))
    end
    return merged
end


local function inherit(...)
    local cls
    local parents = {...}
    local lparents = {}
    local i, parent
    for i, parent in ipairs(parents) do
        table.insert(lparents, getmro(parent))
    end
    local linearizations = extendTable({}, lparents, {parents})
    local newmro = mergeLinearizations(unpack(linearizations))
    cls = clone(newmro[1] or {})
    table.insert(newmro, 1, cls)
    getmetatable(cls).__mro = newmro
    return cls
end


local ContextManager = {}
setmetatable(ContextManager, getmetatable(ContextManager) or {})


function ContextManager:clone()
    return clone(self, {})
end


function ContextManager:enter()
end


function ContextManager:exit()
end


function ContextManager:with(...)
    -- Context body is the last argument, but Lua doesn't like arguments after
    -- the elipsis, so pull off the last argument manually.
    local enter_args = {...}
    local body = table.remove(enter_args, #enter_args)

    -- Call the enter method and capture the output as arguments to the body.
    local body_args = {self:enter(unpack(enter_args))}

    -- xpcall doesn't support arguments to the invoked function like pcall, so
    -- wrap the arguments with the body.
    body = partial(body, unpack(body_args))

    -- Call is a method, but xpcall doesn't call it as one, so wrap it.
    local exit = partial(self.exit, self)

    -- Call exit with the error if one is raised, otherwise call with nothing.
    local success = xpcall(body, exit)
    if success then
        self:exit()
    end
end


getmetatable(ContextManager).__call = ContextManager.with


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
local function isCC()
    return type(os.loadAPI) ~= "nil"
end


-- API versions --
local _ver = {
    ["0"]={
        ["1"]={last="0"},
        ["0"]={last="0"},
        last="1"
    },
    last="0"
}


local Version = {}
local VersionMt = getmetatable(Version) or {}
setmetatable(Version, VersionMt)


function Version:clone(v)
    assert(v.major ~= nil and v.minor ~= nil and v.patch ~= nil,
           'version must have major, minor, and patch fields')
    return clone(Version, {
        major=tonumber(v.major),
        minor=tonumber(v.minor),
        patch=tonumber(v.patch)
    })
end


function Version:fromStr(s)
    assert(type(s) == "string", "Must be a string.")

    -- Version must start with a number. --
    assert(s:find("%d")==1, "Invalid version string.")

    -- Extract the major, minor, patch version from string. --
    local ver = {s:match("(%d*)%.?(%d*)%.?(%d*)")}
    if ver[1]:len() < 1 then
        ver[1] = _ver.last
    end
    -- Pattern will return empty minor version if only major given. --
    if ver[2]:len() < 1 then
        if not _ver[ver[1]] then
            assert("invalid major version number")
        end
        ver[2] = _ver[ver[1]].last
    end
    -- Pattern will return empty patch version if only major or only major    --
    -- and minor given. --
    if ver[3]:len() < 1 then
        if not _ver[ver[1]][ver[2]] then
            assert("invalid minor version number")
        end
        ver[3] = _ver[ver[1]][ver[2]].last
    end
    return Version:clone{
        major=tonumber(ver[1]),
        minor=tonumber(ver[2]),
        patch=tonumber(ver[3])
    }
end


function Version:toStr()
    return string.format("%d.%d.%d", self.major, self.minor, self.patch)
end


function Version:isLessThan(other)
    return (self.major < other.major or
            self.minor < other.minor or
            self.patch < other.patch)
end


function Version:equals(other)
    return (self.major == other.major and
            self.minor == other.minor and
            self.patch == other.patch)
end


function Version:isLessThanOrEqualTo(other)
    return self:isLessThan(other) or self:equals(other)
end


VersionMt.__eq = Version.equals
VersionMt.__lt = Version.isLessThan
VersionMt.__le = Version.isLessThanOrEqualTo
VersionMt.__tostring = Version.toStr


local function _verFromStr(s)
    assert(type(s) == "string", "Must be a string.")

    -- If the version is a word (i.e. branch name), return it. --
    if s:find("%a") then return s end

    return 'v' .. Version:fromStr(s)
end


-- Third-party APIs --
local _3rdPartyAPIs = {
    argparse="https://raw.githubusercontent.com/mpeterv/argparse/master/src/argparse.lua",
    json="https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"
}


local function _modToPath(modname)
    return modname:gsub("%.", "/")
end


-- First-party URLs --
local _urlbase = "https://raw.githubusercontent.com/ignirtoq/cc-api"


local function _makeUrl(apiname, version)
    local thirdparty = _3rdPartyAPIs[apiname]
    if thirdparty then return thirdparty end
    return string.format(
        "%s/%s/%s%s", _urlbase, tostring(version), _modToPath(apiname), ".lua"
    )
end


-- Local paths. --
local _pathbase = "/modules"


local function _makePath(apiname)
    return string.format("%s/%s.lua", _pathbase, _modToPath(apiname))
end


local function _writeUrlToFile(args)
    local req = assert(http.get(args.url), "invalid url")
    fs.makeDir(dirname(args.path))
    if fs.exists(args.path) then fs.delete(args.path) end
    local f = fs.open(args.path, "w")
    f.write(req.readAll())
    f.close()
end


local _requiresTurtle = {
    ['ig.igturtle']=true,
    ['ig.igfarm']=true
}


local function _patchPath()
    if package.path:find('/modules') == nil then
        package.path = package.path ..
                       ';/modules/?;/modules/?.lua;/modules/?/init.lua'
    end
end


-- Check that a module exists.  Download and load the module if it does not. --
local function _require(apiname, version)
    if _requiresTurtle[apiname] then
        assert(turtle, apiname .. " can only be loaded for turtles.")
    end
    _patchPath()
    -- Check if the module exists. --
    local prequire = {pcall(require, apiname)}
    -- Return the module if loading succeeded. --
    if prequire[1] then return prequire[2] end
    -- Download and load the module. --
    -- Convert version string to tag/branch name. --
    version = _verFromStr(version or "master")
    local path = _makePath(apiname)
    _writeUrlToFile{url=_makeUrl(apiname, version), path=path}
    prequire = {pcall(require, apiname)}
    assert(prequire[1], "Error loading "..apiname..".")
    return prequire[2]
end


-- Loads the other API components. --
local function loadAPI(args)
    local ig = require("ig.ig")
    args = args or {}
    version = args.version or "master"
    if version ~= "master" then
        ig = _require("ig.ig", version)
    end
    ig.require("ig.iglogging", version)
    ig.require("ig.iginput", version)
    ig.require("ig.igrednet", version)
    ig.require("ig.igpower", version)
    ig.require("ig.iggeo", version)
    -- Check if this is a turtle. --
    if turtle then
        ig.require("ig.igturtle", version)
        ig.require("ig.igfarm", version)
    end
    return true
end


----------------
-- Public API --
----------------
return {
    empty=empty,
    waitFor=waitFor,
    reverseArray=reverseArray,
    arrayToSet=arrayToSet,
    numericalSetToArray=numericalSetToArray,
    valuesToArray=valuesToArray,
    tableToString=tableToString,
    printTable=printTable,
    extendTable=extendTable,
    partial=partial,
    iter=iter,
    zip=zip,
    enumerate=enumerate,
    basename=basename,
    dirname=dirname,
    clone=clone,
    super=super,
    instanceOf=instanceOf,
    getmro=getmro,
    mergeLinearizations=mergeLinearizations,
    inherit=inherit,
    ContextManager=ContextManager,
    isCC=isCC,
    Version=Version,
    require=_require,
    loadAPI=loadAPI,
}
