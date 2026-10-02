import subprocess
import os
import shutil

# Use Resources/AppIcon.svg directly
if os.path.exists("Resources/icon_concepts/knotes_icon_white_pencil.svg"):
    shutil.copy("Resources/icon_concepts/knotes_icon_white_pencil.svg", "Resources/AppIcon_Light.svg")
    shutil.copy("Resources/icon_concepts/knotes_icon_black_pencil.svg", "Resources/AppIcon_Dark.svg")
    shutil.copy("Resources/icon_concepts/knotes_icon_white_pencil.svg", "Resources/AppIcon.svg")

# Render 1024x1024 PNG from AppIcon.svg
subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", "Resources", "Resources/AppIcon.svg"], check=True)
master_png = "Resources/AppIcon.svg.png"

# Create iconset directory
iconset_dir = "Resources/AppIcon.iconset"
if os.path.exists(iconset_dir):
    shutil.rmtree(iconset_dir)
os.makedirs(iconset_dir, exist_ok=True)

sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for sz, name in sizes:
    out_path = os.path.join(iconset_dir, name)
    subprocess.run(["sips", "-z", str(sz), str(sz), master_png, "--out", out_path], capture_output=True, check=True)

# Run iconutil
subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", "Resources/AppIcon.icns"], check=True)
shutil.rmtree(iconset_dir)
if os.path.exists(master_png):
    os.remove(master_png)

print("Successfully generated Resources/AppIcon.icns!")
