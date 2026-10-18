"""Convert a downloaded BlendSwap asset (.zip or .blend) to .glb for Godot, and report what is in it.

Downloads are untrusted: run with Blender's Python module in isolated mode, from outside the
download folder, and pass paths as arguments:

    /opt/bpyenv/bin/python -I tools/assets/blendswap_convert.py <asset.zip|asset.blend> <out_dir>

Embedded scripts never run (auto-run off, `use_scripts=False`). A zip is extracted into
`<out_dir>/raw/` (size-capped). For every .blend it writes `<out_dir>/<name>.glb` and
`<out_dir>/report.json`: the Blender version the file was saved with, objects by type,
triangles after modifiers (instances included), size in metres, materials (node based or legacy,
image textures, emission), images (packed, external, missing), modifiers, particle systems,
drivers and embedded text blocks. Curves, text and metaballs become meshes first; legacy
(pre-2.8, no node tree) materials get a Principled BSDF from their viewport colour, so they at
least export a colour.

Install: `uv venv /opt/bpyenv --python 3.13 && VIRTUAL_ENV=/opt/bpyenv uv pip install bpy==5.2.2`.
"""
import json
import os
import sys
import zipfile

import bpy
import mathutils

MAX_UNZIPPED = 3 * 1024 ** 3        # refuse archives that unpack to more than 3 GB
GEOMETRY = {"MESH", "CURVE", "FONT", "SURFACE", "META", "CURVES", "POINTCLOUD", "VOLUME"}


def extract(zip_path: str, dest: str) -> list[str]:
	with zipfile.ZipFile(zip_path) as z:
		total = sum(i.file_size for i in z.infolist())
		if total > MAX_UNZIPPED:
			raise SystemExit(f"archive unpacks to {total / 1e9:.1f} GB, over the cap")
		z.extractall(dest)          # zipfile drops absolute paths and '..' components
	found = []
	for root, _dirs, files in os.walk(dest):
		for f in files:
			if f.lower().endswith(".blend"):
				found.append(os.path.join(root, f))
	return sorted(found)


def evaluated_tris(depsgraph) -> int:
	tris = 0
	for inst in depsgraph.object_instances:
		ob = inst.object
		if inst.is_instance and inst.parent is not None and inst.parent.name == ob.name:
			continue        # a curve/text object's own generated mesh: already counted with it
		if ob.type not in GEOMETRY or not ob.original.visible_get():
			continue
		try:
			me = ob.to_mesh()
		except RuntimeError:
			continue
		if me is not None:
			me.calc_loop_triangles()
			tris += len(me.loop_triangles)
		ob.to_mesh_clear()
	return tris


def scene_bounds(scene) -> list[float]:
	lo = [1e30] * 3
	hi = [-1e30] * 3
	for ob in scene.objects:
		if ob.type not in GEOMETRY or not ob.visible_get():
			continue
		for corner in ob.bound_box:
			w = ob.matrix_world @ mathutils.Vector(corner)
			for i in range(3):
				lo[i] = min(lo[i], w[i])
				hi[i] = max(hi[i], w[i])
	if lo[0] > hi[0]:
		return [0.0, 0.0, 0.0]
	return [round(hi[i] - lo[i], 2) for i in range(3)]


def material_info(mat) -> dict:
	info = {"name": mat.name, "nodes": mat.node_tree is not None, "principled": False,
			"image_textures": 0, "emission": False, "procedural_nodes": []}
	if info["nodes"]:
		for n in mat.node_tree.nodes:
			if n.type == "BSDF_PRINCIPLED":
				info["principled"] = True
				strength = n.inputs.get("Emission Strength")
				if strength is not None and strength.default_value > 0.0:
					col = n.inputs.get("Emission Color")
					if col is None or any(c > 0.0 for c in col.default_value[:3]) or col.is_linked:
						info["emission"] = True
			elif n.type == "EMISSION":
				info["emission"] = True
			elif n.type == "TEX_IMAGE" and n.image is not None:
				info["image_textures"] += 1
			elif n.type.startswith("TEX_"):
				info["procedural_nodes"].append(n.type)
	return info


def legacy_to_principled(mat) -> None:
	"""A material without a node tree (files from before 2.8, if versioning left one): give it a
	Principled BSDF with its viewport colour."""
	mat.use_nodes = True
	nt = mat.node_tree
	bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
	if bsdf is None:
		return
	bsdf.inputs["Base Color"].default_value = tuple(mat.diffuse_color)
	bsdf.inputs["Roughness"].default_value = mat.roughness
	bsdf.inputs["Metallic"].default_value = mat.metallic


def to_meshes(scene, depsgraph) -> int:
	"""Curves, text, surfaces and metaballs become mesh objects (modifiers applied)."""
	converted = 0
	for ob in list(scene.objects):
		if ob.type not in {"CURVE", "FONT", "SURFACE", "META"} or not ob.visible_get():
			continue
		me = bpy.data.meshes.new_from_object(ob.evaluated_get(depsgraph))
		if me is None or len(me.polygons) == 0:
			continue
		new = bpy.data.objects.new(ob.name + "_mesh", me)
		new.matrix_world = ob.matrix_world.copy()
		for coll in ob.users_collection:
			coll.objects.link(new)
		bpy.data.objects.remove(ob)
		converted += 1
	return converted


def report_file(path: str, out_dir: str) -> dict:
	bpy.context.preferences.filepaths.use_scripts_auto_execute = False
	bpy.ops.wm.open_mainfile(filepath=path, load_ui=False, use_scripts=False)
	scene = bpy.context.scene
	depsgraph = bpy.context.evaluated_depsgraph_get()
	by_type: dict[str, int] = {}
	modifiers: dict[str, int] = {}
	particles = 0
	for ob in bpy.data.objects:
		by_type[ob.type] = by_type.get(ob.type, 0) + 1
		for m in ob.modifiers:
			modifiers[m.type] = modifiers.get(m.type, 0) + 1
		particles += len(ob.particle_systems)
	images = []
	for img in bpy.data.images:
		if img.type != "IMAGE":
			continue
		packed = img.packed_file is not None
		exists = packed or os.path.exists(bpy.path.abspath(img.filepath))
		images.append({"name": img.name, "size": list(img.size), "packed": packed, "missing": not exists})
	in_materials = {n.image.name for m in bpy.data.materials if m.node_tree
			for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image is not None}
	drivers = sum(len(ad.drivers) for ad in (getattr(o, "animation_data", None) for o in bpy.data.objects) if ad)
	rep = {
		"file": os.path.basename(path),
		"saved_with": ".".join(str(v) for v in bpy.data.version),
		"render_engine": scene.render.engine,
		"objects": by_type,
		"tris": evaluated_tris(depsgraph),
		"size_m": scene_bounds(scene),
		"modifiers": modifiers,
		"particle_systems": particles,
		"drivers": drivers,
		"text_blocks": [t.name for t in bpy.data.texts],          # never run, only listed
		"materials": [material_info(m) for m in bpy.data.materials if m.users > 0],
		"images": images,
		# images the materials don't use: on old Blender Internal files these are usually the
		# texture slots that didn't survive into node materials (re-texture by hand)
		"images_not_in_materials": [i["name"] for i in images if i["name"] not in in_materials],
	}
	legacy = [m for m in bpy.data.materials if m.users > 0 and m.node_tree is None]
	for m in legacy:
		legacy_to_principled(m)
	rep["legacy_materials_converted"] = len(legacy)
	rep["converted_to_mesh"] = to_meshes(scene, depsgraph)
	glb = os.path.join(out_dir, os.path.splitext(os.path.basename(path))[0] + ".glb")
	bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_visible=True, export_apply=True,
			export_lights=False, export_cameras=False, export_animations=False)
	rep["glb"] = os.path.basename(glb)
	rep["glb_bytes"] = os.path.getsize(glb) if os.path.exists(glb) else 0
	return rep


def main() -> None:
	if len(sys.argv) != 3:
		raise SystemExit(__doc__)
	src = os.path.abspath(sys.argv[1])
	out_dir = os.path.abspath(sys.argv[2])
	os.makedirs(out_dir, exist_ok=True)
	blends = extract(src, os.path.join(out_dir, "raw")) if src.lower().endswith(".zip") else [src]
	reports = [report_file(b, out_dir) for b in blends]
	with open(os.path.join(out_dir, "report.json"), "w") as f:
		json.dump(reports, f, indent=1)
	for r in reports:
		mats = r["materials"]
		print(f"{r['file']}: Blender {r['saved_with']}, {r['tris']} tris, size {r['size_m']} m, "
				f"{len(mats)} materials ({sum(m['image_textures'] > 0 for m in mats)} textured, "
				f"{r['legacy_materials_converted']} legacy), {len(r['images'])} images "
				f"({sum(i['missing'] for i in r['images'])} missing, {len(r['images_not_in_materials'])} unused) -> {r['glb']} {r['glb_bytes'] // 1024} KB")


if __name__ == "__main__":
	main()
