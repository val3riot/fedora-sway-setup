"""One persistent, local-only sampler shared by all output bars."""
import json
from pathlib import Path
import time


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def cpu_sample(text):
    fields = text.splitlines()[0].split() if text else []
    if len(fields) < 5 or fields[0] != "cpu":
        return None
    try:
        # guest/guest_nice are already included in user/nice, do not double count.
        values = [int(x) for x in fields[1:9]]
        return sum(values), values[3] + (values[4] if len(values) > 4 else 0)
    except ValueError:
        return None


def cpu_usage(previous, current):
    if previous is None or current is None:
        return None
    total, idle = current[0] - previous[0], current[1] - previous[1]
    if total <= 0 or idle < 0 or idle > total:
        return None
    return round(100 * (total - idle) / total)


def memory_usage(text):
    values = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ("MemTotal:", "MemAvailable:"):
            try:
                values[parts[0]] = int(parts[1])
            except ValueError:
                return None
    total, available = values.get("MemTotal:", 0), values.get("MemAvailable:")
    if total <= 0 or available is None or not 0 <= available <= total:
        return None
    return round(100 * (total - available) / total)


def detect_temperature(sys=Path('/sys')):
    candidates = []
    for hwmon in (sys / 'class/hwmon').glob('hwmon*'):
        name = read(hwmon / 'name').lower()
        for sensor in hwmon.glob('temp*_input'):
            label = read(sensor.with_name(sensor.name.replace('_input', '_label'))).lower()
            rank = None
            if name == 'coretemp':
                rank = 0 if 'package' in label else 2
            elif name in ('k10temp', 'zenpower'):
                rank = 0 if label == 'tdie' else 1 if label == 'tctl' else 2
            elif name in ('cpu_thermal', 'cpu-thermal', 'k8temp') or 'cpu' in label:
                rank = 3
            if rank is not None:
                candidates.append((rank, str(sensor)))
    for zone in (sys / 'class/thermal').glob('thermal_zone*'):
        name = read(zone / 'type').lower()
        if name in ('x86_pkg_temp', 'cpu-thermal', 'cpu_thermal') or name.startswith('cpu'):
            candidates.append((4, str(zone / 'temp')))
    return [Path(path) for _, path in sorted(candidates)]


def temperature(paths):
    for path in paths:
        try:
            value = int(read(path)) / 1000
            if -20 <= value <= 130:
                return round(value)
        except ValueError:
            pass
    return None


def main():
    previous = None
    paths = []
    next_detection = 0
    while True:
        now = time.monotonic()
        if now >= next_detection:
            paths = detect_temperature()
            next_detection = now + 60
        current = cpu_sample(read('/proc/stat'))
        result = dict(cpu=cpu_usage(previous, current),
                      ram=memory_usage(read('/proc/meminfo')),
                      temperature=temperature(paths))
        print(json.dumps(result), flush=True)
        previous = current
        time.sleep(2)


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        pass
