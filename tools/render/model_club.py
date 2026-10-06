"""Modelliert den Knüppel des Räubers; Quelle und GLB behalten den Griffpunkt im Ursprung."""
import os
import bpy
from mathutils import Vector


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Die lokale y-Achse folgt dem Handknochen; die verdickte Spitze sitzt vor dem Griff.
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=.055, radius2=.105, depth=.9)
    obj = bpy.context.object
    obj.name = 'Knueppel'
    obj.rotation_euler = Vector((0, 1, 0)).to_track_quat('Z', 'Y').to_euler()
    obj.location = (0, .3, 0)
    material = bpy.data.materials.new('Holz')
    material.use_nodes = True
    material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.36, .24, .14, 1)
    obj.data.materials.append(material)
    folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'models', 'burgwacht')
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, 'club.blend'))
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder, 'club.glb'), export_format='GLB')


if __name__ == '__main__':
    main()
