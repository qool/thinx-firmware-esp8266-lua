-- THiNX Example device application
-- Requires following nodemcu modules: http,mqtt,net,cjson,wifi

print ("* THiNX-Client v0.2")

dofile("config.lua") -- must contain 'ssid', 'password'

mqtt_client = null

function registration_json_body()
  return '{"registration": {"mac": "'..thinx_device_mac()..'", "firmware": "'..THINX_FIRMWARE_VERSION..'", "commit": "' .. THINX_COMMIT_ID .. '", "version": "'..THINX_FIRMWARE_VERSION_SHORT..'", "checksum": "' .. THINX_COMMIT_ID .. '", "alias": "' .. THINX_DEVICE_ALIAS .. '", "udid" :"' ..THINX_UDID..'", "owner" : "'..THINX_DEVICE_OWNER..'", "platform":"nodemcu" }}'
end

function connect(ssid, password)
  wifi.setmode(wifi.STATION)
  wifi.sta.config(ssid, password)
  wifi.sta.connect()
  tmr.alarm(1, 5000, 1, function()
    if wifi.sta.getip() == nil then
      print("* THiNX: Connecting " .. ssid .. "...")
    else
      tmr.stop(1)
      print("* THiNX: Connected to " .. ssid .. ", IP is "..wifi.sta.getip())
      thinx_register()
      if THINX_UDID ~= "" then
        do_mqtt()
      end
    end
  end)
end

-- devuce registration request
function thinx_register()
  restore_device_info()
  url = 'http://' .. THINX_CLOUD_URL .. ':7442/device/register'
  headers = 'Authentication:' .. THINX_API_KEY .. '\r\n' ..
            'Accept: application/json\r\n' ..
            'Origin: device\r\n' ..
            'Content-Type: application/json\r\n' ..
            'User-Agent: THiNX-Client\r\n'
  data = registration_json_body()
  print("* THiNX: Registration request: " .. data)
  http.post(url, headers, data,
    function(code, data)
      if (code < 0) then
        print("* THiNX: HTTP request failed")
      else
        print("* THiNX: ", code, data)
        if code == 200 then
          process_thinx_response(data)
      end
    end
  end)
end

-- firmware update request
function thinx_update(commit, checksum)
  url = 'http://' .. THINX_CLOUD_URL .. ':7442/device/firmware'
  headers = 'Authentication: ' .. THINX_API_KEY .. '\r\n' ..
            'Accept: */*\r\n' ..
            'Origin: device\r\n' ..
            'Content-Type: application/json\r\n' ..
            'User-Agent: THiNX-Client\r\n'

  data = registration_json_body()
  print("* THiNX: Update Request: " .. data)
  http.post(url, headers, body,
    function(code, data)
      if (code < 0) then
        print("* THiNX: HTTP request failed")
      else
        print("* THiNX: ", code, data)
        if code == 200 then
          print("* THiNX: Attempting to install update with response: " .. data)
          print("* THiNX: TODO: Calculate data checksum...")
          update_and_reboot(data)
      end
    end
  end)
end

-- process incoming JSON response (both MQTT/HTTP) for register/force-update/update and forward others to client app)
function process_thinx_response(response_json)

  local ok, response = pcall(cjson.decode, response_json)
  if ok then
    local reg = response['registration']
    if reg then
      print("* THiNX: ", cjson.encode(reg))
      THINX_DEVICE_ALIAS = reg['alias']
      THINX_DEVICE_OWNER = reg['owner']
      if reg['apikey'] ~= nil then
        THINX_API_KEY = reg['apikey']
      end
      THINX_UDID = reg['udid']
      save_device_info()
    end

    local upd = response['update']
    if upd then
      print("* THiNX: ", cjson.encode(reg))
      print("* THiNX: TODO: Define UPDATE payload (instead of checksum and commit, see MQTT vs. HTTP...)")
      local checksum = upd['checksum'];
      local commit = upd['commit'];
      thinx_update(checksum, commit)
    end
  else
    print("* THiNX: JSON could not be parsed:" .. response_json)
  end

  if THINX_UDID == "" then
    print("* THiNX: MQTT cannot be used until UDID will be assigned.")
  else
    do_mqtt()
  end
end

-- provides only current status as JSON so it can be loaded/saved independently
function get_device_info()

  device_info = {}

  if THINX_DEVICE_ALIAS ~= "" then
    device_info['alias'] = THINX_DEVICE_ALIAS
  end

  if THINX_DEVICE_OWNER ~= "" then
    device_info['owner'] = THINX_DEVICE_OWNER
  end

  if THINX_API_KEY~= "" then
    device_info['apikey'] = THINX_API_KEY
  end

  if THINX_UDID ~= "" then
    device_info['udid'] = THINX_UDID
  end

  device_info['platform'] = "nodemcu"

  return device_info

end

-- apply given device info to current runtime environment
function apply_device_info(info)
    if info['alias'] ~= nil then
        THINX_DEVICE_ALIAS = info['alias']
    end
    if info['owner'] ~= nil then
        if info['owner'] ~= "" then
            THINX_DEVICE_OWNER = info['owner']
        end
    end
    if info['apikey'] ~= nil then
        THINX_API_KEY = info['apikey']
    end
    if info['udid'] ~= nil then
        THINX_UDID = info['udid']
    end
end

-- Used by response parser
function save_device_info()
  if file.open("thinx.cfg", "w") then
    info = cjson.encode(get_device_info())
    file.write(info .. '\n')
    file.close()
  else
    print("* THiNX: failed to open config file for writing")
  end
end

-- Restores incoming data from filesystem overriding build-time-constants
function restore_device_info()
  if file.open("thinx.cfg", "r") then
    data = file.read('\n')
    file.close()
    local ok, info = pcall(cjson.decode, data)
    if ok then
        apply_device_info(info)
    else
        print("* THiNX: Custom configuration could not be parsed." .. data)
    end
  else
    print("* THiNX: No custom configuration stored. Using build-time constants.")
  end
end

function do_mqtt()

    if THINX_API_KEY == nil then
        print("* THiNX: Reloading vars...")
        dofile("config.lua") -- max require configuration reload..
    end

    restore_device_info()

    KEEPALIVE = 120
    CLEANSESSION = false -- keep retained messages

    print("* THiNX: Initializing MQTT client "..THINX_UDID.." / "..THINX_API_KEY)

    mqtt_client = mqtt.Client(node.chipid(), KEEPALIVE, THINX_UDID, THINX_API_KEY, CLEANSESSION)

    -- default MQTT QoS can lose messages
    MQTT_QOS = 0
    MQTT_RETAIN = false

    -- LWT has default QoS but is retained
    MQTT_LWT_QOS = 0
    MQTT_LWT_RETAIN = true
    mqtt_client:lwt("/lwt", '{"connected":false', MQTT_LWT_QOS, MQTT_LWT_RETAIN)

    -- device channel has QoS 2 and msut keep retained messages until device gets reconnected
    MQTT_DEVICE_QOS = 2 -- do not loose anything, require confirmation... (may not be supported)

    -- subscribe to device channel and publish to status channel
    mqtt_client:on("connect", function(client)
        print ("* THiNX: m:connect-01, subscribing to device topic, publishing registration status...")
        mqtt_client:subscribe("/device/"..THINX_UDID, MQTT_DEVICE_QOS, function(client) print("* THiNX: m:subscribe01 success") end)
        mqtt_client:publish("/device/"..THINX_UDID.."/status", registration_json_body(), MQTT_QOS, MQTT_RETAIN)
    end)


    mqtt_client:on("offline", function(client)
        print ("* THiNX: m:offline!!!")
        --mqtt_client:close()
        -- TODO: attempt reconnect after a while; do not use autoreconnect!
    end)

    mqtt_client:on("message", function(client, topic, data)
      print("* THiNX: m:message")
        print("* THiNX: topic: " .. topic)
        if data ~= nil then
          print("* THiNX: message: " .. data)
          process_mqtt(data)
        end
    end)

    print("* THiNX: Connecting to MQTT to " .. THINX_MQTT_URL .. "...")

    mqtt_client:connect(THINX_MQTT_URL, THINX_MQTT_PORT, KEEPALIVE, THINX_UDID, THINX_API_KEY,
        function(client)
            print ("* THiNX: m:connect-02, subscribing to device topic, publishing registration status...")
            mqtt_client:subscribe("/device/"..THINX_UDID, 0, function(client) print("* THiNX: m:subscribe02 success") end)
            mqtt_client:publish("/device/"..THINX_UDID.."/status", '{ "status" : "OK", "success" : true }', 0, 0)
        end,
        function(client, reason)
            print("* THiNX: failed reason: "..reason)
        end)

end

function process_mqtt(payload)
  process_mqtt_payload(payload)
end

function process_mqtt_payload(payload_json)
  local ok, payload = pcall(cjson.decode, payload_json)
  if ok then
      local upd = payload['update']
    if upd then
      print("* THiNX: Update payload: " ..cjson.encode(upd))
      update_and_reboot(payload)
    end

    local msg = payload['message']
    if msg then
      print("* THiNX: Incoming MQTT message: " .. msg)
      return
    end
  else
      print("* THiNX: Processing MQTT payload failed: " .. payload_json)
  end
end

-- update specific filename on filesystem with data, returns success/false
function update_file(name, data)
  if file.open(name, "w") then
    print("* THiNX: Uploading new file: "..name)
    file.write(data)
    file.close()
    return true
  else
    print("* THiNX: failed to open " .. name .. " for writing!")
    return false
  end
end

-- update specific filename on filesystem with data from URL
function update_from_url(name, url)
  http.get(url, nil, function(code, data)
    if (code < 0) then
      print("* THiNX: HTTP Update request failed")
    else
      if code == 200 then
        local success = update_file(name, data)
        if success then
          print("* THiNX: Updated from URL, rebooting...")
          node.restart()
        else
          file.rename("thinx.bak", "thinx.lua")
          print("* THiNX: Update from URL failed...")
        end
      else
        print("* THiNX: HTTP Update request failed with status: "..code)
      end
    end
  end)
end

-- the update payload may contain files, URL or OTT
function update_and_reboot(payload)

  -- update variants
  local files = upd['files']
  local ott = upd['ott']
  local url = upd['url']
  local type = upd['type']
  local name = "thinx.lua"

  -- as a default for NodeMCU, files are updated instead of whole firmware
  if type ~= nil then
    type = "file"
  end

  if files then
    file.rename("thinx.lua", "thinx.bak") -- backup
    local success = false
    if files then
      for file in files do
        local name = file['name']
        local data = file['data']
        local data = file['url']
        if name and data then
          success = update_file(name, data)
        elseif name and url then
          update_from_url(name, url)
          print("* THiNX: rebooting...")
          node.restart()
          return
        else
          print("* THiNX: MQTT Update payload has invalid file descriptors.")
        end
      end
      local commit = upd['commit']
      thinx_update(checksum, commit)
    else
      print("* THiNX: MQTT Update payload is missing file descriptors.")
    end

  else if ott then

    if type == "file" then
      url = 'http://' .. THINX_CLOUD_URL .. ':7442/device/firmware?ott=' .. ott
      print("* THiNX: Updating " .. name .. " from " .. url)
      update_from_url(name, url)
      print("* THiNX: rebooting...")
      node.restart()
      return

    else
      print("* THiNX: Whole firmware update will be supported in future.")
    end

  else if url then

    if type == "file" then
      print("* THiNX: Updating " .. name .. " from URL " .. url)
      update_from_url(name, url)
      print("* THiNX: rebooting...")
      node.restart()
      return

    else
      print("Whole firmware update will be supported in future.")
    end

  end

  if success then
    print("* THiNX: rebooting...")
    node.restart()
  else
    file.rename("thinx.bak", "thinx.lua")
    print("* THiNX: update failed...")
  end

end

function thinx_device_mac()
  return wifi.sta.getmac()
end

function thinx()
    restore_device_info()
    connect(wifi_ssid, wifi_password) -- calls register an mqtt
end

thinx()
