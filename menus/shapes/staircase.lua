--- Staircase shape options for SimplifyDig

local tamperer = require "tamperer"
local menu = tamperer.new {
  title = "Staircase Shape Options",
  description = "Options for digging a staircase shape."
}

menu:add_callback(
  "run",
  "Start",
  "Start digging the staircase shape.",
  function()
    error("Staircase callback was not overridden! This is a bug.")
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
  "Steps",
  "The number of steps to dig (the length forward).",
  16,
  2
)

menu:add_number(
  "height",
  "Height",
  "The height of the passage for each step. 5 is a comfortable height with stairs.",
  3,
  3
)

menu:add_list(
  "up_down",
  "Up/Down",
  "Select whether the turtle will dig upwards or downwards.",
  {"Up", "Down"},
  1
)

menu:add_boolean(
  "stairs",
  "Stairs",
  "Whether to place stairs in the staircase (requires stairs in inventory).",
  false
)

menu:add_boolean(
  "torches",
  "Torches",
  "Whether to place torches in the staircase for lighting (requires torches in inventory).",
  false
)

menu:add_number(
  "torch_interval",
  "Torch Intrvl",
  "The interval (in steps) at which to place torches if enabled.",
  10,
  1
)

return menu