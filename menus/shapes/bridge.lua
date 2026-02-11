--- Bridge options for SimplifyDig

local tamperer = require "tamperer"
local menu = tamperer.new {
  title = "Bridge Options",
  description = "Options for setting a bridge."
}

menu:add_callback(
  "run",
  "Start",
  "Start setting the bridge.",
  function()
    error("Bridge callback was not overridden! This is a bug.")
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
  "Length",
  "The length to set the bridge. If the turtle runs into a block before this length, it will stop setting the bridge.",
  16,
  2
)

menu:add_boolean(
  "safe_mode",
  "Safe Mode",
  "Enables safe mode by placing blocks on the sides of the bridge as well to prevent falling off. Requires more blocks in the inventory, and more time.",
  false
)

menu:add_boolean(
  "roof",
  "Roof",
  "Whether to place blocks 2 blocks above the bridge to create a roof.",
  false
)

menu:add_boolean(
  "torches",
  "Torches",
  "Whether to place torches on the bridge for lighting (requires torches in inventory).",
  false
)

menu:add_number(
  "torch_interval",
  "Torch Intrvl",
  "The interval (in blocks) at which to place torches if enabled.",
  10,
  1
)

return menu