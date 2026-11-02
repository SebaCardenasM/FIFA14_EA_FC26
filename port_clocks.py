"""Apply supported devfreq limits in an order accepted by the running kernel."""
from pathlib import Path
import argparse
import json
import re
import sys

GPU = Path('/sys/class/devfreq/ff400000.gpu')
DDR = Path('/sys/class/devfreq/dmc')
CPU = Path('/sys/devices/system/cpu/cpufreq/policy0')


def bounds(device):
    return tuple(int((device / name).read_text()) for name in ('min_freq', 'max_freq'))


def frequencies(device):
    return sorted({int(value) for value in (device / 'available_frequencies').read_text().split()
                   if value.isdigit() and int(value) > 0})


def choose(device, requested):
    values = frequencies(device)
    if not values:
        raise ValueError('No available_frequencies for ' + str(device))
    lower = [value for value in values if value <= requested]
    return max(lower) if lower else min(values)


def _write_number(device, name, value):
    (device / name).write_text(str(value) + '\n')


def _ordered_write(device, old, new):
    # A zero upper bound means unlimited. For an upward range change, expand
    # the upper bound before raising the lower one; otherwise lower min first.
    order = ('max_freq', 'min_freq') if old[1] and new[0] > old[1] else ('min_freq', 'max_freq')
    values = dict(zip(('min_freq', 'max_freq'), new))
    for name in order:
        # max_freq can expose the current cooling cap while a different user
        # request remains underneath it. Always write both requested limits;
        # an equal readback is not proof that the saved user limit matches.
        _write_number(device, name, values[name])


def set_bounds(device, minimum, maximum):
    new = (int(minimum), int(maximum))
    if min(new) < 0 or (new[1] and new[0] > new[1]):
        raise ValueError('Invalid frequency interval')
    old = bounds(device)
    try:
        _ordered_write(device, old, new)
        if bounds(device) != new:
            raise OSError('Kernel did not retain the requested frequency limits')
    except OSError:
        try:
            _ordered_write(device, bounds(device), old)
        except OSError as restore_error:
            print('Clock rollback warning: ' + str(restore_error), file=sys.stderr, flush=True)
        raise


def pin(device, requested):
    target = choose(device, requested)
    set_bounds(device, target, target)
    return target


def cooling_state(device):
    path = Path('/sys/class/thermal/cooling_device1/cur_state')
    return int(path.read_text()) if device == GPU and path.exists() else 0


def ceiling(device, requested):
    """Keep the lowest stock floor so thermal downshifts cannot invert it."""
    target = choose(device, requested)
    floor = min(frequencies(device))
    # Cooling may lower max_freq independently while we are writing. Never
    # roll back to a stale raised floor, and never raise an active cooling cap.
    _write_number(device, 'min_freq', floor)
    capped = cooling_state(device) > 0
    current = bounds(device)
    if not capped or target < current[1]:
        _write_number(device, 'max_freq', target)
    current = bounds(device)
    if current[0] != floor or not floor <= current[1] <= target:
        raise OSError('GPU limits changed during optional adjustment')
    return target


def start():
    # Clock tuning is optional. Unsupported controls must not prevent a game
    # from reaching the runtime; retain the system's defaults on failure.
    # Establish this game's baseline with the card's existing GPU ceiling.
    # Do not inherit another game's measured 300 MHz preference.
    gpu_request = bounds(GPU)[1] or max(frequencies(GPU))
    for device, request in ((GPU, gpu_request), (DDR, 666000000)):
        try:
            previous = bounds(device)
            selected = ceiling(device, request) if device == GPU else pin(device, request)
            print(json.dumps({'device': str(device), 'before': previous, 'selected_hz': selected}), flush=True)
        except (OSError, ValueError) as error:
            print(json.dumps({'device': str(device), 'optional_adjustment_skipped': str(error)}), flush=True)
    try:
        available = (CPU / 'scaling_available_governors').read_text().split()
        if 'performance' in available:
            (CPU / 'scaling_governor').write_text('performance\n')
    except OSError as error:
        print('Optional CPU governor skipped: ' + str(error), flush=True)


def restore(report):
    saved = {}
    source = Path(report) / 'clocks-before.tsv'
    if not source.is_file():
        return
    allowed = {str(device / name) for device in (GPU, DDR) for name in ('min_freq', 'max_freq')}
    governor_path = str(CPU / 'scaling_governor')
    for line in source.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] in allowed | {governor_path}:
            saved[parts[0]] = parts[1]
    for device in (GPU, DDR):
        values = [saved.get(str(device / name)) for name in ('min_freq', 'max_freq')]
        if not all(value is not None and value.isdigit() for value in values):
            continue
        try:
            set_bounds(device, *map(int, values))
            print('Restored clock limits: ' + str(device), flush=True)
        except (OSError, ValueError) as error:
            print('Clock restore warning: ' + str(error), file=sys.stderr, flush=True)
    governor = saved.get(governor_path)
    if governor and re.fullmatch('[a-zA-Z0-9_-]+', governor):
        try:
            Path(governor_path).write_text(governor + '\n')
        except OSError as error:
            print('CPU governor restore warning: ' + str(error), file=sys.stderr, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('start', 'restore', 'ddr'))
    parser.add_argument('value', nargs='?')
    args = parser.parse_args()
    if args.action == 'start':
        start()
    elif args.action == 'restore':
        if not args.value:
            parser.error('restore needs the report directory')
        restore(args.value)
    else:
        if not args.value or not args.value.isdigit():
            parser.error('ddr needs a positive frequency in Hz')
        print(pin(DDR, int(args.value)), flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print('Clock adjustment skipped: ' + str(error), file=sys.stderr)
        sys.exit(1)
