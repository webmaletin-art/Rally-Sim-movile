#!/usr/bin/env python3
"""Reconocimiento de los gestos de Mixamo: cada clip en 6 instantes, con un piloto solo y cámara fija (para elegir la mejor pose de cada gesto).
Uso: python3 tools/trailer/make_pose_scout.py /carpeta_de_trabajos /carpeta_de_fotos"""
import json
import os
import sys

jobs_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(jobs_dir, exist_ok=True)
# (clip, duración)
CLIPS = [('Waving', 0.53), ('Clapping', 1.17), ('Standing_Fist_Pump', 3.77), ('Standing_Thumbs_Up', 4.17), ('Pointing_Forward', 4.7), ('Pointing', 3.6), ('Pointing_2', 2.77),
         ('Shaking_Hands_1', 4.37), ('Laughing', 9.77), ('Standing_Greeting', 5.1), ('Reaching_Out', 4.0), ('happy_hand_gesture', 2.93), ('Arm_Gesture', 3.4),
         ('Hands_Forward_Gesture', 3.1), ('Thinking', 4.23), ('being_cocky', 2.9), ('Agreeing_2', 1.83), ('Shrugging', 2.0), ('Leaning', 3.33), ('One_Shoulder_Lean', 2.0),
         ('Happy_Idle_2', 2.93), ('Standing_Arguing', 20.8), ('Talking_7', 10.27), ('relieved_sigh', 3.0), ('acknowledging', 1.93), ('Entering_Car', 5.47), ('Exiting_Car', 5.8),
         ('Looking_Around', 6.33), ('Counting_2', 6.63), ('Texting_While_Standing', 23.57)]
shots = []
for name, dur in CLIPS:
    for k in range(6):
        t = dur * (k + 0.5) / 6.0
        shots.append({'name': '%s_%d' % (name, k), 'fov': 36, 'cam': {'abs': [4.0, 1.0, 4.4], 'look': [4.0, 0.95, 0.0]},
                      'pilots': [{'clip': name, 't': round(t, 2), 'at': [4.0, 0.0], 'face': 'cam', 'h': 1.78}], 'wait': 2})
job = {'mode': 'studio', 'out': out_dir, 'car': 'hatch', 'shots': shots}
json.dump(job, open(os.path.join(jobs_dir, 'poses.json'), 'w'), indent=1)
print(len(shots), 'tomas')
