#!/usr/bin/env python3
"""Compiles a gettext .po file into a .mo file.

Minimal replacement for msgfmt, which is not installed by default on Kubuntu.
Handles plain msgid/msgstr pairs with multi-line strings; no plurals or contexts.

Usage: compile_mo.py input.po output.mo
"""
import ast
import struct
import sys


def parse_po(path):
    messages = {}
    msgid = msgstr = None
    section = None

    def flush():
        if msgid is not None and msgstr:
            messages[msgid] = msgstr

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("msgid "):
                flush()
                msgid, msgstr, section = ast.literal_eval(line[6:]), "", "id"
            elif line.startswith("msgstr "):
                msgstr, section = ast.literal_eval(line[7:]), "str"
            elif line.startswith('"'):
                if section == "id":
                    msgid += ast.literal_eval(line)
                else:
                    msgstr += ast.literal_eval(line)
    flush()
    return messages


def write_mo(messages, path):
    keys = sorted(messages)
    ids = [k.encode("utf-8") for k in keys]
    strs = [messages[k].encode("utf-8") for k in keys]
    header_size = 7 * 4
    ids_table = header_size
    strs_table = ids_table + 8 * len(keys)
    data_start = strs_table + 8 * len(keys)

    offsets, data = [], b""
    for blob in ids + strs:
        offsets.append((len(blob), data_start + len(data)))
        data += blob + b"\0"

    out = struct.pack("<7I", 0x950412DE, 0, len(keys), ids_table, strs_table, 0, 0)
    for length, offset in offsets:
        out += struct.pack("<2I", length, offset)
    with open(path, "wb") as f:
        f.write(out + data)


if __name__ == "__main__":
    write_mo(parse_po(sys.argv[1]), sys.argv[2])
