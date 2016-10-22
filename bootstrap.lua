if not ig then
  dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for Ignirtoq's API")
  ig = fs.open("/ig/ig","w")
  ig.write(http.get("https://raw.githubusercontent.com/ignirtoq/cc-api/master/ig.lua").readAll())
  ig.close()
  assert(os.loadAPI("/ig/ig"),"Error loading API")
end
