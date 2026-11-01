"""Read timestamped stdout without rewriting messages, times or archive files."""
from datetime import datetime
from functools import lru_cache
import re

STAMP = re.compile(r'^\[([^\]]+)\]')


def parse_lines(text, source):
    events = []
    for number, line in enumerate(text.splitlines(), 1):
        match = STAMP.match(line)
        if not match:
            continue
        try:
            stamp = datetime.fromisoformat(match[1].replace('Z', '+00:00'))
            if stamp.tzinfo is None:
                continue  # Do not invent a timezone or chronology.
        except ValueError:
            continue
        events.append(dict(id=f'{source}:{number}', source=source, line=number,
                           timestamp=match[1], time=stamp.timestamp(), text=line))
    return events


@lru_cache(maxsize=32)
def archive_events(studies, study):
    root = studies / study / 'runs'
    events = []
    for file in sorted(root.rglob('_stdout.txt')):
        if file.resolve().is_relative_to(root.resolve()):
            events.extend(parse_lines(file.read_text(errors='replace'), str(file.relative_to(studies))))
    return sorted(events, key=lambda event: (event['time'], event['source'], event['line']))
