-- Dependencies --
assert(ig, "iginput API requires ig API")

-- Logging Levels --
DEBUG    = 10
INFO     = 20
WARNING  = 30
ERROR    = 40
CRITICAL = 50

local levelname = {
    [DEBUG]="DEBUG",
    [INFO]="INFO",
    [WARNING]="WARNING",
    [ERROR]="ERROR",
    [CRITICAL]="CRITICAL"
}

local loggers = {}

local LogOutput = {
    level=WARNING,
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
    self:log(DEBUG, msg, ...)
end

function LogInput:info(msg, ...)
    self:log(INFO, msg, ...)
end

function LogInput:warning(msg, ...)
    self:log(WARNING, msg, ...)
end

function LogInput:error(msg, ...)
    self:log(ERROR, msg, ...)
end

function LogInput:critical(msg, ...)
    self:log(CRITICAL, msg, ...)
end

----------------
-- Public API --
----------------
function getLogger(name)
    name = name or "root"
    if loggers[name] == nil then
        loggers[name] = LogInput:new{name=name}
    end
    return loggers[name]
end

function setLevel(level)
    LogOutput.level = level
end

function getLevel()
    return LogOutput.level
end
