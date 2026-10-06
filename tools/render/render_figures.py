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
    proportions = recipe.get('proportions')
    snapshots = []
    if proportions:
        for obj in objects:
            if not hidden_by_parent(obj):
                obj.hide_render = True
                mesh = bpy.data.meshes.new('Pose')
                snapshot = bpy.data.objects.new(obj.name + '_Proportion', mesh)
                bpy.context.scene.collection.objects.link(snapshot)
                snapshots.append((obj, snapshot))
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
                if proportions:
                    reshape_pose(snapshots, rigs[0], proportions)
                pipeline.render_to('%s_%s_%d_%d.png' % (out, animation, direction, frame))
    shutil.copyfile(out + '_idle_0_0.png', out + '.png')
    # Bodenschatten wird wie bisher in der Ansicht gezeichnet; die Datenschnittstelle bleibt gleich.
    image = bpy.data.images.new('Schatten', width=width, height=height, alpha=True)
    image.pixels.foreach_set([0.0] * (width * height * 4))
    image.filepath_raw = out + '_shadow.png'
    image.file_format = 'PNG'
    image.save()
    pipeline.strip_metadata(out + '_shadow.png')


def reshape_pose(snapshots, rig, settings):
    """Formt die echte Skelettpose anatomisch um; der Boden bleibt bei z=0 fest."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    rig_inverse = rig.matrix_world.inverted()
    head = rig.pose.bones[settings['head_bone']].matrix.translation
    hip = settings['hip_height']
    for source, target in snapshots:
        previous = target.data
        evaluated = source.evaluated_get(depsgraph)
        mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
        to_rig = rig_inverse @ evaluated.matrix_world
        from_rig = to_rig.inverted()
        for vertex in mesh.vertices:
            point = to_rig @ vertex.co
            if source.name == settings['head_mesh']:
                point = head + (point - head) * settings['head_scale']
            point.x *= settings['body_width']
            point.y *= settings['body_width']
            # Beine gewinnen Länge, darüber beginnt der Rumpf ohne Sprung.
            point.z = (min(point.z, hip) * settings['leg_length']
                + max(0.0, point.z - hip) * settings['torso_length'])
            vertex.co = from_rig @ point
        target.data = mesh
        target.matrix_world = evaluated.matrix_world.copy()
        if previous is not None:
            bpy.data.meshes.remove(previous)


def hidden_by_parent(obj):
    """Ausgeblendete Ausrüstung kann eigene untergeordnete Meshes enthalten."""
    while obj is not None:
        if obj.hide_render:
            return True
        obj = obj.parent
    return False
