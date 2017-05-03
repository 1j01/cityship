
state =
	zones: []
	grid: []

place_zone_type = null

zone_type_select = document.getElementById("zone-type")
get_zone_type = -> zone_type_select.options[zone_type_select.selectedIndex].value
place_zone_type = get_zone_type()
zone_type_select.addEventListener "change", (e)->
	place_zone_type = get_zone_type()


update_ship = ()->
	{grid, zones} = state
	for zone in zones
		for x in [zone.x ... zone.x + zone.w]
			for y in [zone.y ... zone.y + zone.h]
				grid[y] ?= []
				grid[y][x] = {type: zone.type}

undos = []
redos = []

get_state = ->
	JSON.stringify(state)

set_state = (state_json)->
	state = JSON.parse(state_json)
	update_ship()

undoable = (action)->
	saved = false
	redos = []
	
	undos.push(get_state())
	
	action && action()
	return true

undo = ->
	return false if undos.length < 1

	redos.push(get_state())
	set_state(undos.pop())
	render()
	
	return true

redo = ->
	return false if redos.length < 1

	undos.push(get_state())
	set_state(redos.pop())
	render()
	
	return true


load_image = (src)->
	img = new Image
	img.src = src
	img

# images = furnace: load_image ""

colors = {
	"population": "#263238",
	"reservior": "#03A9F4",
	"weapon": "#f44336",
	"furnace": "#9c27b0",
	"storage": "#4CAF50",
	"winch": "#FF9800",
	"shield": "#FFEB3B",
}

tile_size = 32
cursor = {}
do reset_cursor = ->
	cursor.x = undefined
	cursor.y = undefined
	cursor.x2 = undefined
	cursor.y2 = undefined
	cursor.down = no

draw_zone = (x, y, w, h, zone_type, alpha=1)->
	ctx.setLineDash([4, 2])
	ctx.lineWidth = 2
	#ctx.fillRect(x * tile_size, y * tile_size, w * tile_size, h * tile_size)
	roundRect(ctx, x * tile_size, y * tile_size, w * tile_size, h * tile_size, 5)
	color = colors[zone_type]
	ctx.fillStyle = color
	ctx.globalAlpha = alpha * 0.4
	ctx.fill()
	ctx.strokeStyle = color
	ctx.globalAlpha = alpha
	ctx.stroke()

do @render = ->
	ctx.clearRect(0, 0, canvas.width, canvas.height)
	
	{grid, zones} = state
	
	update_ship()
	
	for row, y in grid when row
		for tile, x in row when tile
			# tile.image ?= images[tile.type]
			#ctx.drawImage tile.image, x * tile_size, y * tile_size
			ctx.fillStyle = "rgba(0, 0, 0, 0.5)"
			# ctx.fillRect(x * tile_size, y * tile_size, tile_size, tile_size)
			dot_size = 4
			ctx.fillRect((x + 1/2) * tile_size - dot_size/2, (y + 1/2) * tile_size - dot_size/2, dot_size, dot_size)
	
	for zone in zones
		draw_zone(zone.x, zone.y, zone.w, zone.h, zone.type)
	
	if cursor.x2? and cursor.y2?
		x = Math.min(cursor.x, cursor.x2)
		y = Math.min(cursor.y, cursor.y2)
		w = Math.max(cursor.x, cursor.x2) - x + 1
		h = Math.max(cursor.y, cursor.y2) - y + 1
	else
		{x, y} = cursor
		w = h = 1
	
	ctx.save()
	alpha = if cursor.down then 0.5 else 0.3
	draw_zone x, y, w, h, place_zone_type, alpha
	ctx.restore()



mouse_to_grid = (e)->
	# TODO: view offset
	x: ~~(e.clientX / tile_size)
	y: ~~(e.clientY / tile_size)

window.addEventListener "mousemove", (e)->
	{x, y} = mouse_to_grid(e)
	if cursor.down
		cursor.x2 = x
		cursor.y2 = y
	render()

window.addEventListener "mouseup", (e)->
	{x, y} = mouse_to_grid(e)
	if e.button is 0
		if cursor.x2? and cursor.y2?
			x = Math.min(cursor.x, cursor.x2)
			y = Math.min(cursor.y, cursor.y2)
			w = Math.max(cursor.x, cursor.x2) - x + 1
			h = Math.max(cursor.y, cursor.y2) - y + 1
			undoable ->
				state.zones.push({
					x, y, w, h
					type: place_zone_type
				})
				render()
		reset_cursor()
		render()

canvas.addEventListener "mousedown", (e)->
	{x, y} = mouse_to_grid(e)
	if e.button is 0
		cursor.down = yes
		cursor.x2 = cursor.x = x
		cursor.y2 = cursor.y = y
		render()
	else
		reset_cursor()
		render()

window.addEventListener "contextmenu", (e)->
	e.preventDefault()
	reset_cursor()
	render()

window.addEventListener "keydown", (e)->
	key = (e.key ? String.fromCharCode(e.keyCode)).toUpperCase()
	if e.ctrlKey
		switch key
			when "Z"
				if e.shiftKey then redo() else undo()
			when "Y"
				redo()
			#when "A"
				#select_all()
			else
				return # don't prevent default
	else
		switch e.keyCode
			#when 27 # Escape
				#deselect() if selection
			#when 13 # Enter
				#deselect() if selection
			when 115 # F4
				redo()
			#when 46 # Delete
				#delete_selected()
			else
				return # don't prevent default
	e.preventDefault()
