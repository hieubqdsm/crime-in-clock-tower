"""Wooden artist mannequin: build + in-place walk cycle + glTF export + previews.

Run headless (no window):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
      --factory-startup --python tools/blender/make_mannequin.py

Deliverable (committed with this script):
  assets/models/mannequin.glb   - in-place Walk_loop + Idle_loop (breathing),
                                  faces -Y in Blender (= +Z in Godot)

Previews (scratch, outside the repo):
  D:/GODOTPRJ/blender_out/mannequin/preview/frame_XXX.png

Design: artist's articulated wooden figure ~1.8 m tall. Beech-wood body,
darker wood for the ball joints. Limbs hang from joint-origin pivots so the
walk cycle rotates them around the correct point (no transform_apply — see
skill references/blender52-pitfalls.md §1).
Knees fold BACKWARD ONLY: the per-leg phase weight is clamped to [0,1] and
smoothstepped before applying BEND_KNEE — never multiplied by the leg sign
(the old form made the R knee hyperextend forward, worst in the rest pose).
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GLB_OUT = os.path.join(REPO, "assets", "models", "mannequin.glb")
PREVIEW_DIR = r"D:\GODOTPRJ\blender_out\mannequin\preview"
os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)

# ------------------------------- config ------------------------------------
FPS = 24
CYCLE = 24                    # frames per walk cycle (1 s)
END = CYCLE                   # in-place loop: one cycle keyed, f=1 pose == f=25 pose

A_LEG = math.radians(26)      # thigh swing amplitude
A_ARM = math.radians(30)      # upper-arm swing amplitude
BEND_KNEE = math.radians(45)  # max knee bend (smoothstep lowers the average)
BEND_ELBOW = math.radians(18) # constant elbow bend (arms never dead straight)
CHEST_SWAY = math.radians(3)
BOB = 0.02                    # rise at the legs-together passing pose
LEG_LEN = 0.82                # thigh + shin, for the contact-pose hip drop
DROP = LEG_LEN * (1 - math.cos(A_LEG))  # hip drop when legs are split (contact)
IDLE_SWAY = math.radians(0.8) # idle clip: faint chest breathing sway
IDLE_BOB = 0.004              # idle clip: tiny root lift per breath


def report(msg):
    print("[mannequin] " + msg, flush=True)


# ------------------------------- scene -------------------------------------
scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
scene.frame_start = 1
scene.frame_end = END
scene.render.fps = FPS


def wood_material(name, base, rough=0.8):
    mat = bpy.data.materials.new(name)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = rough
    return mat


MAT_WOOD = wood_material("WoodBeech", (0.55, 0.36, 0.16, 1))   # light beech body
MAT_JOINT = wood_material("WoodJoint", (0.33, 0.19, 0.08, 1))  # darker ball joints


def part(name, mesh, location, parent=None, mat=MAT_WOOD):
    """Link a mesh object at its world rest location. All parents in this build
    are translated, unrotated objects, so inverting parent.location is the safe
    matrix_parent_inverse (matrix_world can be stale in an ops-free flow)."""
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.location = location
    if parent is not None:
        ob.parent = parent
        p = parent.location
        ob.matrix_parent_inverse = Matrix.Translation((-p.x, -p.y, -p.z))
    ob.data.materials.append(mat)
    return ob


def ellipsoid(name, radii, location, origin_z_offset=0.0, parent=None, mat=MAT_WOOD):
    """UV sphere scaled per-axis. origin_z_offset moves the mesh up relative to
    the object origin (used to put a part's pivot at its joint, e.g. waist)."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.transform(Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0)))
    if origin_z_offset:
        mesh.transform(Matrix.Translation((0.0, 0.0, origin_z_offset)))
    return part(name, mesh, location, parent, mat)


def limb(name, length, r_joint, r_far, location, parent=None):
    """Tapered cylinder hanging straight down (-Z) from its top-joint origin.
    bmesh.ops.create_cone: radius1 = bottom (far end), radius2 = top (joint)."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20,
                          radius1=r_far, radius2=r_joint, depth=length)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.transform(Matrix.Translation((0.0, 0.0, -length / 2)))  # origin -> joint
    return part(name, mesh, location, parent, MAT_WOOD)


def joint_ball(name, radius, location, parent=None):
    return ellipsoid(name, (radius, radius, radius), location, parent=parent, mat=MAT_JOINT)


# ------------------------------ build ---------------------------------------
# Rest pose. All locations are WORLD positions (see part()). The figure faces
# Blender -Y (= Godot +Z after glTF Y-up conversion).
root = bpy.data.objects.new("Mannequin", None)
scene.collection.objects.link(root)

HIP_Z = 0.90
WAIST_Z = 1.06
SHOULDER_Z = 1.40

pelvis = ellipsoid("Pelvis", (0.16, 0.125, 0.115), (0, 0, HIP_Z + 0.06), parent=root)
# Chest pivot at the waist so the sway rotation bends the figure correctly.
chest = ellipsoid("Chest", (0.20, 0.14, 0.28), (0, 0, WAIST_Z),
                 origin_z_offset=0.20, parent=pelvis)
neck = ellipsoid("Neck", (0.045, 0.045, 0.055), (0, 0, WAIST_Z + 0.42), parent=chest)
head = ellipsoid("Head", (0.112, 0.115, 0.118), (0, 0, WAIST_Z + 0.60), parent=chest)

arms = {}
for side, sx in (("L", 1), ("R", -1)):
    joint_ball("Shoulder" + side, 0.055, (sx * 0.23, 0, SHOULDER_Z), parent=chest)
    upper = limb("UpperArm" + side, 0.30, 0.048, 0.040, (sx * 0.23, 0, SHOULDER_Z), parent=chest)
    joint_ball("Elbow" + side, 0.041, (sx * 0.23, 0, SHOULDER_Z - 0.30), parent=upper)
    fore = limb("Forearm" + side, 0.27, 0.038, 0.031, (sx * 0.23, 0, SHOULDER_Z - 0.30), parent=upper)
    ellipsoid("Hand" + side, (0.045, 0.048, 0.062),
              (sx * 0.23, 0, SHOULDER_Z - 0.30 - 0.27 - 0.03), parent=fore)
    arms[side] = (upper, fore)

legs = {}
for side, sx in (("L", 1), ("R", -1)):
    joint_ball("Hip" + side, 0.055, (sx * 0.10, 0, HIP_Z), parent=pelvis)
    thigh = limb("Thigh" + side, 0.42, 0.054, 0.045, (sx * 0.10, 0, HIP_Z), parent=pelvis)
    joint_ball("Knee" + side, 0.046, (sx * 0.10, 0, HIP_Z - 0.42), parent=thigh)
    shin = limb("Shin" + side, 0.40, 0.042, 0.036, (sx * 0.10, 0, HIP_Z - 0.42), parent=thigh)
    # Foot: toes point forward (-Y), ankle sits slightly above the shin end.
    ellipsoid("Foot" + side, (0.055, 0.105, 0.042),
              (sx * 0.10, -0.028, HIP_Z - 0.42 - 0.40 - 0.03), parent=shin)
    legs[side] = (thigh, shin)

report("built: %d objects, hip z=%.2f, head top z≈%.2f"
       % (len(scene.objects), HIP_Z, WAIST_Z + 0.60 + 0.118))

# ----------------------------- animation ------------------------------------
# Two shared slotted actions (one slot per object, pitfalls §2): Walk_loop and
# Idle_loop. In-place: only limbs move + a tiny root bob. Each action is later
# pushed onto per-object NLA tracks so the glTF exporter emits both clips.
animated = [root, chest]
for side in ("L", "R"):
    animated += [arms[side][0], arms[side][1], legs[side][0], legs[side][1]]


def action_fcurves(ob):
    ad = ob.animation_data
    act = ad.action
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    fcs = []
    for layer in act.layers:
        for strip in layer.strips:
            bag = None
            try:
                bag = strip.channelbag(ad.action_slot)
            except (TypeError, KeyError, RuntimeError):
                bag = None
            if bag is not None:
                fcs.extend(bag.fcurves)
            else:
                for cb in strip.channelbags:
                    fcs.extend(cb.fcurves)
    return fcs


def assign_action(act):
    """Point every animated object at `act` (one slot each) so keyframe_insert
    writes into it; returns {object name: its slot on this action}."""
    slots = {}
    for ob in animated:
        ad = ob.animation_data_create()
        ad.action = act
        slot = act.slots.new(id_type="OBJECT", name=ob.name)
        ad.action_slot = slot
        slots[ob.name] = slot
    return slots


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def linearize():
    """All-LINEAR keys => clean glTF samplers (keys land every frame anyway)."""
    for ob in animated:
        for fc in action_fcurves(ob):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"


# -- Walk ------------------------------------------------------------------
walk_act = bpy.data.actions.new("Walk_loop")
walk_slots = assign_action(walk_act)
# Keyed every frame, first == last pose. Character faces -Y:
# rotation_euler.x > 0 swings a hanging limb BACKWARD (+Y).
for f in range(1, END + 2):
    ph = 2 * math.pi * (f - 1) / CYCLE
    sin_ph = math.sin(ph)
    for side in ("L", "R"):
        s = 1.0 if side == "L" else -1.0          # legs in counter-phase
        thigh, shin = legs[side]
        thigh.rotation_euler.x = s * A_LEG * sin_ph
        # Knee weight peaks mid-swing, zero at both contacts (reaching leg
        # lands straight). Clamp BEFORE the leg sign touches it; the smoothstep
        # makes the fold start/stop with zero velocity (no joint snap).
        shin.rotation_euler.x = BEND_KNEE * smoothstep(-s * math.cos(ph))
        upper, fore = arms[side]
        upper.rotation_euler.x = -s * A_ARM * sin_ph               # arms counter the legs
        fore.rotation_euler.x = -BEND_ELBOW - s * 0.25 * A_ARM * (-sin_ph)
    chest.rotation_euler.x = CHEST_SWAY * sin_ph
    # Legs split (contact) at ph=pi/2, 3pi/2 -> root LOW by DROP so the planted
    # foot reaches the floor; legs together at ph=0, pi -> root up by BOB.
    root.location.z = (BOB * (0.5 + 0.5 * math.cos(2 * ph))
                       - DROP * (0.5 - 0.5 * math.cos(2 * ph)))
    for ob in animated[1:]:
        ob.keyframe_insert("rotation_euler", frame=f)
    root.keyframe_insert("location", frame=f)
linearize()
report("Walk_loop: %d frames keyed" % (END + 1))

# Knee-direction invariant: shins never rotate negative (forward fold).
for side in ("L", "R"):
    xs = []
    for fc in action_fcurves(legs[side][1]):
        if fc.data_path == "rotation_euler" and fc.array_index == 0:
            xs += [kp.co[1] for kp in fc.keyframe_points]
    ok = min(xs) >= -0.001
    report("knee check Shin%s: min %+0.3f max %+0.3f rad -> %s"
           % (side, min(xs), max(xs), "OK (backward only)" if ok else "BUG: forward fold!"))
    assert ok, "Shin%s rotates negative — knee folds forward" % side

# -- Idle --------------------------------------------------------------------
# Rest pose + a faint breathing sway. Keys EVERY animated node (limbs at 0) so
# crossfading Walk->Idle in Godot drives every track back to rest smoothly.
idle_act = bpy.data.actions.new("Idle_loop")
idle_slots = assign_action(idle_act)
for f in range(1, END + 2):
    ph = 2 * math.pi * (f - 1) / CYCLE
    for ob in animated[1:]:
        ob.rotation_euler = Vector((0.0, 0.0, 0.0))
    chest.rotation_euler.x = IDLE_SWAY * math.sin(ph)
    root.location.z = IDLE_BOB * (0.5 - 0.5 * math.cos(2 * ph))
    for ob in animated[1:]:
        ob.keyframe_insert("rotation_euler", frame=f)
    root.keyframe_insert("location", frame=f)
linearize()
report("Idle_loop: %d frames keyed (rest + breathing)" % (END + 1))

# -- NLA stash ---------------------------------------------------------------
# animation_data.action holds ONE action at a time; pushing each clip onto its
# own per-object NLA track is what makes the glTF exporter emit both clips.
def stash_to_nla(act, slots, track_name):
    for ob in animated:
        track = ob.animation_data.nla_tracks.new()
        track.name = track_name
        strip = track.strips.new(act.name, 1, act)
        strip.action_slot = slots[ob.name]


stash_to_nla(walk_act, walk_slots, "WalkTrack")
stash_to_nla(idle_act, idle_slots, "IdleTrack")
for ob in animated:
    ob.animation_data.action = None  # NLA tracks are the export source now
report("NLA: %d clips stashed (Walk_loop, Idle_loop)" % 2)

# --------------------------- glTF export (main deliverable) -----------------
# Only the mannequin exists in the scene here; previews are added after, so
# no light/camera/ground leaks into the asset. Exported from the NLA tracks
# (ad.action is None) so both clips come out exactly once.
bpy.ops.export_scene.gltf(
    filepath=GLB_OUT,
    export_format="GLB",
    export_animations=True,
    export_yup=True,
)
report("glb: %s (%d KB)" % (GLB_OUT, os.path.getsize(GLB_OUT) // 1024))


def apply_action(act, slots):
    """Re-attach an authored action (reusing its slots) so scene evaluation and
    preview renders below show its poses."""
    for ob in animated:
        ad = ob.animation_data
        ad.action = act
        ad.action_slot = slots[ob.name]


apply_action(walk_act, walk_slots)

# Numeric sanity probe at quarter-cycle (mid-stride): feet near the ground,
# head on top, swung limbs displaced along Y. Numbers are ground truth.
scene.frame_set(CYCLE // 4 + 1)
for ob in (root, pelvis, chest, head, legs["L"][0], legs["L"][1], legs["R"][0],
           arms["L"][0], arms["R"][0]):
    zs = [(ob.matrix_world @ Vector(c)).z for c in ob.bound_box]
    ys = [(ob.matrix_world @ Vector(c)).y for c in ob.bound_box]
    report("probe %-10s z %6.3f..%6.3f  y %6.3f..%6.3f" % (
        ob.name, min(zs), max(zs), min(ys), max(ys)))

# ------------------------- previews (never block the glb) -------------------
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
ground = bpy.context.active_object
gm = wood_material("FloorGray", (0.45, 0.45, 0.47, 1), rough=0.95)
ground.data.materials.append(gm)

bpy.ops.object.light_add(type="SUN")
sun = bpy.context.active_object
sun.data.energy = 3.0
light_dir = Vector((-0.55, -0.35, -0.8)).normalized()
sun.rotation_euler = light_dir.to_track_quat("-Z", "Y").to_euler()

cam_target = bpy.data.objects.new("CamTarget", None)
scene.collection.objects.link(cam_target)
cam_target.location = (0, 0, 0.95)


def add_camera(name, loc, lens=50):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.active_object
    cam.name = name
    cam.data.lens = lens
    con = cam.constraints.new("TRACK_TO")
    con.target = cam_target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    return cam


side_cam = add_camera("SideCam", (4.6, 0, 1.1), lens=50)     # reads the gait
front_cam = add_camera("FrontCam", (3.0, -3.6, 1.5), lens=50)  # 3/4 face/silhouette
scene.render.resolution_x = 900
scene.render.resolution_y = 1200


def pick_engine():
    for eid in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eid
            return eid
        except TypeError:
            continue
    scene.render.engine = "BLENDER_WORKBENCH"
    return "BLENDER_WORKBENCH"


ENGINE = pick_engine()
report("render engine: " + ENGINE)


def render_frame(frame, cam, tag):
    scene.frame_set(frame)
    scene.camera = cam
    global ENGINE
    try:
        bpy.ops.render.render(write_still=True)
    except Exception as ex:
        report("render failed on %s (%s), falling back to Workbench" % (ENGINE, ex))
        scene.render.engine = ENGINE = "BLENDER_WORKBENCH"
        bpy.ops.render.render(write_still=True)
    report("still: %s frame_%03d.png" % (tag, frame))


scene.render.image_settings.media_type = "IMAGE"
scene.render.image_settings.file_format = "PNG"
for f in (1, CYCLE // 4 + 1, CYCLE // 2 + 1, 3 * CYCLE // 4 + 1, CYCLE):
    scene.render.filepath = os.path.join(PREVIEW_DIR, "side_%03d.png" % f)
    render_frame(f, side_cam, "side")
for f in (1, CYCLE // 4 + 1):
    scene.render.filepath = os.path.join(PREVIEW_DIR, "front_%03d.png" % f)
    render_frame(f, front_cam, "front")

report("DONE")
