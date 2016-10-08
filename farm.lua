args = {...}
-- Check for API --
if not ig then
  shell.run("pastebin","get","g8QXZrXa","ig")
  assert(os.loadAPI("ig"),"Error loading API")
end
if args[1] then
  igfarm.farm(unpack(args))
else
  igfarm.farm(3)
end
