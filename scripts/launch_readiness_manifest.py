#!/usr/bin/env python3
"""
Regenerates launch_readiness.json at the repo root -- a small, honest
snapshot of the repo-derivable signals CGC Core's Launch Readiness module
(cgc_core/api/v1/endpoints/launch_readiness.py) fetches over HTTPS from
raw.githubusercontent.com on refresh.

Deliberately only includes facts that can actually be checked from
committed repo state. Things like "is the release keystore configured"
CANNOT be derived this way -- android/key.properties (the real one, not
the .example template) is gitignored by design, so that stays a manual
checklist item in the dashboard, not something this script pretends to
know.

Run manually before a check-in that changes one of these signals (no CI
wiring yet -- see the CGC Core plan's own "explicitly out of scope"
note). Safe to re-run any time; always overwrites the file with current
truth.

Usage:
    python scripts/launch_readiness_manifest.py
"""

import json
import re
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def check_android_package_placeholder() -> bool:
    """True = BAD, still the com.example.* Flutter template placeholder
    Google Play rejects. False = a real package name is set."""
    gradle = REPO_ROOT / "android" / "app" / "build.gradle.kts"
    if not gradle.exists():
        return True  # can't find it at all -- treat as unresolved/bad
    text = gradle.read_text(encoding="utf-8")
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', text)
    if not match:
        return True
    return match.group(1).startswith("com.example")


def check_ios_platform_scaffolded() -> bool:
    """True = the ios/ platform folder exists (flutter create --platforms=ios
    has been run) -- a prerequisite for any Apple submission work at all."""
    return (REPO_ROOT / "ios").is_dir()


def main() -> None:
    manifest = {
        "app_source": "controlmiles",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "signals": {
            "android_package_placeholder": check_android_package_placeholder(),
            "ios_platform_scaffolded": check_ios_platform_scaffolded(),
        },
    }

    out_path = REPO_ROOT / "launch_readiness.json"
    out_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path}")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
