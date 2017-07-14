THINX_API_KEY="88eb20839c1d8bf43819818b75a25cef3244c28e77817386b7b73b043193cef4"
THINX_DEVICE_OWNER="cedc16bb6bb06daaa3ff6d30666d91aacd6e3efbf9abbc151b4dcade59af7c12"
THINX_DEVICE_ALIAS="nodemcu-lua-test"

-- beginning of machine-generated header
-- This is an auto-generated stub, it will be pre-pended by THiNX on cloud build.

majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()

-- build-time constants
THINX_COMMIT_ID = "fb5e1c8755d12f3d32e86f1d24f68294952077b1"
THINX_FIRMWARE_VERSION_SHORT = "1.0.0" -- majorVer.."."..minorVer.."."..devVer
THINX_FIRMWARE_VERSION = "thinx-esp8266-lua-"..THINX_FIRMWARE_VERSION_SHORT
THINX_UDID = "" -- each build is specific only for given udid to prevent data leak


-- dynamic variables (adjustable by user but overridden from API)
THINX_CLOUD_URL="thinx.cloud" -- can change to proxy (?)
THINX_MQTT_URL="thinx.cloud" -- should try thinx.local first for proxy
THINX_AUTO_UPDATE=true

THINX_MQTT_PORT = 1883
THINX_API_PORT = 7442 -- use 7443 for https

THINX_PROXY = "thinx.local"

-- end of machine-generated code

-- BEGINNING OF USER FILE

wifi_ssid='VINARNA'
wifi_password='najednicku'
