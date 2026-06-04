# ujson encoder/decoder
A lightweight JSON encode/decode library written in Luau, compatible with Lune runtime without external dependencies.

## Features
* `json.encode` / `json.decode` support
* Real JSON `null` via `json.null`
* Proper string escaping
* Full JSON object & array support
* Detects:
  * circular references
  * sparse arrays
  * invalid table keys
* Built from scratch parser (no dependencies)

## Installation
Using [Pesde](https://pesde.dev) or simply copying the lib.
```lua
local json = require(path.to.lib)
```

If you use Pesde:
```bash
pesde add onefiverdev/json
pesde install # remember to install dependencies
```

## Usage
### Encode
```lua
local json = require("path.to.lib")

local data = {
    hello = "world",
    num = 123,
    nested = {
        ok = true,
        value = json.null
    }
}

print(json.encode(data))
```

**Output:**
```json
{"hello":"world","num":123,"nested":{"ok":true,"value":null}}
```

### Decode
```lua
local json = require("path.to.lib")

local str = [[
    {
        "hello": "world",
        "num": 123
    }
]]

local data = json.decode(str)

print(data.hello) -- world
print(data.num)   -- 123
```

## JSON Null
Lua has no native `null`, so this library uses:
```lua
json.null
```

**Example:**
```lua
local t = {
    value = json.null
}
```
This will serialize as:
```json
{"value":null}
```

## Encoding Rules
### Arrays
A table is treated as an array if:
* keys are `1..n` without gaps
* no string keys exist
```lua
{ "a", "b", "c" }
```

### Objects
```lua
{ a = 1, b = 2 }
```

## Error Handling
The library throws errors for:
* circular references
* sparse arrays
* mixed/invalid table keys
* unsupported value types
* invalid JSON during decoding


## 🧠 API
### `json.encode(value) -> string`
Encodes a Lua table into a JSON string.

---

### `json.decode(string) -> any`
Parses a JSON string into a Lua table.

---

### `json.null`
Represents JSON `null`.
```lua
local x = json.null
```

## Full Example

```lua
local json = require("json")

local encoded = json.encode({
    name = "Luau",
    features = { "fast", "lightweight" },
    nilValue = json.null
})

local decoded = json.decode(encoded)

print(encoded)
print(decoded.features[1])
```