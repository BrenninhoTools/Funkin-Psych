Put your note style .json files here!

A song uses a note style when its chart has "noteStyle": "your-style" (you can set it in the Chart Editor, Data tab).
Without it, stages with the "pixel" UI use pixel.json and every other stage uses funkin.json.
A stage UI with the same name as a note style also selects that style.

{
	"version": "1.0.0",
	"name": "My Style",
	"fallback": "funkin",
	"pixel": false,
	"splash": "noteSplashes/noteSplashes",
	"note": {
		"render": {"type": "sparrow", "image": "noteSkins/NOTE_assets"},
		"scale": 0.7,
		"antialiasing": true,
		"animations": {
			"left": {"prefix": "purple0"},
			"down": {"prefix": "blue0"},
			"up": {"prefix": "green0"},
			"right": {"prefix": "red0"}
		}
	},
	"hold": {
		"render": {"type": "sparrow", "image": "noteSkins/NOTE_assets"},
		"scale": 0.7,
		"animations": {
			"left": {"prefix": "purple hold piece"},
			"leftEnd": {"prefix": "purple hold end"}
		}
	},
	"strum": {
		"render": {"type": "sparrow", "image": "noteSkins/NOTE_assets"},
		"scale": 0.7,
		"animations": {
			"left": {"prefix": "arrowLEFT"},
			"leftPress": {"prefix": "left press", "fps": 24, "loop": false},
			"leftConfirm": {"prefix": "left confirm", "fps": 24, "loop": false}
		}
	}
}

Animation keys: left, down, up, right for notes and holds, leftEnd, downEnd, upEnd, rightEnd for hold ends,
and left, leftPress, leftConfirm (same for down, up, right) for strums.

"fallback" copies note, hold, strum and splash from another style when they are missing.
render.type accepts the same values as characters: auto, sparrow, packer, aseprite, multisparrow, grid, image.
For grid images use "frameSize": [w, h] or "frameCount": [columns, rows] and pick frames with "indices".
