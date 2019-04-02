
state =
	zones: []

grid = []

place_zone_type = null

zone_type_select = document.getElementById("zone-type")
get_zone_type = -> zone_type_select.options[zone_type_select.selectedIndex].value
place_zone_type = get_zone_type()
zone_type_select.addEventListener "change", (e)->
	place_zone_type = get_zone_type()


update_ship = ->
	{zones} = state
	grid = []
	width = 0
	height = 0
	for zone in zones
		for x in [zone.x ... zone.x + zone.w]
			for y in [zone.y ... zone.y + zone.h]
				grid[y] ?= []
				grid[y][x] = {type: zone.type}
				width = Math.max(width, x)
				height = Math.max(height, y)
	
	for y in [0..height]
		grid[y] ?= []
	
	loop
		island_detection_matrix = []
		for y in [0..height]
			island_detection_matrix[y] ?= []
			for x in [0..width]
				island_detection_matrix[y][x] = if grid[y]?[x]? then 1 else 0
		
		island_count = getIslandCount(island_detection_matrix)
		console.log "Island count:", island_count
		break if island_count <= 1
		
		new_grid = []
		for y in [0..height]
			new_grid[y] ?= []
		
		for y in [0..height]
			for x in [0..width]
				if grid[y]?[x]?
					new_grid[y][x] = grid[y][x]
					new_grid[y - 1]?[x] ?= {type: "structural"}
					new_grid[y + 1]?[x] ?= {type: "structural"}
					new_grid[y]?[x - 1] ?= {type: "structural"}
					new_grid[y]?[x + 1] ?= {type: "structural"}
		
		grid = new_grid

@state_changed = ->
	update_ship()
	try localStorage.cityship_state = JSON.stringify(state)
	render()

@get_state = ->
	JSON.stringify(state)

@set_state = (state_json)->
	state = JSON.parse(state_json)
	state_changed()

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
	# b = ctx.lineWidth #/ 2
	#ctx.fillRect(x * tile_size, y * tile_size, w * tile_size, h * tile_size)
	# roundRect(ctx, x * tile_size, y * tile_size, w * tile_size, h * tile_size, 5)
	# roundRect(ctx, x * tile_size + b, y * tile_size + b, w * tile_size - b * 2, h * tile_size - b * 2, 5)
	roundRect(ctx, x * tile_size + 1, y * tile_size + 1, w * tile_size - 3, h * tile_size - 3, 5)
	color = colors[zone_type]
	ctx.fillStyle = color
	ctx.globalAlpha = alpha * 0.4
	ctx.fill()
	ctx.strokeStyle = color
	ctx.globalAlpha = alpha
	ctx.stroke()

do @render = ->
	ctx.clearRect(0, 0, canvas.width, canvas.height)
	
	{zones} = state
	
	for row, y in grid when row
		for cell, x in row when cell
			# tile.image ?= images[tile.type]
			#ctx.drawImage tile.image, x * tile_size, y * tile_size
			if cell.type is "structural"
				ctx.fillStyle = "rgba(0, 0, 0, 0.4)"
				dot_size = 4
			else
				ctx.fillStyle = colors[cell.type] #"rgba(0, 0, 0, 0.2)"
				dot_size = 4
			# ctx.fillRect(x * tile_size, y * tile_size, tile_size, tile_size)
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


mouse_to_canvas_coords = (e)->
	rect = canvas.getBoundingClientRect()
	x: e.clientX - rect.left
	y: e.clientY - rect.top

mouse_to_grid_coords = (e)->
	# TODO: view offset (i.e. panning)
	{x, y} = mouse_to_canvas_coords(e)
	x: ~~(x / tile_size)
	y: ~~(y / tile_size)

window.addEventListener "mousemove", (e)->
	{x, y} = mouse_to_grid_coords(e)
	if cursor.down
		cursor.x2 = x
		cursor.y2 = y
		render()

window.addEventListener "mouseup", (e)->
	{x, y} = mouse_to_grid_coords(e)
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
		reset_cursor()
		render()

canvas.addEventListener "mousedown", (e)->
	{x, y} = mouse_to_grid_coords(e)
	if e.button is 0
		cursor.down = yes
		cursor.x2 = cursor.x = x
		cursor.y2 = cursor.y = y
		render()
	else if e.button is 2
		{zones} = state
		for zone in zones
			delete_zone = zone if (
				zone.x <= x < zone.x + zone.w and
				zone.y <= y < zone.y + zone.h
			)
		if delete_zone?
			undoable ->
				zones.splice(zones.indexOf(delete_zone), 1)
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

try set_state(localStorage.cityship_state)
