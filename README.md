# ujson encoder/decoder
A lightweight JSON encode/decode library written in Luau, compatible with Lune runtime without external dependencies.

## Features
* `ujson.encode` / `ujson.decode` support
* Real JSON `null` via `ujson.null`
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
local ujson = require(path.to.lib)
```

If you use Pesde:
```bash
pesde add onefiverdev/ujson
pesde install # remember to install dependencies
```

## Usage
### Encode
```lua
local ujson = require("path.to.lib")

local data = {
    hello = "world",
    num = 123,
    nested = {
        ok = true,
        value = ujson.null
    }
}

print(ujson.encode(data))
```

**Output:**
```ujson
{"hello":"world","num":123,"nested":{"ok":true,"value":null}}
```

### Decode
```lua
local ujson = require("path.to.lib")

local str = [[
    {
        "hello": "world",
        "num": 123
    }
]]

local data = ujson.decode(str)

print(data.hello) -- world
print(data.num)   -- 123
```

## JSON Null
Lua has no native `null`, so this library uses:
```lua
ujson.null
```

**Example:**
```lua
local t = {
    value = ujson.null
}
```
This will serialize as:
```ujson
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
### `ujson.encode(value) -> string`
Encodes a Lua table into a JSON string.

---

### `ujson.decode(string) -> any`
Parses a JSON string into a Lua table.

---

### `ujson.null`
Represents JSON `null`.
```lua
local x = ujson.null
```

## Full Example

```lua
local ujson = require("path.to.lib")

local encoded = ujson.encode({
    name = "Luau",
    features = { "fast", "lightweight" },
    nilValue = ujson.null
})

local decoded = ujson.decode(encoded)

print(encoded)
print(decoded.features[1])
```