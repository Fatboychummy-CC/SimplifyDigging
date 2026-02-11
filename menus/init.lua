--- Combines all the menus into a single location for easier collection.

local menus = {}

menus.main = require "menus.main"
menus.shapes = {
  cuboid = require "menus.shapes.cuboid",
  staircase = require "menus.shapes.staircase",
  bridge = require "menus.shapes.bridge",
}

return menus