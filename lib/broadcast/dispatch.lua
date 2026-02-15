-- Empty broadcaster for SimplifyDig.

--- Timeout values, in milliseconds.
---@type table<SimplifyDig.Broadcaster.Message.Types, integer>
local TIMEOUTS = {
  keepalive = 15000,
  completion = 30000,
  status = 10000,
  panic = 2000,
  error = 2000,
  state = 500,
}

local next_send = {
  keepalive = 0,
  completion = 0,
  status = 0,
  panic = 0,
  error = 0,
  state = 0,
}

-- Limit everything to one second.
local next_send_general = 0
local GENERAL_TIMEOUT = 1000

local function general_timeout()
  local current_time = os.epoch "utc"
  while current_time < next_send_general do
    sleep(0.1)
    current_time = os.epoch "utc"
  end
  next_send_general = current_time + GENERAL_TIMEOUT
end

--- Check if the given dispatch type is on timeout.
--- Triggers a timeout for the given message type if it is not already on timeout.
---@param message_type SimplifyDig.Broadcaster.Message.Types The type of the message to check.
---@return boolean Whether the message type is on timeout.
local function on_timeout(message_type)
  local timeout = TIMEOUTS[message_type]
  if not timeout then
    -- No timeout registered, so it's fine.
    general_timeout()
    return false
  end

  local current_time = os.epoch "utc"
  if current_time < next_send[message_type] then
    -- Still on timeout.
    return true
  end

  general_timeout()

  -- Not on timeout, trigger timeout and return false.
  next_send[message_type] = current_time + timeout
  return false
end


---@class SimplifyDig.Broadcaster.Dispatcher
---@field broadcaster SimplifyDig.Broadcaster? The broadcaster to dispatch to.
local Dispatcher = {
  TIMEOUTS = TIMEOUTS,
  last_state = "none",
}

local function check_dispatcher()
  if not Dispatcher.broadcaster then
    error("No broadcaster set for dispatcher.")
  end
end



--- Sets up anything the broadcaster needs.
---@param broadcaster SimplifyDig.Broadcaster The broadcaster to dispatch to.
function Dispatcher.set_broadcaster(broadcaster)
  Dispatcher.broadcaster = broadcaster
end



--- Sends a raw message.
--- Raw messages are allowed through always by default.
---@param message SimplifyDig.Broadcaster.Message The message to send.
function Dispatcher.raw(message)
  check_dispatcher()
  Dispatcher.broadcaster.raw(message)
end



--- Limit broadcaster keepalive messages to once per 15 seconds.
function Dispatcher.keepalive()
  check_dispatcher()

  if on_timeout("keepalive") then
    return
  end

  Dispatcher.broadcaster.keepalive()
end



--- Disallow dispatching a state update if it's the same as the last state sent.
---@param state SimplifyDig.Broadcaster.States The current state of the turtle.
function Dispatcher.state(state)
  check_dispatcher()

  if state == Dispatcher.last_state then
    return
  end

  while on_timeout("state") do
    -- State updates are important, but we don't want to spam them
    -- if the turtle is rapidly swapping between states.
    sleep(0.25)
  end

  Dispatcher.broadcaster.state(state)
  Dispatcher.last_state = state
end



--- Send a basic status update message.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function Dispatcher.status(pos, facing, fuel)
  check_dispatcher()

  if on_timeout("status") then
    return
  end

  Dispatcher.broadcaster.status(pos, facing, fuel)
end



--- Sends a completion status message.
---@param completion_percent number The percentage of the dig that is complete, from 0 to 1.
function Dispatcher.completion(completion_percent)
  check_dispatcher()

  if on_timeout("completion") then
    return
  end

  Dispatcher.broadcaster.completion(completion_percent)
end



--- Send a message that the dig is complete.
function Dispatcher.complete()
  check_dispatcher()

  -- No need to check timeout for completion messages, they are only sent once!

  Dispatcher.broadcaster.complete()
end



--- Sends a message that the turtle is stuck.
---@param reason string The reason the turtle is stuck.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function Dispatcher.panic(reason, pos, facing, fuel)
  check_dispatcher()

  while on_timeout("panic") do
    -- Panic messages are important, but we don't want to spam them
    -- if the turtle for some reason starts spamming the messages.
    sleep(0.25)
  end

  Dispatcher.broadcaster.panic(reason, pos, facing, fuel)
end



--- Send a message stating the turtle has errored.
---@param message string The error message to send.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function Dispatcher.error(message, pos, facing, fuel)
  check_dispatcher()

  while on_timeout("error") do
    -- Error messages are important, but we don't want to spam them
    -- if the turtle for some reason starts spamming the messages.
    sleep(0.25)
  end

  Dispatcher.broadcaster.error(message, pos, facing, fuel)
end



return Dispatcher