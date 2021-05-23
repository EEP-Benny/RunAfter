# RunAfter

Delayed Lua function calls in EEP &ndash; _Zeitverzögerte Lua-Funktionsaufrufe in EEP_

### Schnellstartanleitung

#### 1. Installieren

Nach dem [Download](http://emaps-eep.de/lua/runafter) die zip-Datei in EEP über den Menüpunkt „Modelle installieren“ installieren (gibt es seit EEP13), ansonsten die zip-Datei entpacken und die `Installation.eep` aufrufen. Anschließend „Modelle scannen“ nicht vergessen.

#### 2. Einrichten

Setze die Immobilie „Zeitgeber für RunAfter_BH2“ irgendwo auf die Anlage. Die Position spielt keine Rolle, du kannst die Immobilie auch unter der Geländeoberfläche verstecken. Öffne das Eigenschaftenfenster der Immobilie und merke dir die Zahl, die unten im Feld „Lua-Name“ steht.

Füge diese Zeile an den Anfang des Anlagen-Skripts ein:

```lua
RunAfter = require("RunAfter_BH2"){immoId = 12}
```

Die 12 musst du natürlich die Zahl ersetzen, die du zuvor im Eigenschaftenfenster abgelesen hast.

Füge außerdem diese Zeile irgendwo innerhalb der `EEPMain`-Funktion ein:

```lua
RunAfter.tick()
```

#### 3. Verwenden

Um nun eine Funktion zeitverzögert aufzurufen, rufe einfach `RunAfter` auf. Als ersten Parameter übergibst du die Wartezeit (entweder als Zahl in Sekunden, oder als String). Als zweiten Parameter übergibst du den Namen der aufzurufenden Funktion (als String).
Das kann zum Beispiel so aussehen:

```lua
RunAfter("10s", "MachEtwas")
```

Dadurch wird die Lua-Funktion `MachEtwas` nach 10 Sekunden aufgerufen.

Du kannst der aufzurufenden Funktion auch Parameter mitgeben. Diese musst du in geschweifte (statt runde) Klammern schreiben:

```lua
print("Dieser Text wird sofort ausgegeben")
RunAfter("10s", "print", {"Dieser Text wird erst nach 10 Sekunden ausgegeben"})
```

# Development

## Editor

I recommend using VSCode with two extensions: [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) for Intellisense and [vscode-lua](https://marketplace.visualstudio.com/items?itemName=trixnz.vscode-lua) for formatting. They should be recommended automatically if you open this repository in VSCode.

Parameter types are annotated in the code using the [EmmyLua style](https://emmylua.github.io/annotation.html). These annotations are used by the Lua extension for Intellisense.

## Testing

Unit tests are located in `test.lua`, they use [LuaUnit](https://github.com/bluebird75/luaunit/) and some custom functions. Mock implementations of the used EEP functions are located in `EEPGlobals.lua`.

To execute the tests, make sure to have Lua installed and LuaUnit available for `require()`, then open a terminal and run

```sh
lua test.lua -v
```
