#!/usr/bin/env python3
"""
Generate the "all classes on all races" DBC data for WotLK 3.3.5a.

Two DBC files are rewritten:

  CharBaseInfo.dbc    - the list of race/class combinations the *client* offers
                        on the character creation screen. The server does not
                        read this file at all, so it only matters for the
                        client patch.
  CharStartOutfit.dbc - starting gear per race/class/gender. The *server* reads
                        this one when a character is created, so combinations
                        that do not exist here would start with empty bags.
                        Missing combinations are filled in by copying the
                        outfit of a race that already has that class.

Outputs (idempotent, always regenerated from the .orig backups):

  <server dbc>/CharBaseInfo.dbc,    <server dbc>/CharStartOutfit.dbc   (patched)
  <server dbc>/*.dbc.orig                                             (backups)
  <out>/DBFilesClient/*.dbc                                           (for the client patch MPQ)
"""

import argparse
import os
import shutil
import struct

HEADER = struct.Struct("<4siiii")   # magic, records, fields, record size, string block size
OUTFIT_ITEMS = 24
OUTFIT_RECORD_SIZE = 4 + 4 + OUTFIT_ITEMS * 4 * 3   # id + packed race/class/gender/outfit + 3 arrays


def read_dbc(path):
    with open(path, "rb") as handle:
        blob = handle.read()

    magic, records, fields, record_size, string_size = HEADER.unpack_from(blob, 0)
    if magic != b"WDBC":
        raise SystemExit(f"{path}: not a WDBC file")

    body_start = HEADER.size
    body_end = body_start + records * record_size
    rows = [blob[body_start + i * record_size: body_start + (i + 1) * record_size]
            for i in range(records)]
    strings = blob[body_end:body_end + string_size]
    return rows, fields, record_size, strings


def write_dbc(path, rows, fields, record_size, strings):
    with open(path, "wb") as handle:
        handle.write(HEADER.pack(b"WDBC", len(rows), fields, record_size, len(strings)))
        for row in rows:
            handle.write(row)
        handle.write(strings)


def original_of(path):
    """Keep a pristine copy so the script can be re-run any number of times."""
    backup = path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    return backup


def build_char_base_info(source):
    rows, fields, record_size, strings = read_dbc(source)
    if record_size != 2:
        raise SystemExit(f"{source}: unexpected record size {record_size}, expected 2")

    existing = [(row[0], row[1]) for row in rows]
    races = sorted({race for race, _ in existing})
    classes = sorted({klass for _, klass in existing})

    combos = [(race, klass) for race in races for klass in classes]
    new_rows = [bytes((race, klass)) for race, klass in combos]

    added = sorted(set(combos) - set(existing))
    return new_rows, fields, record_size, strings, races, classes, added


def build_char_start_outfit(source, races, classes):
    rows, fields, record_size, strings = read_dbc(source)
    if record_size != OUTFIT_RECORD_SIZE:
        raise SystemExit(f"{source}: unexpected record size {record_size}, expected {OUTFIT_RECORD_SIZE}")

    by_key = {}
    max_id = 0
    for row in rows:
        (entry_id,) = struct.unpack_from("<I", row, 0)
        race, klass, gender, _outfit = struct.unpack_from("<BBBB", row, 4)
        by_key[(race, klass, gender)] = row
        max_id = max(max_id, entry_id)

    new_rows = list(rows)
    added = []
    next_id = max_id + 1

    for klass in classes:
        for gender in (0, 1):
            donors = [race for race in races if (race, klass, gender) in by_key]
            if not donors:
                continue
            donor = by_key[(donors[0], klass, gender)]

            for race in races:
                if (race, klass, gender) in by_key:
                    continue

                row = bytearray(donor)
                struct.pack_into("<I", row, 0, next_id)
                row[4] = race                      # race byte, class/gender/outfit kept
                new_rows.append(bytes(row))
                added.append((race, klass, gender, donors[0]))
                next_id += 1

    return new_rows, fields, record_size, strings, added


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbc-dir", default="/root/classic/run/data/dbc",
                        help="server side dbc directory (patched in place)")
    parser.add_argument("--out-dir", default="/root/classic/client-patch/staging",
                        help="where to stage the files for the client patch MPQ")
    args = parser.parse_args()

    staging = os.path.join(args.out_dir, "DBFilesClient")
    os.makedirs(staging, exist_ok=True)

    base_path = os.path.join(args.dbc_dir, "CharBaseInfo.dbc")
    outfit_path = os.path.join(args.dbc_dir, "CharStartOutfit.dbc")

    rows, fields, record_size, strings, races, classes, added = build_char_base_info(original_of(base_path))
    write_dbc(base_path, rows, fields, record_size, strings)
    write_dbc(os.path.join(staging, "CharBaseInfo.dbc"), rows, fields, record_size, strings)
    print(f"CharBaseInfo.dbc:    {len(races)} races x {len(classes)} classes = {len(rows)} combinations "
          f"({len(added)} added)")

    rows, fields, record_size, strings, added = build_char_start_outfit(original_of(outfit_path), races, classes)
    write_dbc(outfit_path, rows, fields, record_size, strings)
    write_dbc(os.path.join(staging, "CharStartOutfit.dbc"), rows, fields, record_size, strings)
    print(f"CharStartOutfit.dbc: {len(rows)} outfit records ({len(added)} added)")


if __name__ == "__main__":
    main()
