"""Read-only debug regressions; does not execute MATLAB, VBScript or HFSS."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess


def audit_sources(root):
    for file in root.rglob('*.m'):
        text = file.read_text(encoding='utf-8')
        assert not re.search(r'onCleanup\s*\(\s*@refresh\b', text), file
    legacy = (root / 'Vivaldi_Element_Designer.m').read_text()
    assert 'vivaldiExportPreview(' in legacy and 'exportgraphics(' not in legacy
    assert "'Text', 'Calculate'" in legacy
    assert "'Text', 'Build Antenna'" in legacy
    assert '17_10_2026_vivaldi.aedt' in legacy
    protected = ['Vivaldi_23_9_2026.aedt',
                 'SingleElementBuilder/reference/17_10_2026_vivaldi.aedt',
                 'vivaldiCalculateGeometry.m', 'vivaldiDefaultParams.m',
                 'SingleElementBuilder/vivaldiBuilderGeometry.m',
                 'SingleElementBuilder/vivaldiBuilderDefaultParams.m',
                 'SingleElementBuilder/HFSSGeometryBuilder.m',
                 'SingleElementBuilder/HFSSCoaxBuilder.m',
                 'SingleElementBuilder/HFSSSetupBuilder.m']
    for name in protected:
        before = subprocess.check_output(['git', 'show', 'HEAD:' + name], cwd=root)
        assert (root / name).read_bytes() == before, name
    sha = hashlib.sha256((root / protected[1]).read_bytes()).hexdigest()
    assert sha == '631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619'
    print(f'PASS: no deferred refresh cleanup; nine reference/math/CAD files unchanged; SHA-256 {sha}')


def audit_scripts(folder):
    files = list(folder.glob('*.vbs'))
    assert files, 'Run runDebugPortableChecks first'
    for file in files:
        raw = file.read_bytes()
        assert raw.startswith(b'\xff\xfe') and len(raw) % 2 == 0, file
        text = raw.decode('utf-16')
        assert '\0' not in text
        depth, continued = 0, 0
        for line in text.splitlines():
            assert len(line) < 1023, file
            continued = continued + 1 if line.rstrip().endswith('_') else 0
            assert continued < 25, file
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
                    if char == '(':
                        depth += 1
                    elif char == ')':
                        depth -= 1
                        assert depth >= 0, (file, line)
                index += 1
            assert not quoted, (file, line)
        assert depth == 0, file
        if 'Sub Main()' not in text:  # Explicit Unicode I/O fixture
            continue
        main = text.split('Sub Main()', 1)[1]
        assert 'GetAppDesktop' in main and 'GetVersion' in main
        if 'oDesktop.NewProject()' in main:
            assert 'oDesktop.OpenProject(' not in main
            assert 'oDesign.ValidateDesign(' in main
            assert 'sbValidation = 1' in main
            assert not re.search(r'^\s*oDesign\.Analyze', main, re.M)
            assert 'If sbErr <> 0 Then Fail' in main
    print(f'PASS: {len(files)} UTF-16 files checked for strings, parentheses, limits and build guards')
    print('VBScript execution, MATLAB GUI and HFSS Validate remain UNRUN.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scripts', type=Path)
    args = parser.parse_args()
    audit_sources(Path(__file__).resolve().parents[1])
    if args.scripts:
        audit_scripts(args.scripts)
