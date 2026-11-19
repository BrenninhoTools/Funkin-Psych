Put your custom stage .json files here!

You can create a custom stage using the Stage Editor in the editors menu.

Stages use the v2 format. Old Psych Engine and V-Slice stage files still load and are converted when saved from the editor.

{
	"version": "2.0.0",
	"directory": "week1",
	"zoom": 0.9,
	"ui": "normal",
	"cameraSpeed": 1,
	"characters": {
		"boyfriend": {"position": [770, 100], "camera": [0, 0]},
		"girlfriend": {"position": [400, 130], "camera": [0, 0], "hidden": false},
		"opponent": {"position": [100, 100], "camera": [0, 0]}
	},
	"objects": [
		{
			"name": "bg",
			"type": "sprite",
			"render": {"type": "image", "image": "stageback", "antialiasing": true},
			"position": [-600, -200],
			"scroll": [0.9, 0.9],
			"scale": [1, 1]
		},
		{"type": "girlfriend"},
		{"type": "opponent"},
		{"type": "boyfriend"}
	]
}

Object types: sprite, animatedSprite, square, boyfriend, girlfriend, opponent.
Object fields: position, scroll, scale, color, alpha, angle, flipX, flipY, filters, animations, firstAnimation.
render.type accepts the same values as characters: auto, sparrow, packer, aseprite, multisparrow, grid, image.
