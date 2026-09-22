#!/usr/bin/env python3
"""
Merge the rows one DBC patch adds into another patch's copy of the same DBC.

The client keeps only the last copy of a DBC it loads, so two patches that
each ship, say, CreatureDisplayInfo.dbc cannot both win: an HD-model patch
(Patch-G) and mod-worgoblin (patch-A) both do, and whichever loads later
silently erases the other's rows. With G above A the Worgen display ids
vanish and clicking the Worgen race button dereferences a null record.

    merge_dbc.py --base G/CreatureDisplayInfo.dbc \\
                 --overlay A/CreatureDisplayInfo.dbc \\
                 --stock  stock/CreatureDisplayInfo.dbc \\
                 --out    Z/CreatureDisplayInfo.dbc

The output is the base file with every row the overlay *changed* relative
to stock (new id, or same id with different content) copied in on top. Rows
the base changed and the overlay did not are untouched, so the HD patch
keeps its work and the race module keeps its additions. If both changed the
same id the overlay wins, and that is reported.

No knowledge of each DBC's layout is needed. Base rows are copied verbatim
with the base string block kept as is; only overlay rows have to be
re-encoded, and for those the string fields are detected: a field is a
string offset if, in all three files and every row, its value is 0 or points
just past a NUL inside the string block, and it is not constant-small
across the board. The detection has to agree across the three files or the
tool refuses.
"""

import argparse
import struct
import sys

HEADER = struct.Struct("<4sIIII")


def read(path):
    data = open(path, "rb").read()
    magic, records, fields, recsize, strsize = HEADER.unpack_from(data, 0)
    if magic != b"WDBC" or recsize != fields * 4:
        raise SystemExit(f"{path}: not a plain 4-byte-field DBC (magic {magic!r}, recsize {recsize}, fields {fields})")
    body = data[HEADER.size:HEADER.size + records * recsize]
    strings = data[HEADER.size + records * recsize:HEADER.size + records * recsize + strsize]
    rows = [struct.unpack_from(f"<{fields}I", body, i * recsize) for i in range(records)]
    return fields, rows, strings


def string_fields(fields, rows, strings):
    """Indices of fields that are string offsets, by the rule in the docstring."""
    out = set()
    for f in range(1, fields):                     # field 0 is the id
        values = [r[f] for r in rows]
        if max(values, default=0) < 2:             # 0/1 everywhere: flags, not strings
            continue
        ok = all(v == 0 or (v < len(strings) and strings[v - 1] == 0) for v in values)
        if ok:
            out.add(f)
    return out


def cstr(strings, off):
    end = strings.find(b"\0", off)
    return strings[off:end + 1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--overlay", required=True)
    ap.add_argument("--stock", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key", default="0",
                    help="comma-separated field indices that identify a row (default 0, the id column; "
                         "CharacterFacialHairStyles has no id and is keyed 0,1,2 = race,sex,variation)")
    ap.add_argument("--base-drop", default=None, metavar="FIELD=V1,V2",
                    help="before merging, drop base rows that are not in stock and whose FIELD is one of "
                         "the values - e.g. 1=9,12 on the character-appearance DBCs, where Patch-H carries "
                         "its own older goblin rows that would sit beside the module's and scramble faces")
    args = ap.parse_args()
    key_fields = [int(k) for k in args.key.split(",")]

    def key(row):
        return tuple(row[k] for k in key_fields)

    bf, brows, bstr = read(args.base)
    of, orows, ostr = read(args.overlay)
    sf, srows, sstr = read(args.stock)
    if not (bf == of == sf):
        raise SystemExit(f"field count differs: base {bf}, overlay {of}, stock {sf}")

    sfields = string_fields(bf, brows, bstr)
    if not (sfields == string_fields(of, orows, ostr) == string_fields(sf, srows, sstr)):
        raise SystemExit("string-field detection disagrees between the three files; refusing")

    def resolved(row, strings):
        return tuple(cstr(strings, v) if f in sfields else v for f, v in enumerate(row))

    stock = {key(r): resolved(r, sstr) for r in srows}

    dropped = 0
    if args.base_drop:
        field, values = args.base_drop.split("=")
        field, values = int(field), {int(v) for v in values.split(",")}
        kept = [r for r in brows if not (r[field] in values and key(r) not in stock)]
        dropped = len(brows) - len(kept)
        brows = kept
    base_by_id = {key(r): i for i, r in enumerate(brows)}

    # Rows the overlay added or changed relative to stock.
    changed = [r for r in orows if stock.get(key(r)) != resolved(r, ostr)]

    out_rows = list(brows)
    out_str = bytearray(bstr)
    added = replaced = clashed = 0
    for r in changed:
        new = []
        for f, v in enumerate(r):
            if f in sfields and v:
                s = cstr(ostr, v)
                new.append(len(out_str))
                out_str += s
            else:
                new.append(v)
        new = tuple(new)
        if key(r) in base_by_id:
            i = base_by_id[key(r)]
            if resolved(brows[i], bstr) != stock.get(key(r)):
                clashed += 1
            out_rows[i] = new
            replaced += 1
        else:
            base_by_id[key(r)] = len(out_rows)
            out_rows.append(new)
            added += 1

    out_rows.sort(key=key)
    with open(args.out, "wb") as h:
        h.write(HEADER.pack(b"WDBC", len(out_rows), bf, bf * 4, len(out_str)))
        for r in out_rows:
            h.write(struct.pack(f"<{bf}I", *r))
        h.write(out_str)

    print(f"{args.out}: base {len(brows)} rows ({dropped} dropped) + overlay {len(changed)} changed rows "
          f"-> {len(out_rows)} rows ({added} added, {replaced} replaced, {clashed} where both patches "
          f"had changed the same id; overlay kept). string fields: {sorted(sfields)}")


if __name__ == "__main__":
    main()
