#!/usr/bin/env python3
"""
Script to remove alpha channel from app icon
This converts PNG with transparency to PNG without alpha channel
"""

from PIL import Image
import sys
from pathlib import Path

def remove_alpha_channel(input_path, output_path=None):
    """Remove alpha channel from PNG image"""
    
    if output_path is None:
        # Create output filename
        path = Path(input_path)
        output_path = path.parent / f"{path.stem}_no_alpha{path.suffix}"
    
    try:
        # Open the image
        img = Image.open(input_path)
        print(f"✓ Loaded {input_path}")
        print(f"  Mode: {img.mode}, Size: {img.size}")
        
        # Check if image has alpha channel
        if img.mode in ('RGBA', 'LA', 'PA'):
            print(f"\n✓ Image has alpha channel, converting...")
            
            # Create a white background
            background = Image.new('RGB', img.size, (255, 255, 255))
            
            # Paste the image on white background
            if img.mode == 'RGBA':
                background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
            else:
                background.paste(img)
            
            # Save the result
            background.save(output_path, 'PNG')
            print(f"✅ Saved to: {output_path}")
            
        elif img.mode == 'RGB':
            print("\n⚠ Image is already RGB (no alpha channel)")
            # Still save it to ensure it's properly formatted
            img.save(output_path, 'PNG')
            print(f"✅ Saved copy to: {output_path}")
        else:
            # Convert other modes to RGB
            print(f"\n✓ Converting {img.mode} to RGB...")
            rgb_img = img.convert('RGB')
            rgb_img.save(output_path, 'PNG')
            print(f"✅ Saved to: {output_path}")
        
    except FileNotFoundError:
        print(f"❌ Error: File not found: {input_path}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix_app_icon_alpha.py /path/to/icon.png [output.png]")
        print("\nExample: python3 fix_app_icon_alpha.py ./AppIcon-1024.png")
        print("         python3 fix_app_icon_alpha.py ./AppIcon-1024.png ./AppIcon-1024-fixed.png")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    remove_alpha_channel(input_path, output_path)

if __name__ == "__main__":
    main()
