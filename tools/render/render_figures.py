"""Rendert echte glTF-Animationen in acht Kachelrichtungen mit unverändertem Fußpunkt."""
import math
import os
import shutil
import bpy
from mathutils import Matrix, Vector


def render_figure(recipe, name, palette, pipeline):
    pipeline.reset_scene()
    # Typfarbe wird direkt aus units.json gelesen, damit Rezept und Spiel nicht auseinanderlaufen.
    palette = dict(palette)
    if 'unit_color' in recipe:
        import json
        with open(os.path.join(pipeline.ROOT, 'data', 'units.json'), encoding='utf-8') as file:
            units = json.load(file)
        palette['unit_cloth'] = pipeline.hex_to_srgb(units[recipe['unit_color']]['color'])
    objects = []
    attachments = []
    for part in recipe['parts']:
        meshes = pipeline.add_part(part, palette, {})
        objects += meshes
        if 'bone' in part:
            attachments += [(obj, part, obj.matrix_world.copy()) for obj in meshes]

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
        if settings.get('bow_pose') or settings.get('work_pose'):
            action = action.copy()
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
                phase = frame / max(settings['frames'] - 1, 1)
                if settings.get('bow_pose'):
                    bow_pose(rigs[0], phase)
                if settings.get('work_pose'):
                    work_pose(rigs[0], phase)
                bpy.context.view_layer.update()
                for obj, part, placement in attachments:
                    rig = rigs[0]
                    bone = rig.pose.bones[part['bone']]
                    # Aufrechte Geräte bleiben senkrecht, folgen aber dem animierten Griffpunkt.
                    socket = Matrix.Translation(bone.matrix.translation) if part.get('upright') else bone.matrix
                    obj.hide_render = animation not in part.get('visible_in', [animation]) or phase >= part.get('hide_after', 2)
                    local = placement
                    if part.get('draw_string') and obj.name.startswith('Sehne_'):
                        draw = bow_draw(phase) if settings.get('bow_pose') else 0
                        tip = Vector((0, .10, .63 if 'Oben' in obj.name else -.63))
                        center = Vector((0, .10 + .27*draw, 0))
                        local = Matrix.LocRotScale((tip+center)/2, (tip-center).to_track_quat('Z','Y'), Vector((1,1,(tip-center).length/.63)))
                    obj.matrix_world = rig.matrix_world @ socket @ local
                bpy.context.view_layer.update()
                pipeline.render_to('%s_%s_%d_%d.png' % (out, animation, direction, frame))
    shutil.copyfile(out + '_idle_0_0.png', out + '.png')
    # Bodenschatten wird wie bisher in der Ansicht gezeichnet; die Datenschnittstelle bleibt gleich.
    image = bpy.data.images.new('Schatten', width=width, height=height, alpha=True)
    image.pixels.foreach_set([0.0] * (width * height * 4))
    image.filepath_raw = out + '_shadow.png'
    image.file_format = 'PNG'
    image.save()
    pipeline.strip_metadata(out + '_shadow.png')



def bow_pose(rig, phase):
    """Retargetet die Armhaltung auf einen senkrechten Bogen: links halten, rechts ziehen und lösen."""
    # Die Originalglieder behalten ihre Länge; nur die Gelenkstellungen ändern sich.
    draw = bow_draw(phase)
    wrists = {'l': Vector((.20, -.47, 1.13)), 'r': Vector((-.10, -.31 + .27*draw, 1.13))}
    for side, wrist in wrists.items():
        pose_arm(rig, side, wrist)


def bow_draw(phase):
    return min(phase / .65, 1.0) if phase < .75 else max(0, (1-phase) / .25)


def work_pose(rig, phase):
    """Hebt und senkt die Werkzeughand zum Vorkommen, ohne Gliederlängen zu verändern."""
    swing = (1-math.cos(phase*2*math.pi))/2
    wrist = Vector((-.20, -.25-.38*swing, 1.75-.80*swing))
    upper = rig.pose.bones['upperarm.r']
    lower = rig.pose.bones['lowerarm.r']
    shoulder = upper.bone.head_local.copy()
    axis = (wrist-shoulder).normalized()
    wrist = shoulder + axis*min((wrist-shoulder).length, upper.bone.length+lower.bone.length-.001)
    pose_arm(rig, 'r', wrist)


def pose_arm(rig, side, wrist):
    """Stellt einen Arm mit unveränderten Gliederlängen auf den Griffpunkt ein."""
    upper = rig.pose.bones['upperarm.'+side]
    lower = rig.pose.bones['lowerarm.'+side]
    shoulder = upper.bone.head_local.copy()
    a, b = upper.bone.length, lower.bone.length
    axis = (wrist-shoulder).normalized()
    distance = min((wrist-shoulder).length, a+b-.001)
    along = (a*a-b*b+distance*distance)/(2*distance)
    normal = Vector((1 if side=='l' else -1, 0, .25))
    normal = (normal-axis*normal.dot(axis)).normalized()
    elbow = shoulder + axis*along + normal*math.sqrt(max(0,a*a-along*along))
    for name, head, tail in [('upperarm',shoulder,elbow),('lowerarm',elbow,wrist),('wrist',wrist,wrist+Vector((0,-.07,0))),('hand',wrist+Vector((0,-.07,0)),wrist+Vector((0,-.18,0)))]:
        bone = rig.pose.bones[name+'.'+side]
        rotation = (tail-head).to_track_quat('Y','Z')
        bone.rotation_mode = 'QUATERNION'
        bone.matrix = Matrix.LocRotScale(head, rotation, Vector((1,1,1)))
        for channel in ['location', 'rotation_quaternion', 'scale']:
            bone.keyframe_insert(data_path=channel, frame=bpy.context.scene.frame_current)
        bpy.context.view_layer.update()
