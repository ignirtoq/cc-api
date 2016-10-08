args = {...}
-- Check for API --
if not ig then
  shell.run("pastebin","get","g8QXZrXa","ig")
  assert(os.loadAPI("ig"),"Error loading API")
end
if args[1] then
  igfarm.harvestBirch(tonumber(args[1]))
else
  igfarm.harvestBirch(3)
end
