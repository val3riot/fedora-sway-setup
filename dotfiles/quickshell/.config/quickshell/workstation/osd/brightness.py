#!/usr/bin/env python3
"""One brightnessctl request per key event, no background polling."""
import json
import subprocess
import sys
from pathlib import Path


def change(action):
    if action not in ('brightness-up', 'brightness-down') or not any(Path('/sys/class/backlight').iterdir()):
        return {'ok': False}
    try:
        data = subprocess.check_output(['brightnessctl', '-c', 'backlight', '-m', 'set', '+5%' if action.endswith('up') else '5%-'], stderr=subprocess.DEVNULL, timeout=3, text=True)
        return {'ok': True, 'value': float(data.strip().split(',')[3].rstrip('%')) / 100}
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return {'ok': False}


if __name__ == '__main__':
    print(json.dumps(change(sys.argv[1] if len(sys.argv) == 2 else '')))
