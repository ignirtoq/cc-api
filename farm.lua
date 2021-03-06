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
ig.require("igfarm")
-- Execute farm function. --
if args[1] then
  igfarm.farm{length=tonumber(args[1])}
else
  igfarm.farm{length=3}
end
