print("Loading ig API ...")
local apiLoaded = os.loadAPI("ig")
if not apiLoaded then
	print("Downloading API ...")
	shell.run("pastebin get g8QXZrXa ig")
	apiLoaded = os.loadAPI("ig")
	assert(apiLoaded,"Error loading API")
end
print("ig API loaded")
