local plugin = {}

plugin["name"] = "Tank Engine"
plugin["version"] = "1.0.0"
plugin["author"] = "Divest"
plugin["load"] = true

-- check if local player exists before loading the script (user is on loading screen / not ingame)
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- For debugging, we'll allow loading for any class/spec
-- Remove or comment this line once you're ready to enforce tank specs only
-- plugin["load"] = true

return plugin
