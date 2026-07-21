#!/usr/bin/env python3
"""Behavioral contract for the bounded legacy-receipt migration CLI.

The future standard-library helper is invoked from the workspace root as:

    python migrate.py preview INITIATIVE [STORY]
    python migrate.py apply INITIATIVE [STORY] --confirm PREVIEW_DIGEST

Each successful command prints one JSON object.  Preview objects contain a stable
``digest``, ``remove`` paths, and ``no_op`` paths.  Apply objects contain
``removed`` and ``no_op`` paths.  Invalid input exits nonzero before any write.
"""

from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from typing import Any, cast

REPO_ROOT = Path(__file__).resolve().parents[1]
MIGRATE = REPO_ROOT / "claude" / "skills" / "openspec-migrate" / "migrate.py"
INITIATIVE = "sample-initiative"

FIELDS = (
    "Reviewed at",
    "Decision",
    "Approval gate",
    "Status transition",
    "Evidence reviewed",
    "Identity method",
    "Identity digest",
    "Identity bases",
    "Identity paths",
    "Findings",
    "Proof",
    "Next owner",
)
LEGACY_TEMPLATE_COMMENT = """<!-- Explicitly deprecated legacy-reader compatibility retained until the
     publisher migration slice. Readonly implementation review does not own this
     section. Exactly one compact current completed-verdict body remains the
     compatibility shape for a bound DONE story. Status controls non-DONE routing, where an older receipt may be
     historical/superseded by
     authorized later work. Duplicate headings/bodies, malformed or
     non-approving fields, or a contradiction block. Missing-receipt
     compatibility is limited to an unbound pre-v3 DONE story with zero
     Initiative or Initiative-like lines; malformed present Initiative-like
     fields are conflicts, never absence. Never synthesize a backfill. -->"""


def receipt(*, comment: str = "", extra: str = "") -> bytes:
    lines = ["## Implementation Review Receipt"]
    if comment:
        lines.extend(comment.splitlines())
    for index, field in enumerate(FIELDS, 1):
        lines.append(f"- {field}: value-{index}")
    if extra:
        lines.append(extra)
    return ("\n".join(lines) + "\n\n").encode()


def progress_with_receipt(*, suffix: bytes | None = None) -> tuple[bytes, bytes]:
    prefix = (
        "# Progress\n"
        "\n"
        "Status: ✅ DONE\n"
        "Review Focus: |\n"
        "  preserve  trailing spaces  \n"
        "\n"
        "## Progress Timeline\n"
        "- 2026-01-02: implementation complete\n"
        "\n"
    ).encode()
    tail = (
        suffix
        if suffix is not None
        else ("## Session Handoff\n- Status: ✅ DONE\n- Exact bytes: café\n").encode()
    )
    return prefix + receipt() + tail, prefix + tail


class Workspace:
    def __init__(self, root: Path) -> None:
        self.root = root
        initiative = root / "openspec" / "initiatives" / INITIATIVE
        initiative.mkdir(parents=True)
        (initiative / "initiative.md").write_bytes(b"# Sample initiative\n")
        (root / "openspec" / "changes").mkdir(parents=True)

    def story(
        self,
        slug: str,
        *,
        progress: bytes | None = b"# Progress\n\n## Progress Timeline\n- clean\n",
        story: bytes | None = None,
    ) -> Path:
        directory = self.root / "openspec" / "changes" / slug
        directory.mkdir(parents=True)
        story_bytes = (
            story
            or (
                f"# Story\nPlan: 🟢 PLAN APPROVED\nStatus: ✅ DONE\n"
                f"Initiative: {INITIATIVE}\n\n## Acceptance Criteria\n- exact\n"
            ).encode()
        )
        (directory / "story.md").write_bytes(story_bytes)
        if progress is not None:
            (directory / "progress.md").write_bytes(progress)
        return directory


class MigrateBehaviorTest(unittest.TestCase):
    maxDiff = None

    @classmethod
    def setUpClass(cls) -> None:
        if not MIGRATE.is_file():
            raise AssertionError(
                "RED: missing future migration helper: "
                "claude/skills/openspec-migrate/migrate.py"
            )

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="openspec-migrate-test-")
        self.root = Path(self.temporary.name)
        self.workspace = Workspace(self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_cli(
        self,
        phase: str,
        *scope: str,
        confirm: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(MIGRATE), phase, *scope]
        if confirm is not None:
            command.extend(("--confirm", confirm))
        return subprocess.run(
            command,
            cwd=self.root,
            text=True,
            encoding="utf-8",
            capture_output=True,
            check=False,
            timeout=10,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )

    def success_json(self, result: subprocess.CompletedProcess[str]) -> dict[str, Any]:
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        try:
            value = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            self.fail(f"stdout is not one JSON object: {exc}: {result.stdout!r}")
        self.assertIsInstance(value, dict)
        return cast(dict[str, Any], value)

    def preview(self, story: str | None = None) -> dict[str, Any]:
        scope = (INITIATIVE,) if story is None else (INITIATIVE, story)
        value = self.success_json(self.run_cli("preview", *scope))
        self.assertEqual(value.get("action"), "preview")
        digest = value.get("digest")
        if not isinstance(digest, str):
            self.fail(f"preview digest is not a string: {digest!r}")
        self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertIsInstance(value.get("remove"), list)
        self.assertIsInstance(value.get("no_op"), list)
        return value

    def apply(self, digest: str, story: str | None = None) -> dict[str, Any]:
        scope = (INITIATIVE,) if story is None else (INITIATIVE, story)
        value = self.success_json(self.run_cli("apply", *scope, confirm=digest))
        self.assertEqual(value.get("action"), "apply")
        self.assertEqual(value.get("digest"), digest)
        self.assertIsInstance(value.get("removed"), list)
        self.assertIsInstance(value.get("no_op"), list)
        return value

    @staticmethod
    def tree_state(root: Path) -> dict[str, tuple[str, bytes | str]]:
        """Snapshot entries without following symlinks."""
        state: dict[str, tuple[str, bytes | str]] = {}
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root).as_posix()
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                state[relative] = ("symlink", os.readlink(path))
            elif stat.S_ISREG(mode):
                state[relative] = ("file", path.read_bytes())
            elif stat.S_ISDIR(mode):
                state[relative] = ("directory", b"")
            else:
                state[relative] = ("nonregular", b"")
        return state

    def assert_fails_without_writes(
        self,
        phase: str = "preview",
        *scope: str,
        confirm: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        before = self.tree_state(self.root)
        result = self.run_cli(phase, *(scope or (INITIATIVE,)), confirm=confirm)
        self.assertNotEqual(result.returncode, 0, "unsafe input unexpectedly succeeded")
        self.assertEqual(self.tree_state(self.root), before)
        return result

    def assert_post_replace_swap_reports_committed_partial_state(
        self, story_slug: str, swap_level: str
    ) -> None:
        original, expected = progress_with_receipt()
        directory = self.workspace.story(story_slug, progress=original)
        plan = self.preview(story_slug)
        if swap_level == "leaf":
            swap_root = directory
        elif swap_level == "changes":
            swap_root = self.root / "openspec" / "changes"
        elif swap_level == "openspec":
            swap_root = self.root / "openspec"
        else:  # pragma: no cover - test helper contract
            self.fail(f"unknown swap level: {swap_level}")
        swap_before = self.tree_state(swap_root)
        workspace_before = self.tree_state(self.root)
        escaped = self.root.parent / f"{self.root.name}-escaped-{swap_level}"
        self.addCleanup(shutil.rmtree, escaped, True)

        spec = importlib.util.spec_from_file_location(
            f"openspec_migrate_post_replace_{swap_level}_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail(f"could not load migration helper for {swap_level} swap test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        mutation_observed = False
        named_progress_after_swap: bytes | None = None

        def replace_then_swap(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed, named_progress_after_swap
            original_replace(*args, **kwargs)
            if not mutation_observed:
                swap_root.rename(escaped)
                shutil.copytree(escaped, swap_root)
                named_progress_after_swap = (directory / "progress.md").read_bytes()
                mutation_observed = True

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(module.os, "replace", side_effect=replace_then_swap),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    ["apply", INITIATIVE, story_slug, "--confirm", plan["digest"]]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "post-replace swap hook did not run")
        self.assertEqual(
            named_progress_after_swap,
            expected,
            "active named replacement did not retain the migrated bytes",
        )
        self.assertNotEqual(result, 0, "post-write containment drift reported success")
        self.assertIn(
            "containment drift immediately after atomic replace", stderr.getvalue()
        )
        workspace_expected = dict(workspace_before)
        workspace_expected[f"openspec/changes/{story_slug}/progress.md"] = (
            "file",
            expected,
        )
        if swap_level == "leaf":
            swap_progress = "progress.md"
            escaped_progress = escaped / "progress.md"
        elif swap_level == "changes":
            swap_progress = f"{story_slug}/progress.md"
            escaped_progress = escaped / story_slug / "progress.md"
        else:
            swap_progress = f"changes/{story_slug}/progress.md"
            escaped_progress = escaped / "changes" / story_slug / "progress.md"
        swap_expected = dict(swap_before)
        swap_expected[swap_progress] = ("file", expected)

        self.assertEqual(self.tree_state(self.root), workspace_expected)
        self.assertEqual(self.tree_state(swap_root), swap_expected)
        self.assertEqual(self.tree_state(escaped), swap_expected)
        self.assertEqual((directory / "progress.md").read_bytes(), expected)
        self.assertEqual(escaped_progress.read_bytes(), expected)

    def test_clean_workspace_is_stable_no_op(self) -> None:
        progress = self.workspace.story("clean-story") / "progress.md"
        before = progress.read_bytes()

        first = self.preview("clean-story")
        second = self.preview("clean-story")
        self.assertEqual(first["digest"], second["digest"])
        self.assertEqual(first["remove"], [])
        self.assertEqual(first["no_op"], ["openspec/changes/clean-story/progress.md"])

        applied = self.apply(first["digest"], "clean-story")
        self.assertEqual(applied["removed"], [])
        self.assertEqual(progress.read_bytes(), before)

    def test_valid_exact_receipt_removes_only_receipt_bytes_and_preserves_status(
        self,
    ) -> None:
        original, expected = progress_with_receipt()
        directory = self.workspace.story("legacy-story", progress=original)
        story_path = directory / "story.md"
        story_before = story_path.read_bytes()

        plan = self.preview("legacy-story")
        relative = "openspec/changes/legacy-story/progress.md"
        self.assertEqual([item["path"] for item in plan["remove"]], [relative])
        item = plan["remove"][0]
        self.assertEqual(item["sha256"], hashlib.sha256(original).hexdigest())
        self.assertEqual((item["start_line"], item["end_line"]), (10, 23))

        applied = self.apply(plan["digest"], "legacy-story")
        self.assertEqual(applied["removed"], [relative])
        self.assertEqual((directory / "progress.md").read_bytes(), expected)
        self.assertEqual(story_path.read_bytes(), story_before)
        self.assertIn(b"Status: \xe2\x9c\x85 DONE", expected)

    def test_historical_template_comment_is_removed_with_legacy_receipt(self) -> None:
        original, expected = progress_with_receipt()
        original = original.replace(
            receipt(), receipt(comment=LEGACY_TEMPLATE_COMMENT), 1
        )
        directory = self.workspace.story("commented-story", progress=original)

        plan = self.preview("commented-story")
        relative = "openspec/changes/commented-story/progress.md"
        self.assertEqual([item["path"] for item in plan["remove"]], [relative])

        applied = self.apply(plan["digest"], "commented-story")
        self.assertEqual(applied["removed"], [relative])
        self.assertEqual((directory / "progress.md").read_bytes(), expected)

    def test_preview_digest_is_stable_and_apply_requires_exact_explicit_confirmation(
        self,
    ) -> None:
        original, _ = progress_with_receipt()
        path = self.workspace.story("confirm-story", progress=original) / "progress.md"
        first = self.preview("confirm-story")
        second = self.preview("confirm-story")
        self.assertEqual(first["digest"], second["digest"])

        self.assert_fails_without_writes("apply", INITIATIVE, "confirm-story")
        self.assert_fails_without_writes(
            "apply", INITIATIVE, "confirm-story", confirm="0" * 64
        )
        self.assertEqual(path.read_bytes(), original)

        self.apply(first["digest"], "confirm-story")

    def test_stale_confirmation_and_cross_story_drift_abort_before_all_writes(
        self,
    ) -> None:
        original_a, _ = progress_with_receipt()
        original_b, _ = progress_with_receipt(suffix=b"## Tail\n- b\n")
        path_a = self.workspace.story("a-story", progress=original_a) / "progress.md"
        path_b = self.workspace.story("z-story", progress=original_b) / "progress.md"
        plan = self.preview()

        drifted_b = original_b + b"independent drift\n"
        path_b.write_bytes(drifted_b)
        after_drift = self.tree_state(self.root)
        result = self.run_cli("apply", INITIATIVE, confirm=plan["digest"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.tree_state(self.root), after_drift)
        self.assertEqual(path_a.read_bytes(), original_a)
        self.assertEqual(path_b.read_bytes(), drifted_b)

    def test_duplicate_malformed_and_mixed_receipt_inputs_fail_closed(self) -> None:
        malformed: dict[str, bytes] = {}
        base, _ = progress_with_receipt()
        malformed["duplicate"] = base + receipt()
        malformed["missing-field"] = base.replace(b"- Proof: value-11\n", b"")
        malformed["empty-field"] = base.replace(b"- Proof: value-11\n", b"- Proof:\n")
        malformed["spaces-only-field"] = base.replace(
            b"- Proof: value-11\n", b"- Proof:     \n"
        )
        malformed["tabs-and-spaces-only-field"] = base.replace(
            b"- Proof: value-11\n", b"- Proof: \t \t\n"
        )
        malformed["unknown-field"] = base.replace(
            b"- Proof: value-11\n", b"- Unexpected: value\n- Proof: value-11\n"
        )
        malformed["arbitrary-comment"] = base.replace(
            b"## Implementation Review Receipt\n",
            b"## Implementation Review Receipt\n<!-- arbitrary -->\n",
            1,
        )
        malformed["altered-historical-comment"] = base.replace(
            receipt(),
            receipt(
                comment=LEGACY_TEMPLATE_COMMENT.replace(
                    "Never synthesize a backfill.", "Never synthesize a receipt."
                )
            ),
            1,
        )
        malformed["mixed-outside"] = base + b"- Decision: stray receipt field\n"
        malformed["near-heading"] = base.replace(
            b"## Implementation Review Receipt", b"### Implementation Review Receipt", 1
        )

        for name, content in malformed.items():
            with self.subTest(name=name):
                # Rebuild a bounded tree for every independently meaningful shape.
                with tempfile.TemporaryDirectory(
                    prefix="openspec-migrate-malformed-"
                ) as tmp:
                    prior_root, prior_workspace = self.root, self.workspace
                    self.root = Path(tmp)
                    self.workspace = Workspace(self.root)
                    self.workspace.story("bad-story", progress=content)
                    try:
                        self.assert_fails_without_writes(
                            "preview", INITIATIVE, "bad-story"
                        )
                    finally:
                        self.root, self.workspace = prior_root, prior_workspace

    def test_explicit_story_scope_requires_exactly_one_matching_binding(self) -> None:
        original, _ = progress_with_receipt()
        invalid_stories = {
            "zero": b"# Story\nStatus: \xe2\x9c\x85 DONE\n\n## Body\n",
            "duplicate": (
                f"# Story\nInitiative: {INITIATIVE}\nInitiative: {INITIATIVE}\n\n## Body\n"
            ).encode(),
            "unbound": b"# Story\nInitiative: another-initiative\n\n## Body\n",
        }
        for name, story in invalid_stories.items():
            with self.subTest(name=name):
                directory = self.workspace.story(name, progress=original, story=story)
                self.assert_fails_without_writes("preview", INITIATIVE, name)
                self.assertEqual((directory / "progress.md").read_bytes(), original)

    def test_initiative_scope_skips_unrelated_and_pre_v3_unbound_stories(self) -> None:
        selected_original, selected_expected = progress_with_receipt()
        selected = self.workspace.story("selected", progress=selected_original)
        unrelated = self.workspace.story(
            "other-initiative",
            story=(
                "# Story\nPlan: 🟢 PLAN APPROVED\nStatus: ✅ DONE\n"
                "Initiative: another-initiative\n\n## Acceptance Criteria\n- exact\n"
            ).encode(),
        )
        pre_v3 = self.workspace.story(
            "pre-v3-unbound",
            story=b"# Story\nStatus: \xe2\x9c\x85 DONE\n\n## Acceptance Criteria\n- old\n",
        )
        untouched_before = {
            "unrelated": self.tree_state(unrelated),
            "pre-v3": self.tree_state(pre_v3),
        }

        plan = self.preview()
        selected_path = "openspec/changes/selected/progress.md"
        self.assertEqual([item["path"] for item in plan["remove"]], [selected_path])
        self.assertEqual(plan["no_op"], [])
        self.apply(plan["digest"])

        self.assertEqual((selected / "progress.md").read_bytes(), selected_expected)
        self.assertEqual(self.tree_state(unrelated), untouched_before["unrelated"])
        self.assertEqual(self.tree_state(pre_v3), untouched_before["pre-v3"])

    def test_initiative_scope_still_rejects_malformed_initiative_like_candidate(
        self,
    ) -> None:
        selected_original, _ = progress_with_receipt()
        selected = self.workspace.story("selected", progress=selected_original)
        malformed = self.workspace.story(
            "malformed-binding",
            story=(
                "# Story\nStatus: ✅ DONE\n"
                f"Initiative : {INITIATIVE}\n\n## Acceptance Criteria\n- malformed\n"
            ).encode(),
        )
        before = self.tree_state(self.root)

        self.assert_fails_without_writes("preview", INITIATIVE)
        self.assertEqual(self.tree_state(self.root), before)
        self.assertEqual((selected / "progress.md").read_bytes(), selected_original)
        self.assertEqual(
            self.tree_state(malformed),
            {
                key.removeprefix("openspec/changes/malformed-binding/"): value
                for key, value in before.items()
                if key.startswith("openspec/changes/malformed-binding/")
            },
        )

    def test_archive_and_reviews_trees_are_excluded_and_untouched(self) -> None:
        original, _ = progress_with_receipt()
        self.workspace.story("active-clean")
        archive = self.root / "openspec" / "changes" / "archive" / "old-story"
        reviews = self.root / "openspec" / "changes" / "reviews" / "packet"
        for directory in (archive, reviews):
            directory.mkdir(parents=True)
            (directory / "story.md").write_text(
                f"# Story\nInitiative: {INITIATIVE}\n", encoding="utf-8"
            )
            (directory / "progress.md").write_bytes(original)
        before = self.tree_state(self.root)

        plan = self.preview()
        self.assertEqual(plan["remove"], [])
        self.assertEqual(
            plan.get("excluded"),
            ["openspec/changes/archive", "openspec/changes/reviews"],
        )
        self.apply(plan["digest"])
        self.assertEqual(self.tree_state(self.root), before)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks unavailable")
    def test_symlinked_or_escaping_inputs_fail_without_touching_target(self) -> None:
        original, _ = progress_with_receipt()
        directory = self.workspace.story("linked-story", progress=None)
        outside = self.root.parent / f"{self.root.name}-outside-progress.md"
        outside.write_bytes(original)
        self.addCleanup(lambda: outside.unlink(missing_ok=True))
        os.symlink(outside, directory / "progress.md")

        self.assert_fails_without_writes("preview", INITIATIVE, "linked-story")
        self.assertEqual(outside.read_bytes(), original)

    def test_nonregular_and_traversal_escape_inputs_fail_without_writes(self) -> None:
        directory = self.workspace.story("nonregular-story", progress=None)
        (directory / "progress.md").mkdir()
        self.assert_fails_without_writes("preview", INITIATIVE, "nonregular-story")

        outside = self.root.parent / f"{self.root.name}-escape"
        before = self.tree_state(self.root)
        result = self.run_cli("preview", INITIATIVE, f"../{outside.name}")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.tree_state(self.root), before)
        self.assertFalse(outside.exists())

    def test_all_stories_are_prevalidated_before_any_apply_write(self) -> None:
        original, _ = progress_with_receipt()
        valid = self.workspace.story("a-valid", progress=original) / "progress.md"
        malformed = original.replace(b"- Proof: value-11\n", b"")
        invalid = self.workspace.story("z-invalid", progress=malformed) / "progress.md"
        before = self.tree_state(self.root)

        result = self.run_cli("preview", INITIATIVE)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.tree_state(self.root), before)
        self.assertEqual(valid.read_bytes(), original)
        self.assertEqual(invalid.read_bytes(), malformed)

    def test_apply_revalidates_story_binding_at_the_write_boundary(self) -> None:
        original, _ = progress_with_receipt()
        directory = self.workspace.story("binding-drift", progress=original)
        story_path = directory / "story.md"
        plan = self.preview("binding-drift")

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail("could not load migration helper for write-boundary test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_atomic_replace = module.atomic_replace
        mutation_observed = False

        def mutate_binding_then_replace(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed
            story_path.write_bytes(
                story_path.read_bytes().replace(
                    f"Initiative: {INITIATIVE}".encode(),
                    b"Initiative: another-initiative",
                    1,
                )
            )
            mutation_observed = True
            original_atomic_replace(*args, **kwargs)

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module, "atomic_replace", side_effect=mutate_binding_then_replace
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    ["apply", INITIATIVE, "binding-drift", "--confirm", plan["digest"]]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "write-boundary mutation hook did not run")
        self.assertNotEqual(result, 0, stdout.getvalue() or stderr.getvalue())
        self.assertEqual((directory / "progress.md").read_bytes(), original)
        self.assertIn(b"Initiative: another-initiative", story_path.read_bytes())

    def test_concurrent_progress_edit_after_commit_is_not_clobbered(
        self,
    ) -> None:
        original, _expected = progress_with_receipt()
        directory = self.workspace.story("concurrent-post-write", progress=original)
        progress_path = directory / "progress.md"
        plan = self.preview("concurrent-post-write")
        concurrent = (
            b"# Progress\n\n## Concurrent writer\n- preserve these exact bytes\n"
        )

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_concurrent_post_replace_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail("could not load migration helper for concurrent commit test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        mutation_observed = False

        def replace_then_concurrently_edit(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed
            original_replace(*args, **kwargs)
            if not mutation_observed:
                progress_fd = os.open(
                    "progress.md",
                    os.O_WRONLY | os.O_TRUNC,
                    dir_fd=kwargs["dst_dir_fd"],
                )
                try:
                    os.write(progress_fd, concurrent)
                    os.fsync(progress_fd)
                finally:
                    os.close(progress_fd)
                mutation_observed = True

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module.os, "replace", side_effect=replace_then_concurrently_edit
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    [
                        "apply",
                        INITIATIVE,
                        "concurrent-post-write",
                        "--confirm",
                        plan["digest"],
                    ]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "post-replace mutation hook did not run")
        self.assertNotEqual(result, 0, "concurrent post-write drift reported success")
        self.assertIn("input drift immediately after atomic replace", stderr.getvalue())
        self.assertEqual(
            progress_path.read_bytes(),
            concurrent,
            "post-commit handling clobbered a concurrent writer's progress bytes",
        )

    def test_post_commit_failure_never_enters_racy_restore_replace(self) -> None:
        original, expected = progress_with_receipt()
        directory = self.workspace.story("restore-boundary", progress=original)
        progress_path = directory / "progress.md"
        uncommitted_original, _uncommitted_expected = progress_with_receipt(
            suffix=b"## Tail\n- must remain legacy until rerun\n"
        )
        uncommitted_path = (
            self.workspace.story("z-uncommitted", progress=uncommitted_original)
            / "progress.md"
        )
        initiative_path = (
            self.root / "openspec" / "initiatives" / INITIATIVE / "initiative.md"
        )
        plan = self.preview()
        concurrent = b"# Progress\n\n## Concurrent writer\n- exact later bytes\n"

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_restore_boundary_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail("could not load migration helper for restore-boundary test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        replace_calls = 0
        restore_boundary_reached = False

        def drift_then_mutate_at_restore_replace(*args: Any, **kwargs: Any) -> None:
            nonlocal replace_calls, restore_boundary_reached
            replace_calls += 1
            if replace_calls == 1:
                original_replace(*args, **kwargs)
                initiative_path.write_bytes(b"# Concurrent initiative authority\n")
                return

            # This is the old check-then-replace rollback boundary: ownership was
            # just checked as migration output, but a later writer can still win
            # before the unconditional POSIX rename and would be clobbered by it.
            restore_boundary_reached = True
            progress_fd = os.open(
                "progress.md",
                os.O_WRONLY | os.O_TRUNC,
                dir_fd=kwargs["dst_dir_fd"],
            )
            try:
                os.write(progress_fd, concurrent)
                os.fsync(progress_fd)
            finally:
                os.close(progress_fd)
            original_replace(*args, **kwargs)

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module.os,
                    "replace",
                    side_effect=drift_then_mutate_at_restore_replace,
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    [
                        "apply",
                        INITIATIVE,
                        "--confirm",
                        plan["digest"],
                    ]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertNotEqual(result, 0, "post-commit authority drift reported success")
        self.assertIn(
            "initiative drift immediately after atomic replace", stderr.getvalue()
        )
        self.assertNotEqual(
            progress_path.read_bytes(),
            original,
            "racy rollback clobbered the later concurrent bytes with source bytes",
        )
        self.assertEqual(replace_calls, 1, "post-commit failure attempted rollback")
        self.assertFalse(
            restore_boundary_reached,
            "unsafe restore boundary remained reachable after the commit point",
        )
        self.assertEqual(
            progress_path.read_bytes(),
            expected,
            "the committed migration output was not preserved",
        )
        self.assertNotEqual(progress_path.read_bytes(), concurrent)
        self.assertEqual(
            uncommitted_path.read_bytes(),
            uncommitted_original,
            "an operation after the failed commit was unexpectedly written",
        )

    def test_leaf_swap_after_commit_reports_both_migrated_trees(self) -> None:
        self.assert_post_replace_swap_reports_committed_partial_state(
            "leaf-post-write", "leaf"
        )

    def test_changes_swap_after_commit_reports_both_migrated_trees(self) -> None:
        self.assert_post_replace_swap_reports_committed_partial_state(
            "changes-post-write", "changes"
        )

    def test_openspec_swap_after_commit_reports_both_migrated_trees(self) -> None:
        self.assert_post_replace_swap_reports_committed_partial_state(
            "openspec-post-write", "openspec"
        )

    def test_story_directory_rename_at_commit_reports_escaped_partial_state(
        self,
    ) -> None:
        original, _expected = progress_with_receipt()
        directory = self.workspace.story("renamed-at-write", progress=original)
        story_source = (directory / "story.md").read_bytes()
        plan = self.preview("renamed-at-write")
        escaped = self.root.parent / f"{self.root.name}-escaped-story"
        self.addCleanup(shutil.rmtree, escaped, True)

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail("could not load migration helper for directory-race test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        mutation_observed = False

        def rename_story_then_replace(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed
            if not mutation_observed:
                directory.rename(escaped)
                directory.mkdir()
                (directory / "story.md").write_bytes(story_source)
                (directory / "progress.md").write_bytes(original)
                mutation_observed = True
            original_replace(*args, **kwargs)

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module.os, "replace", side_effect=rename_story_then_replace
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    [
                        "apply",
                        INITIATIVE,
                        "renamed-at-write",
                        "--confirm",
                        plan["digest"],
                    ]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "directory mutation hook did not run")
        self.assertNotEqual(result, 0, stdout.getvalue() or stderr.getvalue())
        self.assertIn(
            "story containment drift immediately after atomic replace",
            stderr.getvalue(),
        )
        self.assertEqual((escaped / "progress.md").read_bytes(), _expected)
        self.assertEqual((directory / "progress.md").read_bytes(), original)
        self.assertEqual(
            sorted(path.name for path in escaped.iterdir()),
            ["progress.md", "story.md"],
        )

    def test_changes_directory_move_at_commit_reports_partial_state(
        self,
    ) -> None:
        original, _expected = progress_with_receipt()
        directory = self.workspace.story("changes-moved-at-write", progress=original)
        plan = self.preview("changes-moved-at-write")
        changes = self.root / "openspec" / "changes"
        before = self.tree_state(changes)
        workspace_before = self.tree_state(self.root)
        escaped = self.root.parent / f"{self.root.name}-escaped-changes"
        self.addCleanup(shutil.rmtree, escaped, True)

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_changes_ancestor_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail("could not load migration helper for changes-ancestor race test")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        mutation_observed = False

        def move_changes_then_replace(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed
            if not mutation_observed:
                changes.rename(escaped)
                shutil.copytree(escaped, changes)
                mutation_observed = True
            original_replace(*args, **kwargs)

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module.os, "replace", side_effect=move_changes_then_replace
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    [
                        "apply",
                        INITIATIVE,
                        "changes-moved-at-write",
                        "--confirm",
                        plan["digest"],
                    ]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "changes mutation hook did not run")
        self.assertNotEqual(result, 0, "ancestor drift was reported as success")
        self.assertIn(
            "containment drift immediately after atomic replace", stderr.getvalue()
        )
        named_temporaries = list(
            (changes / "changes-moved-at-write").glob(".progress.md.migrate-*")
        )
        self.assertEqual(len(named_temporaries), 1)
        self.assertEqual(named_temporaries[0].read_bytes(), _expected)
        workspace_without_temporary = {
            key: value
            for key, value in self.tree_state(self.root).items()
            if ".progress.md.migrate-" not in key
        }
        self.assertEqual(workspace_without_temporary, workspace_before)
        self.assertEqual(
            (changes / "changes-moved-at-write" / "progress.md").read_bytes(),
            original,
        )
        self.assertEqual(
            (escaped / "changes-moved-at-write" / "progress.md").read_bytes(),
            _expected,
        )
        escaped_expected = dict(before)
        escaped_expected["changes-moved-at-write/progress.md"] = ("file", _expected)
        self.assertEqual(self.tree_state(escaped), escaped_expected)
        self.assertEqual((directory / "progress.md").read_bytes(), original)

    def test_initiative_directory_move_at_commit_reports_partial_state(
        self,
    ) -> None:
        original, _expected = progress_with_receipt()
        directory = self.workspace.story("initiative-moved-at-write", progress=original)
        plan = self.preview("initiative-moved-at-write")
        initiative = self.root / "openspec" / "initiatives" / INITIATIVE
        initiative_before = self.tree_state(initiative)
        workspace_before = self.tree_state(self.root)
        escaped = self.root.parent / f"{self.root.name}-escaped-initiative"
        self.addCleanup(shutil.rmtree, escaped, True)

        spec = importlib.util.spec_from_file_location(
            "openspec_migrate_initiative_ancestor_under_test", MIGRATE
        )
        if spec is None or spec.loader is None:
            self.fail(
                "could not load migration helper for initiative-ancestor race test"
            )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_replace = module.os.replace
        mutation_observed = False

        def move_initiative_then_replace(*args: Any, **kwargs: Any) -> None:
            nonlocal mutation_observed
            if not mutation_observed:
                initiative.rename(escaped)
                shutil.copytree(escaped, initiative)
                mutation_observed = True
            original_replace(*args, **kwargs)

        prior_cwd = Path.cwd()
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            os.chdir(self.root)
            with (
                mock.patch.object(
                    module.os, "replace", side_effect=move_initiative_then_replace
                ),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                result = module.main(
                    [
                        "apply",
                        INITIATIVE,
                        "initiative-moved-at-write",
                        "--confirm",
                        plan["digest"],
                    ]
                )
        finally:
            os.chdir(prior_cwd)

        self.assertTrue(mutation_observed, "initiative mutation hook did not run")
        self.assertNotEqual(result, 0, "ancestor drift was reported as success")
        self.assertIn(
            "containment drift immediately after atomic replace", stderr.getvalue()
        )
        workspace_expected = dict(workspace_before)
        workspace_expected["openspec/changes/initiative-moved-at-write/progress.md"] = (
            "file",
            _expected,
        )
        self.assertEqual(self.tree_state(self.root), workspace_expected)
        self.assertEqual(self.tree_state(initiative), initiative_before)
        self.assertEqual(self.tree_state(escaped), initiative_before)
        self.assertEqual((directory / "progress.md").read_bytes(), _expected)

    def test_interrupted_partial_state_reruns_only_remaining_work_then_is_idempotent(
        self,
    ) -> None:
        original_a, expected_a = progress_with_receipt()
        original_b, expected_b = progress_with_receipt(suffix=b"## Tail\n- b\n")
        path_a = (
            self.workspace.story("a-already-written", progress=expected_a)
            / "progress.md"
        )
        path_b = (
            self.workspace.story("b-still-legacy", progress=original_b) / "progress.md"
        )

        recovery = self.preview()
        self.assertEqual(
            [item["path"] for item in recovery["remove"]],
            ["openspec/changes/b-still-legacy/progress.md"],
        )
        self.assertIn(
            "openspec/changes/a-already-written/progress.md", recovery["no_op"]
        )
        self.apply(recovery["digest"])
        self.assertEqual(path_a.read_bytes(), expected_a)
        self.assertEqual(path_b.read_bytes(), expected_b)

        rerun = self.preview()
        self.assertEqual(rerun["remove"], [])
        self.assertEqual(
            rerun["no_op"],
            [
                "openspec/changes/a-already-written/progress.md",
                "openspec/changes/b-still-legacy/progress.md",
            ],
        )
        final_before = self.tree_state(self.root)
        self.apply(rerun["digest"])
        self.assertEqual(self.tree_state(self.root), final_before)
        self.assertNotEqual(original_a, expected_a)  # fixture sanity


if __name__ == "__main__":
    unittest.main()
