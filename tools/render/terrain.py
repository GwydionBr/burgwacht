"""Rendert flache Gelände-Atlanten aus dem CC0-Modell, mit vier Varianten und weichen Kanten.

Grundbilder haben vier Varianten; transparente Übergänge enthalten acht Kanten/Ecken
nebeneinander (je 128×64 Pixel). Die ursprüngliche Wiese unterstützt weiterhin 16 Kantenmasken.
Die Textur wird in Blender über das auf die Kachel normierte Modell gelegt; Licht und Kamera
kommen aus der gemeinsamen Pipeline. Das Modell wird abgeflacht, damit benachbarte Kacheln
keine sichtbaren Seitenflächen oder Schatten aufeinander werfen.
"""
import math
import os

import bpy
import numpy
from mathutils import Vector


def render_terrain(name, recipe, palette, pipeline):
    if recipe.get("edge_depth"):
        render_edge(name, recipe, palette, pipeline)
        return
    masks = 8 if recipe.get("overlay") else (16 if recipe.get("transition_color") else 1)
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
        if not recipe.get("overlay"):
            bleed_tile_edges(out + ".png", masks, pipeline)
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
    if mask and recipe.get("transition_color"):
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
    alpha = None
    if recipe.get("overlay"):
        axes = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coordinates.outputs["Generated"], axes.inputs[0])
        distances = [math_node("SUBTRACT", 1.0, axes.outputs["Y"]),
                     math_node("SUBTRACT", 1.0, axes.outputs["X"]),
                     axes.outputs["Y"], axes.outputs["X"]]
        if mask < 4:
            distance = distances[mask]
        else:
            corner = mask - 4
            distance = math_node("ADD", distances[corner], distances[(corner + 1) % 4])
        width = math_node("ADD", 0.18, math_node("MULTIPLY", noise.outputs["Fac"], 0.12))
        factor = math_node("SUBTRACT", 1.0, math_node("DIVIDE", distance, width))
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        links.new(factor, ramp.inputs[0])
        alpha = ramp.outputs["Color"]
        if recipe.get("shore_color"):
            shore = nodes.new("ShaderNodeMixRGB")
            links.new(math_node("MINIMUM", 1.0, math_node("MULTIPLY", distance, 14.0)), shore.inputs[0])
            links.new(color, shore.inputs[1])
            shore.inputs[2].default_value = tuple(pipeline.srgb_to_linear(c) for c in palette[recipe["shore_color"]]) + (1,)
            color = shore.outputs[0]
    bsdf = nodes.get("Principled BSDF")
    links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1
    bsdf.inputs["Specular IOR Level"].default_value = 0
    if alpha is not None:
        links.new(alpha, bsdf.inputs["Alpha"])
    return material


def render_edge(name, recipe, palette, pipeline):
    """Frontflächen als aus dem CC0-Geländemodell extrudierte Scholle, ohne obere Raute."""
    pipeline.reset_scene()
    camera = pipeline.add_camera()
    pipeline.add_sun()
    right = camera.rotation_euler.to_matrix() @ Vector((1, 0, 0))
    for side in range(2):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(pipeline.MODEL_DIR, recipe["model"]))
        imported = [o for o in bpy.data.objects if o not in before]
        points = [o.matrix_world @ v.co for o in imported if o.type == "MESH" for v in o.data.vertices]
        low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
        high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
        # Modellgrenzen liefern die Kachel; die Front wird bis zur vereinbarten Erdkante extrudiert.
        if side == 0:
            source_top = [(high.x, high.y), (high.x, low.y)]
        else:
            source_top = [(high.x, low.y), (low.x, low.y)]
        top = [((x - low.x) / (high.x - low.x) - 0.5,
                (y - low.y) / (high.y - low.y) - 0.5, 0) for x, y in source_top]
        vertices = top + [(p[0], p[1], -recipe["edge_depth"]) for p in reversed(top)]
        for obj in imported:
            bpy.data.objects.remove(obj, do_unlink=True)
        mesh = bpy.data.meshes.new("Erdkante")
        mesh.from_pydata(vertices, [], [(0, 1, 2, 3)])
        obj = bpy.data.objects.new("Erdkante", mesh)
        obj.visible_shadow = False
        bpy.context.scene.collection.objects.link(obj)
        obj.location = right * ((side - 0.5) * math.sqrt(2))
        mesh.materials.append(terrain_material(recipe, palette, 0, 0, pipeline))
    scene = bpy.context.scene
    scene.render.resolution_x = 256
    scene.render.resolution_y = 104
    # Zusätzliche Höhe liegt ausschließlich unter dem Kachelmittelpunkt.
    camera.location += camera.rotation_euler.to_matrix() @ Vector((0, -20 / pipeline.PX_PER_UNIT, 0))
    camera.data.ortho_scale = 2 * math.sqrt(2)
    out = os.path.join(pipeline.SPRITE_DIR, name)
    pipeline.render_to(out + ".png")


def bleed_tile_edges(path, cells, pipeline):
    """Gerenderte Farbe über die Filterkante hinausziehen; verhindert schwarze Subpixel-Nähte."""
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = numpy.empty(width * height * 4, dtype=numpy.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    for cell in range(cells):
        part = pixels[:, cell * 128:(cell + 1) * 128]
        opaque = part[:, :, 3] > 0.99
        for _ in range(2):
            previous = part.copy()
            filled = opaque.copy()
            for dy, dx in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                shifted = numpy.roll(previous, (dy, dx), axis=(0, 1))
                valid = numpy.roll(opaque, (dy, dx), axis=(0, 1))
                if dy == 1:
                    valid[0] = False
                elif dy == -1:
                    valid[-1] = False
                elif dx == 1:
                    valid[:, 0] = False
                elif dx == -1:
                    valid[:, -1] = False
                added = valid & ~filled
                part[added] = shifted[added]
                part[added, 3] = 1
                filled |= added
            opaque = filled
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    pipeline.strip_metadata(path)
