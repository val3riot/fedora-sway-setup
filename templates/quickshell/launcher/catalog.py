#!/usr/bin/env python3
"""Validate standard desktop entries without running their commands."""
import json
import shutil
import gi
gi.require_version("GioUnix", "2.0")
from gi.repository import Gio, GioUnix


def launchable(app):
    if not app.should_show() or not app.get_name() or not app.get_commandline(): return False
    executable = app.get_executable()
    if not executable or not shutil.which(executable): return False
    wanted = app.get_string('TryExec') if isinstance(app, GioUnix.DesktopAppInfo) else None
    return not wanted or bool(shutil.which(wanted))


if __name__ == '__main__':
    print(json.dumps({'ids': [app.get_id().removesuffix('.desktop') for app in Gio.AppInfo.get_all()
                              if app.get_id() and launchable(app)]}))
