#!/usr/bin/env python3
"""
Script to fix iCloud entitlements
This will set the iCloud container environment to 'Production'
"""

import plistlib
import sys
from pathlib import Path

def fix_icloud_entitlements(entitlements_path):
    """Fix iCloud container environment in entitlements file"""
    
    try:
        # Read the entitlements file
        with open(entitlements_path, 'rb') as f:
            entitlements_data = plistlib.load(f)
        
        print(f"✓ Loaded {entitlements_path}")
        
        # Check for iCloud environment key
        icloud_key = 'com.apple.developer.icloud-container-environment'
        
        if icloud_key in entitlements_data:
            old_value = entitlements_data[icloud_key]
            print(f"\nCurrent value: '{old_value}'")
            
            # Set to Production
            entitlements_data[icloud_key] = 'Production'
            
            # Write back to file
            with open(entitlements_path, 'wb') as f:
                plistlib.dump(entitlements_data, f)
            
            print(f"✅ Updated to: 'Production'")
            print(f"\n✅ Successfully updated {entitlements_path}")
        else:
            print(f"\n⚠ Key '{icloud_key}' not found in entitlements")
            print("This is okay if you're not using iCloud")
        
    except FileNotFoundError:
        print(f"❌ Error: File not found: {entitlements_path}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix_entitlements.py /path/to/YourApp.entitlements")
        print("\nExample: python3 fix_entitlements.py ./hatti/hatti.entitlements")
        sys.exit(1)
    
    entitlements_path = Path(sys.argv[1])
    fix_icloud_entitlements(entitlements_path)

if __name__ == "__main__":
    main()
