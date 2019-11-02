args = {...}
if not ig then
  local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for Ignirtoq's API")
  local f = fs.open("/ig/ig","w")
  f.write(http.get("https://raw.githubusercontent.com/ignirtoq/cc-api/master/src/ig.lua").readAll())
  f.close()
  assert(os.loadAPI("/ig/ig"),"Error loading API")
  local version = args[1] or "master"
  ig.loadAPI{version=version}
end
