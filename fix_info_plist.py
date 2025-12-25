#!/usr/bin/env python3
"""
Script to fix Info.plist UIBackgroundModes errors
This will remove invalid background mode values from your Info.plist
"""

import plistlib
import sys
from pathlib import Path

def fix_background_modes(plist_path):
    """Remove invalid UIBackgroundModes from Info.plist"""
    
    # Invalid modes that need to be removed
    invalid_modes = ['background-fetch', 'background-processing', 'weather-updates']
    
    # Valid modes (for reference)
    valid_modes = [
        'audio',
        'location',
        'voip',
        'external-accessory',
        'bluetooth-central',
        'bluetooth-peripheral',
        'fetch',
        'remote-notification',
        'processing'
    ]
    
    try:
        # Read the plist file
        with open(plist_path, 'rb') as f:
            plist_data = plistlib.load(f)
        
        print(f"✓ Loaded {plist_path}")
        
        # Check if UIBackgroundModes exists
        if 'UIBackgroundModes' not in plist_data:
            print("⚠ No UIBackgroundModes found in Info.plist")
            return
        
        original_modes = plist_data['UIBackgroundModes']
        print(f"\nOriginal UIBackgroundModes: {original_modes}")
        
        # Filter out invalid modes
        updated_modes = [mode for mode in original_modes if mode not in invalid_modes]
        
        if len(updated_modes) == len(original_modes):
            print("✓ No invalid modes found!")
            return
        
        # Update or remove the key
        if updated_modes:
            plist_data['UIBackgroundModes'] = updated_modes
            print(f"\n✓ Updated UIBackgroundModes to: {updated_modes}")
        else:
            del plist_data['UIBackgroundModes']
            print("\n✓ Removed UIBackgroundModes (no valid modes remaining)")
        
        # Write back to file
        with open(plist_path, 'wb') as f:
            plistlib.dump(plist_data, f)
        
        print(f"\n✅ Successfully updated {plist_path}")
        
        if updated_modes:
            print("\nValid modes kept:")
            for mode in updated_modes:
                print(f"  • {mode}")
        
    except FileNotFoundError:
        print(f"❌ Error: File not found: {plist_path}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix_info_plist.py /path/to/Info.plist")
        print("\nExample: python3 fix_info_plist.py ./hatti/Info.plist")
        sys.exit(1)
    
    plist_path = Path(sys.argv[1])
    fix_background_modes(plist_path)

if __name__ == "__main__":
    main()
