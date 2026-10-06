"""Erzeugt die eigene Flamme mit vier flackernden Posen, samt modellierter Quelldatei."""
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent
POSES = [(1, 1, 1, 0), (0.8, 1.1, 0.8, 18), (1.1, 0.8, 1.13, -15), (0.9, 1, 0.9, 10)]
LAYERS = [(0.14, 0.40, (0.68, 0.31, 0.23)), (0.09, 0.29, (0.83, 0.68, 0.27))]


def linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


# Quelldatei und exportierte Posen mit Blender 5.2 erzeugen; die Sprites rendert tools/render.sh.
if tuple(bpy.app.version[:2]) != (5, 2):
    raise RuntimeError("Blender 5.2 nötig")
bpy.ops.wm.read_factory_settings(use_empty=True)
for layer, (radius, height, color) in enumerate(LAYERS):
    vertices = [(radius * math.cos(i * math.tau / 5), radius * math.sin(i * math.tau / 5), 0) for i in range(5)]
    vertices += [(radius * 0.4 * math.cos(i * math.tau / 5), radius * 0.4 * math.sin(i * math.tau / 5), height * 0.65) for i in range(5)]
    vertices.append((radius * 0.3, 0, height))
    faces = [tuple(range(4, -1, -1))]
    faces += [(i, (i + 1) % 5, (i + 1) % 5 + 5, i + 5) for i in range(5)]
    faces += [(i + 5, (i + 1) % 5 + 5, 10) for i in range(5)]
    mesh = bpy.data.meshes.new("Flamme")
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new("Flamme%d" % layer, mesh)
    bpy.context.collection.objects.link(obj)
    material = bpy.data.materials.new("Feuerfarbe")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = tuple(linear(c) for c in color) + (1,)
    obj.data.materials.append(material)
    obj.location.z = 0.04 + layer * 0.005
    if layer:
        # Die helle Zunge liegt auf der zur Kamera gerichteten Seite der äußeren Flamme.
        obj.location.x = 0.08
        obj.location.y = -0.08
    for frame, (sx, sy, sz, rotation) in enumerate(POSES):
        obj.scale = (sx, sy, sz)
        obj.rotation_euler.z = math.radians(rotation + layer * 70)
        obj.keyframe_insert("scale", frame=frame)
        obj.keyframe_insert("rotation_euler", frame=frame)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "campfire-flame.blend"))
for frame in range(4):
    bpy.context.scene.frame_set(frame)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / ("campfire-flame-%d.glb" % frame)), export_format="GLB", export_animations=False)
