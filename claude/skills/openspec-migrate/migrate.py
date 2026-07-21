#!/usr/bin/env python3
"""Deterministically remove the bounded legacy implementation-review receipt.

This program deliberately has no repository-specific dependencies.  It plans from
bytes on disk for both ``preview`` and ``apply``; a digest therefore confirms an
exact scope and exact set of inputs rather than a serialized, reusable plan.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys
from typing import Any, NoReturn

SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
HEADING = b"## Implementation Review Receipt"
FIELDS = (
    b"Reviewed at",
    b"Decision",
    b"Approval gate",
    b"Status transition",
    b"Evidence reviewed",
    b"Identity method",
    b"Identity digest",
    b"Identity bases",
    b"Identity paths",
    b"Findings",
    b"Proof",
    b"Next owner",
)
EXCLUDED = ["openspec/changes/archive", "openspec/changes/reviews"]
LEGACY_TEMPLATE_COMMENT = (
    b"<!-- Explicitly deprecated legacy-reader compatibility retained until the",
    b"     publisher migration slice. Readonly implementation review does not own this",
    b"     section. Exactly one compact current completed-verdict body remains the",
    b"     compatibility shape for a bound DONE story. Status controls non-DONE routing, where an older receipt may be",
    b"     historical/superseded by",
    b"     authorized later work. Duplicate headings/bodies, malformed or",
    b"     non-approving fields, or a contradiction block. Missing-receipt",
    b"     compatibility is limited to an unbound pre-v3 DONE story with zero",
    b"     Initiative or Initiative-like lines; malformed present Initiative-like",
    b"     fields are conflicts, never absence. Never synthesize a backfill. -->",
)


class MigrationError(Exception):
    """An input is outside the migration's fail-closed contract."""


def fail(message: str) -> NoReturn:
    raise MigrationError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        fail(f"path escapes workspace: {path}")


DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW


def open_root(path: Path) -> int:
    """Open and pin the workspace root without following a final symlink."""
    try:
        fd = os.open(path, DIRECTORY_FLAGS)
    except OSError as exc:
        fail(f"workspace root must be a real directory: {path}: {exc}")
    if not stat.S_ISDIR(os.fstat(fd).st_mode):
        os.close(fd)
        fail(f"workspace root must be a real directory: {path}")
    return fd


def open_directory_at(parent_fd: int, name: str, display: Path) -> int:
    """Open one directory component relative to an already pinned parent."""
    if not name or name in {".", ".."} or "/" in name:
        fail(f"invalid directory component: {display}")
    try:
        fd = os.open(name, DIRECTORY_FLAGS, dir_fd=parent_fd)
    except OSError as exc:
        fail(f"directory must be real and non-symlink: {display}: {exc}")
    if not stat.S_ISDIR(os.fstat(fd).st_mode):
        os.close(fd)
        fail(f"directory must be real and non-symlink: {display}")
    return fd


def open_directory_chain(root_fd: int, root: Path, parts: tuple[str, ...]) -> int:
    """Pin a descendant by opening every component with O_NOFOLLOW."""
    current = os.dup(root_fd)
    display = root
    try:
        for part in parts:
            display /= part
            following = open_directory_at(current, part, display)
            os.close(current)
            current = following
        return current
    except BaseException:
        os.close(current)
        raise


def verify_directory_entry(
    parent_fd: int,
    directory_fd: int,
    name: str,
    expected_identity: tuple[int, int],
    display: Path,
    boundary: str,
) -> None:
    """Confirm a pinned directory is still the named child of its pinned parent."""
    pinned = os.fstat(directory_fd)
    try:
        current = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc:
        fail(f"story containment drift {boundary}: {display}: {exc}")
    identities = {
        (pinned.st_dev, pinned.st_ino),
        (current.st_dev, current.st_ino),
    }
    if not stat.S_ISDIR(current.st_mode) or identities != {expected_identity}:
        fail(f"story containment drift {boundary}: {display}")


def fd_identity(fd: int) -> tuple[int, int]:
    value = os.fstat(fd)
    return value.st_dev, value.st_ino


def pin_authority_hierarchy(
    root_fd: int,
    root: Path,
    changes_fd: int,
    initiative: str,
) -> tuple[dict[str, tuple[int, int]], int]:
    """Pin every named directory that authorizes a migration write."""
    opened: list[int] = []
    try:
        openspec_fd = open_directory_at(root_fd, "openspec", root / "openspec")
        opened.append(openspec_fd)
        named_changes_fd = open_directory_at(
            openspec_fd, "changes", root / "openspec" / "changes"
        )
        opened.append(named_changes_fd)
        initiatives_fd = open_directory_at(
            openspec_fd, "initiatives", root / "openspec" / "initiatives"
        )
        opened.append(initiatives_fd)
        initiative_fd = open_directory_at(
            initiatives_fd,
            initiative,
            root / "openspec" / "initiatives" / initiative,
        )
        if fd_identity(named_changes_fd) != fd_identity(changes_fd):
            os.close(initiative_fd)
            fail("changes containment drift during inventory")
        identities = {
            "root": fd_identity(root_fd),
            "openspec": fd_identity(openspec_fd),
            "changes": fd_identity(named_changes_fd),
            "initiatives": fd_identity(initiatives_fd),
            "initiative": fd_identity(initiative_fd),
        }
        return identities, initiative_fd
    finally:
        for fd in reversed(opened):
            os.close(fd)


def verify_named_authority(
    *,
    root_fd: int,
    root: Path,
    changes_fd: int,
    parent_fd: int,
    story_name: str,
    story_directory_identity: tuple[int, int],
    story_source: bytes,
    progress_name: str,
    progress_source: bytes,
    initiative: str,
    initiative_source: bytes,
    authority_identities: dict[str, tuple[int, int]],
    boundary: str,
) -> None:
    """Reopen the named authority tree and compare all planned identities/bytes."""
    opened: list[int] = []
    try:
        openspec_fd = open_directory_at(root_fd, "openspec", root / "openspec")
        opened.append(openspec_fd)
        named_changes_fd = open_directory_at(
            openspec_fd, "changes", root / "openspec" / "changes"
        )
        opened.append(named_changes_fd)
        named_story_fd = open_directory_at(
            named_changes_fd,
            story_name,
            root / "openspec" / "changes" / story_name,
        )
        opened.append(named_story_fd)
        initiatives_fd = open_directory_at(
            openspec_fd, "initiatives", root / "openspec" / "initiatives"
        )
        opened.append(initiatives_fd)
        named_initiative_fd = open_directory_at(
            initiatives_fd,
            initiative,
            root / "openspec" / "initiatives" / initiative,
        )
        opened.append(named_initiative_fd)

        current = {
            "root": fd_identity(root_fd),
            "openspec": fd_identity(openspec_fd),
            "changes": fd_identity(named_changes_fd),
            "initiatives": fd_identity(initiatives_fd),
            "initiative": fd_identity(named_initiative_fd),
        }
        if (
            current != authority_identities
            or fd_identity(named_changes_fd) != fd_identity(changes_fd)
            or fd_identity(named_story_fd) != story_directory_identity
            or fd_identity(named_story_fd) != fd_identity(parent_fd)
        ):
            fail(f"authority containment drift {boundary}")

        story_path = root / "openspec" / "changes" / story_name / "story.md"
        named_story = read_file_at(named_story_fd, "story.md", story_path)
        assert named_story is not None
        binding, _story_hash = canonical_binding(named_story, story_path)
        if named_story != story_source or binding != initiative:
            fail(f"story binding drift {boundary}: {story_path}")
        progress_path = root / "openspec" / "changes" / story_name / progress_name
        if (
            read_file_at(named_story_fd, progress_name, progress_path)
            != progress_source
        ):
            fail(f"input drift {boundary}: {progress_path}")
        initiative_path = (
            root / "openspec" / "initiatives" / initiative / "initiative.md"
        )
        if (
            read_file_at(named_initiative_fd, "initiative.md", initiative_path)
            != initiative_source
        ):
            fail(f"initiative drift {boundary}: {initiative}")
    finally:
        for fd in reversed(opened):
            os.close(fd)


def read_file_at(
    parent_fd: int, name: str, display: Path, *, required: bool = True
) -> bytes | None:
    """Read a pinned regular file without following a symlink."""
    try:
        fd = os.open(name, FILE_FLAGS, dir_fd=parent_fd)
    except FileNotFoundError:
        if required:
            fail(f"missing file: {display}")
        return None
    except OSError as exc:
        fail(f"file must be regular and non-symlink: {display}: {exc}")
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            fail(f"file must be regular and non-symlink: {display}")
        chunks: list[bytes] = []
        while chunk := os.read(fd, 1024 * 1024):
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(fd)


def lines_with_offsets(data: bytes) -> list[tuple[int, int, bytes]]:
    result: list[tuple[int, int, bytes]] = []
    offset = 0
    for raw in data.splitlines(keepends=True):
        end = offset + len(raw)
        result.append((offset, end, raw.rstrip(b"\r\n")))
        offset = end
    if offset < len(data):  # defensive; splitlines(keepends=True) normally covers it
        result.append((offset, len(data), data[offset:]))
    return result


def canonical_binding(data: bytes, story_path: Path) -> tuple[str | None, str]:
    """Return a canonical binding, allowing only an exact zero-candidate legacy case."""
    candidates: list[bytes] = []
    for _start, _end, line in lines_with_offsets(data):
        if line.startswith(b"## "):
            break
        if re.match(rb"^Initiative(?:\b|\s|:)", line, flags=re.IGNORECASE):
            candidates.append(line)
    if not candidates:
        return None, sha256(data)
    canonical = [
        line
        for line in candidates
        if re.fullmatch(rb"Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)", line)
    ]
    if len(candidates) != 1 or len(canonical) != 1:
        fail(f"story must have exactly one canonical Initiative binding: {story_path}")
    value = canonical[0].split(b": ", 1)[1].decode("ascii")
    return value, sha256(data)


def is_receipt_heading_like(line: bytes) -> bool:
    return bool(
        re.match(
            rb"^#{1,6}[ \t]+.*Implementation[ \t_-]+Review[ \t_-]+Receipt.*$",
            line,
            flags=re.IGNORECASE,
        )
    )


def is_receipt_field_like(line: bytes) -> bool:
    stripped = line.lstrip(b" \t")
    return any(
        re.match(
            rb"^-[ \t]+" + re.escape(field) + rb"[ \t]*:",
            stripped,
            flags=re.IGNORECASE,
        )
        for field in FIELDS
    )


def placeholder(value: bytes) -> bool:
    normalized = value.strip().lower()
    return (
        not normalized
        or normalized
        in {
            b"tbd",
            b"todo",
            b"unknown",
            b"n/a",
            b"none",
            b"-",
            b"pending",
            b"placeholder",
        }
        or (normalized.startswith(b"<") and normalized.endswith(b">"))
    )


def receipt_range(path: Path, data: bytes) -> tuple[int, int, int, int] | None:
    lines = lines_with_offsets(data)
    exact = [index for index, item in enumerate(lines) if item[2] == HEADING]
    heading_like = [
        index for index, item in enumerate(lines) if is_receipt_heading_like(item[2])
    ]
    field_like = [
        index for index, item in enumerate(lines) if is_receipt_field_like(item[2])
    ]

    if not exact:
        if heading_like or field_like:
            fail(f"malformed or stray legacy receipt material: {path}")
        return None
    if len(exact) != 1 or heading_like != exact:
        fail(f"duplicate or malformed legacy receipt heading: {path}")

    first = exact[0]
    stop = len(lines)
    for index in range(first + 1, len(lines)):
        if lines[index][2].startswith(b"## "):
            stop = index
            break

    seen: list[bytes] = []
    body = [line for _start, _end, line in lines[first + 1 : stop]]
    index = 0
    while index < len(body):
        line = body[index]
        if not line.strip(b" \t"):
            index += 1
            continue
        comment_end = index + len(LEGACY_TEMPLATE_COMMENT)
        if tuple(body[index:comment_end]) == LEGACY_TEMPLATE_COMMENT:
            index = comment_end
            continue
        match = re.fullmatch(rb"- ([^:]+): (.+)", line)
        if match is None:
            fail(f"invalid content inside legacy receipt: {path}")
        field, value = match.groups()
        if field not in FIELDS or placeholder(value):
            fail(f"unknown, empty, or placeholder legacy receipt field: {path}")
        seen.append(field)
        index += 1
    if tuple(seen) != FIELDS:
        fail(f"legacy receipt fields are missing, duplicate, or reordered: {path}")

    outside = lines[:first] + lines[stop:]
    if any(
        is_receipt_heading_like(line) or is_receipt_field_like(line)
        for _, _, line in outside
    ):
        fail(f"mixed legacy receipt material outside removable section: {path}")

    start_byte = lines[first][0]
    end_byte = lines[stop][0] if stop < len(lines) else len(data)
    start_line = first + 1
    end_line = stop if stop < len(lines) else len(lines)
    return start_byte, end_byte, start_line, end_line


def validate_output(path: Path, output: bytes) -> None:
    if receipt_range(path, output) is not None:
        fail(f"constructed output still contains a legacy receipt: {path}")


def inventory(
    root: Path,
    initiative: str,
    story: str | None,
    *,
    root_fd: int | None = None,
    changes_fd: int | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    if not SLUG.fullmatch(initiative) or (
        story is not None and not SLUG.fullmatch(story)
    ):
        fail("initiative and story must be lowercase kebab-case slugs")

    owned_root_fd = root_fd is None
    owned_changes_fd = changes_fd is None
    workspace_fd = open_root(root) if root_fd is None else root_fd
    initiative_fd: int | None = None
    try:
        if changes_fd is None:
            changes_fd = open_directory_chain(
                workspace_fd, root, ("openspec", "changes")
            )
        authority_identities, initiative_fd = pin_authority_hierarchy(
            workspace_fd, root, changes_fd, initiative
        )
        initiative_identity = fd_identity(initiative_fd)
        initiative_path = (
            root / "openspec" / "initiatives" / initiative / "initiative.md"
        )
        initiative_data = read_file_at(initiative_fd, "initiative.md", initiative_path)
        assert initiative_data is not None
        changes = root / "openspec" / "changes"

        if story is not None:
            if story in {"archive", "reviews"}:
                fail("archive and reviews are not active stories")
            candidate_names = [story]
        else:
            candidate_names = []
            for name in sorted(os.listdir(changes_fd)):
                child = changes / name
                if name in {"archive", "reviews"}:
                    continue
                if not SLUG.fullmatch(name):
                    fail(f"active change directory has an invalid slug: {child}")
                mode = os.stat(name, dir_fd=changes_fd, follow_symlinks=False).st_mode
                if stat.S_ISLNK(mode):
                    fail(f"active change candidate must not be a symlink: {child}")
                if stat.S_ISDIR(mode):
                    candidate_names.append(name)

        remove: list[dict[str, Any]] = []
        no_op: list[str] = []
        inputs: list[dict[str, Any]] = []
        writes: list[dict[str, Any]] = []
        for name in candidate_names:
            directory = changes / name
            directory_fd = open_directory_at(changes_fd, name, directory)
            try:
                directory_stat = os.fstat(directory_fd)
                directory_identity = (directory_stat.st_dev, directory_stat.st_ino)
                story_path = directory / "story.md"
                story_data = read_file_at(directory_fd, "story.md", story_path)
                assert story_data is not None
                binding, story_hash = canonical_binding(story_data, story_path)
                if binding != initiative:
                    if story is not None:
                        detail = "unbound" if binding is None else f"bound to {binding}"
                        fail(f"story is {detail}, not {initiative}: {story_path}")
                    continue
                progress = directory / "progress.md"
                data = read_file_at(
                    directory_fd, "progress.md", progress, required=False
                )
            finally:
                os.close(directory_fd)
            rel = relative(progress, root)
            if data is None:
                no_op.append(rel)
                inputs.append(
                    {"path": rel, "missing": True, "story_sha256": story_hash}
                )
                continue
            found = receipt_range(progress, data)
            source_hash = sha256(data)
            inputs.append(
                {"path": rel, "sha256": source_hash, "story_sha256": story_hash}
            )
            if found is None:
                no_op.append(rel)
                continue
            start, end, start_line, end_line = found
            output = data[:start] + data[end:]
            validate_output(progress, output)
            item = {
                "path": rel,
                "sha256": source_hash,
                "start_line": start_line,
                "end_line": end_line,
            }
            remove.append(item)
            writes.append(
                {
                    "path": progress,
                    "relative_path": rel,
                    "source": data,
                    "output": output,
                    "story_source": story_data,
                    "story_directory_identity": directory_identity,
                    "initiative": initiative,
                    "initiative_source": initiative_data,
                    "initiative_directory_identity": initiative_identity,
                    "authority_identities": authority_identities,
                }
            )

        digest_payload = {
            "version": 1,
            "initiative": initiative,
            "story": story,
            "initiative_sha256": sha256(initiative_data),
            "inputs": inputs,
            "remove": remove,
            "no_op": no_op,
            "excluded": EXCLUDED,
        }
        encoded = json.dumps(
            digest_payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")
        public = {
            "initiative": initiative,
            "story": story,
            "digest": sha256(encoded),
            "remove": remove,
            "no_op": no_op,
            "excluded": EXCLUDED,
        }
        return public, writes
    finally:
        if initiative_fd is not None:
            os.close(initiative_fd)
        if owned_changes_fd and changes_fd is not None:
            os.close(changes_fd)
        if owned_root_fd:
            os.close(workspace_fd)


def atomic_replace(
    path: Path,
    source: bytes,
    output: bytes,
    *,
    root: Path,
    root_fd: int,
    changes_fd: int,
    relative_path: str,
    story_source: bytes,
    story_directory_identity: tuple[int, int],
    initiative: str,
    initiative_source: bytes,
    initiative_directory_identity: tuple[int, int],
    authority_identities: dict[str, tuple[int, int]],
) -> None:
    """Replace one progress file through a pinned, no-symlink directory chain."""
    parts = tuple(Path(relative_path).parts)
    if (
        len(parts) != 4
        or parts[:2] != ("openspec", "changes")
        or parts[-1] != "progress.md"
    ):
        fail(f"invalid migration write path: {relative_path}")
    story_name = parts[2]
    parent_fd = open_directory_at(changes_fd, story_name, path.parent)
    try:
        initiative_fd = open_directory_chain(
            root_fd, root, ("openspec", "initiatives", initiative)
        )
    except BaseException:
        os.close(parent_fd)
        raise
    temporary_name = f".{parts[-1]}.migrate-{secrets.token_hex(12)}"
    temporary_created = False
    replaced = False
    mode: int | None = None

    def verify_authority(progress_source: bytes, boundary: str) -> None:
        verify_named_authority(
            root_fd=root_fd,
            root=root,
            changes_fd=changes_fd,
            parent_fd=parent_fd,
            story_name=story_name,
            story_directory_identity=story_directory_identity,
            story_source=story_source,
            progress_name=parts[-1],
            progress_source=progress_source,
            initiative=initiative,
            initiative_source=initiative_source,
            authority_identities=authority_identities,
            boundary=boundary,
        )

    def cleanup_named_temporary() -> None:
        """Remove our copied temporary file from a replacement named tree."""
        opened: list[int] = []
        try:
            openspec_fd = open_directory_at(root_fd, "openspec", root / "openspec")
            opened.append(openspec_fd)
            named_changes_fd = open_directory_at(
                openspec_fd, "changes", root / "openspec" / "changes"
            )
            opened.append(named_changes_fd)
            named_story_fd = open_directory_at(
                named_changes_fd, story_name, path.parent
            )
            opened.append(named_story_fd)
            temporary = read_file_at(
                named_story_fd,
                temporary_name,
                path.parent / temporary_name,
                required=False,
            )
            if temporary is None:
                return
            if temporary != output:
                fail(
                    f"unexpected named temporary contents: {path.parent / temporary_name}"
                )
            os.unlink(temporary_name, dir_fd=named_story_fd)
            os.fsync(named_story_fd)
        finally:
            for fd in reversed(opened):
                os.close(fd)

    try:
        verify_directory_entry(
            changes_fd,
            parent_fd,
            story_name,
            story_directory_identity,
            path.parent,
            "immediately before write",
        )
        initiative_stat = os.fstat(initiative_fd)
        if (
            initiative_stat.st_dev,
            initiative_stat.st_ino,
        ) != initiative_directory_identity or read_file_at(
            initiative_fd,
            "initiative.md",
            root / "openspec" / "initiatives" / initiative / "initiative.md",
        ) != initiative_source:
            fail(f"initiative drift immediately before write: {initiative}")
        current_story = read_file_at(parent_fd, "story.md", path.parent / "story.md")
        assert current_story is not None
        binding, _story_hash = canonical_binding(
            current_story, path.parent / "story.md"
        )
        if current_story != story_source or binding != initiative:
            fail(
                f"story binding drift immediately before write: {path.parent / 'story.md'}"
            )
        current = read_file_at(parent_fd, parts[-1], path)
        if current != source:
            fail(f"input drift immediately before write: {path}")
        source_fd = os.open(parts[-1], FILE_FLAGS, dir_fd=parent_fd)
        try:
            mode = stat.S_IMODE(os.fstat(source_fd).st_mode)
        finally:
            os.close(source_fd)

        verify_directory_entry(
            changes_fd,
            parent_fd,
            story_name,
            story_directory_identity,
            path.parent,
            "immediately before temporary write",
        )
        verify_authority(source, "immediately before temporary creation")
        temporary_fd = os.open(
            temporary_name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            mode,
            dir_fd=parent_fd,
        )
        temporary_created = True
        try:
            verify_authority(source, "immediately after temporary creation")
            verify_directory_entry(
                changes_fd,
                parent_fd,
                story_name,
                story_directory_identity,
                path.parent,
                "after temporary creation",
            )
            view = memoryview(output)
            while view:
                verify_directory_entry(
                    changes_fd,
                    parent_fd,
                    story_name,
                    story_directory_identity,
                    path.parent,
                    "immediately before temporary write",
                )
                verify_authority(source, "immediately before temporary write")
                written = os.write(temporary_fd, view)
                view = view[written:]
                verify_authority(source, "immediately after temporary write")
                verify_directory_entry(
                    changes_fd,
                    parent_fd,
                    story_name,
                    story_directory_identity,
                    path.parent,
                    "immediately after temporary write",
                )
            os.fsync(temporary_fd)
            os.fchmod(temporary_fd, mode)
        finally:
            os.close(temporary_fd)

        # These are the final reads before the dirfd-relative atomic rename.
        verify_directory_entry(
            changes_fd,
            parent_fd,
            story_name,
            story_directory_identity,
            path.parent,
            "immediately before atomic replace",
        )
        initiative_stat = os.fstat(initiative_fd)
        if (
            initiative_stat.st_dev,
            initiative_stat.st_ino,
        ) != initiative_directory_identity or read_file_at(
            initiative_fd,
            "initiative.md",
            root / "openspec" / "initiatives" / initiative / "initiative.md",
        ) != initiative_source:
            fail(f"initiative drift immediately before atomic replace: {initiative}")
        current_story = read_file_at(parent_fd, "story.md", path.parent / "story.md")
        assert current_story is not None
        binding, _story_hash = canonical_binding(
            current_story, path.parent / "story.md"
        )
        if current_story != story_source or binding != initiative:
            fail(
                f"story binding drift immediately before atomic replace: {path.parent / 'story.md'}"
            )
        if read_file_at(parent_fd, parts[-1], path) != source:
            fail(f"input drift immediately before atomic replace: {path}")
        verify_authority(source, "immediately before atomic replace")
        os.replace(
            temporary_name,
            parts[-1],
            src_dir_fd=parent_fd,
            dst_dir_fd=parent_fd,
        )
        temporary_created = False
        replaced = True
        os.fsync(parent_fd)
        verify_directory_entry(
            changes_fd,
            parent_fd,
            story_name,
            story_directory_identity,
            path.parent,
            "immediately after atomic replace",
        )
        verify_authority(output, "immediately after atomic replace")
        if read_file_at(parent_fd, parts[-1], path) != output:
            fail(f"post-write verification failed: {path}")
    except BaseException as exc:
        if replaced:
            # POSIX has no atomic compare-and-swap rename.  Once replacement
            # succeeds, any attempted rollback could overwrite bytes written by
            # a later actor between an ownership check and the restoring rename.
            # The rename is therefore the commit point: report truthful partial
            # state and leave every post-commit byte untouched for preview/rerun.
            if isinstance(exc, (MigrationError, OSError)):
                fail(f"partial migration after atomic commit: {path}: {exc}")
            raise
        try:
            cleanup_named_temporary()
        except BaseException as cleanup_exc:
            fail(f"pre-commit temporary cleanup failed: {path}: {cleanup_exc}")
        raise
    finally:
        if temporary_created:
            try:
                os.unlink(temporary_name, dir_fd=parent_fd)
            except FileNotFoundError:
                pass
        os.close(parent_fd)
        os.close(initiative_fd)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="action", required=True)
    preview = subparsers.add_parser("preview")
    preview.add_argument("initiative")
    preview.add_argument("story", nargs="?")
    apply = subparsers.add_parser("apply")
    apply.add_argument("initiative")
    apply.add_argument("story", nargs="?")
    apply.add_argument("--confirm", required=True)
    return result


def emit(value: dict[str, Any]) -> None:
    print(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True))


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    root = Path.cwd()
    root_fd: int | None = None
    changes_fd: int | None = None
    try:
        root_fd = open_root(root)
        changes_fd = open_directory_chain(root_fd, root, ("openspec", "changes"))
        plan, writes = inventory(
            root,
            args.initiative,
            args.story,
            root_fd=root_fd,
            changes_fd=changes_fd,
        )
        if args.action == "preview":
            emit({"action": "preview", **plan})
            return 0
        if (
            not re.fullmatch(r"[0-9a-f]{64}", args.confirm)
            or args.confirm != plan["digest"]
        ):
            fail("confirmation digest does not match the current exact preview")
        # inventory() fully validates every target before the first write.
        removed: list[str] = []
        for write in writes:
            atomic_replace(
                write["path"],
                write["source"],
                write["output"],
                root=root,
                root_fd=root_fd,
                changes_fd=changes_fd,
                relative_path=write["relative_path"],
                story_source=write["story_source"],
                story_directory_identity=write["story_directory_identity"],
                initiative=write["initiative"],
                initiative_source=write["initiative_source"],
                initiative_directory_identity=write["initiative_directory_identity"],
                authority_identities=write["authority_identities"],
            )
            removed.append(relative(write["path"], root))
        emit(
            {
                "action": "apply",
                "digest": plan["digest"],
                "removed": removed,
                "no_op": plan["no_op"],
                "excluded": plan["excluded"],
            }
        )
        return 0
    except (MigrationError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    finally:
        if changes_fd is not None:
            os.close(changes_fd)
        if root_fd is not None:
            os.close(root_fd)


if __name__ == "__main__":
    raise SystemExit(main())
