#!/usr/bin/env python3
"""
Log in to the auth server the way a 3.3.5a client does and print the realm
list it hands back.

This is the only way to check, without a game client, that a remote player can
authenticate and that the realm row advertises an address they can reach.

    ./check_login.py <host> <account> <password> [port]

Connecting to the server's *public* address (rather than 127.0.0.1) matters:
the auth server picks the realm address based on the client's source IP, so a
loopback client and a remote client are told different things.
"""

import hashlib
import os
import socket
import struct
import sys

# SRP6 parameters used by WoW
N = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
G = 7
K = 3

CMD_CHALLENGE = 0x00
CMD_PROOF = 0x01
CMD_REALM_LIST = 0x10

CHALLENGE_RESULTS = {
    0x00: "success",
    0x04: "unknown account",
    0x05: "incorrect password",
    0x06: "account already online",
    0x0A: "account banned",
    0x0C: "account suspended",
    0x09: "wrong client version",
}


def sha1(*chunks):
    digest = hashlib.sha1()
    for chunk in chunks:
        digest.update(chunk)
    return digest.digest()


def to_le(value, size):
    return value.to_bytes(size, "little")


def from_le(raw):
    return int.from_bytes(raw, "little")


def recv_exactly(sock, count):
    buffer = b""
    while len(buffer) < count:
        chunk = sock.recv(count - len(buffer))
        if not chunk:
            raise SystemExit(f"server closed the connection after {len(buffer)} of {count} bytes")
        buffer += chunk
    return buffer


def build_challenge(account):
    account = account.upper().encode()
    body = b"".join([
        b"WoW\x00",
        bytes([3, 3, 5]),
        struct.pack("<H", 12340),
        b"68x\x00",        # platform, reversed
        b"niW\x00",        # os, reversed
        b"SUne",           # locale, reversed
        struct.pack("<I", 0),   # timezone bias
        struct.pack("<I", 0),   # client ip
        bytes([len(account)]),
        account,
    ])
    # size counts everything after the size field itself
    return bytes([CMD_CHALLENGE, 0x08]) + struct.pack("<H", len(body)) + body


def interleave(session_key_int):
    """SRP6 session key derivation: split S, hash both halves, interleave."""
    raw = to_le(session_key_int, 32)

    # drop leading zero byte pairs (trailing bytes in little endian form)
    while raw and raw[0] == 0:
        raw = raw[2:]

    even = sha1(raw[0::2])
    odd = sha1(raw[1::2])

    return bytes(byte for pair in zip(even, odd) for byte in pair)


def login(host, port, account, password):
    sock = socket.create_connection((host, port), timeout=15)

    sock.sendall(build_challenge(account))

    header = recv_exactly(sock, 3)
    if header[0] != CMD_CHALLENGE:
        raise SystemExit(f"unexpected opcode {header[0]:#02x} in challenge reply")

    result = header[2]
    print(f"logon challenge : {CHALLENGE_RESULTS.get(result, f'error {result:#02x}')}")
    if result != 0x00:
        raise SystemExit(1)

    body = recv_exactly(sock, 32 + 1 + 1 + 1 + 32 + 32 + 16 + 1)
    offset = 0

    def take(count):
        nonlocal offset
        chunk = body[offset:offset + count]
        offset += count
        return chunk

    b_raw = take(32)
    g_len = take(1)[0]
    g_raw = take(g_len)
    n_len = take(1)[0]
    n_raw = take(n_len)
    salt = take(32)
    take(16)   # version challenge
    security_flags = take(1)[0]

    if security_flags:
        raise SystemExit(f"account needs extra security (flags {security_flags:#02x}), not supported here")

    server_b = from_le(b_raw)
    if from_le(g_raw) != G or from_le(n_raw) != N:
        raise SystemExit("server uses unexpected SRP6 parameters")

    # x = SHA1(salt | SHA1(USER:PASS)), the credentials hash
    credentials = sha1(f"{account.upper()}:{password.upper()}".encode())
    x = from_le(sha1(salt, credentials))

    a = from_le(os.urandom(19))
    client_a = pow(G, a, N)
    a_raw = to_le(client_a, 32)

    u = from_le(sha1(a_raw, b_raw))
    s = pow((server_b - K * pow(G, x, N)) % N, a + u * x, N)
    session_key = interleave(s)

    # M1 proves to the server that we know the password
    n_hash = sha1(to_le(N, 32))
    g_hash = sha1(bytes([G]))
    xored = bytes(left ^ right for left, right in zip(n_hash, g_hash))
    m1 = sha1(xored, sha1(account.upper().encode()), salt, a_raw, b_raw, session_key)

    sock.sendall(bytes([CMD_PROOF]) + a_raw + m1 + b"\x00" * 20 + bytes([0, 0]))

    proof_header = recv_exactly(sock, 2)
    if proof_header[1] != 0x00:
        raise SystemExit(f"logon proof rejected: error {proof_header[1]:#02x} (wrong password?)")

    recv_exactly(sock, 20 + 4 + 4 + 2)   # M2 + account flags + survey id + login flags
    print("logon proof     : accepted")

    # Ask for the realm list, which is what tells a client where to connect
    sock.sendall(bytes([CMD_REALM_LIST]) + struct.pack("<I", 0))

    list_header = recv_exactly(sock, 3)
    payload = recv_exactly(sock, struct.unpack("<H", list_header[1:3])[0])

    offset = 6   # uint32 unused + uint16 realm count
    realm_count = struct.unpack_from("<H", payload, 4)[0]
    print(f"realms          : {realm_count}")

    def take_cstring():
        nonlocal offset
        end = payload.index(b"\x00", offset)
        value = payload[offset:end].decode("utf-8", "replace")
        offset = end + 1
        return value

    for _ in range(realm_count):
        realm_type, locked, flags = struct.unpack_from("<BBB", payload, offset)
        offset += 3
        name = take_cstring()
        address = take_cstring()
        population, characters, timezone, _unk = struct.unpack_from("<fBBB", payload, offset)
        offset += 7
        print(f"  {name!r} -> {address}  (type {realm_type}, locked {locked}, "
              f"flags {flags:#02x}, characters {characters}, population {population:.0f})")

    sock.close()


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)

    login(sys.argv[1], int(sys.argv[4]) if len(sys.argv) > 4 else 3724, sys.argv[2], sys.argv[3])
