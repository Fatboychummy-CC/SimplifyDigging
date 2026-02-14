-- Empty broadcaster for SimplifyDig.

---@class SimplifyDig.Broadcaster.Basic : SimplifyDig.Broadcaster
---@field modem_side ("left"|"right")? The side the modem is on.
local BasicBroadcaster = {
  ready = false,
  modem_side = nil,
  CHANNEL_SEND = 0xC0DE -- haha code, get it, this is code? hahgahahagfda im so funny
}


--- Find an empty slot in the inventory.
---@return integer? slot An empty slot, or nil if there are no empty slots.
local function empty_slot()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then
      return i
    end
  end
end



local function find_modem()
  for i = 1, 16 do
    local detail = turtle.getItemDetail(i)
    if detail and (detail.name == "computercraft:wireless_modem" or detail.name == "computercraft:wireless_modem_advanced") then
      return i
    end
  end
end



--- Sets up anything the broadcaster needs.
---@param parsed_args argparse-parsed Arguments passed to the program.
---@return boolean success Whether the setup was successful.
---@return string? error An error message if the setup failed.
function BasicBroadcaster.setup(parsed_args)
  -- Check that a modem is either currently equipped, or is in the inventory.
  if peripheral.hasType("left", "modem") or peripheral.hasType("right", "modem") then
    BasicBroadcaster.modem_side = peripheral.hasType("left", "modem") and "left" or "right"

    local slot = empty_slot()
    if not slot then
      return false, "No empty inventory slot to check peripherals."
    end

    -- Attempt to unequip the modem to see if it is actually on us and not just
    -- beside us on the ground or something.
    turtle.select(slot)
    if BasicBroadcaster.modem_side == "left" then
      turtle.equipLeft()
    else
      turtle.equipRight()
    end

    local modem_slot = find_modem()
    if not modem_slot then
      return false, "No modem found in inventory."
    end

    if modem_slot ~= slot then
      -- Someone is trolling, but equip the one we just found instead.
      turtle.select(modem_slot)
    end
    -- Re-equip the modem to put it back where it was.
    if BasicBroadcaster.modem_side == "left" then
      turtle.equipLeft()
    else
      turtle.equipRight()
    end

    BasicBroadcaster.ready = true
    return true
  end

  local modem_slot = find_modem()
  if not modem_slot then
    return false, "No modem found in inventory."
  end
  turtle.select(modem_slot)

  -- Attempt to equip on the left side first.
  local success = turtle.equipLeft()
  local detail = turtle.getItemDetail(modem_slot)
  if detail and detail.name:find("pickaxe") then
    -- Oops, equip that on the other side.
    turtle.equipRight()
  end

  if not success then
    return false, "Failed to equip modem."
  end

  BasicBroadcaster.modem_side = peripheral.hasType("left", "modem") and "left" or "right"
  BasicBroadcaster.ready = true
  -- Pickaxe should now be on right, modem on left.
  return true
end



--- Sends a raw message.
---@param message SimplifyDig.Broadcaster.Message The message to send.
function BasicBroadcaster.raw(message)
  if not BasicBroadcaster.ready then
    error("Broadcaster not ready. Call setup() first.")
  end

  peripheral.call(
    BasicBroadcaster.modem_side,
    "transmit",
    BasicBroadcaster.CHANNEL_SEND,
    0, -- reply channel, not used
    message
  )
end



--- Broadcast a keepalive message.
function BasicBroadcaster.keepalive()
  BasicBroadcaster.raw {
    type = "keepalive",
    data = {
      turtle_id = os.getComputerID(),
    },
  }
end



--- Update the state of the turtle.
---@param state SimplifyDig.Broadcaster.States The current state of the turtle.
function BasicBroadcaster.state(state)
  BasicBroadcaster.raw {
    type = "state",
    data = {
      state = state,
    },
  }
end



--- Send a basic status update message.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function BasicBroadcaster.status(pos, facing, fuel)
  BasicBroadcaster.raw {
    type = "status",
    data = {
      pos = pos,
      facing = facing,
      fuel = fuel,
    },
  }
end



--- Sends a completion status message.
---@param completion_percent number The percentage of the dig that is complete, from 0 to 1.
function BasicBroadcaster.completion(completion_percent)
  BasicBroadcaster.raw {
    type = "completion",
    data = {
      completion_percent = completion_percent,
    },
  }
end



--- Send a message that the dig is complete.
function BasicBroadcaster.complete()
  BasicBroadcaster.raw {
    type = "complete",
    data = {},
  }
end



--- Sends a message that the turtle is stuck.
---@param reason string The reason the turtle is stuck.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function BasicBroadcaster.panic(reason, pos, facing, fuel)
  BasicBroadcaster.raw {
    type = "panic",
    data = {
      reason = reason,
      pos = pos,
      facing = facing,
      fuel = fuel,
    },
  }
end



--- Send a message stating the turtle has errored.
---@param message string The error message to send.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function BasicBroadcaster.error(message, pos, facing, fuel)
  BasicBroadcaster.raw {
    type = "error",
    data = {
      message = message,
      pos = pos,
      facing = facing,
      fuel = fuel,
    },
  }
end



return BasicBroadcaster