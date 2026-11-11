#!/usr/bin/env python3
"""cs_determinism.py: no unseeded randomness, and no clock in the sim, in the Unity port's C# (rule 2, U6 C1).

Every sim path is seeded and replayable (CLAUDE.md rule 2). The port's seeded generator is the Godot RNG
port (S.RandomNumberGenerator, usually built by S.Seeds.Make); views may also use new System.Random(seed).
Scans hand-written C# under unity/Assets (Sim/Game is gd2cs output and excluded). Comments and strings
are not code.
  D1  anywhere: UnityEngine.Random / Random.Range|value|insideUnit*|onUnit*|rotation*|InitState|ColorHSV|state,
      new System.Random() with no seed (also target-typed: `Random r = new();`), a Random seeded from a clock
      (TickCount, DateTime, Stopwatch, Time.), Guid.NewGuid, System.Security.Cryptography.RandomNumberGenerator
  D2  anywhere: new [S.]RandomNumberGenerator() whose .seed (or .state) is not set within the next 3 lines
  D3  in Scripts/GameLogic/ and Scripts/Sim/ only: DateTime.Now|UtcNow|Today, DateTimeOffset.Now|UtcNow,
      Stopwatch, Environment.TickCount, UnityEngine.Time / Time.<clock> (views may read clocks)
A line that is right to do it says why in a marker on the same line: `// seed-ok: <reason>`.

Usage: python3 tools/lint/cs_determinism.py [--root DIR]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs_source  # noqa: E402

# A clock used as a seed: never replayable, so wrong anywhere (D3 bans clocks only in GameLogic/Sim).
CLOCK_SEED = r"(?:\bTickCount\b|\bDateTime(?:Offset)?\b|\bStopwatch\b|(?<![\w.])Time\.)"
D1 = re.compile(
    r"\bUnityEngine\.Random\b"
    r"|(?<![\w.])Random\.(?:Range|value|insideUnitSphere|insideUnitCircle|onUnitSphere|rotation|rotationUniform"
    r"|InitState|ColorHSV|state)\b"
    r"|\bnew\s+(?:System\.)?Random\s*\(\s*\)"
    r"|\bRandom\s+\w+\s*=\s*new\s*\(\s*\)"
    r"|\bnew\s+(?:System\.)?Random\s*\([^;]*?" + CLOCK_SEED +
    r"|\bRandom\b[^;]*?\bnew\s*\([^;]*?" + CLOCK_SEED +
    r"|\bGuid\.NewGuid\b"
    r"|\bCryptography\.RandomNumberGenerator\b|(?<![\w.])RandomNumberGenerator\.(?:Create|GetBytes|GetInt32|Fill)\b"
)
D2 = re.compile(r"\bnew\s+(?:S\.)?RandomNumberGenerator\s*\(\s*\)")
D2_SEEDED = re.compile(r"\.(?:seed|state)\s*=(?!=)|\{\s*(?:seed|state)\s*=")
D2_WINDOW = 3
D3 = re.compile(
    r"\bDateTime\.(?:Now|UtcNow|Today)\b|\bDateTimeOffset\.(?:Now|UtcNow)\b|\bStopwatch\b|\bEnvironment\.TickCount"
    r"|\bUnityEngine\.Time\b|(?<![\w.])Time\.(?:time|timeAsDouble|realtimeSinceStartup|realtimeSinceStartupAsDouble"
    r"|unscaledTime|deltaTime|unscaledDeltaTime|frameCount|fixedDeltaTime|timeSinceLevelLoad)\b"
)
PURE = ("unity/Assets/Scripts/GameLogic/", "unity/Assets/Scripts/Sim/")
MARKER = re.compile(r"//\s*seed-ok:\s*\S")


def check(root):
    """Findings as (path, line, rule, message), and the number of files read."""
    found = []
    files = cs_source.hand_written(root)
    for path in files:
        raw = cs_source.read(root, path).split("\n")
        code = cs_source.strip("\n".join(raw)).split("\n")
        pure = path.startswith(PURE)
        for i, line in enumerate(code):
            if MARKER.search(raw[i]):
                continue
            m = D1.search(line)
            if m:
                found.append((path, i + 1, "D1", "%s is not the seeded RNG: use S.Seeds.Make / new System.Random(seed)"
                              % m.group(0).strip()))
            if D2.search(line) and not any(D2_SEEDED.search(x) for x in code[i:i + 1 + D2_WINDOW]):
                found.append((path, i + 1, "D2", "new RandomNumberGenerator() with no .seed set within %d lines"
                              % D2_WINDOW))
            m = D3.search(line) if pure else None
            if m:
                found.append((path, i + 1, "D3", "%s is a clock in GameLogic/Sim: the sim takes time from its tick"
                              % m.group(0)))
    return found, len(files)


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    found, files = check(root)
    for path, line, rule, message in found:
        cs_source.emit(path, line, rule, message + " (or mark the line `// seed-ok: <why>`)")
    if found:
        print("FAIL: %d determinism problem(s) in %d C# files" % (len(found), files))
        return 1
    print("ok: %d hand-written C# files, no unseeded randomness and no sim clock" % files)
    return 0


if __name__ == "__main__":
    sys.exit(main())
