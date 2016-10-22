args = {...}
-- Check for API --
if not ig then
  shell.run("pastebin","get","g8QXZrXa","ig")
  assert(os.loadAPI("ig"),"Error loading API")
end
-- Get options --
minenergy = 1500000 or args[1]
maxenergy = 6500000 or args[2]
options = {minenergy=minenergy, maxenergy=maxenergy}
-- Start reactor regulation --
igpower.simpleRegulateReactor(options)
