args = {...}
-- Check for API --
local apiLoaded = os.loadAPI("ig")
if not apiLoaded then
  shell.run("pastebin get g8QXZrXa ig")
  apiLoaded = os.loadAPI("ig")
  assert(apiLoaded,"Error loading API")
end
if args[1] then
  ig.harvestBirch(tonumber(args[1]))
else
  ig.harvestBirch(3)
end
