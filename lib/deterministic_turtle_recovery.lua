
---@alias DTR.State.Facing
---| 0 # North
---| 1 # East
---| 2 # South
---| 3 # West

---@enum DTR.State.MovementDirection
local MOVEMENT_DIRECTION = {
  forward = 0,
  back = 1,
  up = 2,
  down = 3,
  turnLeft = 4,
  turnRight = 5
}

---@class DTR.State.Position
---@field x integer
---@field y integer
---@field z integer

---@class DTR.State
---@field recorded_moves integer The number of moves recorded in the current dig.
---@field fuel_level_moves table<integer, integer> A table mapping fuel levels to the move the fuel level was recorded at.
---@field returns table<integer, true> The moves at which the turtle returned to the surface to refuel or dump items.
---@field position DTR.State.Position The current position of the turtle within the cuboid being dug.
---@field home_position DTR.State.Position The initial position of the turtle when starting the dig.
---@field facing DTR.State.Facing The direction the turtle is facing.
---@field last_fuel integer|"unlimited" The last recorded fuel level of the turtle. Used when recovering to determine if the turtle successfully moved.
---@field movement_direction DTR.State.MovementDirection? The direction the turtle is currently moving in, if it is moving.
---@field moving boolean Whether the turtle is currently moving.
---@field returning boolean Whether the turtle is currently returning to the surface (or returning *back* to the dig after returning).
---@field return_to_pos DTR.State.Position? The position the turtle will return to, after returning to the surface.
---@field return_to_facing DTR.State.Facing? The direction the turtle will face when it returns to the dig, after returning to the surface.

--[[
  For recovery, we use multiple points of data to determine where we were within
  the dig. These values are taken because digging in such a way should be
  deterministic (with only a few variables that we can also record separately to
  account for them), so we can be reasonably confident in our ability to recover
  to the correct position even if interrupted.

  Lots of these are redundant, but more data points allow for better
  verification.

  These data points are:

  1. Recorded moves: We keep track of how many moves the turtle has made since
     the start of the dig. A "move" is defined as any action that changes the
     turtle's position or facing. Digging or placing blocks is not counted. This
     value is used to know how many iterations of the digging loop we can skip
     when recovering. The turtle is simulated until this amount of moves is
     reached.
  2. Fuel level at moves: We record the turtle's fuel level at the start of
     digging, and any time it refuels during the dig. This allows us to also
     simulate returning to the surface when the fuel runs out, and to verify the
     last fuel level.
  3. Returns to surface: We record the moves at which the turtle returns to the
     surface to refuel or dump items. This allows us to simulate these returns
     during recovery, and to verify that we are at the correct point in the dig
     when we return to the surface.
  4. Position and facing: We keep track of the turtle's position within the
     shape being dug, as well as its facing.
  5. Recording fuel before and after each move: Turtles can shut down in-between
     movements if we're unlucky. However, a way to verify if the move succeeded
     is to simply check if the fuel level has gone down by 1. Unfortunately,
     this metric does not work for turns, as they do not consume fuel.
  6. Is moving? And if so, the direction: This metric enhances the above metric
     by giving us a direction for the move. If the move succeeded, then we can
     record a successful move in the given direction.
]]

local expect = require "cc.expect".expect
local root = require "filesystem"
local log = require "minilogger".new("DTR")

---@class DTR
---@field state DTR.State The current state of the DTR system.
---@field save_file FS_File The file where the DTR state is saved.
---@field simulating boolean Whether the DTR system is currently simulating movements (i.e. during recovery) or actually moving the turtle.
---@field initial_state DTR.State? Stores the initial state, since the current state will be modified.
local DTR = {}

local DTR_MT = {
  __index = DTR
}



--- Create a new DTR instance.
---@param save_file string The file where the DTR state will be saved.
---@return DTR
function DTR.new(save_file)
  expect(1, save_file, "string")

  local self = {
    state = {
      recorded_moves = 0,
      fuel_level_moves = {},
      returns = {},
      position = {x=0, y=0, z=0},
      home_position = {x=0, y=0, z=0},
      facing = 0,
      last_fuel = 0,
      moving = false,
      returning = false,

      -- Just noting to self that these values *can* exist.
      return_to_pos = nil,
      return_to_facing = nil,
      movement_direction = nil,
    },
    save_file = root:file(save_file),
    simulating = false,
    initial_state = nil
  }

  log.infof("Initialized DTR with save file '%s'", save_file)

  return setmetatable(self, DTR_MT)
end



--- Verifies that the value input is a valid DTR state.
local function verify_state(state)
  ---@cast state table
  local function type_error(field, ...)
    error(("Invalid save state: expected %s to be a %s"):format(field, table.concat({...}, " or ")), 3)
  end

  local function type_check(field, ...)
    local expecteds = table.pack(...)
    for _, expected in ipairs(expecteds) do
      if type(state[field]) == expected then
        return
      end
    end

    type_error(field, ...)
  end


  if type(state) ~= "table" then
    error("Invalid save state: not a table", 2)
  end

  type_check("recorded_moves", "number")
  if state.recorded_moves < 0 then
    error("Invalid save state: recorded_moves cannot be negative", 2)
  end

  type_check("fuel_level_moves", "table")
  for i, move in pairs(state.fuel_level_moves) do
    -- If fuel is inf, no `fuel_level_moves` are recorded.
    if type(move) ~= "number" then
      type_error(("fuel_level_moves[%d]"):format(i), "number")
    end

    if move < 0 then
      error(("Invalid save state: fuel_level_moves[%d] cannot be negative"):format(i), 2)
    end
  end

  type_check("returns", "table")
  for move, truth in pairs(state.returns) do
    if type(move) ~= "number" then
      type_error(("returns[%d]"):format(move), "number")
    end

    if move < 0 then
      error(("Invalid save state: returns[%d] cannot be negative"):format(move), 2)
    end

    if truth ~= true then
      type_error(("returns[%d]"):format(move), "true")
    end
  end

  type_check("position", "table")
  for _, axis in ipairs({"x", "y", "z"}) do
    if type(state.position[axis]) ~= "number" then
      type_error(("position.%s"):format(axis), "number")
    end
  end

  type_check("home_position", "table")
  for _, axis in ipairs({"x", "y", "z"}) do
    if type(state.home_position[axis]) ~= "number" then
      type_error(("home_position.%s"):format(axis), "number")
    end
  end

  type_check("facing", "number")
  if state.facing < 0 or state.facing > 3 then
    error("Invalid save state: facing must be between 0 and 3", 2)
  end
  if state.facing % 1 ~= 0 then
    error("Invalid save state: facing must be an integer", 2)
  end

  type_check("last_fuel", "number", "string")
  if type(state.last_fuel) == "number" then
    if state.last_fuel < 0 then
      error("Invalid save state: last_fuel cannot be negative", 2)
    end
  elseif state.last_fuel ~= "unlimited" then
    error("Invalid save state: last_fuel must be a non-negative number or 'unlimited'", 2)
  end

  type_check("movement_direction", "number", "nil")
  type_check("moving", "boolean")
end



--- Deep copy a value
---@param v any The value to copy.
---@return any copied The copied value.
local function deep_copy(v)
  if type(v) ~= "table" then
    return v
  end

  local copy = {}
  for k, val in pairs(v) do
    copy[k] = deep_copy(val)
  end
  return copy
end



---@param self DTR
function DTR:save_state()
  self.save_file:serialize(
    self.state,
    {compact=true}
  )
end



--- Loads the DTR state from the save file.
function DTR:load_state()
  if self.save_file:exists() then
    self.initial_state = self.save_file:unserialize()
    verify_state(self.initial_state)
    log.infof(
      "DTR state loaded successfully:\n  Moves: %d\n  Last Fuel: %d\n Was Moving: %s",
      self.initial_state.recorded_moves,
      self.initial_state.last_fuel,
      self.initial_state.moving and "Yes" or "No"
    )
    self:refueled() -- Force update of fuel level.
  else
    error("DTR state file does not exist.")
  end
end



--- Determines if the you should activate simulation mode to recover.
--- This should be used *after* loading.
---@param self DTR
---@return boolean should_simulate Whether or not the turtle should attempt to recover.
function DTR:should_simulate()
  if not self.initial_state then
    return false -- No recovery if the initial state is not loaded.
  end

  if self.initial_state.recorded_moves > self.state.recorded_moves then
    return true
  end

  return false
end



local old_turtle = {}

--- Locks turtle movement functions by replacing them with error-throwing functions.
--- Used when the turtle is at the surface during, to prevent any
--- non-deterministic behavior that could cause recovery to fail.
local function no_turtle()
  old_turtle = deep_copy(turtle)

  local function error_func()
    error("Turtle functions cannot be called at the surface!", 0)
  end

  turtle.forward = error_func
  turtle.back = error_func
  turtle.up = error_func
  turtle.down = error_func
  turtle.turnLeft = error_func
  turtle.turnRight = error_func
end

--- Restore the turtle API after returning to the surface.
local function restore_turtle()
  for k, v in pairs(old_turtle) do
    turtle[k] = v
  end
end




--- Mark that the turtle is returning to the surface.
--- This should be called just before the first move towards the surface is made.
---@param self DTR
---@param allow_digging boolean Whether the turtle is allowed to dig blocks in the way when returning to the surface.
---@param surface_facing DTR.State.Facing The direction the turtle will face when it reaches the surface.
---@param surface_func fun() A callback to run once the turtle has reached the surface. Once this is complete, the turtle will return to the last position and resume the dig.
---@param dont_return boolean? If true, the turtle will not return to the dig after reaching the surface.
function DTR:return_to_surface(allow_digging, surface_facing, surface_func, dont_return)
  expect(1, allow_digging, "boolean")
  expect(2, surface_func, "function")
  expect(3, surface_facing, "number")
  expect(4, dont_return, "boolean", "nil")

  log.infof("Return to surface at %d", self.state.recorded_moves)

  self.state.returns[self.state.recorded_moves] = true
  self.state.returning = true
  self.state.return_to_pos = deep_copy(self.state.position)
  self.state.return_to_facing = self.state.facing
  self:go_to(self.state.home_position.x, self.state.home_position.y, self.state.home_position.z, allow_digging)
  self:face(surface_facing)

  if not self.simulating then
    -- Lock turtle functions while at the surface, otherwise we cannot guarantee deterministic behavior.
    no_turtle()
    local ok, err = pcall(surface_func)
    restore_turtle()
    if not ok then
      error(err, 2)
    end
  end

  if dont_return then
    log.info("Not returning to dig after reaching surface.")
    return
  end

  log.infof("Returning from surface at %d", self.state.recorded_moves)

  self:go_to(self.state.return_to_pos.x, self.state.return_to_pos.y, self.state.return_to_pos.z, allow_digging)
  self:face(self.state.return_to_facing)

  log.infof("Returned to dig at %d", self.state.recorded_moves)
end



--- You should check this method during recovery, to see if the turtle should
--- "return to the surface".
---@param self DTR
---@return boolean should_return Whether the turtle should return to the surface.
function DTR:should_return_to_surface()
  if self.simulating and self.initial_state.returns[self.state.recorded_moves] then
    return true
  end

  return false
end



--- Returns the distance between two positions in manhattan distance.
local function manhattan(pos1, pos2)
  return math.abs(pos1.x - pos2.x) + math.abs(pos1.y - pos2.y) + math.abs(pos1.z - pos2.z)
end

--- This method determines if the current fuel range is too low to reach the home position (plus a small buffer).
---@param self DTR
---@return boolean should_refuel Whether the turtle should return to the surface to refuel.
function DTR:should_refuel()
  local fuel_level = self:get_fuel_level()
  if fuel_level == "unlimited" then
    return false
  end

  if fuel_level < manhattan(self.state.position, self.state.home_position) + 5 then
    log.infof("Fuel level %d is too low to return to surface, should refuel.", fuel_level)
    return true
  end

  return false
end



--- Mark that the turtle has refueled.
---@param self DTR
function DTR:refueled()
  if self.simulating then
    local fuel = self.initial_state.fuel_level_moves[self.state.recorded_moves]

    self.state.fuel_level_moves[self.state.recorded_moves] = fuel
    self.state.last_fuel = fuel
    log.infof("Restored refuel at move %d, fuel level %d", self.state.recorded_moves, fuel)
  else
    local fuel = turtle.getFuelLevel()

    self.state.last_fuel = fuel
    if fuel == "unlimited" then
      log.warn("Fuel is unlimited! Cannot recover.")
      return
    end
    ---@cast fuel number
    self.state.fuel_level_moves[self.state.recorded_moves] = fuel
    log.infof("Recorded refuel at move %d, fuel level %d", self.state.recorded_moves, fuel)
  end
end



--- Gets the current fuel level of the turtle.
--- This should be prefered over direct calls to `turtle.getFuelLevel()` as it
--- accounts for simulation mode and fuel level recording.
---@param self DTR
---@return integer|"unlimited" fuel_level The current fuel level, or "unlimited" if the turtle has unlimited fuel.
function DTR:get_fuel_level()
  if self.state.last_fuel == "unlimited" then
    return "unlimited"
  elseif self.state.last_fuel == 0 then
    local level = turtle.getFuelLevel()
    self.state.last_fuel = level
    return level
  end

  return self.state.last_fuel
end


--- Record any pre-movement data.
---@param self DTR
---@param movement_direction DTR.State.MovementDirection The direction the turtle is moving in.
local function pre_move(self, movement_direction)
  log.debugf("Pre: %d", movement_direction)
  self.state.movement_direction = movement_direction
  self.state.moving = true

  self:save_state()
end



--- Record any post-movement data
---@param self DTR
local function post_move(self)
  log.debugf("Post")
  self.state.movement_direction = nil
  self.state.moving = false

  self:save_state()
end



--- Writes a movement
---@param self DTR
---@param movement_direction DTR.State.MovementDirection The direction the turtle moved in.
local function write_movement(self, movement_direction)
  log.debugf("Write: %d", movement_direction)
  if movement_direction == MOVEMENT_DIRECTION.up then
    self.state.position.y = self.state.position.y + 1
  elseif movement_direction == MOVEMENT_DIRECTION.down then
    self.state.position.y = self.state.position.y - 1
  elseif movement_direction == MOVEMENT_DIRECTION.forward or movement_direction == MOVEMENT_DIRECTION.back then
    local multiplier = movement_direction == MOVEMENT_DIRECTION.forward and 1 or -1
    if self.state.facing == 0 then -- North (-z)
      self.state.position.z = self.state.position.z - multiplier
    elseif self.state.facing == 1 then -- East (+x)
      self.state.position.x = self.state.position.x + multiplier
    elseif self.state.facing == 2 then -- South (+z)
      self.state.position.z = self.state.position.z + multiplier
    elseif self.state.facing == 3 then -- West (-x)
      self.state.position.x = self.state.position.x - multiplier
    end
  else
    self.state.facing = (self.state.facing + (movement_direction == MOVEMENT_DIRECTION.turnLeft and -1 or 1)) % 4
  end
  if self.state.last_fuel ~= "unlimited" and (
    movement_direction == MOVEMENT_DIRECTION.forward or
    movement_direction == MOVEMENT_DIRECTION.back or
    movement_direction == MOVEMENT_DIRECTION.up or
    movement_direction == MOVEMENT_DIRECTION.down)
  then
    self.state.last_fuel = self.state.last_fuel - 1
  end
end



-- Problem. When we increment the recorded moves to say, 14, we assume that means the 14th move has completed.



--- Records data for a movement, and checks simulation state.
---@param self DTR
---@param movement_direction DTR.State.MovementDirection
local function record_movement(self, movement_direction)
  log.debugf("Record: %d", movement_direction)
  write_movement(self, movement_direction)
  self.state.recorded_moves = self.state.recorded_moves + 1

  if self.simulating then
    local should_end = self.initial_state.moving
      and self.state.recorded_moves > self.initial_state.recorded_moves
      or (not self.initial_state.moving and self.state.recorded_moves >= self.initial_state.recorded_moves)

    if should_end then
      self.simulating = false
      log.debugf(
        "End simulation at move %d\n  initial recorded moves: %d\n  was moving: %s",
        self.state.recorded_moves,
        self.initial_state.recorded_moves,
        tostring(self.initial_state.moving)
      )

      -- Now, we need to determine if the turtle actually made the last move that was saved.
      if not self.initial_state.moving then
        log.info("Simulation ended, turtle was not moving. Done.")
        return -- The turtle shut down in between moves, so we're okay.
      end

      local expected_fuel = self.initial_state.last_fuel
      local actual_fuel = turtle.getFuelLevel()
      local expected_movement_direction = self.initial_state.movement_direction

      if expected_movement_direction ~= movement_direction then
        error(("Simulation ended, but expected movement direction %d does not match actual movement direction %d, which is unrecoverable."):format(expected_movement_direction, movement_direction))
      end
      ---@cast expected_movement_direction DTR.State.MovementDirection

      if expected_fuel == "unlimited" or actual_fuel == "unlimited" then
        -- If the turtle does not require fuel, we cannot check the fuel level to
        -- verify the move!
        error("Simulation ended, but expected or actual fuel was 'unlimited', which is unrecoverable.")
      end

      if expected_movement_direction == MOVEMENT_DIRECTION.turnLeft or expected_movement_direction == MOVEMENT_DIRECTION.turnRight then
        -- We just assume that turns succeed.
        -- Unfortunately, there is nothing we can use to check for turns.
        log.warn("Simulation ended during a turn which was incomplete. Assuming it is complete.")
        self.state.recorded_moves = self.initial_state.recorded_moves + 1
        post_move(self)
        return
      end

      if expected_fuel > actual_fuel then
        -- Movement succeeded
        log.infof("Simulation ended, fuel decreased. Last move was successful.")
        self.state.recorded_moves = self.initial_state.recorded_moves + 1
        post_move(self)
        return
      elseif expected_fuel == actual_fuel then
        -- The move has failed
        log.infof("Simulation ended, fuel level the same. Last move failed.")
        post_move(self)
        -- Problem: Last move failed, but we recorded the move already.
        -- Invert the movement direction to get back to the correct position in the state.
        local inverse_direction
        if expected_movement_direction == MOVEMENT_DIRECTION.forward then
          inverse_direction = MOVEMENT_DIRECTION.back
        elseif expected_movement_direction == MOVEMENT_DIRECTION.back then
          inverse_direction = MOVEMENT_DIRECTION.forward
        elseif expected_movement_direction == MOVEMENT_DIRECTION.up then
          inverse_direction = MOVEMENT_DIRECTION.down
        elseif expected_movement_direction == MOVEMENT_DIRECTION.down then
          inverse_direction = MOVEMENT_DIRECTION.up
        else
          error(("Invalid movement direction: %d"):format(expected_movement_direction))
        end
        write_movement(self, inverse_direction)
        -- Recover the extra fuel used for both movements.
        self.state.last_fuel = self.state.last_fuel + 2
        return
      end
      error(("Simulation ended, but expected fuel was less than the actual fuel (%d < %d), which is unrecoverable."):format(expected_fuel, actual_fuel))
    end
  end
end



--- Moves the turtle in a given direction, recording the movement in the DTR state.
---@param self DTR
---@param movement_direction DTR.State.MovementDirection The direction to move in.
---@return boolean success Whether the move was successful.
---@return string? reason If the move was not successful, the reason why.
local function move(self, movement_direction)
  if self.simulating and not self.initial_state.recorded_moves then
    error("Initial state must have recorded_moves for simulation.", 2)
  end

  if not self.simulating then
    pre_move(self, movement_direction)
  end

  local func = movement_direction == MOVEMENT_DIRECTION.forward and turtle.forward
    or movement_direction == MOVEMENT_DIRECTION.back and turtle.back
    or movement_direction == MOVEMENT_DIRECTION.up and turtle.up
    or movement_direction == MOVEMENT_DIRECTION.down and turtle.down
    or movement_direction == MOVEMENT_DIRECTION.turnLeft and turtle.turnLeft
    or movement_direction == MOVEMENT_DIRECTION.turnRight and turtle.turnRight

  if not func then
    error(("Bad move direction: %d"):format(movement_direction))
  end

  local success, reason
  if self.simulating then
    log.debugf("Simulating move in direction %d", movement_direction)
    success = true
  else
    log.debugf("Moving in direction %d", movement_direction)
    success, reason = func()
  end
  ---@cast success boolean

  if self.simulating then
    record_movement(self, movement_direction)
  else
    if success then
      record_movement(self, movement_direction)
    end
    post_move(self)
  end
  return success, reason
end



--- Toggle simulating movements. Will simulate until the initial_state.recorded_moves is reached.
function DTR:start_simulating()
  self.simulating = true
  log.info("Started simulating movements for recovery.")
end



--- Move the turtle forward.
---@return boolean success Whether the move was successful.
---@return string? reason If the move was not successful, the reason why.
function DTR:forward()
  return move(self, MOVEMENT_DIRECTION.forward)
end



--- Move the turtle back.
---@return boolean success Whether the move was successful.
---@return string? reason If the move was not successful, the reason why.
function DTR:back()
  return move(self, MOVEMENT_DIRECTION.back)
end



--- Move the turtle up.
---@return boolean success Whether the move was successful.
---@return string? reason If the move was not successful, the reason why.
function DTR:up()
  return move(self, MOVEMENT_DIRECTION.up)
end



--- Move the turtle down.
---@return boolean success Whether the move was successful.
---@return string? reason If the move was not successful, the reason why.
function DTR:down()
  return move(self, MOVEMENT_DIRECTION.down)
end



--- Turn the turtle left.
---@return boolean success Whether the turn was successful.
---@return string? reason If the turn was not successful, the reason why.
function DTR:turn_left()
  return move(self, MOVEMENT_DIRECTION.turnLeft)
end



--- Turn the turtle right.
---@return boolean success Whether the turn was successful.
---@return string? reason If the turn was not successful, the reason why.
function DTR:turn_right()
  return move(self, MOVEMENT_DIRECTION.turnRight)
end



--- Face a specific direction.
---@param direction DTR.State.Facing The direction to face.
---@return boolean success Whether the operation was successful.
---@return string? reason If the operation was not successful, the reason why.
---@return integer? facing The direction the turtle is now facing, if failed.
function DTR:face(direction)
  expect(1, direction, "number")

  if direction < 0 or direction > 3 then
    error(("Invalid direction: %d"):format(direction))
  end

  if self.state.facing == direction then
    return true
  end

  local turns = (direction - self.state.facing) % 4
  if turns == 3 then
    return self:turn_left()
  else
    for _=1, turns do
      local success, reason = self:turn_right()

      if not success then
        return false, reason, self.state.facing
      end
    end

    return true
  end
end



--- Go to a specific block.
---@param x integer The x coordinate to go to, relative to the starting position.
---@param y integer The y coordinate to go to, relative to the starting position.
---@param z integer The z coordinate to go to, relative to the starting position.
---@param allow_digging boolean? Whether the turtle is allowed to dig blocks in the way.
---@return boolean success Whether the operation was successful.
---@return string? reason If the operation was not successful, the reason why.
---@return DTR.State.Position? position The current position of the turtle, if failed.
function DTR:go_to(x, y, z, allow_digging)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")
  expect(4, allow_digging, "boolean", "nil")

  log.debugf("goto %d.%d.%d", x, y, z)

  if self.state.position.x == x and self.state.position.y == y and self.state.position.z == z then
    return true
  end

  ---@param name "x"|"y"|"z"
  ---@param to integer
  ---@param move_f function The function to move in the given axis.
  ---@param dig_f function The function to dig in the given axis.
  local function move_axis(name, to, move_f, dig_f)
    local pos_t = self.state.position

    while pos_t[name] ~= to do
      local success, reason = move_f()
      if not success then
        if allow_digging then
          dig_f()
        else
          return false, reason, deep_copy(self.state.position)
        end
      end
    end

    return true
  end

  local function forward()
    return self:forward()
  end
  local function up()
    return self:up()
  end

  local function down()
    return self:down()
  end

  if self.state.position.x ~= x then
    if self.state.position.x > x then
      local success, reason = self:face(3) -- West (-x)
      if not success then
        return false, reason, deep_copy(self.state.position)
      end
    else
      local success, reason = self:face(1) -- East (+x)
      if not success then
        return false, reason, deep_copy(self.state.position)
      end
    end

    local success, reason, pos = move_axis("x", x, forward, turtle.dig)
    if not success then
      return false, reason, pos
    end
  end

  if self.state.position.z ~= z then
    if self.state.position.z > z then
      local success, reason = self:face(0) -- North (-z)
      if not success then
        return false, reason, deep_copy(self.state.position)
      end
    else
      local success, reason = self:face(2) -- South (+z)
      if not success then
        return false, reason, deep_copy(self.state.position)
      end
    end

    local success, reason, pos = move_axis("z", z, forward, turtle.dig)
    if not success then
      return false, reason, pos
    end
  end

  if self.state.position.y ~= y then
    if self.state.position.y < y then
      local success, reason, pos = move_axis("y", y, up, turtle.digUp)
      if not success then
        return false, reason, pos
      end
    else
      local success, reason, pos = move_axis("y", y, down, turtle.digDown)
      if not success then
        return false, reason, pos
      end
    end
  end

  return true
end



--- Simple wrapper for turtle.dig, so most turtle functions can be called through DTR.
function DTR:dig()
  if self.simulating then
    return true
  end
  return turtle.dig()
end



--- Simple wrapper for turtle.digUp, so most turtle functions can be called through DTR.
function DTR:dig_up()
  if self.simulating then
    return true
  end
  return turtle.digUp()
end



--- Simple wrapper for turtle.digDown, so most turtle functions can be called through DTR.
function DTR:dig_down()
  if self.simulating then
    return true
  end
  return turtle.digDown()
end



--- Simple wrapper for turtle.place, so most turtle functions can be called through DTR.
function DTR:place()
  if self.simulating then
    return true
  end
  return turtle.place()
end



--- Simple wrapper for turtle.placeUp, so most turtle functions can be called through DTR.
function DTR:place_up()
  if self.simulating then
    return true
  end
  return turtle.placeUp()
end



--- Simple wrapper for turtle.placeDown, so most turtle functions can be called through DTR.
function DTR:place_down()
  if self.simulating then
    return true
  end
  return turtle.placeDown()
end



--- Clean up the DTR state file. Should be called at the end of the dig.
function DTR:cleanup()
  if self.save_file:exists() then
    self.save_file:delete()
  end
end



return DTR