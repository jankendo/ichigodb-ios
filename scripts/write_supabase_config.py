from __future__ import annotations

import json
import os
from pathlib import Path


def main() -> None:
    url = os.environ.get("SUPABASE_URL", "")
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "")
    target = Path("Sources/Generated/SupabaseConfig.generated.swift")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        "\n".join(
            [
                "import Foundation",
                "",
                "enum SupabaseGeneratedConfig {",
                f"    static let url = {json.dumps(url)}",
                f"    static let anonKey = {json.dumps(anon_key)}",
                "}",
                "",
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
