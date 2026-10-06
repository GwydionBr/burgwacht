"""Rendert flache Gelände-Atlanten aus dem CC0-Modell, mit vier Varianten und weichen Kanten.

Eine Übergangsvariante enthält die 16 Kantenmasken nebeneinander (je 128×64 Pixel).
Die Textur wird in Blender über das auf die Kachel normierte Modell gelegt; Licht und Kamera
kommen aus der gemeinsamen Pipeline. Das Modell wird abgeflacht, damit benachbarte Kacheln
keine sichtbaren Seitenflächen oder Schatten aufeinander werfen.
"""
import math
import os

import bpy
from mathutils import Vector


def render_terrain(name, recipe, palette, pipeline):
    masks = 16 if recipe.get("transition_color") else 1
    for variant in range(recipe["variants"]):
        pipeline.reset_scene()
        bpy.context.scene.cycles.samples = 16
        camera = pipeline.add_camera()
        pipeline.add_sun()
        right = camera.rotation_euler.to_matrix() @ Vector((1, 0, 0))
        for mask in range(masks):
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=os.path.join(pipeline.MODEL_DIR, recipe["model"]))
            objects = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
            points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
            low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
            high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
            offset = right * ((mask - (masks - 1) / 2) * math.sqrt(2))
            material = terrain_material(recipe, palette, variant, mask, pipeline)
            for obj in objects:
                transform = obj.matrix_world.copy()
                obj.parent = None
                obj.matrix_world.identity()
                for vertex in obj.data.vertices:
                    point = transform @ vertex.co
                    vertex.co = ((point.x - low.x) / (high.x - low.x) - 0.5,
                                 (point.y - low.y) / (high.y - low.y) - 0.5, 0)
                obj.location = offset
                obj.data.materials.clear()
                obj.data.materials.append(material)
        scene = bpy.context.scene
        scene.render.resolution_x = 128 * masks
        scene.render.resolution_y = 64
        camera.data.ortho_scale = masks * math.sqrt(2)
        out = os.path.join(pipeline.SPRITE_DIR, name + ("_%d" % variant if variant else ""))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        pipeline.render_to(out + ".png")
        # Gelände liegt in der Bodenebene und wirft keinen eigenen Schlagschatten.
        image = bpy.data.images.new("Leerer Schatten", width=128 * masks, height=64, alpha=True)
        image.pixels = [0.0] * (128 * masks * 64 * 4)
        image.filepath_raw = out + "_shadow.png"
        image.file_format = "PNG"
        image.save()
        bpy.data.images.remove(image)
        pipeline.strip_metadata(out + "_shadow.png")
        print("Gelände gerendert: " + out)


def terrain_material(recipe, palette, variant, mask, pipeline):
    material = bpy.data.materials.new("Gelände")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    def math_node(operation, a, b=None):
        node = nodes.new("ShaderNodeMath")
        node.operation = operation
        for index, value in enumerate((a, b)):
            if value is None:
                continue
            if isinstance(value, (float, int)):
                node.inputs[index].default_value = value
            else:
                links.new(value, node.inputs[index])
        return node.outputs[0]
    coordinates = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = 14
    noise.inputs["Detail"].default_value = 2
    noise.inputs["Roughness"].default_value = 0.7
    noise.inputs["W"].default_value = variant * 3.17
    links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
    base = tuple(pipeline.srgb_to_linear(c) for c in palette[recipe["color"]]) + (1,)
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 0.14
    mix.inputs[1].default_value = base
    links.new(noise.outputs["Fac"], mix.inputs[2])
    color = mix.outputs[0]
    if mask:
        axes = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coordinates.outputs["Generated"], axes.inputs[0])
        distances = [math_node("SUBTRACT", 1.0, axes.outputs["Y"]),
                     math_node("SUBTRACT", 1.0, axes.outputs["X"]),
                     axes.outputs["Y"], axes.outputs["X"]]
        edge = 1.0
        for index, distance in enumerate(distances):
            if mask & (1 << index):
                edge = math_node("MINIMUM", edge, distance)
        # Unregelmäßiger, sanfter Saum; an der gemeinsamen Kante vollständig Sand.
        width = math_node("ADD", 0.18, math_node("MULTIPLY", noise.outputs["Fac"], 0.12))
        factor = math_node("SUBTRACT", 1.0, math_node("DIVIDE", edge, width))
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        links.new(factor, ramp.inputs[0])
        transition = nodes.new("ShaderNodeMixRGB")
        links.new(ramp.outputs["Color"], transition.inputs[0])
        links.new(color, transition.inputs[1])
        transition.inputs[2].default_value = tuple(pipeline.srgb_to_linear(c) for c in palette[recipe["transition_color"]]) + (1,)
        color = transition.outputs[0]
    bsdf = nodes.get("Principled BSDF")
    links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1
    bsdf.inputs["Specular IOR Level"].default_value = 0
    return material
