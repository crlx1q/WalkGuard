#!/usr/bin/env python3
"""Optional desktop CPU smoke check. Does not simulate Android performance.
Install: python -m pip install ai-edge-litert numpy pillow
Run: python tools/verify_model.py --image path/to/controlled-scene.jpg
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
import importlib.metadata
import numpy as np
from PIL import Image, ImageOps
from ai_edge_litert.interpreter import Interpreter

EXPECTED = '2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b'
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--image', type=Path, required=True)
p.add_argument('--output', type=Path)
args = p.parse_args()
model = ROOT / 'android/app/src/main/assets/models/efficientdet_lite0.tflite'
assert hashlib.sha256(model.read_bytes()).hexdigest() == EXPECTED, 'Model checksum mismatch'
labels = (model.parent / 'labels.txt').read_text().splitlines()
engine = Interpreter(model_path=str(model), num_threads=2)
engine.allocate_tensors()
input_info = engine.get_input_details()[0]
assert input_info['shape'].tolist() == [1, 320, 320, 3]
assert input_info['dtype'] == np.uint8
outputs = engine.get_output_details()
assert [x['shape'].tolist() for x in outputs] == [[1, 25, 4], [1, 25], [1, 25], [1]]
with Image.open(args.image) as image:
    image = ImageOps.exif_transpose(image).convert('RGB')
    image = ImageOps.pad(image, (320, 320), color=(127, 127, 127))
    data = np.asarray(image, dtype=np.uint8)[None, ...]
measurements = []
for _ in range(4):
    engine.set_tensor(input_info['index'], data)
    start = time.perf_counter()
    engine.invoke()
    measurements.append((time.perf_counter() - start) * 1000)
boxes, classes, scores, count = [engine.get_tensor(x['index']) for x in outputs]
found = [{'class': labels[int(classes[0, i])], 'confidence': round(float(scores[0, i]), 5),
          'box_yxyx': boxes[0, i].tolist()} for i in range(int(count[0])) if scores[0, i] >= .4]
result = {'environment': 'Desktop Linux ARM64 CPU, NOT an Android device benchmark',
          'runtime': 'ai-edge-litert Python ' + importlib.metadata.version('ai-edge-litert'), 'sha256': EXPECTED,
          'model_bytes': model.stat().st_size, 'input_shape': input_info['shape'].tolist(),
          'quantization': list(input_info['quantization']),
          'output_shapes': [x['shape'].tolist() for x in outputs],
          'inference_ms_desktop': measurements, 'detections': found}
print(json.dumps(result, ensure_ascii=False, indent=2))
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
