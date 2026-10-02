extends RefCounted
## Parte los objetos largos de la pista (camino, banquina, guardarraíl, pastos) en tramos de ~180 m.
## Un objeto único que recorre toda la ruta nunca puede descartarse por estar fuera de pantalla: el teléfono procesa todos sus
## triángulos en cada cuadro aunque solo se vea el tramo de adelante. En tramos, el motor descarta solos los que están detrás
## o a los costados. La imagen es exactamente la misma.

const CELL := 180.0

## Parte un ArrayMesh de una superficie en una malla por celda de la grilla (según el centro de cada triángulo)
static func split_mesh(mesh: ArrayMesh, cell := CELL) -> Array:
	var arr := mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var Nn = arr[Mesh.ARRAY_NORMAL]
	var Cc = arr[Mesh.ARRAY_COLOR]
	var Uu = arr[Mesh.ARRAY_TEX_UV]
	var mat: Material = mesh.surface_get_material(0)
	var ids := {}
	var lists: Array = []
	for t in range(0, I.size(), 3):
		var a := V[I[t]]
		var b := V[I[t + 1]]
		var c := V[I[t + 2]]
		var key := Vector2i(floori((a.x + b.x + c.x) / (3.0 * cell)), floori((a.z + b.z + c.z) / (3.0 * cell)))
		if not ids.has(key):
			ids[key] = lists.size()
			lists.append([])
		(lists[ids[key]] as Array).append(t)
	var map := PackedInt32Array()
	map.resize(V.size())
	map.fill(-1)
	var out: Array = []
	for lst in lists:
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nc := PackedColorArray()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		var touched: Array = []
		for t in lst:
			for k in 3:
				var v := I[t + k]
				if map[v] < 0:
					map[v] = nv.size()
					nv.append(V[v])
					if Nn != null:
						nn.append(Nn[v])
					if Cc != null:
						nc.append(Cc[v])
					if Uu != null:
						nu.append(Uu[v])
					touched.append(v)
				ni.append(map[v])
		for v in touched:
			map[v] = -1
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = nv
		na[Mesh.ARRAY_INDEX] = ni
		if Nn != null:
			na[Mesh.ARRAY_NORMAL] = nn
		if Cc != null:
			na[Mesh.ARRAY_COLOR] = nc
		if Uu != null:
			na[Mesh.ARRAY_TEX_UV] = nu
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		m.surface_set_material(0, mat)
		out.append(m)
	return out

## Parte un MultiMesh (transformaciones 3D, con o sin color) en un MultiMesh por celda
static func split_multimesh(mm: MultiMesh, cell := CELL) -> Array:
	var ids := {}
	var lists: Array = []
	for i in mm.instance_count:
		var p := mm.get_instance_transform(i).origin
		var key := Vector2i(floori(p.x / cell), floori(p.z / cell))
		if not ids.has(key):
			ids[key] = lists.size()
			lists.append([])
		(lists[ids[key]] as Array).append(i)
	var out: Array = []
	for lst in lists:
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = mm.use_colors
		m.mesh = mm.mesh
		m.instance_count = lst.size()
		for j in lst.size():
			m.set_instance_transform(j, mm.get_instance_transform(lst[j]))
			if mm.use_colors:
				m.set_instance_color(j, mm.get_instance_color(lst[j]))
		out.append(m)
	return out

## Reemplaza, dentro de root, cada MeshInstance3D / MultiMeshInstance3D por sus tramos (mismos materiales y opciones)
static func chunk_children(root: Node, cell := CELL) -> void:
	for ch in root.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is ArrayMesh and (ch as MeshInstance3D).get_surface_override_material_count() <= 1:
			var mi := ch as MeshInstance3D
			var parts := split_mesh(mi.mesh as ArrayMesh, cell)
			for pm in parts:
				var n := MeshInstance3D.new()
				n.mesh = pm
				n.material_override = mi.material_override
				n.cast_shadow = mi.cast_shadow
				n.transform = mi.transform
				root.add_child(n)
			root.remove_child(ch)
			ch.free()
		elif ch is MultiMeshInstance3D:
			var mmi := ch as MultiMeshInstance3D
			for pm in split_multimesh(mmi.multimesh, cell):
				var n := MultiMeshInstance3D.new()
				n.multimesh = pm
				n.material_override = mmi.material_override
				n.cast_shadow = mmi.cast_shadow
				n.transform = mmi.transform
				n.visibility_range_begin = mmi.visibility_range_begin
				n.visibility_range_end = mmi.visibility_range_end
				root.add_child(n)
			root.remove_child(ch)
			ch.free()
