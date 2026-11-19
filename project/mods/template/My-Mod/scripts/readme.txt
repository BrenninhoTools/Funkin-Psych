Put your .lua and .hx scripts here!

Scripts here run on every song. If you want a script to run only on a specific song, put it in data/song-name/script.lua or script.hx.

Lua scripts can load other Lua files from this folder with require("fileName").
HScript files support import, using, string interpolation ('$value' and '${expression}') and #if checks like #if mobile.

The classes folder is for Polymod scripted classes (.hxc). They only load if _polymod_meta.json exists in the mod folder.
