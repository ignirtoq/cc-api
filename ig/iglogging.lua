-- Dependencies --
local ig = ig or require("ig.ig")
assert(ig, "iglogging API requires ig API")

-- Logging Levels --
local _DEBUG    = 10
local _INFO     = 20
local _WARNING  = 30
local _ERROR    = 40
local _CRITICAL = 50

local levelname = {
    [_DEBUG]="DEBUG",
    [_INFO]="INFO",
    [_WARNING]="WARNING",
    [_ERROR]="ERROR",
    [_CRITICAL]="CRITICAL"
}

local loggers = {}

local LogOutput = {
    level=_WARNING,
    format="[%s] [%s] [%s] %s"
}

function LogOutput:log(args)
    if self.level <= args.level then
        local time = textutils.formatTime(os.time(), false)
        local level = levelname[args.level]
        local msg = string.format(args.message, unpack(args.fmtargs))
        local outstr = string.format(
            self.format, time, level, args.logger.name, msg
        )
        print(outstr)
    end
end

local LogInput = {}

function LogInput:new(args)
    return ig.clone(self, {
        name=args.name
    })
end

function LogInput:log(level, msg, ...)
    LogOutput:log{level=level, logger=self, message=msg, fmtargs={...}}
end

function LogInput:debug(msg, ...)
    self:log(_DEBUG, msg, ...)
end

function LogInput:info(msg, ...)
    self:log(_INFO, msg, ...)
end

function LogInput:warning(msg, ...)
    self:log(_WARNING, msg, ...)
end

function LogInput:error(msg, ...)
    self:log(_ERROR, msg, ...)
end

function LogInput:critical(msg, ...)
    self:log(_CRITICAL, msg, ...)
end

----------------
-- Public API --
----------------
local function _getLogger(name)
    name = name or "root"
    if loggers[name] == nil then
        loggers[name] = LogInput:new{name=name}
    end
    return loggers[name]
end

local function _setLevel(level)
    LogOutput.level = level
end

local function _getLevel()
    return LogOutput.level
end


if ig.isCC() then
    DEBUG = _DEBUG
    INFO = _INFO
    WARNING = _WARNING
    ERROR = _ERROR
    CRITICAL = _CRITICAL
    getLogger = _getLogger
    setLevel = _setLevel
    getLevel = _getLevel
else
    return {
        DEBUG=_DEBUG,
        INFO=_INFO,
        WARNING=_WARNING,
        ERROR=_ERROR,
        CRITICAL=_CRITICAL,
        getLogger=_getLogger,
        setLevel=_setLevel,
        getLevel=_getLevel
    }
end
