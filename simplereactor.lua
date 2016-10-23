args = {...}
-- Check for API --
if not ig then
  local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for Ignirtoq's API")
  local ig = fs.open("/ig/ig","w")
  ig.write(http.get("https://raw.githubusercontent.com/ignirtoq/cc-api/master/ig.lua").readAll())
  ig.close()
  assert(os.loadAPI("/ig/ig"),"Error loading API")
end
ig.require("igpower")
-- Get options --
minenergy = 1500000 or args[1]
maxenergy = 6500000 or args[2]
options = {minenergy=minenergy, maxenergy=maxenergy}
-- Start reactor regulation --
igpower.simpleRegulateReactor(options)
