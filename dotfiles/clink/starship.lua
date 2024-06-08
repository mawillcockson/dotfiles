--[[
This is a startup file that clink loads when CMD starts.
In order for clink to check this folder, clink must be installed with a command similar to:

clink autorun install -- --profile ($env.ONEDRIVE | path join 'Documents' 'configs' 'clink')

https://chrisant996.github.io/clink/clink.html#filelocations
--]]
-- set `lua.debug = True` in `clink_settings` file
local lua_debug = settings.get("lua.debug")

local starship_dir = (
	os.getenv("HOME")
	..
	"\\OneDrive\\Documents\\configs\\starship"
)
local starship_installed = io.popen("starship --version", "r"):close()

local function starship_init ()
	os.setenv("STARSHIP_CONFIG", starship_dir .. "\\starship.toml")
	os.setenv("STARSHIP_CACHE", starship_dir)
	-- os.setenv("STARSHIP_LOG", "trace")
	local starship_init_cmd = io.popen("starship init cmd")
	local starship_init_cmd_func, loading_err = load(starship_init_cmd:read("*a"))
	starship_init_cmd:close()
	if starship_init_cmd_func then starship_init_cmd_func() end
	return loading_err
end

if os.getenv("COMPUTERNAME") ~= "P28F" and starship_installed then
	starship_loading_err = starship_init()
end

if lua_debug then
	print("starship_dir: " .. starship_dir .. (
		os.isdir(starship_dir) and " [exists]" or " [does not exist]"
	))
	print("COMPUTERNAME: " .. os.getenv("COMPUTERNAME"))
	print("starship: " .. (
		starship_loading_err and "[failed]" or "[loaded]"
	))
	if starship_loading_err then 
		print("error loading starship: " .. tostring(starship_loading_err))
		pause()
	end
end
