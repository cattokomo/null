local F <const> = require("warna").format

local Levels <const> = {
  trace = 1,
  debug = 2,
  info = 3,
  warn = 4,
  error = 5,
  fatal = 6,
}

local LevelColors <const> = {
  "blue", "cyan", "green", "yellow", "red", "magenta"
}

local log = {}

log.level = "trace"

for k, lvl in pairs(Levels) do
	log[k] = function(...)
	  if lvl < Levels[log.level] then
    	return
    end
	  local args = {...}
	  local color = LevelColors[lvl]
    print(
    F("%{dim magenta}null %{reset bold " .. color .. "}[" .. k:sub(1, 1):upper() .. "]%{reset} ") ..
    table.remove(args, 1), table.unpack(args))
  end
end

return log
