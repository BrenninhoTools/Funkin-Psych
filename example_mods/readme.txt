Psych's mods/ folder.

If you're a beginner, we recommend you extract modTemplate.zip to get started on developing your mod.
The template source lives in project/mods/template/ in the repository, edit it there and rebuild the zip.

Mods with a _polymod_meta.json file are also loaded by Polymod, which allows scripted classes (.hxc) in scripts/classes/.
Read the Psych GitHub wiki here:
https://github.com/ShadowMario/FNF-PsychEngine/wiki
Read the Lua Script API here:
https://shadowmario.github.io/psychengine.lua/

You can also add or edit specific files without the mod template, you just have to re-create the path to said file.

ABOUT EDITING:
If you want to change something, for example, within assets/preload/images, assets/shared/images or assets/week1/images,
said edited files *must* be put in mods/images, the engine will handle the rest.