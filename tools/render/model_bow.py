"""Modelliert den fehlenden Langbogen; speichert Quelle und glTF ohne die Figur zu verändern."""
import os, math
import bpy
from mathutils import Vector
ROOT = os.path.dirname(os.path.abspath(__file__))


def rod(name, start, end, radius, color):
    midpoint = (Vector(start) + Vector(end)) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=(Vector(end)-Vector(start)).length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (Vector(end)-Vector(start)).to_track_quat('Z','Y').to_euler()
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    linear = tuple(value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4 for value in color)
    material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*linear, 1)
    obj.data.materials.append(material)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    points = [(0, .10, -.63), (0, -.03, -.46), (0, -.09, -.22), (0, -.11, 0), (0, -.09, .22), (0, -.03, .46), (0, .10, .63)]
    for index in range(len(points)-1):
        rod('Bogenholz',points[index],points[index+1],.035,(.36,.24,.14))
    rod('Sehne_Unten',points[0],(0,.10,0),.009,(.9,.84,.7))
    rod('Sehne_Oben',(0,.10,0),points[-1],.009,(.9,.84,.7))
    rod('Griff',(0,-.11,-.09),(0,-.11,.09),.043,(.18,.13,.08))
    folder = os.path.join(ROOT,'models','burgwacht')
    os.makedirs(folder,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder,'bow.blend'))
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder,'bow.glb'),export_format='GLB')

if __name__ == '__main__':
    main()
