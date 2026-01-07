# Installing nowayCAS

nowayCAS is a pure-Luau symbolic math engine designed to run inside Roblox Studio or any Luau environment.
There are **no external dependencies**, just install the module and start computing.

---

## 📦 Option 1: Install via Roblox Studio (recommended)
1. Download the latest release from the GitHub **Releases** page
2. Insert the `.rbxm` or `.rbxmx` file into your project
3. Place the `nowayCAS` folder/module in:
    - `ReplicatedStorage`, or
    - `ServerScriptService`, or
    - any shared location in your project.
4. Require it like any other module:
```lua
local nowayCAS = require(path.to.nowayCAS)
```

## 🔧 Option 2: Install via Rojo
1. Clone the repository:

```sh
git clone https://github.com/me-when102/nowayCAS/
```

2. Add the `src/` directory to your Rojo project:

```json
{
    "name": "YourProject",
    "tree": {
        "$className": "DataModel",
        "ReplicatedStorage": {
            "$className": "ReplicatedStorage",
            "nowayCAS": {
                "$path": "path/to/nowayCAS/src"
            }
        }
    }
}
```

3. Sync with Rojo and require it normally:

```lua
local nowayCAS = require(game.ReplicatedStorage.nowayCAS) -- or game.ReplicatedStorage.nowayCAS.nowayCAS if parented under the nowayCAS folder.
```

## 🧪 Option 3: Use as a standalone Luau library

nowayCAS is pure Luau, it runs fine in any Luau interpreter.
1. Copy the `src/` folder into your project
2. Require the root module:

```lua
local nowayCAS = require("src/init")
```

---

## 🧱 Verifying Installation

Try a quick symbolic computation:
```lua
local x = nowayCAS.new("x")
local expr = x^2 + 2*x + 1

print(expr:toString()) -- x^2 + 2x + 1
print(expr:diff():toString()) -- 2x + 2
print(expr:eval({x = 3})) -- 16
```

## ❓ Need help?
If you run into installation issues, open an issue on GitHub, we're happy to help.