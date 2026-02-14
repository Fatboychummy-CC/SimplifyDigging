-- Empty broadcaster for SimplifyDig.

---@alias SimplifyDig.Broadcaster.Message.Types
---| "keepalive"
---| "state"
---| "status"
---| "completion"
---| "panic"
---| "error"
---| "complete"

---@class SimplifyDig.Broadcaster.Message
---@field type SimplifyDig.Broadcaster.Message.Types|string The type of the message.
---@field data table The data of the message.

---@class SimplifyDig.Broadcaster
---@field ready boolean Whether the broadcaster is ready to send messages.
local EmptyBroadcaster = {
  ready = false
}



--- Sets up anything the broadcaster needs.
---@param parsed_args argparse-parsed Arguments passed to the program.
---@return boolean success Whether the setup was successful.
---@return string? error An error message if the setup failed.
function EmptyBroadcaster.setup(parsed_args)
  EmptyBroadcaster.ready = true
  return true
end



--- Sends a raw message.
---@param message SimplifyDig.Broadcaster.Message The message to send.
function EmptyBroadcaster.raw(message) end



---@class SimplifyDig.Broadcaster.Message.KeepAlive : SimplifyDig.Broadcaster.Message
---@field type "keepalive"
---@field data SimplifyDig.Broadcaster.Message.KeepAlive.Data

---@class SimplifyDig.Broadcaster.Message.KeepAlive.Data
---@field turtle_id integer The ID of the turtle sending the keepalive.

--- Broadcast a keepalive message.
function EmptyBroadcaster.keepalive() end



---@class SimplifyDig.Broadcaster.Message.State : SimplifyDig.Broadcaster.Message
---@field type "state"
---@field data SimplifyDig.Broadcaster.Message.State.Data

---@class SimplifyDig.Broadcaster.Message.State.Data
---@field state SimplifyDig.Broadcaster.States The state of the turtle.

---@alias SimplifyDig.Broadcaster.States
---| "init" # The turtle is initializing (recovering or just starting up).
---| "idle" # The turtle is idle, waiting for work (or in between states).
---| "digging" # The turtle is actively digging.
---| "return-home" # The turtle is returning home to refuel/dump items.
---| "return-mine" # The turtle is returning to the mine after going home to refuel/dump items.
---| "stuck" # The turtle is stuck and cannot continue without intervention.
---| "error" # The turtle has encountered an error and cannot continue.
---| "done" # Dig is complete.
---| "teapot" # Easter egg state

--- Update the state of the turtle.
---@param state SimplifyDig.Broadcaster.States The current state of the turtle.
function EmptyBroadcaster.state(state) end



---@class SimplifyDig.Broadcaster.Message.Status : SimplifyDig.Broadcaster.Message
---@field type "status"
---@field data SimplifyDig.Broadcaster.Message.Status.Data

---@class SimplifyDig.Broadcaster.Message.Status.Data
---@field pos DTR.State.Position The position to send.
---@field facing DTR.State.Facing The facing to send.
---@field fuel integer|"unlimited" The fuel level to send.

--- Send a basic status update message.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function EmptyBroadcaster.status(pos, facing, fuel) end



---@class SimplifyDig.Broadcaster.Message.Completion : SimplifyDig.Broadcaster.Message
---@field type "completion"
---@field data SimplifyDig.Broadcaster.Message.Completion.Data

---@class SimplifyDig.Broadcaster.Message.Completion.Data
---@field completion_percent number The percentage of the dig that is complete, from 0 to 1.

--- Sends a completion status message.
---@param completion_percent number The percentage of the dig that is complete, from 0 to 1.
function EmptyBroadcaster.completion(completion_percent) end



--- Send a message that the dig is complete.
function EmptyBroadcaster.complete() end



---@class SimplifyDig.Broadcaster.Message.Panic : SimplifyDig.Broadcaster.Message
---@field type "panic"
---@field data SimplifyDig.Broadcaster.Message.Panic.Data

---@class SimplifyDig.Broadcaster.Message.Panic.Data : SimplifyDig.Broadcaster.Message.Status.Data
---@field reason string The reason the turtle is stuck.

--- Sends a message that the turtle is stuck.
---@param reason string The reason the turtle is stuck.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function EmptyBroadcaster.panic(reason, pos, facing, fuel) end



---@class SimplifyDig.Broadcaster.Message.Error : SimplifyDig.Broadcaster.Message
---@field type "error"
---@field data SimplifyDig.Broadcaster.Message.Error.Data

---@class SimplifyDig.Broadcaster.Message.Error.Data : SimplifyDig.Broadcaster.Message.Status.Data
---@field message string The error message to send.

--- Send a message stating the turtle has errored.
---@param message string The error message to send.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function EmptyBroadcaster.error(message, pos, facing, fuel) end



return EmptyBroadcaster