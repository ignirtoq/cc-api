-- Common basic function. --

-- Executes a function once per second until its output is not false or nil.  --
function waitFor(myfun, args)
  assert(type(myfun) == "function", "Can only wait for functions.")
  if args then
    assert(type(args) == "table",
           "Second argument must be array of arguments to function.")
  end
  args = args or {}
  while not myfun(unpack(args)) do
    os.sleep(1)
  end
end

-- Load in other API components. --

-- Pastebin URL stubs. --
local igrednetpaste = "TkAMePaX"
local igpowerpaste  = "cVPjDFpM"
local igturtlepaste = "1icJ9QFM"
local igfarmpaste   = "LZ3r5WAg"

-- Loads the other API components. --
function loadApi()
  local apiLoaded = false
  -- Get igrednet. --
  if not igrednet then
    shell.run("pastebin get " .. igrednetpaste .. " igrednet")
    apiLoaded = os.loadApi("igrednet")
    assert(apiLoaded, "Error loading igrednet API.")
  end
  -- Get igpower. --
  if not igpower then
    shell.run("pastebin get " .. igpowerpaste .. " igpower")
    apiLoaded = os.loadApi("igrednet")
    assert(apiLoaded, "Error loading igpower API.")
  end
  -- Check if this is a turtle. --
  if turtle then
    -- Get igturtle. --
    if not igturtle then
      shell.run("pastebin get " .. igturtlepaste .. " igturtle")
      apiLoaded = os.loadApi("igrednet")
      assert(apiLoaded, "Error loading igturtle API.")
    end
    -- Get igfarm. --
    if not igfarm then
      shell.run("pastebin get " .. igfarmpaste .. " igfarm")
      apiLoaded = os.loadApi("igrednet")
      assert(apiLoaded, "Error loading igfarm API.")
    end
  end
end

loadApi()
