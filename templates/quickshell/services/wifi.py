"""Wi-Fi presentation rules. No credentials, D-Bus calls or logging."""


def deduplicate(rows):
    groups = {}
    for row in rows:
        # Raw SSID identity, not lossy UTF-8. Hidden APs remain individually selectable.
        key = row['ssidKey'] or row['path']
        groups.setdefault(key, []).append(row)
    result = []
    for candidates in groups.values():
        best = max(candidates, key=lambda r: r['strength'])
        current = next((r for r in candidates if r['current']), None)
        # Never turn a connected SSID click into roaming to another adapter/BSSID.
        selected = dict(current or best)
        selected['strength'] = best['strength']
        selected['current'] = current is not None
        result.append(selected)
    return sorted(result, key=lambda r: (not r['current'], -r['strength'], r['ssid']))


def saved_profile(device, ap):
    return next((c for c in device.get_available_connections() if ap.connection_valid(c)), None)


def valid_command(command):
    if not isinstance(command, dict):
        return False
    action = command.get('action')
    fields = {'toggle': {'action', 'enabled'}, 'scan': {'action'},
              'connect': {'action', 'path'}, 'configure': {'action'}}
    if action not in fields or set(command) != fields[action]:
        return False
    if action == 'toggle':
        return type(command['enabled']) is bool
    if action == 'connect':
        return isinstance(command['path'], str) and len(command['path']) < 256
    return True
