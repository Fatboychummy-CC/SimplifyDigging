--- Cuboid shape options for SimplifyDig

local tamperer = require "tamperer"
local menu = tamperer.new {
  title = "Cuboid Shape Options",
  description = "Options for digging a cuboid shape."
}

menu:add_callback(
  "run",
  "Start",
  "Start digging the cuboid shape.",
  function()
    error("Cuboid callback was not overridden! This is a bug.")
  end
)

menu:add_exit("back", "Go back", "Exit this menu and return to the main menu.")

menu:add_boolean(
  "resume",
  "Resume",
  "Enable automatic resume when interrupted.",
  true
)

menu:add_number(
  "forward_length",
  "Forward Length",
  "The length to dig forward.",
  16,
  2
)

menu:add_number(
  "width",
  "Width",
  "The width to dig.",
  16,
  2
)

menu:add_number(
  "height",
  "Height",
  "The height to dig.",
  16,
  2
)

menu:add_boolean(
  "quarry",
  "Quarry Mode",
  "Enable quarry mode to dig downwards until bedrock (Ignoring 'height' parameter).",
  false
)

menu:add_list(
  "left_right",
  "Left/Right",
  "Select the direction the turtle will dig the cuboid shape.",
  {"Left", "Right"},
  2
)

menu:add_list(
  "up_down",
  "Up/Down",
  "Select whether the turtle will dig upwards or downwards.",
  {"Up", "Down"},
  2
)

menu:add_boolean(
  "fuel",
  "Consume Fuel",
  "Enables consuming fuel items (like coal) from the turtle's inventory, as it finds it underground.",
  true
)

menu:add_boolean(
  "inv_handling",
  "Inventory",
  "Enables automatic inventory management during digging. If disabled, will drop everything instead of returning to the surface when full.",
  true
)

local run_dir = fs.getDir(shell.getRunningProgram())
menu:add_file(
  "broadcast_file",
  "Broadcaster",
  "A file to handle broadcasting status updates during digging.",
  fs.combine(run_dir, "lib", "broadcast", "empty.lua")
)

menu:add_list(
  "log_level",
  "Log Level",
  "Sets the logging level for this operation.",
  {"debug", "info", "warning", "error"},
  2
)

return menu