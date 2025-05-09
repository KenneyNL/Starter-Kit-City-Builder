# Used to resize images into icons (64x64)

#!/bin/bash
 

for dir in ../sprites/*/; do
  # Extract the directory name (e.g., "power_plants")
  subdir=$(basename "$dir")
  
  # Create corresponding output directory under "icons/"
  mkdir -p "icons/$subdir"
  
  for img in "$dir"*.png; do
    [ -e "$img" ] || continue  # Skip if no PNGs
    filename=$(basename "$img" .png)
    
    convert "$img" -resize 64x64! "icons/$subdir/${filename}_icon.png"
  done
done
