--- SimplifyDig 2.0: ComputerCraft Digging Utility.
---
--- This program intends to provide an easy-to-use interface for digging
--- different shapes with a ComputerCraft turtle.
--- It supports digging cuboids, tunnels, staircases, and bridges.
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
local root = require "filesystem"
local pp = root:programPath()
local DTR = require "deterministic_turtle_recovery"


-- Argument parsing.
local argparse = require "simple_argparse"
local parser = argparse.new_parser(
  "Simplify Digging 2.0",
  "A utility to simplify digging operations with a turtle."
)
parser.add_option(
  "shape",
  "The shape to dig. Valid options are: cuboid, staircase, bridge.",
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
  "noinv",
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
local shape = initial_parsed.options.shape

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

local alias_map = {
  cuboid = "cuboid",
  cube = "cuboid",
  box = "cuboid",
  tunnel = "cuboid",

  staircase = "staircase",
  stair = "staircase",
  stairs = "staircase",

  bridge = "bridge",
}

local shape_type
if shape then
  shape_type = alias_map[shape]
  if not shape_type then
    log.error("Invalid shape specified: '%s'. Valid options are: cuboid, tunnel, staircase, bridge.", shape)
    return
  end
end

-- Add shape-specific arguments.
if shape_type == "cuboid" then
  parser.add_option(
    "forwardlength",
    "The length to dig forward.",
    16
  )
  parser.add_option(
    "width",
    "The width to dig.",
    16
  )
  parser.add_option(
    "height",
    "The height to dig. If not specified, will dig until bedrock.",
    16
  )
  parser.add_flag(
    "q",
    "quarry",
    "If set, the turtle will dig downwards until bedrock, ignoring the 'height' parameter."
  )

elseif shape_type == "staircase" then
  parser.add_option(
    "forwardlength",
    "The number of steps to dig.",
    16
  )
  parser.add_option(
    "height",
    "The height of the passage for each step. Default is 3.",
    3
  )
  parser.add_flag(
    "s",
    "stairs",
    "If set, the turtle will place stairs in the staircase (requires stairs in inventory)."
  )
  parser.add_flag(
    "t",
    "torches",
    "If set, the turtle will place torches in the staircase for lighting (requires torches in inventory)."
  )
  parser.add_option(
    "torchinterval",
    "The interval (in steps) at which to place torches if enabled.",
    10
  )
elseif shape_type == "bridge" then
  parser.add_option(
    "forwardlength",
    "The length to dig the bridge.",
    16
  )
  parser.add_flag(
    "s",
    "safe",
    "If set, the turtle will place blocks beside itself as well to create a safe walkway."
  )
  parser.add_flag(
    "r",
    "roof",
    "If set, the turtle will place blocks 2 blocks above itself to create a roof."
  )
  parser.add_flag(
    "t",
    "torches",
    "If set, the turtle will place torches on the bridge for lighting (requires torches in inventory)."
  )
  parser.add_option(
    "torchinterval",
    "The interval (in blocks) at which to place torches if enabled.",
    16
  )
end

-- Final parse.
local parsed = parser.parse({...})



--- Set up automatic rebooting (save a `.lua` file to `/startup/` that re-runs this program with the same arguments).
---@return DTR dtr The initialized DTR instance.
local function setup_reboot()
  if parsed.options.save then
    log.info("Setting up automatic reboot")

    local data_dir = pp:at("data")
    local startup_dir = root:at("startup")
    if not data_dir:exists() then
      data_dir:mkdir()
    end
    if not startup_dir:exists() then
      startup_dir:mkdir()
    end

    local reboot_file = startup_dir:file("9999_simplifydig_reboot.lua")
    local running_program = shell.getRunningProgram()
    local flags = ""
    for flag, value in pairs(parsed.flags) do
      if value then
        flags = flags .. ("--%s "):format(flag)
      end
    end
    local options = ""
    for option, value in pairs(parsed.options) do
      log.infof("Option %s=%s", option, tostring(value))
      if option == "save" then option = "load" end -- The reboot file should mark the file to load from.
      options = options .. ("--%s=%s "):format(option, tostring(value))
    end

    log.infof("Reboot file will have:\n  Command: %s\n  Flags: %s\n  Options: %s", running_program, flags, options)

    reboot_file:write(("shell.run('%s %s %s')"):format(running_program, flags, options))

    return DTR.new(parsed.options.save)
  end
  if parsed.options.load then
    log.infof("Loading state from file '%s' for recovery.", parsed.options.load)

    local dtr = DTR.new(parsed.options.load)
    dtr:load_state()
    return dtr
  end

  log.info("No recovery file specified. Creating temporary file but not automatically rebooting.")
  return DTR.new(tostring(pp:at("data"):file("temp_state.lua")))
end



--- Clean up the automatic reboot, deleting the auto save file if it exists.
local function cleanup_reboot()
  log.info("Cleaning up reboot files.")

  local startup_dir = root:at("startup")
  local reboot_file = startup_dir:file("9999_simplifydig_reboot.lua")
  if reboot_file:exists() then
    reboot_file:delete()
  end

  if parsed.options.save or parsed.options.load then
    local save_file = root:file(parsed.options.save or parsed.options.load)
    if save_file:exists() then
      save_file:delete()
    end
  else
    -- It's under the temp file.
    local temp_file = pp:at("data"):file("temp_state.lua")
    if temp_file:exists() then
      temp_file:delete()
    end
  end
end



--- Cuboid digging function
local function dig_cuboid()
  log.infof("Starting cuboid dig with parameters:\n  forwardlength=%d\n  width=%d\n  height=%s\n  quarry=%s\n  left_right=%s\n  up_down=%s\n  fuel=%s\n  noinv=%s\n  broadcast_file=%s\n  log_level=%s",
    parsed.options.forwardlength or -1,
    parsed.options.width or -1,
    parsed.options.height or "infinite",
    parsed.flags.quarry and "true" or "false",
    parsed.flags.left and "left" or "right",
    parsed.flags.up and "up" or "down",
    parsed.flags.fuel and "true" or "false",
    parsed.flags.noinv and "true" or "false",
    parsed.options.broadcast or "None",
    parsed.options.loglevel or "info"
  )
  local dtr = setup_reboot()

  if dtr:should_simulate() then
    dtr:start_simulating()
  end

  local function forward()
    repeat dtr:dig() until dtr:forward()
  end

  local function up()
    repeat dtr:dig_up() until dtr:up()
  end

  local function down()
    repeat dtr:dig_down() until dtr:down()
  end

  local function left()
    dtr:turn_left()
  end

  local function right()
    dtr:turn_right()
  end

  local function dig()
    dtr:dig()
  end

  local function dig_up()
    dtr:dig_up()
  end

  local function dig_down()
    dtr:dig_down()
  end

  -- Initialization:
  -- 1. Determine which way we want to turn based off arguments.
  -- 2. Determine if we're going up or down based off arguments.
  local turn = parsed.flags.left and left or right
  local vertical_move = parsed.flags.up and up or down
  local duo_vertical_dig = parsed.flags.up and dig_up or dig_down
  local n_duo_vertical_dig = parsed.flags.up and dig_down or dig_up

  -- Pull the values from arguments
  local forward_length = tonumber(parsed.options.forwardlength)
  local width = tonumber(parsed.options.width)
  local height = parsed.flags.quarry and math.huge or tonumber(parsed.options.height) or math.huge
  local no_inv = parsed.flags.noinv
  local fuel = parsed.flags.fuel
  if parsed.options.loglevel ~= "info" then
    minilogger.set_log_level(minilogger.LOG_LEVELS[parsed.options.loglevel:upper()])
  end

  local function count_slots()
    local n = 0

    for i = 1, 16 do
      if turtle.getItemCount(i) > 0 then
        n = n + 1
      end
    end

    return n
  end

  local function drop()
    for i = 1, 16 do
      if turtle.getItemCount(i) > 0 then
        turtle.select(i)
        if fuel or no_inv then
          -- Attempt to refuel before dropping it.
          -- We also refuel if no_inv is enabled, since we'd just be throwing
          -- away the item anyways.
          if turtle.refuel(64) then
            dtr:refueled()
          end
        end
        turtle.drop()
      end
    end
  end

  --- The function ran at the surface.
  local function surface_func()
    while not peripheral.hasType("front", "inventory") do
      log.warn("No inventory in front...")
      sleep(10)
    end

    while true do
      drop()
      if count_slots() == 0 then
        break
      else
        log.warn("Inventory still not empty after dumping...")
        sleep(10)
      end
    end
  end

  local function return_to_surface()
    dtr:return_to_surface(true, 2, surface_func)
  end

  local function home()
    dtr:return_to_surface(true, 2, surface_func, true)
  end

  local moves = {}
  local n_moves = 0 -- Only used for populating the table
  local function m_insert(f)
    n_moves = n_moves + 1
    moves[n_moves] = f
  end
  local function get_next_move()
    -- If we're recovering and we have recorded a return to surface, simulate that return.
    if dtr:should_return_to_surface() then
      log.debug("Return to surface caused by DTR recovery.")
      return return_to_surface
    end


    if not dtr.simulating then
      -- If the inventory is full, either dump it or return and dump it.
      if count_slots() == 16 then
        if no_inv then
          drop()
        else
          log.debug("Return to surface caused by full inventory.")
          return return_to_surface
        end
      end

      -- If we are running low on fuel, return to the surface.
      if dtr:should_refuel() then
        log.debug("Return to surface caused by low fuel.")
        return return_to_surface
      end
    end

    return table.remove(moves, 1)
  end

  local function reverse()
    m_insert(turn)
    m_insert(forward)
    m_insert(turn)
    turn = turn == left and right or left
  end

  -- Move forward one block to be in the right position.
  m_insert(forward)

  local height_remaining = height

  -- If we only are digging one vertical layer, we just dig a plane.
  -- If we are digging two layers, we dig a plane but enable digging down or up.
  while height_remaining > 0 do
    if height_remaining > 2 then
      -- Digging in rows of three.
      -- Need to move down (or up) by one to compensate.
      m_insert(vertical_move)
    end

    for w = 1, width do
      for _ = 1, forward_length - 1 do -- Subtract one here since we start 'in' the first block.
        if height_remaining >= 2 then
          m_insert(duo_vertical_dig)
        end
        if height_remaining >= 3 then
          m_insert(n_duo_vertical_dig)
        end
        m_insert(forward)
      end
      if w < width then
        if height_remaining >= 2 then
          m_insert(duo_vertical_dig)
        end
        if height_remaining >= 3 then
          m_insert(n_duo_vertical_dig)
        end
        reverse()
      end
    end
    if height_remaining >= 3 then
      m_insert(n_duo_vertical_dig)
    end
    if height_remaining >= 2 then
      m_insert(duo_vertical_dig)
    end

    if height_remaining > 3 then
      for _ = 1, 2 do
        m_insert(vertical_move)
      end
      m_insert(turn)
      m_insert(turn)
    else
      log.debug("Return home caused by ITS THE END WOOOOOOOOOOOOOOOOOO")
      m_insert(home)
    end

    height_remaining = height_remaining - 3
  end

  dtr:refueled() -- Force dtr to update fuel level after initialization.
  log.infof("Pre-calculated move list with %d moves.", #moves)
  local move = 0
  while #moves > 0 do
    move = move + 1
    local func = get_next_move()

    ---@type string?
    local func_name
    if func == forward then
      func_name = "forward"
    elseif func == return_to_surface then
      func_name = "return_to_surface (has child calls)"
    elseif func == home then
      func_name = "home (has child calls)"
    elseif func == left then
      func_name = "turn_left"
    elseif func == right then
      func_name = "turn_right"
    elseif func == up then
      func_name = "up"
    elseif func == down then
      func_name = "down"
    elseif func == dig_up then
      func_name = nil
    elseif func == dig_down then
      func_name = nil
    elseif func == dig then
      func_name = nil
    else
      func_name = "unknown"
    end

    if func_name then
      log.debugf("%d (%d): %s", dtr.state.recorded_moves, move, func_name)
    end

    local success, reason = func()
    --if not success then
    --  log.error("Move failed: %s. Stopping execution to prevent further issues.", reason)
    --  break
    --end
  end
  cleanup_reboot()
end



--- Staircase digging function
local function dig_staircase()

end



--- Bridge digging function
local function dig_bridge()

end



--- Load a saved state from a file if specified.
local function load()

end



--- Displays the main user interface.
local function main_ui()
  local menus = require "menus"

  ---@type string?
  local selected_shape
  local shape_option_defaults = {
    -- shared/cuboid.
    resume = true,
    forwardlength = 16,
    width = 16,
    height = 16,
    quarry = false,
    left_right = "right",
    up_down = "down",
    fuel = true,
    noinv = false,
    broadcast = "",
    loglevel = "info",

    -- Staircase specific
    stairs = false,
    torches = false,
    torchinterval = 10,

    -- Bridge specific
    safemode = false,
    roof = false,
  }
  local shape_option_overrides = {}


  -- Override the callbacks within the menus to call the appropriate `dig_*` function.
  local function run()
    local func = selected_shape == "cuboid" and dig_cuboid
      or selected_shape == "staircase" and dig_staircase
      or selected_shape == "bridge" and dig_bridge
    if not func then
      log.error("No shape selected. This should not be able to be reached.")
      return
    end

    -- Set the arguments table based on the current menu selections.
    parsed.options.shape = selected_shape
    parsed.options.forwardlength = tostring(shape_option_overrides.forwardlength or shape_option_defaults.forwardlength)
    parsed.options.width = tostring(shape_option_overrides.width or shape_option_defaults.width)
    parsed.options.height = tostring(shape_option_overrides.height or shape_option_defaults.height)
    parsed.flags.quarry = shape_option_overrides.quarry or shape_option_defaults.quarry

    if (shape_option_overrides.left_right or shape_option_defaults.left_right) == "left" then
      parsed.flags.left = true
      parsed.flags.right = false
    else
      parsed.flags.left = false
      parsed.flags.right = true
    end
    if (shape_option_overrides.up_down or shape_option_defaults.up_down) == "up" then
      parsed.flags.up = true
      parsed.flags.down = false
    else
      parsed.flags.up = false
      parsed.flags.down = true
    end

    parsed.options.broadcast = tostring(shape_option_overrides.broadcast or shape_option_defaults.broadcast)
    parsed.options.loglevel = tostring(shape_option_overrides.loglevel or shape_option_defaults.loglevel)
    parsed.options.torchinterval = tostring(shape_option_overrides.torchinterval or shape_option_defaults.torchinterval)
    parsed.flags.fuel = shape_option_overrides.fuel or shape_option_defaults.fuel
    parsed.flags.noinv = shape_option_overrides.noinv or shape_option_defaults.noinv
    parsed.flags.stairs = shape_option_overrides.stairs or shape_option_defaults.stairs
    parsed.flags.torches = shape_option_overrides.torches or shape_option_defaults.torches
    parsed.flags.safemode = shape_option_overrides.safemode or shape_option_defaults.safemode
    parsed.flags.roof = shape_option_overrides.roof or shape_option_defaults.roof

    if (type(shape_option_overrides.resume) == "boolean" and shape_option_overrides.resume) or type(shape_option_overrides.resume) == "nil" then
      parsed.options.save = fs.combine(".simplifydig", ("auto_%s_%d.lua"):format(selected_shape, os.epoch "utc"))
    end
    func()
  end


  local cuboid_run = menus.shapes.cuboid:get_selection("run")
  if not cuboid_run then
    log.error("Cuboid menu is missing 'run' callback selection. This is a bug.")
    return
  end
  local staircase_run = menus.shapes.staircase:get_selection("run")
  if not staircase_run then
    log.error("Staircase menu is missing 'run' callback selection. This is a bug.")
    return
  end
  local bridge_run = menus.shapes.bridge:get_selection("run")
  if not bridge_run then
    log.error("Bridge menu is missing 'run' callback selection. This is a bug.")
    return
  end
  cuboid_run.value = run
  staircase_run.value = run
  bridge_run.value = run



  local function reset()
    selected_shape = nil
    for k, v in pairs(shape_option_defaults) do
      shape_option_overrides[k] = v
    end
  end
  reset()

  ---@type table<string, fun(self: Tamperer, selection: TampererSelection)>
  local selection_callbacks = {
    resume = function(self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.resume = selection.value
    end,

    -- Main menu selections for submenus
    dig_type_cuboid = function(self, selection)
      ---@cast selection TampererSelection.Submenu
      if selection.opened then
        selected_shape = "cuboid"
      else
        reset()
      end
    end,
    dig_type_staircase = function(self, selection)
      ---@cast selection TampererSelection.Submenu
      if selection.opened then
        selected_shape = "staircase"
      else
        reset()
      end
    end,
    dig_type_bridge = function(self, selection)
      ---@cast selection TampererSelection.Submenu
      if selection.opened then
        selected_shape = "bridge"
      else
        reset()
      end
    end,

    -- All other options
    forwardlength = function(self, selection)
      ---@cast selection TampererSelection.Number
      shape_option_overrides.forwardlength = selection.value
    end,
    width = function(self, selection)
      ---@cast selection TampererSelection.Number
      shape_option_overrides.width = selection.value
    end,
    height = function(self, selection)
      ---@cast selection TampererSelection.Number
      shape_option_overrides.height = selection.value
    end,
    quarry = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.quarry = selection.value
    end,
    left_right = function(self, selection)
      ---@cast selection TampererSelection.List
      shape_option_overrides.left_right = selection.value == 1 and "left" or "right"
    end,
    up_down = function(self, selection)
      ---@cast selection TampererSelection.List
      shape_option_overrides.up_down = selection.value == 1 and "up" or "down"
    end,
    fuel = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.fuel = selection.value
    end,
    inv_handling = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      -- We display this to the user inverse.
      shape_option_overrides.noinv = not selection.value
    end,
    broadcast_file = function (self, selection)
      ---@cast selection TampererSelection.String
      shape_option_overrides.broadcast = selection.value
    end,
    log_level = function (self, selection)
      ---@cast selection TampererSelection.List
      local level_str = ({ "debug", "info", "warning", "error" })[selection.value]
      shape_option_overrides.loglevel = level_str
    end,
    stairs = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.stairs = selection.value
    end,
    torches = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.torches = selection.value
    end,
    torchinterval = function (self, selection)
      ---@cast selection TampererSelection.Number
      shape_option_overrides.torchinterval = selection.value
    end,
    safemode = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.safemode = selection.value
    end,
    roof = function (self, selection)
      ---@cast selection TampererSelection.Boolean
      shape_option_overrides.roof = selection.value
    end,

    load = function(self, selection)
      ---@cast selection TampererSelection.String
      parsed.options.load = selection.value
      load()
    end,
    run = function(self, selection)
      -- This callback is ran after `run` is finished.
      -- Thus, it's run after the program completes, so we can kill the menu
      -- and exit cleanly here.
      menus.main:kill()
    end
  }

  menus.main:set_on_change_recursive(function (self, selection)
    if selection_callbacks[selection.i_label] then
      selection_callbacks[selection.i_label](self, selection)
    end
  end)


  menus.main:run()
end



local ok, err = xpcall(function()
  local function option_check(value, to_type)
    if to_type == "number" then
      local n = tonumber(parsed.options[value])
      if not n then
        error(("Expected a number for option '%s', got '%s'."):format(value, type(parsed.options[value])))
      end
      return n
    elseif to_type == "string" then
      if not parsed.options[value] then
        error(("Expected a string for option '%s', got '%s'."):format(value, type(parsed.options[value])))
      end
    else
      error(("Unsupported type for option check: '%s'."):format(to_type))
    end
  end

  -- Execute the appropriate digging function.
  if shape_type == "cuboid" then
    option_check("forwardlength", "number")
    option_check("width", "number")
    if not parsed.flags.quarry then
      option_check("height", "number")
    end

    dig_cuboid()
  elseif shape_type == "staircase" then
    dig_staircase()
  elseif shape_type == "bridge" then
    dig_bridge()
  elseif not shape_type then
    main_ui()
  else
    log.error("Unsupported shape type: '%s'.", shape_type)
  end
end, debug.traceback)

if not ok then
  log.fatal(err)
end