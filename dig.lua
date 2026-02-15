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

local MAX_HEIGHT = 320 -- Minecraft maximum world height.


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



--- Wraps a dtr instance's turtle functions such that they can be passed to the shape digging functions without modification.
---@param dtr DTR The DTR instance to wrap.
---@return WrappedDTR wrapped The wrapped DTR instance.
local function wrap_dtr(dtr)
  ---@class WrappedDTR
  local wrapped = {
    hit_bedrock = false
  }

  ---@return boolean success
  ---@return string? reason
  function wrapped.forward()
    local ok, err = dtr:forward()
    if err == "bedrock" then
      wrapped.hit_bedrock = true
    end

    while not ok do
      dtr:dig()
      ok, err = dtr:forward()
    end

    return ok, err
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.back()
    local ok, err = dtr:back()
    if err == "bedrock" then
      wrapped.hit_bedrock = true
    end

    while not ok do
      dtr:turn_left()
      dtr:turn_left()
      dtr:dig()
      dtr:turn_left()
      dtr:turn_left()
      ok, err = dtr:back()
    end

    return ok, err
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.up()
    local ok, err = dtr:up()
    if err == "bedrock" then
      wrapped.hit_bedrock = true
    end

    while not ok do
      dtr:dig_up()
      ok, err = dtr:up()
    end

    return ok, err
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.down()
    local ok, err = dtr:down()
    if err == "bedrock" then
      wrapped.hit_bedrock = true
    end

    while not ok do
      dtr:dig_down()
      ok, err = dtr:down()
    end

    return ok, err
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.turn_left()
    return dtr:turn_left()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.turn_right()
    return dtr:turn_right()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.dig()
    return dtr:dig()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.dig_up()
    return dtr:dig_up()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.dig_down()
    return dtr:dig_down()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.place()
    return dtr:place()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.place_up()
    return dtr:place_up()
  end



  ---@return boolean success
  ---@return string? reason
  function wrapped.place_down()
    return dtr:place_down()
  end

  return wrapped
end



--- Count the number of slots in the turtle's inventory that are occupied.
---@return integer n The number of occupied slots.
local function count_slots()
  local n = 0

  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      n = n + 1
    end
  end

  return n
end



--- Drop the turtle's inventory.
---@param dtr DTR The DTR instance to notify when refueling.
---@param fuel boolean If true, will attempt to refuel with the items before dropping them.
---@param no_inv boolean Does the same as `fuel` in this function.
local function drop(dtr, fuel, no_inv)
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



--- Convert a file path to a require path (remove .lua and replace / with .).
---@param path string The file path to convert.
---@return string require_path The converted require path.
local function to_require_path(path)
  return (path:gsub("%.lua$", ""):gsub("/", "."))
end



--- Verify that a broadcaster has the necessary functions.
---@param broadcaster SimplifyDig.Broadcaster The broadcaster to verify.
local function verify_broadcaster(broadcaster)
  local function broadcaster_field_error(field, got)
    error(("Broadcaster is missing required field '%s'. Got '%s'."):format(field, got))
  end
  local function broadcaster_field_check(field, _type)
    if type(broadcaster[field]) ~= _type then
      broadcaster_field_error(field, type(broadcaster[field]))
    end
  end

  if type(broadcaster) ~= "table" then
    error("Broadcaster must be a table.")
  end
  broadcaster_field_check("ready", "boolean")
  broadcaster_field_check("setup", "function")
  broadcaster_field_check("raw", "function")
  broadcaster_field_check("keepalive", "function")
  broadcaster_field_check("status", "function")
  broadcaster_field_check("complete", "function")
  broadcaster_field_check("panic", "function")
  broadcaster_field_check("error", "function")
  local ok, err = broadcaster.setup(parsed)

  if not ok then
    error(("Broadcaster setup failed: %s"):format(err or "unknown error"))
  end
end



--- The function ran at the surface.
---@param dtr DTR The DTR instance to use for status updates and refueling.
---@param dispatch SimplifyDig.Broadcaster.Dispatcher The dispatcher to use for status updates.
---@param fuel boolean Whether to attempt to refuel with items in the inventory when at the surface. This should be `fuel or no_inv`.
local function gen_surface_func(dtr, dispatch, fuel)
  ---@param returning boolean If we're returning back to the mine when done.
  return function(returning)
    dispatch.status(dtr.state.position, dtr.state.facing, dtr.state.last_fuel)
    while not peripheral.hasType("front", "inventory") do
      log.warn("No inventory in front...")
      dispatch.state "stuck"
      dispatch.panic(
        "No inventory in front to dump items into.",
        dtr.state.position,
        dtr.state.facing,
        dtr.state.last_fuel
      )
      sleep(10)
    end
    dispatch.state "idle"

    while true do
      drop(dtr, fuel, false) -- Ignore `no_inv` here.
      if count_slots() == 0 then
        break
      else
        log.warn("Inventory still not empty after dumping...")
        dispatch.state "stuck"
        dispatch.panic(
          "Inventory still not empty after dumping.",
          dtr.state.position,
          dtr.state.facing,
          dtr.state.last_fuel
        )
        sleep(10)
      end
    end
    dispatch.state "idle"

    if returning then
      dispatch.state "return-mine"
    end
  end
end



--- Run the moves.
---@param dtr DTR The DTR instance to use for status updates and refueling.
---@param wrapped_dtr WrappedDTR The wrapped DTR instance to use for move execution.
---@param dispatch SimplifyDig.Broadcaster.Dispatcher The dispatcher to use for status updates.
---@param get_next_move fun():function A function that returns the next move to execute. This allows the move generation to be dynamic and respond to events like hitting bedrock or needing to return to the surface.
---@param moves table A table of moves to execute, used for calculating completion percentage.
local function run_moves(dtr, wrapped_dtr, dispatch, get_next_move, moves)
  local n_moves = #moves

  dtr:refueled() -- Force dtr to update fuel level after initialization.
  log.infof("Pre-calculated move list with %d moves.", #moves)
  local move = 0

  local function do_the_moves()
    while #moves > 0 do
      dispatch.state "digging"
      move = move + 1
      if not dtr.simulating and move == 420 then
        dispatch.state "teapot"
      end

      local func = get_next_move()

      --#region debug logging
      ---@type string?
      local func_name
      if func == wrapped_dtr.forward then
        func_name = "forward"
      elseif func == wrapped_dtr.turn_left then
        func_name = "turn_left"
      elseif func == wrapped_dtr.turn_right then
        func_name = "turn_right"
      elseif func == wrapped_dtr.up then
        func_name = "up"
      elseif func == wrapped_dtr.down then
        func_name = "down"
      elseif func == wrapped_dtr.dig_up then
        func_name = nil
      elseif func == wrapped_dtr.dig_down then
        func_name = nil
      elseif func == wrapped_dtr.dig then
        func_name = nil
      else
        func_name = "unknown"
      end

      if func_name then
        log.debugf("%d (%d): %s", dtr.state.recorded_moves, move, func_name)
      end
      --#endregion debug logging

      local success, reason = func()

      if not success and reason == "bedrock" then
        log.warn("Hit bedrock during move. Marking bedrock reached and returning to surface.")
        wrapped_dtr.hit_bedrock = true
      end

      if dtr.simulating and dtr.state.recorded_moves % 100 == 0 then
        os.queueEvent("quick_yield")
        os.pullEvent("quick_yield")
      end
    end
  end

  -- Returns a value between 0.25 and 1.25
  local function random_offset_time()
    return math.random() + 0.25
  end

  local function status_update_loop()
    while true do
      sleep((dispatch.TIMEOUTS.status / 1000) + random_offset_time())
      dispatch.status(dtr.state.position, dtr.state.facing, dtr.state.last_fuel)
    end
  end

  local function keepalive_loop()
    while true do
      sleep((dispatch.TIMEOUTS.keepalive / 1000) + random_offset_time())
      dispatch.keepalive()
    end
  end

  local function completion_loop()
    while true do
      sleep((dispatch.TIMEOUTS.completion / 1000) + random_offset_time())
      dispatch.completion(1 - #moves / n_moves)
    end
  end

  parallel.waitForAny(
    do_the_moves,
    status_update_loop,
    completion_loop,
    keepalive_loop
  )
end



--- Cuboid digging impl
---@param dispatch SimplifyDig.Broadcaster.Dispatcher The broadcast dispatcher to use for status updates.
---@param dtr DTR The DTR instance to use for status updates and refueling.
local function dig_cuboid_impl(dispatch, dtr)
  local wrapped_dtr = wrap_dtr(dtr)

  if dtr:should_simulate() then
    dtr:start_simulating()
  end


  -- Initialization:
  -- 1. Determine which way we want to turn based off arguments.
  -- 2. Determine if we're going up or down based off arguments.
  local turn = parsed.flags.left and wrapped_dtr.turn_left or wrapped_dtr.turn_right
  local vertical_move = parsed.flags.up and wrapped_dtr.up or wrapped_dtr.down
  local duo_vertical_dig = parsed.flags.up and wrapped_dtr.dig_up or wrapped_dtr.dig_down
  local n_duo_vertical_dig = parsed.flags.up and wrapped_dtr.dig_down or wrapped_dtr.dig_up
  local surface_func = gen_surface_func(dtr, dispatch, parsed.flags.fuel or parsed.flags.noinv)

  -- Pull the values from arguments
  local forward_length = tonumber(parsed.options.forwardlength)
  local width = tonumber(parsed.options.width)
  local height = parsed.flags.quarry and MAX_HEIGHT or tonumber(parsed.options.height) or math.huge
  local no_inv = parsed.flags.noinv
  local fuel = parsed.flags.fuel
  if parsed.options.loglevel ~= "info" then
    minilogger.set_log_level(minilogger.LOG_LEVELS[parsed.options.loglevel:upper()])
  end

  local function return_to_surface()
    dispatch.state "return-home"
    dtr:return_to_surface(true, 2, surface_func)
  end

  local function home()
    dispatch.state "return-home"
    dtr:return_to_surface(true, 2, surface_func, true)
  end

  ---@type function[]
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
      -- If we've hit bedrock.
      if wrapped_dtr.hit_bedrock then
        log.debug("Return to surface caused by hitting bedrock.")
        return home
      end

      -- If the inventory is full, either dump it or return and dump it.
      if count_slots() == 16 then
        if no_inv then
          drop(dtr, fuel, no_inv)
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
    m_insert(wrapped_dtr.forward)
    m_insert(turn)
    turn = turn == wrapped_dtr.turn_left and wrapped_dtr.turn_right or wrapped_dtr.turn_left
  end

  -- Move forward one block to be in the right position.
  m_insert(wrapped_dtr.forward)

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
        m_insert(wrapped_dtr.forward)
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

  run_moves(dtr, wrapped_dtr, dispatch, get_next_move, moves)
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
  if not parsed.options.broadcast then
    parsed.options.broadcast = tostring(pp:at("lib/broadcast"):file("empty.lua"))
  end

  local broadcaster = require(to_require_path(parsed.options.broadcast)) --[[@as SimplifyDig.Broadcaster]]
  verify_broadcaster(broadcaster)
  broadcaster.state "init"
  local dispatch = require "broadcast.dispatch"
  dispatch.set_broadcaster(broadcaster)

  local dtr = setup_reboot()
  local ok, err = xpcall(dig_cuboid_impl, debug.traceback, dispatch, dtr)

  if not ok then
    pcall(log.errorf, "Cuboid dig failed: %s", err or "unknown error")
    pcall(dispatch.error, err or "unknown error", dtr.state.position, dtr.state.facing, dtr.state.last_fuel)
    pcall(dispatch.state, "error")
    -- Elevate the error
    error(err, 0)
  end

  log.info("Cuboid dig completed successfully.")
  dispatch.complete()
  cleanup_reboot()
end



--- Staircase digging impl
---@param dispatch SimplifyDig.Broadcaster.Dispatcher The broadcaster to use for status updates.
local function dig_staircase_impl(dispatch)
  local dtr = setup_reboot()
  local wrapped_dtr = wrap_dtr(dtr)

  if dtr:should_simulate() then
    dtr:start_simulating()
  end

  -- Pull the values from arguments
  local forward_length = tonumber(parsed.options.forwardlength)
  local height = tonumber(parsed.options.height) or 3
  if height < 3 then
    error("Height must be at least 3 for staircase digging.", 0)
  end
  local place_stairs = parsed.flags.stairs
  local place_torches = parsed.flags.torches
  local torch_interval = tonumber(parsed.options.torchinterval) or 10
  local no_inv = parsed.flags.noinv
  local fuel = parsed.flags.fuel
  local down = not parsed.flags.up
  if parsed.options.loglevel ~= "info" then
    minilogger.set_log_level(minilogger.LOG_LEVELS[parsed.options.loglevel:upper()])
  end
  local surface_func = gen_surface_func(dtr, dispatch, parsed.flags.fuel or parsed.flags.noinv)

  local function return_to_surface()
    dispatch.state "return-home"
    error("Cannot return right now because we are nerds who haven't implemented stuff yet lmao", 0)
    ---@TODO We need to do a custom return to surface here, because we need
    ---      to move in a stair pattern instead of a straight line.
    --dtr:return_to_surface(true, 2, surface_func)
  end

  local function home()
    dispatch.state "return-home"
    error("Cannot return right now because we are nerds who haven't implemented stuff yet lmao", 0)
    --dtr:return_to_surface(true, 2, surface_func, true)
  end

  ---@param item_name string
  ---@param match boolean? If true, will match the item name rather than direct comparison.
  ---@return integer? slot The slot containing the item, or nil if not found.
  local function find(item_name, match)
    for i = 1, 16 do
      local detail = turtle.getItemDetail(i)
      if detail and (match and string.find(detail.name, item_name) or detail.name == item_name) then
        return i
      end
    end
    return nil
  end

  ---@type function[]
  local moves = {}
  local n_moves = 0 -- Only used for populating the table

  ---@param f function
  local function m_insert(f)
    n_moves = n_moves + 1
    moves[n_moves] = f
  end

  local no_torches = false
  local no_stairs = false

  local function get_torch()
    local torch_slot = find("minecraft:torch")
    if not torch_slot then
      no_torches = true
      log.warn("No torches found in inventory.")
      return
    end

    turtle.select(torch_slot)
  end

  local function get_stair()
    local stair_slot = find("stairs", true)
    if not stair_slot then
      no_stairs = true
      log.warn("No stairs found in inventory.")
      return
    end

    turtle.select(stair_slot)
  end


  local function get_next_move()
    -- If we're recovering and we have recorded a return to surface, simulate that return.
    if dtr:should_return_to_surface() then
      log.debug("Return to surface caused by DTR recovery.")
      return return_to_surface
    end


    if not dtr.simulating then
      -- If we've hit bedrock.
      if wrapped_dtr.hit_bedrock then
        log.debug("Return to surface caused by hitting bedrock.")
        return home
      end

      -- If the inventory is full, either dump it or return and dump it.
      if count_slots() == 16 then
        if no_inv then
          drop(dtr, fuel, no_inv)
        else
          log.debug("Return to surface caused by full inventory.")
          return return_to_surface
        end
      end

      -- If there's no torches, return for more.
      if place_torches and no_torches then
        log.debug("Return to surface caused by no torches.")
        return return_to_surface
      end

      -- If there's no stairs, return for more.
      if place_stairs and no_stairs then
        log.debug("Return to surface caused by no stairs.")
        return return_to_surface
      end

      -- If we are running low on fuel, return to the surface.
      if dtr:should_refuel() then
        log.debug("Return to surface caused by low fuel.")
        return return_to_surface
      end
    end

    return table.remove(moves, 1)
  end

  -- Move forward one block to be in the right position.
  m_insert(wrapped_dtr.forward)
  if not down then
    m_insert(wrapped_dtr.up)
  end

  -- Logic time
  -- We're going to do this in a rather interesting way.
  -- Since we can dig 3 blocks at a time (front, top, bottom), we can just dig
  -- in sets of three. Pretending we are digging up, if we have a height of 6,
  -- we can dig a staircase upwards, then turn around, go up 3 blocks, then dig
  -- a staircase downwards. Since the turtle must come back anyways, we can
  -- just continue this pattern until we reach the desired height.

  local next_torch = math.floor((torch_interval or 10000000) / 2 + 0.5) -- Place the first torch at the halfway point.

  --- Digs a staircase in the current direction, placing stairs and torches if enabled.
  ---@param torches boolean Whether to place torches in the staircase.
  ---@param stairs boolean Whether to place stairs in the staircase.
  ---@param down boolean Whether the staircase is going downwards (as opposed to upwards).
  ---@param dig_down boolean Whether to dig the block below the turtle.
  ---@param dig_up boolean Whether to dig the block above the turtle.
  local function dig_staircase(torches, stairs, down, dig_down, dig_up)
    for step = 1, forward_length do
      if dig_down then
        m_insert(wrapped_dtr.dig_down)
      end
      if dig_up then
        m_insert(wrapped_dtr.dig_up)
      end

      if torches then
        next_torch = next_torch - 1
      end

      if down then
        if stairs then
          -- Before we place the stairs, check if we are placing a torch, and if so, dig forward one.
          if torches and next_torch <= 0 then
            m_insert(wrapped_dtr.dig)
          end

          -- Get and place the stair.
          m_insert(get_stair)
          m_insert(wrapped_dtr.turn_left)
          m_insert(wrapped_dtr.turn_left)
          m_insert(wrapped_dtr.place_down)

          -- If we're placing a torch, stay facing backwards.
          if next_torch > 0 then
            m_insert(wrapped_dtr.turn_left)
            m_insert(wrapped_dtr.turn_left)
          end
        end
        if torches and next_torch <= 0 then
          -- If we placed a stair, we're already facing backwards.
          -- However, we need to ensure we are in the right position.
          if stairs then
            m_insert(wrapped_dtr.back)
          else
            m_insert(wrapped_dtr.forward)
            m_insert(wrapped_dtr.turn_left)
            m_insert(wrapped_dtr.turn_left)
          end

          -- Get and place the torch.
          m_insert(get_torch)
          m_insert(wrapped_dtr.place)
          next_torch = torch_interval

          -- Ensure we face the proper direction.
          m_insert(wrapped_dtr.turn_left)
          m_insert(wrapped_dtr.turn_left)
        else
          m_insert(wrapped_dtr.forward)
        end

        if stairs or height > 3 then
          m_insert(wrapped_dtr.dig_up)
        end

        m_insert(wrapped_dtr.down)
      else
        m_insert(wrapped_dtr.up)
        m_insert(wrapped_dtr.forward)
      end
    end
  end

  -- Deploy the initial staircase, always at least 3 high.
  dig_staircase(place_torches, place_stairs, down, true, true)


  run_moves(dtr, wrapped_dtr, dispatch, get_next_move, moves)
end



--- Staircase digging function
local function dig_staircase()
    log.infof("Starting staircase dig with parameters:\n  forwardlength=%d\n  height=%s\n  up_down=%s\n  fuel=%s\n  noinv=%s\n  stairs=%s\n  torches=%s\n  torchinterval=%s\n  broadcast_file=%s\n  log_level=%s",
    parsed.options.forwardlength or -1,
    parsed.options.height or "infinite",
    parsed.flags.up and "up" or "down",
    parsed.flags.fuel and "true" or "false",
    parsed.flags.noinv and "true" or "false",
    parsed.flags.stairs and "true" or "false",
    parsed.flags.torches and "true" or "false",
    parsed.options.torchinterval or 10,
    parsed.options.broadcast or "None",
    parsed.options.loglevel or "info"
  )
  if not parsed.options.broadcast then
    parsed.options.broadcast = tostring(pp:at("lib/broadcast"):file("empty.lua"))
  end

  local broadcaster = require(to_require_path(parsed.options.broadcast)) --[[@as SimplifyDig.Broadcaster]]
  verify_broadcaster(broadcaster)
  broadcaster.state "init"
  local dispatch = require "broadcast.dispatch"
  dispatch.set_broadcaster(broadcaster)

  local ok, err = xpcall(dig_staircase_impl, debug.traceback, dispatch)

  if not ok then
    pcall(log.errorf, "Staircase dig failed: %s", err or "unknown error")
    pcall(dispatch.error, err or "unknown error")
    pcall(dispatch.state, "error")
    -- Elevate the error
    error(err, 0)
  end

  log.info("Staircase dig completed successfully.")
  dispatch.complete()
  cleanup_reboot()
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

  local run_dir = fs.getDir(shell.getRunningProgram())

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
    broadcast = fs.combine(run_dir, "lib", "broadcast", "empty.lua"),
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
      parsed.options.save = fs.combine("data/", ("auto_%s_%d.lua"):format(selected_shape, os.epoch "utc"))
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

  local function cuboid_defaults()
    reset()
  end

  local function staircase_defaults()
    reset()
    shape_option_overrides.height = 3
  end

  local function bridge_defaults()
    reset()
  end

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
        cuboid_defaults()
        selected_shape = "cuboid"
      else
        reset()
      end
    end,
    dig_type_staircase = function(self, selection)
      ---@cast selection TampererSelection.Submenu
      if selection.opened then
        staircase_defaults()
        selected_shape = "staircase"
      else
        reset()
      end
    end,
    dig_type_bridge = function(self, selection)
      ---@cast selection TampererSelection.Submenu
      if selection.opened then
        bridge_defaults()
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

      minilogger.set_log_level(minilogger.LOG_LEVELS[level_str:upper()])
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
      for _, shape_menu in pairs(menus.shapes) do
        shape_menu:kill()
      end
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
  minilogger.close()
end