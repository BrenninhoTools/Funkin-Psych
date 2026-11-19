Put title.json, mainmenu.json or freeplay.json here to change those menus.

Every field is optional. Anything you leave out keeps the default value, so a file can be as small as:

{"items": [{"id": "story_mode", "target": "story"}, {"id": "freeplay", "target": "freeplay"}]}

The full default files are in assets/shared/data/menus/ in the engine source.

title.json
	music, background, logo, character (danceLeft/danceRight or idle), enter (colors, alphas), flash, confirm,
	introTexts (text file used for the random intro lines), intro (beat actions), introSprites, sprites.
	intro actions: create, add, clear, skip. "show"/"hide" toggle an introSprites entry by name.
	{wacky0} and {wacky1} are replaced by the random intro text.

mainmenu.json
	background, flash, layout (startY, spacing, centerX, balance), items, left, right, texts, sprites, sounds, camera.
	item fields: id, image (default mainmenu/menu_<id>), idle, selected, fps, scale, position, requires, target.
	target: story, freeplay, mods, achievements, credits, options, title, editors, donate, url:<link> or state:<class path>.
	requires: mods, achievements, mobile, desktop, lua, hscript, base_game (prefix with ! to negate).
	texts placeholders: {psychVersion} {fnfVersion} {title}.

freeplay.json
	background (image, songColors, color, colorTween), list (position, spacing, verticalMultiplier, maxWidth,
	drawDistance, lerpSpeed, selectedAlpha, unselectedAlpha, icons), score (format with {score} and {accuracy}),
	difficulty (format with {difficulty}), bottom (text, height, size, color, alpha), sounds, sprites.

sprites entries accept image or render, animations, position, scale, scroll, alpha, angle, color, flipX, flipY,
centerX, centerY and "front": true to draw above the menu. Named sprites are available to scripts with getVar.
