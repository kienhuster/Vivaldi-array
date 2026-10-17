"""Read-only source/serialization checks, not a VBScript or HFSS runner.

python tests/check_reference_and_scripts.py --scripts /path/to/portable-check-output
"""
import argparse
import hashlib
import re
from pathlib import Path


def reference_checks(root):
    file = root / "reference" / "17_10_2026_vivaldi.aedt"
    raw = file.read_bytes()
    assert len(raw) == 669840
    assert hashlib.sha256(raw).hexdigest() == (
        "631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619"
    )
    stack, blocks = [], 0
    for number, line in enumerate(raw.decode("utf-8").splitlines(), 1):
        match = re.fullmatch(r"\s*\$(begin|end) '([^']+)'\s*", line)
        if not match:
            continue
        action, name = match.groups()
        if action == "begin":
            stack.append(name)
            blocks += 1
        else:
            assert stack and stack.pop() == name, f"Unbalanced source at {number}"
    assert not stack and blocks == 3285
    text = raw.decode("utf-8")
    designs = re.findall(r"\$begin 'HFSSModel'([\s\S]*?)\$end 'HFSSModel'", text)
    main = [s for s in designs if re.search(
        r"^\s*Name='dual_pol_vivaldi_patch_Wflare_20'", s, re.MULTILINE
    )]
    assert len(main) == 1
    variables = re.findall(r"^\s*VariableProp\('([^']+)', 'UD', '', '([^']*)'\)", main[0], re.MULTILINE)
    assert len(variables) == 31
    values = dict(variables)
    assert values["L_flare_1"] == "40mm" and values["lamda"] == "60mm"
    assert values["scan_theta"] == values["scan_phi"] == "0deg"
    parts = re.search(r"\$begin 'ToplevelParts'([\s\S]*?)\$end 'ToplevelParts'", main[0])[1]
    names = re.findall(r"^\s*Name='([^']+)'", parts, re.MULTILINE)
    assert set(names) == {
        "RadiatingSurface", "cable_in", "cable_out", "port1", "Vivaldi_1",
        "cable_in_1", "cable_out_1", "port2",
    }
    assert len(names) == 8
    print("PASS: source hash, 3285 balanced blocks, 31 variables and eight parts")


def script_checks(directory):
    files = sorted(directory.glob("*/automation.vbs"))
    assert files, "No current-run generated scripts found"
    for file in files:
        raw = file.read_bytes()
        assert raw.startswith(b"\xff\xfe") and len(raw) % 2 == 0, file
        text = raw.decode("utf-16")
        assert "\x00" not in text, file
        depth, continuations = 0, 0
        for line in text.splitlines():
            assert len(line) < 1023, (file, "VBScript physical line limit")
            continuations = continuations + 1 if line.rstrip().endswith("_") else 0
            assert continuations < 25, (file, "VBScript continuation limit")
            index, quoted = 0, False
            while index < len(line):
                char = line[index]
                if char == '"':
                    if quoted and index + 1 < len(line) and line[index + 1] == '"':
                        index += 2
                        continue
                    quoted = not quoted
                elif char == "'" and not quoted:
                    break
                elif not quoted:
                    if char == "(":
                        depth += 1
                    elif char == ")":
                        depth -= 1
                        assert depth >= 0, (file, line)
                index += 1
            assert not quoted, (file, line)
        assert depth == 0, file
        main = text[text.index('State "RUNNING", "Connect"'):]
        wrappers = re.findall(
            r"On Error Resume Next\s+Err.Clear\s+[^\r\n]+\s+"
            r"errorNumber = Err.Number : errorText = Err.Description\s+"
            r"On Error GoTo 0\s+If errorNumber <> 0 Then Fail [^\r\n]+", main
        )
        assert len(wrappers) == main.count("On Error Resume Next"), file
    print(f"PASS: encoding, line limits, strings, parentheses and error wrappers ({len(files)} scripts)")
    print("Windows VBScript, COM and HFSS execution remain unrun.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scripts", type=Path)
    args = parser.parse_args()
    reference_checks(Path(__file__).resolve().parents[1])
    if args.scripts:
        script_checks(args.scripts)
