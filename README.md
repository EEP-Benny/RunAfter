# RunAfter

Delayed Lua function calls in EEP &ndash; _Zeitverzögerte Lua-Funktionsaufrufe in EEP_

## Editor

I recommend using VSCode with two extensions: [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) for Intellisense and [vscode-lua](https://marketplace.visualstudio.com/items?itemName=trixnz.vscode-lua) for formatting. They should be recommended automatically if you open this repository in VSCode.

Parameter types are annotated in the code using the [EmmyLua style](https://emmylua.github.io/annotation.html). These annotations are used by the Lua extension for Intellisense.

## Testing

Unit tests are located in `test.lua`. They use [Lust](https://github.com/bjornbytes/lust), which was copied into the repo for ease of use.

To execute the tests, make sure to have Lua installed, then open a terminal and run

```sh
lua test.lua
```
