print("Loading ig API ...")
if not ig then
  print("Downloading API ...")
  shell.run("pastebin","get","g8QXZrXa","ig")
  assert(os.loadAPI("ig"),"Error loading API")
end
print("ig API loaded")
