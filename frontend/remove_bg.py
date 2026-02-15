#!/usr/bin/env python3
import sys
try:
    from PIL import Image
    import numpy as np
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'Pillow', 'numpy'])
    from PIL import Image
    import numpy as np

img = Image.open('web/assets/bismillah.png').convert('RGBA')
data = np.array(img)

r = data[:,:,0].astype(float)
g = data[:,:,1].astype(float)
b = data[:,:,2].astype(float)

brightness = r * 0.299 + g * 0.587 + b * 0.114
threshold = 55
alpha = np.clip((brightness - threshold) * 4.5, 0, 255).astype(np.uint8)
data[:,:,3] = alpha

result = Image.fromarray(data)
result.save('web/assets/bismillah_clean.png')
print(f'Done! Size: {result.size}, Transparent: {(alpha == 0).sum()}')
