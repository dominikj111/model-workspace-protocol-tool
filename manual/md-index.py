#!/usr/bin/env python3
"""
md_index.py
Usage: md_index <file> [--format yaml|text|json]
Indexes markdown headers with line numbers. Headers only — no prose hints.
"""
import sys
import re
import json
import argparse
from pathlib import Path


def extract_headers(lines):
    headers = []
    n = len(lines)
    fenced = False
    fence_tok = None

    i = 0
    while i < n:
        line = lines[i]

        # Track fenced code blocks
        m_fence = re.match(r'^\s*(`{3,}|~{3,})(.*)$', line)
        if m_fence:
            tok = m_fence.group(1)
            if not fenced:
                fenced = True
                fence_tok = tok
            elif tok == fence_tok:
                fenced = False
                fence_tok = None
            i += 1
            continue

        if fenced:
            i += 1
            continue

        header_info = None

        # ATX header
        m_atx = re.match(r'^(#{1,6})(?:\s+|$)(.*?)\s*(?:#*\s*)?$', line)
        if m_atx:
            level = len(m_atx.group(1))
            title = m_atx.group(2).strip()
            header_info = (level, title, i)

        # Setext header
        elif i + 1 < n and re.match(r'^[=-]{2,}\s*$', lines[i + 1]) and line.strip():
            level = 1 if lines[i + 1].startswith('=') else 2
            title = line.strip()
            header_info = (level, title, i)
            # note: we'll skip the underline line later

        if header_info:
            level, title, start_idx = header_info

            headers.append({
                'level': level,
                'title': title,
                'start': start_idx + 1,
            })

            if i + 1 < n and re.match(r'^[=-]{2,}\s*$', lines[i + 1]):
                i += 1  # skip underline

        i += 1

    # Set end lines and parents
    parent_stack = []  # list of (level, title)
    for idx in range(len(headers)):
        h = headers[idx]

        # Determine parent
        while parent_stack and parent_stack[-1][0] >= h['level']:
            parent_stack.pop()

        if parent_stack:
            h['parent'] = parent_stack[-1][1]
        else:
            h['parent'] = None

        parent_stack.append((h['level'], h['title']))

        # Set end lines
        if idx + 1 < len(headers):
            h['end'] = headers[idx + 1]['start'] - 1
        else:
            h['end'] = n

    return headers


def quote_yaml(s):
    if not s:
        return '""'
    # json.dumps keeps titles safe in YAML (quotes, newlines, etc.)
    return json.dumps(s)


def main():
    p = argparse.ArgumentParser(description="Index markdown headers.")
    p.add_argument('input', type=Path)
    p.add_argument('--format', choices=['yaml', 'text', 'json'], default='yaml')
    args = p.parse_args()

    if not args.input.exists():
        print(f"Error: {args.input} not found", file=sys.stderr)
        sys.exit(1)

    lines = args.input.read_text(encoding='utf-8').splitlines()
    headers = extract_headers(lines)

    if args.format == 'json':
        print(json.dumps({'sections': headers}, indent=2))
    elif args.format == 'yaml':
        print("sections:")
        for h in headers:
            print(f"  - title: {quote_yaml(h['title'])}")
            print(f"    level: {h['level']}")
            print(f"    parent: {quote_yaml(h['parent']) if h['parent'] else 'null'}")
            print(f"    start: {h['start']}")
            print(f"    end: {h['end']}")
    else:  # text
        for h in headers:
            hashes = '#' * h['level']
            print(f"{hashes} {h['title']}  (L{h['start']}–{h['end']})")


if __name__ == '__main__':
    main()
