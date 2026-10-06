"""Rendert echte glTF-Animationen in acht Kachelrichtungen mit unverändertem Fußpunkt."""
import math
import os
import shutil
import bpy


def render_figure(recipe, name, palette, pipeline):
    pipeline.reset_scene()
    objects = []
    for part in recipe['parts']:
        objects += pipeline.add_part(part, palette, {})
    for obj in objects:
        if obj.name in recipe.get('hide', []):
            obj.hide_render = True
    anchor = bpy.data.objects.new('Richtung', None)
    bpy.context.scene.collection.objects.link(anchor)
    for obj in list(bpy.context.scene.objects):
        if obj != anchor and obj.parent is None:
            obj.parent = anchor
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    for rig in rigs:
        for track in rig.animation_data.nla_tracks:
            track.mute = True
    camera = pipeline.add_camera()
    pipeline.add_sun()
    width, height = recipe['canvas']
    camera.data.ortho_scale = width / pipeline.PX_PER_UNIT
    scene = bpy.context.scene
    scene.cycles.samples = 16
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    out = os.path.join(pipeline.SPRITE_DIR, name)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    for animation, settings in recipe['animations'].items():
        action = bpy.data.actions[settings['action']]
        for rig in rigs:
            rig.animation_data.action = action
            if action.slots:
                rig.animation_data.action_slot = action.slots[0]
        start, end = action.frame_range
        for direction in range(8):
            # Das Modell schaut entlang -y; Kachel-y entspricht Blender -y.
            anchor.rotation_euler.z = math.pi / 2 - direction * math.pi / 4
            for frame in range(settings['frames']):
                scene.frame_set(int(start + (end - start) * frame / settings['frames']))
                pipeline.render_to('%s_%s_%d_%d.png' % (out, animation, direction, frame))
    shutil.copyfile(out + '_idle_0_0.png', out + '.png')
    # Bodenschatten wird wie bisher in der Ansicht gezeichnet; die Datenschnittstelle bleibt gleich.
    image = bpy.data.images.new('Schatten', width=width, height=height, alpha=True)
    image.pixels.foreach_set([0.0] * (width * height * 4))
    image.filepath_raw = out + '_shadow.png'
    image.file_format = 'PNG'
    image.save()
    pipeline.strip_metadata(out + '_shadow.png')
