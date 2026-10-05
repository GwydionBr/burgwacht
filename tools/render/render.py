"""Rendert Sprites aus Rezepten (ADR 0006). Läuft in Blender, aufgerufen über tools/render.sh.

Ein Rezept (tools/render/recipes/<pfad>.json) setzt glTF-Modelle aus tools/render/models/
zusammen; das Ergebnis landet als assets/sprites/<pfad>.png und dazu der Schlagschatten als
assets/sprites/<pfad>_shadow.png, beide gleich groß. Die Mitte der Grundfläche liegt genau in der
Bildmitte; so muss das Spiel nur das Bild auf die Mitte der Grundfläche setzen (Faktor 0,5).

Rezept:
    {
      "parts": [
        {
          "model": "kenney-fantasy-town/wall-wood.glb",
          "position": [0.5, 0.5, 0],   Kachelkanten; Ursprung = Mitte der Grundfläche am Boden
          "rotation": 90,              Grad um die Senkrechte, gegen den Uhrzeigersinn von oben
          "scale": 1,                  Zahl oder [x, y, z]
          "color": "wood",             optional: das ganze Teil in dieser Palettenfarbe
          "recolor": {"stone_light": "plaster"}   optional: Palettenfarbe → Palettenfarbe
        }
      ]
    }

Achsen: +x zeigt im Bild nach rechts unten (Kachel-x), +y nach rechts oben (gegen Kachel-y),
z nach oben. Eine Kachelkante ist eine Blender-Einheit.

Umfärben: Jede Fläche nimmt die Farbe ihrer Textur (bzw. ihres Materials) und bekommt die nächste
Farbe der Palette (tools/render/palette.json), danach greifen "recolor" und "color".
"""

import json
import math
import os
import sys

import bpy
import numpy
from mathutils import Matrix, Vector

## Genau diese Blender-Version (Hauptversion.Unterversion), sonst entstehen leicht andere Bilder.
REQUIRED_VERSION = (5, 2)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RENDER_DIR = os.path.join(ROOT, "tools", "render")
RECIPE_DIR = os.path.join(RENDER_DIR, "recipes")
MODEL_DIR = os.path.join(RENDER_DIR, "models")
PALETTE_PATH = os.path.join(RENDER_DIR, "palette.json")
SPRITE_DIR = os.path.join(ROOT, "assets", "sprites")

## Breite einer Bodenkachel im Bild: doppelte Auflösung des logischen Rasters (64×32).
TILE_WIDTH_PX = 128
## Pixel je Blender-Einheit in der Bildebene: Die Diagonale einer Kachel (√2) ist eine Kachelbreite.
PX_PER_UNIT = TILE_WIDTH_PX / math.sqrt(2)
## Kamera: 30° Neigung ergibt genau eine 2:1-Raute, 45° Drehung stellt die Kachel auf die Spitze.
CAMERA_TILT = 30.0
CAMERA_TURN = 45.0
CAMERA_DISTANCE = 50.0
## Sonne von links oben im Bild: Höhe über dem Boden und Richtung (0° = Schatten nach Bild-rechts-unten,
## entlang +x).
SUN_ELEVATION = 50.0
SUN_AZIMUTH = 20.0
SUN_STRENGTH = 3.2
SKY_COLOR = (0.52, 0.55, 0.6)
SKY_STRENGTH = 0.9
## Deckkraft des Schattenbilds, wo die Sonne ganz verdeckt ist.
SHADOW_OPACITY = 0.45
## Leerer Rand um Gebäude und Schatten im Bild (Pixel, doppelte Auflösung).
PADDING_PX = 4
SAMPLES = 64
## Gewicht der Helligkeit beim Suchen der nächsten Palettenfarbe (Farbton und Sättigung zählen 1).
LIGHTNESS_WEIGHT = 0.5


def main() -> None:
    check_version()
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    recipes = [recipe_path(name) for name in names] if names else all_recipes()
    sys.dont_write_bytecode = True
    sys.path.insert(0, RENDER_DIR)
    palette = load_palette()
    for path in recipes:
        render_recipe(path, palette)


def fail(message: str) -> None:
    print("Fehler: " + message, file=sys.stderr)
    sys.exit(1)


def check_version() -> None:
    found = tuple(bpy.app.version[:2])
    if found != REQUIRED_VERSION:
        fail("Blender %d.%d nötig, gefunden %s (ADR 0006). Andere Versionen rendern leicht andere Bilder."
            % (REQUIRED_VERSION + (bpy.app.version_string,)))


def recipe_path(name: str) -> str:
    path = os.path.join(RECIPE_DIR, name if name.endswith(".json") else name + ".json")
    if not os.path.isfile(path):
        fail("Rezept „%s“ fehlt (%s)" % (name, os.path.relpath(path, ROOT)))
    return path


def all_recipes() -> list:
    result = []
    for folder, _dirs, files in os.walk(RECIPE_DIR):
        result += [os.path.join(folder, f) for f in files if f.endswith(".json")]
    return sorted(result)


def load_palette() -> dict:
    with open(PALETTE_PATH, encoding="utf-8") as file:
        raw = json.load(file)
    return {name: hex_to_srgb(value) for name, value in raw.items()}


def hex_to_srgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def render_recipe(path: str, palette: dict) -> None:
    name = os.path.splitext(os.path.relpath(path, RECIPE_DIR))[0]
    with open(path, encoding="utf-8") as file:
        recipe = json.load(file)
    if "terrain" in recipe:
        from terrain import render_terrain
        render_terrain(name, recipe["terrain"], palette, sys.modules[__name__])
        return
    reset_scene()
    materials = {}
    objects = []
    for part in recipe["parts"]:
        objects += add_part(part, palette, materials)
    camera = add_camera()
    sun = add_sun()
    ground = add_ground()
    width, height = canvas_size(objects, camera, sun)
    camera.data.ortho_scale = width / PX_PER_UNIT
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    out = os.path.join(SPRITE_DIR, name)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    # Sprite: das Modell ohne Boden (der Boden wirft nur Licht zurück).
    ground.visible_camera = False
    render_to(out + ".png")

    # Schatten: nur der Boden als Schattenfänger, das Modell selbst unsichtbar.
    ground.visible_camera = True
    ground.is_shadow_catcher = True
    for obj in objects:
        obj.visible_camera = False
    render_to(out + "_shadow.png")
    blacken(out + "_shadow.png")
    print("Gerendert: %s (%d×%d)" % (os.path.relpath(out + ".png", ROOT), width, height))


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _pixel_cache.clear()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.seed = 0
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("Himmel")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = SKY_COLOR + (1.0,)
    background.inputs["Strength"].default_value = SKY_STRENGTH
    scene.world = world


def add_part(part: dict, palette: dict, materials: dict) -> list:
    model = os.path.join(MODEL_DIR, part["model"])
    if not os.path.isfile(model):
        fail("Modell „%s“ fehlt" % part["model"])
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=model)
    imported = [obj for obj in bpy.data.objects if obj not in before]
    scale = part.get("scale", 1)
    scale = Vector(scale) if isinstance(scale, list) else Vector((scale, scale, scale))
    placement = Matrix.LocRotScale(
        Vector(part.get("position", [0, 0, 0])),
        Matrix.Rotation(math.radians(part.get("rotation", 0)), 4, "Z").to_quaternion(),
        scale)
    for obj in imported:
        if obj.parent is None:
            obj.matrix_world = placement @ obj.matrix_world
    bpy.context.view_layer.update()
    meshes = [obj for obj in imported if obj.type == "MESH"]
    for obj in meshes:
        # Flach schattiert wie Low-Poly; geglättete Normalen werfen auf schrägen Flächen Streifen.
        obj.data.shade_flat()
        recolor(obj, part, palette, materials)
    return meshes


## Färbt jede Fläche auf die nächste Palettenfarbe um, danach "recolor" und "color" des Teils.
def recolor(obj, part: dict, palette: dict, materials: dict) -> None:
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    names = []
    for poly in mesh.polygons:
        source = mesh.materials[poly.material_index] if mesh.materials else None
        color = face_color(source, mesh, poly, uv_layer)
        name = nearest(color, palette)
        name = part.get("recolor", {}).get(name, name)
        name = part.get("color", name)
        if name not in palette:
            fail("Palettenfarbe „%s“ fehlt (%s)" % (name, part["model"]))
        names.append(name)
    used = sorted(set(names))
    mesh.materials.clear()
    for name in used:
        mesh.materials.append(palette_material(name, palette, materials))
    for poly, name in zip(mesh.polygons, names):
        poly.material_index = used.index(name)


def face_color(material, mesh, poly, uv_layer) -> tuple:
    image, factor = base_color_of(material)
    if image is None or uv_layer is None:
        return factor
    uv = Vector((0.0, 0.0))
    for index in poly.loop_indices:
        uv += uv_layer.data[index].uv
    uv /= len(poly.loop_indices)
    width, height = image.size
    x = min(width - 1, max(0, int((uv.x % 1.0) * width)))
    y = min(height - 1, max(0, int((uv.y % 1.0) * height)))
    pixels = image_pixels(image)
    return tuple(pixels[y, x, :3] * numpy.array(factor))


_pixel_cache = {}


def image_pixels(image) -> numpy.ndarray:
    key = image.filepath or image.name
    if key not in _pixel_cache:
        width, height = image.size
        buffer = numpy.empty(width * height * 4, dtype=numpy.float32)
        image.pixels.foreach_get(buffer)
        _pixel_cache[key] = buffer.reshape(height, width, 4)
    return _pixel_cache[key]


## Bild und Farbfaktor der Grundfarbe eines Materials (Principled BSDF aus dem glTF-Import).
def base_color_of(material) -> tuple:
    if material is None or not material.use_nodes:
        return None, (0.8, 0.8, 0.8)
    for node in material.node_tree.nodes:
        if node.type != "BSDF_PRINCIPLED":
            continue
        socket = node.inputs["Base Color"]
        factor = tuple(socket.default_value[:3])
        for link in socket.links:
            image_node = find_image_node(link.from_node)
            if image_node is not None:
                return image_node.image, (1.0, 1.0, 1.0)
        return None, tuple(linear_to_srgb(c) for c in factor)
    return None, (0.8, 0.8, 0.8)


def find_image_node(node):
    if node.type == "TEX_IMAGE":
        return node
    for socket in node.inputs:
        for link in socket.links:
            found = find_image_node(link.from_node)
            if found is not None:
                return found
    return None


def linear_to_srgb(channel: float) -> float:
    return channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


## Nächste Palettenfarbe in OKLab; die Helligkeit zählt nur halb, damit eine hellere oder dunklere
## Stelle eines Farbverlaufs bei ihrem Farbton bleibt.
def nearest(color: tuple, palette: dict) -> str:
    lab = oklab(color)
    def distance(name: str) -> float:
        other = oklab(palette[name])
        return LIGHTNESS_WEIGHT * (lab[0] - other[0]) ** 2 + (lab[1] - other[1]) ** 2 + (lab[2] - other[2]) ** 2
    return min(sorted(palette), key=distance)


def oklab(color: tuple) -> tuple:
    r, g, b = (srgb_to_linear(c) for c in color)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def palette_material(name: str, palette: dict, materials: dict):
    if name not in materials:
        material = bpy.data.materials.new("palette_" + name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in palette[name]) + (1.0,)
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
        materials[name] = material
    return materials[name]


def add_camera():
    data = bpy.data.cameras.new("Kamera")
    data.type = "ORTHO"
    data.sensor_fit = "HORIZONTAL"
    data.clip_start = 0.1
    data.clip_end = CAMERA_DISTANCE * 2
    camera = bpy.data.objects.new("Kamera", data)
    camera.rotation_euler = (math.radians(90 - CAMERA_TILT), 0.0, math.radians(CAMERA_TURN))
    forward = camera.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    camera.location = -forward * CAMERA_DISTANCE
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return camera


def add_sun():
    data = bpy.data.lights.new("Sonne", "SUN")
    data.energy = SUN_STRENGTH
    data.angle = math.radians(2.0)
    sun = bpy.data.objects.new("Sonne", data)
    sun.rotation_euler = sun_direction().to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(sun)
    return sun


## Richtung, in die das Sonnenlicht fällt.
def sun_direction() -> Vector:
    elevation = math.radians(SUN_ELEVATION)
    azimuth = math.radians(SUN_AZIMUTH)
    return Vector((math.cos(elevation) * math.cos(azimuth), math.cos(elevation) * math.sin(azimuth),
        -math.sin(elevation)))


def add_ground():
    mesh = bpy.data.meshes.new("Boden")
    size = 20.0
    mesh.from_pydata([(-size, -size, 0), (size, -size, 0), (size, size, 0), (-size, size, 0)], [], [(0, 1, 2, 3)])
    ground = bpy.data.objects.new("Boden", mesh)
    material = bpy.data.materials.new("Boden")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.25, 0.2, 1.0)
    mesh.materials.append(material)
    bpy.context.scene.collection.objects.link(ground)
    return ground


## Bildgröße (gerade Zahlen, Mitte der Grundfläche in der Mitte), die alle Teile und ihren Schatten fasst.
def canvas_size(objects: list, camera, sun) -> tuple:
    rotation = camera.rotation_euler.to_matrix()
    right = rotation @ Vector((1, 0, 0))
    up = rotation @ Vector((0, 1, 0))
    light = sun_direction()
    half_width = 0.0
    half_height = 0.0
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            shadow = point - light * (point.z / light.z)
            for p in (point, shadow):
                half_width = max(half_width, abs(p.dot(right)) * PX_PER_UNIT)
                half_height = max(half_height, abs(p.dot(up)) * PX_PER_UNIT)
    return (2 * (math.ceil(half_width) + PADDING_PX), 2 * (math.ceil(half_height) + PADDING_PX))


def render_to(path: str) -> None:
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    strip_metadata(path)


## Abschnitte eines PNG mit Metadaten (Text wie die Renderzeit, Datum, Exif).
METADATA_CHUNKS = {b"tEXt", b"zTXt", b"iTXt", b"tIME", b"eXIf"}


## Entfernt die Metadaten aus einem PNG: Gleiche Bilder ergeben so gleiche Dateien.
def strip_metadata(path: str) -> None:
    with open(path, "rb") as file:
        data = file.read()
    result = bytearray(data[:8])
    offset = 8
    while offset < len(data):
        length = int.from_bytes(data[offset:offset + 4], "big")
        end = offset + 12 + length
        if data[offset + 4:offset + 8] not in METADATA_CHUNKS:
            result += data[offset:end]
        offset = end
    with open(path, "wb") as file:
        file.write(bytes(result))


## Macht das Schattenbild schwarz; die Deckkraft bleibt, auf SHADOW_OPACITY begrenzt.
def blacken(path: str) -> None:
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = numpy.empty(width * height * 4, dtype=numpy.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(-1, 4)
    pixels[:, 3] = numpy.clip(pixels[:, 3], 0.0, 1.0) * SHADOW_OPACITY
    pixels[:, :3] = 0.0
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    strip_metadata(path)


main()
