--- Main menu for SimplifyDig

local tamperer = require "tamperer"
local cuboid_menu = require "menus.shapes.cuboid"
local staircase_menu = require "menus.shapes.staircase"
local bridge_menu = require "menus.shapes.bridge"

local menu = tamperer.new {
  title = "SimplifyDig",
  description = "The simplest digging program!",
}

-- Select dig type.

menu:add_submenu(
  "dig_type_cuboid",
  "Cuboid",
  "Select this to dig a cuboid shape (or quarry).",
  cuboid_menu
)

--[[menu:add_submenu(
  "dig_type_staircase",
  "Staircase",
  "Select this to dig a staircase shape.",
  staircase_menu
)

menu:add_submenu(
  "dig_type_bridge",
  "Bridge",
  "Select this to dig a bridge shape.",
  bridge_menu
)

menu:add_file(
  "load",
  "Load",
  "Load a dig configuration from a file.",
  ""
)]]

menu:add_callback(
  "refuel",
  "Refuel",
  "Refuel the turtle with items in its inventory.",
  function()
    for i = 1, 16 do
      if turtle.getItemCount(i) > 0 then
        turtle.select(i)
        turtle.refuel(64)
      end
    end

    local fuel = turtle.getFuelLevel()
    if fuel == "unlimited" then
      print("Unlimited.")
    else
      print(("Fuel: %d"):format(fuel))
    end
    sleep(2)
  end
)

menu:add_exit(
  "exit",
  "Exit",
  "Exit SimplifyDig."
)

return menu