#!/usr/bin/env python3
"""
md_index.py
Usage: md_index <file> [--format yaml|text|json] [--max <hint_len>]
Indexes markdown headers with line numbers and optional hints.
"""
import sys
import re
import json
import argparse
from pathlib import Path

def is_table_start(line):
    return line.lstrip().startswith('|') or re.match(r'^\s*:?-+:?\s*\|', line) is not None

def is_fenced_code_start(line):
    return re.match(r'^\s*(`{3,}|~{3,})', line) is not None

def is_indented_code(line):
    return line.startswith('    ') or line.startswith('\t')

def is_list_item(line):
    return re.match(r'^\s*([-+*]|\d+\.)\s+', line) is not None

def extract_headers(lines, max_len=120):
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
        elif i + 1 < n and re.match(r'^[=-]{2,}\s*$', lines[i+1]) and line.strip():
            level = 1 if lines[i+1].startswith('=') else 2
            title = line.strip()
            header_info = (level, title, i)
            # note: we'll skip the underline line later
            
        if header_info:
            level, title, start_idx = header_info
            
            # Find hint
            curr = i + 1
            if i + 1 < n and re.match(r'^[=-]{2,}\s*$', lines[i+1]):
                curr = i + 2
            
            j = curr
            while j < n and lines[j].strip() == '':
                j += 1
            
            hint = ''
            if j < n:
                nxt = lines[j]
                # Don't extract hint if it's a specific block kind or another header
                if not (is_table_start(nxt) or is_fenced_code_start(nxt) or is_indented_code(nxt) or is_list_item(nxt) or re.match(r'^(#{1,6})(?:\s+|$)', nxt)):
                    para_parts = []
                    k = j
                    while k < n and lines[k].strip() != '':
                        if is_table_start(lines[k]) or is_fenced_code_start(lines[k]) or is_indented_code(lines[k]) or is_list_item(lines[k]):
                            para_parts = []
                            break
                        if re.match(r'^(#{1,6})(?:\s+|$)', lines[k]):
                            break
                        para_parts.append(lines[k].strip())
                        k += 1
                    
                    if para_parts:
                        full = ' '.join(para_parts)
                        full = re.sub(r'\s+', ' ', full).strip()
                        hint = full[:max_len]
            
            headers.append({
                'level': level,
                'title': title,
                'start': start_idx + 1,
                'hint': hint
            })
            
            if i + 1 < n and re.match(r'^[=-]{2,}\s*$', lines[i+1]):
                i += 1 # skip underline
                
        i += 1
        
    # Set end lines and parents
    parent_stack = [] # list of (level, title)
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
            h['end'] = headers[idx+1]['start'] - 1
        else:
            h['end'] = n
            
    return headers

def quote_yaml(s):
    if not s: return '""'
    # Always use json.dumps for titles and hints to ensure safety in YAML
    # and to handle escaping of quotes, newlines, etc.
    return json.dumps(s)

def main():
    p = argparse.ArgumentParser(description="Index markdown headers.")
    p.add_argument('input', type=Path)
    p.add_argument('--format', choices=['yaml', 'text', 'json'], default='yaml')
    p.add_argument('--max', type=int, default=120, help="Max hint length")
    args = p.parse_args()

    if not args.input.exists():
        print(f"Error: {args.input} not found", file=sys.stderr)
        sys.exit(1)

    lines = args.input.read_text(encoding='utf-8').splitlines()
    headers = extract_headers(lines, max_len=args.max)
    
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
            if h['hint']:
                print(f"    hint: {quote_yaml(h['hint'])}")
    else: # text (legacy)
        for h in headers:
            hashes = '#' * h['level']
            hint_part = f" — {h['hint']}" if h['hint'] else " —"
            print(f"{hashes} {h['title']}{hint_part}")

if __name__ == '__main__':
    main()
