Put your HUD .json files here!

The game picks the HUD in this order:
1. "hud" in the song chart
2. a file with the same name as the stage UI (for example pixel.json for pixel stages)
3. default.json

Every field is optional. Missing fields come from "fallback" (default.json when not set).

{
	"version": "1.0.0",
	"fallback": "default",
	"font": "vcr.ttf",
	"camera": {"zoom": 1, "angle": 0, "bump": 0.03},
	"healthBar": {"image": "healthBar", "position": [0, 641], "downscroll": [0, 79], "centerX": true, "leftToRight": false, "barOffset": [3, 3]},
	"icons": {"offsetY": -75, "spacing": 26, "visible": true},
	"timeText": {"position": [434, 19], "downscroll": [434, 676], "width": 400, "size": 32, "borderSize": 2},
	"timeBar": {"image": "timeBar", "anchor": "timeText", "anchorHeight": 0.25, "centerX": true},
	"scoreText": {"anchor": "healthBar", "position": [0, 40], "width": 0, "size": 20, "format": "Score: {score} | Misses: {misses} | {rating} ({accuracy}%)"},
	"botplayText": {"anchor": "healthBar", "position": [400, -90], "downscroll": [400, 70], "width": -800, "size": 32},
	"sprites": [
		{"name": "hudFrame", "image": "myHudFrame", "anchor": "healthBar", "position": [0, -20], "centerX": true, "front": false}
	]
}

Text fields: font, size, color, borderColor, borderSize, alignment, width, alpha, antialiasing, visible, position, downscroll, anchor, anchorX, anchorHeight, centerX, offset.
A width of 0 or less is relative to the screen width (0 = full width, -800 = screen width minus 800).
"anchor" moves the element relative to healthBar, timeBar, timeText, scoreText, botplayText, iconP1 or iconP2 (Y only, add "anchorX": true for X too).
scoreText "format" placeholders: {score} {misses} {rating} {accuracy} {fc} {combo}. Without a format the default Psych score text is used.
sprites are extra images on the HUD; "front": true draws them above the bars and texts. They accept render, animations, scale, alpha, angle, color, flipX and flipY like stage objects,
and are available to scripts by their name through getVar / game.variables.
