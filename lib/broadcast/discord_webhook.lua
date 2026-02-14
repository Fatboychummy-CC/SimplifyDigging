-- Discord Webhook broadcaster implementation.

local log = require "minilogger".new "Discord"

---@class SimplifyDig.Broadcaster.DiscordWebhook : SimplifyDig.Broadcaster
---@field url string? The URL of the Discord Webhook to connect to.
local DiscordBroadcaster = {
  ready = false,
  url = "",
  turtle_id = os.getComputerID()
}



---@class SimplifyDig.Broadcaster.DiscordWebhook.WebhookData
---@field content string The content of the webhook message.
---@field username string? The username to display for the webhook message.
---@field avatar_url string? The avatar URL to use for the webhook message.
---@field tts boolean? Whether the message should be sent as a text-to-speech message.
---@field embeds SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed[]? An array of embeds to include in the message.

---@class SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed
---@field title string? The title of the embed.
---@field type "rich" The type of the embed (must be "rich" for our purposes).
---@field description string? The description of the embed.
---@field url string? The URL of the embed.
---@field timestamp string? The timestamp of the embed in ISO8601 format.
---@field color integer? The color of the embed as a decimal integer (e.g. 0xFF0000 for red).
---@field footer SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed.Footer?
---@field fields SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed.Field[]?

---@class SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed.Footer
---@field text string The text of the footer.
---@field icon_url string? The URL of the footer icon.

---@class SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed.Field
---@field name string The name of the field.
---@field value string The value of the field.
---@field inline boolean? Whether the field should be displayed inline.



--- Posts to the webhook
---@param data SimplifyDig.Broadcaster.DiscordWebhook.WebhookData The data to post to the webhook.
---@param wait boolean? Whether to wait for the response before returning. Defaults to true.
---@return false failed If the request failed.
---@return string error If the request failed, an error message describing the failure.
---@return nil If the request failed, no response body.
---@overload fun(data: SimplifyDig.Broadcaster.DiscordWebhook.WebhookData, wait: boolean?): (true, integer, string) upon success
local function post_webhook(data, wait)
  log.debugf("Posting to webhook with data: %s", textutils.serialize(data, {compact=true}))
  local url = DiscordBroadcaster.url .. (wait and "?wait=true" or "")
  if not url then
    return false, "No webhook URL set."
  end

  local json = textutils.serializeJSON(data)
  if not wait then
    http.request {
      url = url,
      method = "POST",
      headers = {
        ["Content-Type"] = "application/json"
      },
      body = json,
    }
    return true, 200, "No wait selected."
  end
  local response, err, err_response = http.post(url, json, {
    ["Content-Type"] = "application/json"
  })

  if not response then
    if not err_response then
      log.errorf("HTTP request failed: %s", err or "unknown error")
      return false, ("HTTP request failed: %s"):format(err or "unknown error")
    end
    log.errorf("HTTP request failed with code %d: %s", err_response.getResponseCode(), err_response.readAll())
    return false, ("HTTP request failed with code %d: %s"):format(err_response.getResponseCode(), err_response.readAll())
  end

  local response_body = response.readAll()
  response.close()

  local response_code = response.getResponseCode()
  if response_code < 200 or response_code >= 300 then
    log.errorf("Webhook returned non-2xx status code: %d\nResponse body: %s", response_code, response_body)
    return false, ("Webhook returned non-2xx status code: %d\nResponse body: %s"):format(response_code, response_body)
  end

  return true, response_code, response_body
end



--- Deletes a message from the webhook.
---@param message_id string The ID of the message to delete.
local function delete_webhook(message_id)
  log.debugf("Deleting webhook message with ID: %s", message_id)
  if not DiscordBroadcaster.url then
    return false, "No webhook URL set."
  end

  local url = ("%s/messages/%s"):format(DiscordBroadcaster.url, message_id)
  local response, err, err_response = http.get {
    url = url,
    method = "DELETE",
    headers = {
      ["Content-Type"] = "application/json"
    }
  }

  if not response then
    if not err_response then
      log.errorf("HTTP request failed: %s", err or "unknown error")
      return false, ("HTTP request failed: %s"):format(err or "unknown error")
    end
    log.errorf("HTTP request failed with code %d: %s", err_response.getResponseCode(), err_response.readAll())
    return false, ("HTTP request failed with code %d: %s"):format(err_response.getResponseCode(), err_response.readAll())
  end

  local response_body = response.readAll()
  response.close()

  log.debugf("Delete webhook response code: %d, body: %s", response.getResponseCode(), response_body)

  local response_code = response.getResponseCode()
  if response_code < 200 or response_code >= 300 then
    log.errorf("Webhook returned non-2xx status code: %d\nResponse body: %s", response_code, response_body)
    return false, ("Webhook returned non-2xx status code: %d\nResponse body: %s"):format(response_code, response_body)
  end

  return true
end



--- Generate a message object for the given content.
---@param content string The content of the message to generate.
---@return SimplifyDig.Broadcaster.DiscordWebhook.WebhookData message The generated message object.
local function create_message(content)
  return {
    username = ("Turtle %d"):format(DiscordBroadcaster.turtle_id),
    content = content,
    embeds = {}
  }
end



--- Creates an embed object given a title and description.
---@param title string The title of the embed.
---@param description string The description of the embed.
---@return SimplifyDig.Broadcaster.DiscordWebhook.WebhookData.Embed embed The generated embed object.
local function create_embed(title, description)
  return {
    title = title,
    description = description,
    type = "rich",
    footer = {
      text = ("SimplifyDig - Turtle %d"):format(DiscordBroadcaster.turtle_id),
    }
  }
end



--- Sets up anything the broadcaster needs.
---@param parsed_args argparse-parsed Arguments passed to the program.
---@return boolean success Whether the setup was successful.
---@return string? error An error message if the setup failed.
function DiscordBroadcaster.setup(parsed_args)
  log.debug("Setting up Discord Webhook broadcaster...")
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)

  if parsed_args.options.webhookurl then
    log.debug("Using webhook URL from arguments.")
    DiscordBroadcaster.url = parsed_args.options.webhookurl
  else
    log.debug("No webhook URL provided in arguments, prompting user for URL.")
    print("Paste the Discord webhook url:")
    write("> ")
    local url = read() --[[@as string]]

    if url == "" then
      log.error("No URL provided.")
      return false, "No URL provided."
    end

    DiscordBroadcaster.url = url
    parsed_args.options.webhookurl = url
  end

  -- Test the webhook URL by sending (then deleting) a test message.
  local test_message = create_message("Testing webhook")
  local success, err, response_body = post_webhook(test_message, true)
  if not success then
    log.fatalf("Failed to test webhook: %s", err)
    return false, ("Failed to test webhook: %s"):format(err)
  end
  ---@cast success true
  ---@cast err integer
  ---@cast response_body string

  local response_data = textutils.unserializeJSON(response_body)
  if not response_data or not response_data.id then
    log.fatalf("Invalid response from webhook: (%s) %s", err, response_body)
    return false, ("Invalid response from webhook: (%s) %s"):format(err, response_body)
  end
  log.debugf("Response data: %s", response_body)

  --sleep(1) -- Sleep for a bit to ensure the message is actually created before we try to delete it.

  -- Delete the test message
  local ok, err = delete_webhook(tostring(response_data.id))
  if not ok then
    log.fatalf("Failed to delete test message: %s", err)
    return false, ("Failed to delete test message: %s"):format(err)
  end

  DiscordBroadcaster.ready = true
  log.info("Discord Webhook broadcaster setup complete.")
  return true
end


local facing_lookup = {
  [0] = "North",
  [1] = "East",
  [2] = "South",
  [3] = "West",
}

--- We keep track of when we last sent a given type of message, to avoid spamming
--- the webhook too much.
---@type table<string, integer>
local next_messages = {}
local last_state = ""

--- Sends a raw message.
---@param message SimplifyDig.Broadcaster.Message The message to send.
function DiscordBroadcaster.raw(message)
  if not DiscordBroadcaster.ready then
    error("Broadcaster not ready. Call setup() first.")
  end

  local next_sent = next_messages[message.type] or 0
  if message.type ~= "state" and next_sent > os.epoch "utc" then
    -- We've sent this in the last 30 seconds, skip it.
    -- We keep all state messages however, as they will be important.
    return
  end
  -- Avoid state spam.
  if message.type == "state" and message.data.state == last_state then return end
  if message.type == "state" then last_state = message.data.state end

  -- Add a random cooldown of 10-30 seconds before we can send this type of
  -- message again, to avoid spamming the webhook if something goes wrong.
  --
  -- We add the random amount so that not all the messages spam all at once.
  next_messages[message.type] = os.epoch "utc" + math.random(10000, 30000)

  local message_obj = create_message("")
  local embed = create_embed(message.type, textutils.serialize(message.data))
  message_obj.embeds = { embed }

  if message.type == "keepalive" then
    ---@cast message SimplifyDig.Broadcaster.Message.KeepAlive
    embed.title = "Keepalive"
    embed.color = 0xaaaaaa -- Gray
    embed.description = "I am alive!"
  elseif message.type == "state" then
    ---@cast message SimplifyDig.Broadcaster.Message.State
    embed.title = "State Update"
    embed.color = 0xffff00 -- Yellow
    embed.description = ("State: %s"):format(message.data.state)
  elseif message.type == "status" then
    ---@cast message SimplifyDig.Broadcaster.Message.Status
    embed.title = "Status Update"
    embed.description = "Still working..."
    embed.color = 0x0000ff -- Blue
    embed.fields = {
      {
        name = "Position",
        value = ("(%d, %d, %d)"):format(message.data.pos.x, message.data.pos.y, message.data.pos.z),
        inline = true,
      },
      {
        name = "Facing",
        value = facing_lookup[message.data.facing] or tostring(message.data.facing),
        inline = true,
      },
      {
        name = "Fuel",
        value = ("%s / %s"):format(tostring(message.data.fuel), tostring(turtle.getFuelLimit())),
        inline = true,
      },
    }
  elseif message.type == "completion" then
    ---@cast message SimplifyDig.Broadcaster.Message.Completion
    embed.title = "Completion Update"
    embed.color = 0x00ff00 -- Green
    embed.description = ("Completion: %.2f%%"):format(message.data.completion_percent * 100)
  elseif message.type == "panic" then
    ---@cast message SimplifyDig.Broadcaster.Message.Panic
    embed.title = "Panic"
    embed.color = 0xcc5500 -- dark orange
    embed.description = ("Reason: %s"):format(message.data.reason)
    embed.fields = {
      {
        name = "Position",
        value = ("(%d, %d, %d)"):format(message.data.pos.x, message.data.pos.y, message.data.pos.z),
        inline = true,
      },
      {
        name = "Facing",
        value = facing_lookup[message.data.facing] or tostring(message.data.facing),
        inline = true,
      },
      {
        name = "Fuel",
        value = ("%s / %s"):format(tostring(message.data.fuel), tostring(turtle.getFuelLimit())),
        inline = true,
      },
    }
  elseif message.type == "error" then
    ---@cast message SimplifyDig.Broadcaster.Message.Error
    embed.title = "Error"
    embed.color = 0xff0000 -- Red
    embed.description = ("```\n%s\n```"):format(message.data.message:sub(1, 1000)) -- Truncate long error messages to avoid hitting Discord limits.
    embed.fields = {
      {
        name = "Position",
        value = ("(%d, %d, %d)"):format(message.data.pos.x, message.data.pos.y, message.data.pos.z),
        inline = true,
      },
      {
        name = "Facing",
        value = facing_lookup[message.data.facing] or tostring(message.data.facing),
        inline = true,
      },
      {
        name = "Fuel",
        value = ("%s / %s"):format(tostring(message.data.fuel), tostring(turtle.getFuelLimit())),
        inline = true,
      },
    }
  elseif message.type == "complete" then
    embed.title = "Dig Complete"
    embed.color = 0x00ff00 -- Green
    embed.description = "The dig is complete!"
  end

  -- Send the message to the webhook.
  local success, err = post_webhook(message_obj)
  if not success then
    log.errorf("Failed to send message to webhook: %s", err)
    return
  end

  log.debugf("Message sent to webhook successfully: %s", textutils.serialize(message_obj, {compact=true}))
end

--- Broadcast a keepalive message.
function DiscordBroadcaster.keepalive()
  DiscordBroadcaster.raw {
    type = "keepalive",
    data = {
      turtle_id = DiscordBroadcaster.turtle_id,
    },
  }
end



--- Update the state of the turtle.
---@param state SimplifyDig.Broadcaster.States The current state of the turtle.
function DiscordBroadcaster.state(state)
  DiscordBroadcaster.raw {
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
function DiscordBroadcaster.status(pos, facing, fuel)
  DiscordBroadcaster.raw {
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
function DiscordBroadcaster.completion(completion_percent)
  DiscordBroadcaster.raw {
    type = "completion",
    data = {
      completion_percent = completion_percent,
    },
  }
end



--- Send a message that the dig is complete.
function DiscordBroadcaster.complete()
  DiscordBroadcaster.raw {
    type = "complete",
    data = {},
  }
end



--- Sends a message that the turtle is stuck.
---@param reason string The reason the turtle is stuck.
---@param pos DTR.State.Position The position to send.
---@param facing DTR.State.Facing The facing to send.
---@param fuel integer|"unlimited" The fuel level to send.
function DiscordBroadcaster.panic(reason, pos, facing, fuel)
  DiscordBroadcaster.raw {
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
function DiscordBroadcaster.error(message, pos, facing, fuel)
  DiscordBroadcaster.raw {
    type = "error",
    data = {
      message = message,
      pos = pos,
      facing = facing,
      fuel = fuel,
    },
  }
end



return DiscordBroadcaster