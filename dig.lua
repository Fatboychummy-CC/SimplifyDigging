--- SimplifyDig 2.0: ComputerCraft Digging Utility.
---
--- This program intends to provide an easy-to-use interface for digging
--- different shapes with a ComputerCraft turtle.
--- It supports digging cuboids, tunnels, staircases, and spheres.
---
--- See the README.md for more information and usage instructions.
---
--- Copyright 2026 Matthew Wilbern (Fatboychummy)
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the “Software”), to
--- deal in the Software without restriction, including without limitation the
--- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
--- sell copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
--- 
--- The above copyright notice and this permission notice shall be included in
--- all copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
--- IN THE SOFTWARE.

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

-- Set up logging.
local minilogger = require "minilogger"
local log = minilogger.new("main")

-- Argument parsing.
local argparse = require "simple_argparse"
local parser = argparse.new_parser(
  "Simplify Digging 2.0",
  "A utility to simplify digging operations with a turtle."
)
parser.add_argument(
  "shape",
  "The shape to dig. Valid options are: cuboid, tunnel, staircase, sphere.",
  true
)
parser.add_flag(
  "l",
  "left",
  "If set, the turtle will dig to the left instead of the right."
)
parser.add_flag(
  "r",
  "right",
  "If set, the turtle will dig to the right instead of the left."
)
parser.add_flag(
  "u",
  "up",
  "If set, the turtle will dig upwards instead of downwards."
)
parser.add_flag(
  "d",
  "down",
  "If set, the turtle will dig downwards instead of upwards."
)
parser.add_flag(
  "f",
  "fuel",
  "If set, allows the turtle to consume items like coal for fuel during digging."
)
parser.add_flag(
  "n",
  "no-inv",
  "Disables automatic inventory management, dumping every item in the inventory."
)
parser.add_option(
  "broadcast",
  "Specifies a path to a file that will handle broadcasting status updates from the turtle. Specify an empty string to disable.",
  ""
)
parser.add_option(
  "loglevel",
  "Sets the logging level for the program. Valid levels are: debug, info, warning, error.",
  "info"
)
parser.add_option(
  "file",
  "Specifies a path to an existing state file to resume from."
)
parser.add_option(
  "save",
  "Specifies a path to save the turtle's state to."
)


-- Get the shape before building the rest of the parser.
local initial_parsed = parser.parse({...})
local shape = initial_parsed.arguments.shape

if initial_parsed.options.loglevel then
  local level = initial_parsed.options.loglevel:upper()
  if level ~= "DEBUG" and level ~= "INFO" and level ~= "WARNING" and level ~= "ERROR" then
    log.error("Invalid log level specified: '%s'. Valid levels are: debug, info, warning, error.", level)
    return
  end
  ---@cast level "debug"|"info"|"warning"|"error"
  minilogger.set_log_level(
    minilogger.LOG_LEVELS[level]
  )
end

local map = {
  cuboid = "cuboid",
  cube = "cuboid",
  box = "cuboid",
  tunnel = "cuboid",

  staircase = "staircase",
  stair = "staircase",
  stairs = "staircase",

  sphere = "sphere",
}

if not shape then
  log.error("No shape specified. Valid options are: cuboid, tunnel, staircase, sphere.")
  return
end

local shape_type = map[shape]
if not shape_type then
  log.error("Invalid shape specified: '%s'. Valid options are: cuboid, tunnel, staircase, sphere.", shape)
  return
end

-- Add shape-specific arguments.
if shape_type == "cuboid" then
  parser.add_argument(
    "forward length",
    "The length to dig forward.",
    true
  )
  parser.add_argument(
    "width",
    "The width to dig.",
    true
  )
  parser.add_argument(
    "height",
    "The height to dig. If not specified, will dig until bedrock.",
    false
  )
elseif shape_type == "staircase" then
  parser.add_argument(
    "steps",
    "The number of steps to dig.",
    true
  )
  parser.add_argument(
    "passage height",
    "The height of the passage for each step. Default is 3.",
    false
  )
elseif shape_type == "sphere" then
  parser.add_argument(
    "radius",
    "The radius of the sphere to dig.",
    true
  )
end

-- Final parse.
local parsed = parser.parse({...})



--- Cuboid digging function
local function dig_cuboid()

end



--- Staircase digging function
local function dig_staircase()

end



--- Sphere digging function
local function dig_sphere()

end



-- Execute the appropriate digging function.
if shape_type == "cuboid" then
  dig_cuboid()
elseif shape_type == "staircase" then
  dig_staircase()
elseif shape_type == "sphere" then
  dig_sphere()
else
  log.error("Unsupported shape type: '%s'.", shape_type)
end