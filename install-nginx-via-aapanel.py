#!/usr/bin/env python3
"""
Install Nginx via aaPanel internal API
"""

import sys
import os

# Add aaPanel paths to Python path
sys.path.insert(0, '/www/server/panel')
sys.path.insert(0, '/www/server/panel/class')

try:
    import panelPlugin
    import json

    print("=" * 50)
    print("Installing Nginx via aaPanel API")
    print("=" * 50)

    # Create plugin instance
    plugin = panelPlugin.panelPlugin()

    # Prepare parameters for nginx installation
    class GetObject:
        def __init__(self):
            self.name = 'nginx'
            self.sName = 'nginx'
            self.version = '1.26'  # Try latest stable version
            self.type = '0'

        def __getitem__(self, key):
            return getattr(self, key, None)

        def get(self, key, default=None):
            return getattr(self, key, default)

    get_obj = GetObject()

    print(f"Attempting to install nginx...")
    print(f"Plugin name: {get_obj.sName}")
    print(f"Version: {get_obj.version}")
    print()

    # Try to install nginx
    result = plugin.install(get_obj)

    print("Installation result:")
    print(json.dumps(result, indent=2))

    if result and result.get('status'):
        print("\n✓ Nginx installation started successfully!")
        print("This may take a few minutes. You can check the progress in aaPanel web interface.")
        sys.exit(0)
    else:
        print("\n✗ Failed to start nginx installation")
        print("Error:", result.get('msg', 'Unknown error'))
        sys.exit(1)

except ImportError as e:
    print(f"Error importing aaPanel modules: {e}")
    print("\nThis script must be run on a system with aaPanel installed.")
    sys.exit(1)
except Exception as e:
    print(f"Error during installation: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
