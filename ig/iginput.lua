-- Dependencies --
local ig = ig or require("ig.ig")
assert(ig, "iginput API requires ig API")
local json = ig.require("json")

local function _splitStr(str, linelen)
    local numparts, i
    local parts = {}
    numparts = math.ceil(str:len()/linelen)
    for i = 1,numparts,1 do
        parts[#parts+1] = str:sub( (i-1)*linelen+1, i*linelen )
    end
    return parts
end

local function _writelines(lines, ystart)
    ystart = ystart - 1 or 0
    local written
    for i = 1,#lines,1 do
        term.setCursorPos(1, ystart+i)
        term.write(lines[i])
        written = i
    end
    return written
end


----------------
-- Public API --
----------------
function readJSON(filename)
    local f = fs.open(filename, "r")
    local data = json.decode(f.readAll())
    f.close()
    return data
end

TextScreen = {}

function TextScreen:makeScreen(s)
    setmetatable(s, self)
    self.__index = self
    return s
end

function TextScreen:new()
    return self:makeScreen({
        title={},
        body={},
        linelen=39
    })
end

function TextScreen:setTitle(newtitle)
    self.title = _splitStr(newtitle, self.linelen)
end

function TextScreen:setBody(newbody)
    self.body = _splitStr(newbody, self.linelen)
end

function TextScreen:clearBody()
    self.body = {}
end

function TextScreen:addLine(line)
    extendTable(self.body, _splitStr(line, self.linelen))
end

function TextScreen:render()
    local ystart, written = 1, 0
    term.clear()
    if #self.title then
        written = _writelines(self.title, ystart)
        ystart = ystart + written + 2
    end
    written = _writelines(self.body, ystart)
    ystart = ystart + written
    term.setCursorPos(1, ystart)
end
