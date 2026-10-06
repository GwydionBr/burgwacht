"""Erzeugt eigene Low-Poly-Ausstattung für Arbeitsstätten mit Blender 5.2.

Die .blend-Datei erhält alle fünf Modelle; je Modell entsteht eine glTF-Datei für die Rezepte.
Licht und Palette stammen beim Rendern unverändert aus der gemeinsamen Pipeline.
"""
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, '..', '..', 'palette.json'), encoding='utf-8') as file:
    PALETTE = json.load(file)


def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    color = PALETTE[name].lstrip('#')
    mat.diffuse_color = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1,)
    mat.use_nodes = True
    linear = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in mat.diffuse_color[:3])
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = linear + (1,)
    return mat


def box(name, center, scale, color, rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler.z = math.radians(rotation)
    obj.data.materials.append(material(color))
    return obj


def mouth(name, width, height, y, color):
    points = [(-width / 2, y, 0.07), (width / 2, y, 0.07), (width / 2, y, height * .65),
              (width * .3, y, height), (-width * .3, y, height), (-width / 2, y, height * .65)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], [list(range(len(points)))])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(color))
    return obj


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
all_models = {}

# Backofen mit steinernem Gewölbe und sichtbarem dunklem Eingang.
before = set(bpy.data.objects)
box('Ofensockel', (0, 0, .2), (1, .9, .4), 'stone')
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.5, location=(0, 0, .4))
bpy.context.object.name = 'Ofengewölbe'
bpy.context.object.scale = (1, .9, .85)
bpy.context.object.data.materials.append(material('stone_light'))
mouth('Backöffnung', .55, .49, -.457, 'dark')
all_models['bread-oven'] = list(set(bpy.data.objects) - before)

# Esse, glühende Kohlen und hinterer Steinschild.
before = set(bpy.data.objects)
box('Essensockel', (0, 0, .24), (1, .8, .48), 'stone_dark')
box('Steinschild', (0, .32, .7), (1, .18, .9), 'stone')
box('Kohle', (0, -.05, .49), (.7, .5, .04), 'dark')
for x, y, size in [(-.15, -.12, .12), (.15, .02, .15), (.0, -.2, .11)]:
    box('Glut', (x, y, .52), (size, size, .06), 'gold' if x > 0 else 'cloth_red')
all_models['forge'] = list(set(bpy.data.objects) - before)

# Sichtbarer Grubeneingang mit Holzrahmen und dunklem Stollen, keine neue Spiellogik.
before = set(bpy.data.objects)
for x in [-.4, .4]:
    box('Grubenstütze', (x, 0, .42), (.15, .65, .84), 'wood_dark')
box('Querbalken', (0, 0, .85), (1, .75, .18), 'wood')
box('Stollendunkel', (0, .28, .42), (.7, .04, .84), 'dark')
box('Grubendach', (0, .1, .99), (1.12, .9, .1), 'stone_dark')
all_models['mine-entrance'] = list(set(bpy.data.objects) - before)

# Sägebock, auch als Hebebock im Steinbruch erkennbar.
before = set(bpy.data.objects)
for y in [-.35, .35]:
    for x in [-.22, .22]:
        obj = box('Bockbein', (x, y, .28), (.1, .12, .65), 'wood')
        obj.rotation_euler.y = math.radians(25 if x < 0 else -25)
box('Auflage', (0, 0, .52), (.16, .9, .14), 'wood_light')
all_models['sawbuck'] = list(set(bpy.data.objects) - before)

# Bogengestell: gespannte Bögen und ringförmiges Übungsziel.
before = set(bpy.data.objects)
for x in [-.35, .35]:
    box('Gestellpfosten', (x, .12, .55), (.08, .12, 1.1), 'wood_dark')
box('Gestellriegel', (0, .12, .96), (.85, .12, .08), 'wood')
for x in [-.23, .08]:
    old = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, 'bow.glb'))
    imported = set(bpy.data.objects) - old
    for obj in imported:
        if obj.parent is None:
            obj.location += Vector((x, 0, .55))
            obj.scale *= .6
    for obj in imported:
        if obj.type == "MESH":
            obj.data.materials.clear()
            obj.data.materials.append(material("plaster" if "Sehne" in obj.name else "wood_dark"))
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=.27, depth=.045, location=(.0, -.12, .55), rotation=(math.pi / 2, 0, 0))
bpy.context.object.name = 'Übungsziel'
bpy.context.object.data.materials.append(material('thatch'))
for radius, color, y in [(.17, 'cloth_red', -.147), (.07, 'plaster', -.15)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=.006, location=(0, y, .55), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(material(color))
all_models['bow-rack'] = list(set(bpy.data.objects) - before)

# Alle Quellen nebeneinander speichern; Exporte bleiben um den lokalen Ursprung zentriert.
for name, objects in all_models.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, name + '.glb'), export_format='GLB', use_selection=True)
for index, objects in enumerate(all_models.values()):
    for obj in objects:
        if obj.parent is None:
            obj.location.x += index * 2
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'trade-fixtures.blend'))
