#!/usr/bin/env python3
"""Independent source/data audit, using only Python's standard library.

This does not execute MATLAB or HFSS and never reports CAD/solver success.
Usage: python3 tests/static_audit.py --reference /path/17_10_2026_vivaldi.aedt
"""
from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass, field
import hashlib
import math
from pathlib import Path
import re
import subprocess

DESIGN = "dual_pol_vivaldi_patch_Wflare_20"
SOURCE_SHA = "631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619"
LENGTH, ANGLE, NUMBER = (1, 0), (0, 1), (0, 0)


@dataclass(frozen=True)
class Quantity:
    value: float
    dimension: tuple[int, int] = NUMBER

    def __add__(self, other):
        assert self.dimension == other.dimension, "Inconsistent dimensions in addition"
        return Quantity(self.value + other.value, self.dimension)

    def __sub__(self, other):
        return self + Quantity(-other.value, other.dimension)

    def __mul__(self, other):
        return Quantity(self.value * other.value,
                        tuple(a + b for a, b in zip(self.dimension, other.dimension)))

    def __truediv__(self, other):
        return Quantity(self.value / other.value,
                        tuple(a - b for a, b in zip(self.dimension, other.dimension)))


class Expressions:
    """Read arithmetic AST nodes explicitly; no eval, exec or arbitrary calls."""

    def __init__(self, definitions, overrides=None, dimensioned=True):
        self.definitions = definitions
        self.dimensioned = dimensioned
        self.values = {"mm": Quantity(1, LENGTH), "deg": Quantity(1, ANGLE)}
        self.values.update(overrides or {})
        if not dimensioned:
            self.values = {n: Quantity(q.value) for n, q in self.values.items()}
        self.active = set()

    def named(self, name):
        if name in self.values:
            return self.values[name]
        assert name in self.definitions and name not in self.active, f"Unknown/cyclic variable {name}"
        self.active.add(name)
        value = self.expression(self.definitions[name])
        self.active.remove(name)
        self.values[name] = value
        return value

    def expression(self, expression):
        expression = re.sub(r"(?<=\d)(mm|deg)\b", r"*\1", expression)
        return self.node(ast.parse(expression.strip(), mode="eval").body)

    def node(self, node):
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            return Quantity(float(node.value))
        if isinstance(node, ast.Name):
            return self.named(node.id)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            value = self.node(node.operand)
            return Quantity((-1 if isinstance(node.op, ast.USub) else 1) * value.value, value.dimension)
        if isinstance(node, ast.BinOp):
            a, b = self.node(node.left), self.node(node.right)
            if isinstance(node.op, ast.Add):
                return a + b
            if isinstance(node.op, ast.Sub):
                return a - b
            if isinstance(node.op, ast.Mult):
                return a * b
            if isinstance(node.op, ast.Div):
                return a / b
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords and len(node.args) == 1:
            name, value = node.func.id, self.node(node.args[0])
            if name in ("sin", "sind", "cos", "cosd"):
                assert value.dimension == (ANGLE if self.dimensioned else NUMBER), "Trigonometric argument must be an angle"
                f = math.sin if name in ("sin", "sind") else math.cos
                return Quantity(f(math.radians(value.value)))
            if name in ("ln", "log", "exp"):
                assert value.dimension == NUMBER, "Exponential/logarithm argument must be dimensionless"
                return Quantity((math.exp if name == "exp" else math.log)(value.value))
        raise AssertionError(f"Unsupported expression node {ast.dump(node)}")


@dataclass
class Section:
    name: str
    line: int
    lines: list[str] = field(default_factory=list)
    children: list["Section"] = field(default_factory=list)

    def walk(self, name=None):
        if name is None or self.name == name:
            yield self
        for child in self.children:
            yield from child.walk(name)

    def prop(self, name, default=None):
        pattern = re.compile(r"\s*" + re.escape(name) + r"=(.*)")
        values = [m.group(1).strip().strip("'") for line in self.lines if (m := pattern.fullmatch(line))]
        assert len(values) <= 1, f"Duplicated property {name} at {self.line}"
        return values[0] if values else default

    def child(self, name):
        result = [c for c in self.children if c.name == name]
        assert len(result) == 1, f"Ambiguous/missing child {name} at {self.line}"
        return result[0]


def sections(text):
    root = Section("ROOT", 0)
    stack = [root]
    count = 0
    for line_number, line in enumerate(text.splitlines(), 1):
        begin = re.fullmatch(r"\s*\$begin '(.*)'", line)
        end = re.fullmatch(r"\s*\$end '(.*)'", line)
        if begin:
            node = Section(begin.group(1), line_number)
            stack[-1].children.append(node)
            stack.append(node)
            count += 1
        elif end:
            assert len(stack) > 1 and stack[-1].name == end.group(1), f"Unbalanced section at {line_number}"
            stack.pop()
        else:
            stack[-1].lines.append(line)
    assert len(stack) == 1, "Unterminated section"
    return root, count


def near(actual, expected, tolerance=1e-9):
    assert math.isfinite(actual) and abs(actual - expected) <= tolerance, (actual, expected, tolerance)


def parse_matlab(core):
    source = (core / "vivaldiBuilderDefaultParams.m").read_text()
    block = re.search(r"p\s*=\s*struct\((.*?)\);", source, re.S).group(1)
    defaults = {name: float(value) for name, value in re.findall(r"'([A-Za-z0-9_]+)'\s*,\s*([-+0-9.eE]+)", block)}
    assert len(defaults) == 19
    geometry = (core / "vivaldiBuilderGeometry.m").read_text()
    block = re.search(r"g\.expressions\s*=\s*\{(.*?)\};", geometry, re.S).group(1)
    declarations = {}
    for line in block.splitlines():
        if not line.strip() or line.strip() == "...":
            continue
        match = re.fullmatch(r"\s*'([A-Za-z0-9_]+)',(.*?)(?:;\s*\.\.\.)?\s*", line)
        assert match, line
        name, value = match.groups()
        literal = re.fullmatch(r"literal\(p\.([A-Za-z0-9_]+),'(mm|deg)'\)", value)
        if literal:
            variable, unit = literal.groups()
            assert variable == name and name in defaults
            declarations[name] = (defaults[name], unit)
        else:
            assert value.startswith("'") and value.endswith("'"), value
            declarations[name] = value[1:-1]
    assert len(declarations) == 31
    scalar = {}
    for name, formula in declarations.items():
        if isinstance(formula, tuple):
            continue
        expression = re.search(r"g\." + re.escape(name) + r"\s*=\s*(.*?);", geometry, re.S).group(1)
        expression = re.sub(r"\.\.\.\s*\n", "", expression)
        scalar[name] = re.sub(r"\b[pg]\.", "", expression)
    a = re.search(r"\na\s*=\s*(.*?);", geometry, re.S).group(1)
    scalar["a"] = re.sub(r"\b[pg]\.", "", a)
    for name in ("name", "label", "group", "unit", "range", "tip"):
        assert "'" + name + "'" in source
    for group in ("labels", "groups", "tips"):
        values = re.search(group + r"\s*=\s*\{(.*?)\};", source, re.S).group(1)
        assert len(re.findall(r"'([^']*)'", values)) == 19, group
    assert "'alpha','0deg'" in geometry and "alpha" not in declarations
    return defaults, declarations, scalar, geometry


def audit_variables(design, core):
    variables = {}
    for section in design.walk():
        for line in section.lines:
            m = re.fullmatch(r"\s*VariableProp\('([^']+)', 'UD', '', '([^']+)'\)", line)
            if m:
                assert m.group(1) not in variables
                variables[m.group(1)] = m.group(2)
    assert len(variables) == 31
    defaults, declarations, scalar, geometry = parse_matlab(core)
    assert list(declarations) == list(variables), "Design variable order differs"
    original = Expressions(variables)
    independent = {}
    for name, declaration in declarations.items():
        if isinstance(declaration, tuple):
            number, unit = declaration
            source = original.named(name)
            near(number, source.value, 1e-12)
            expected_dimension = ANGLE if unit == "deg" else LENGTH
            assert source.dimension == expected_dimension
            independent[name] = Quantity(number, expected_dimension)
        else:
            assert declaration == variables[name], f"Symbolic expression differs: {name}"
    expected = {"L_flare": 46.4, "r_flare": .07950171237314518,
                "x_feed": 2.4993308607789606, "z_feed": .66369670994107,
                "L_patch": 49.23630329005893, "de_L": 22, "de_W": 22}
    for name, value in expected.items():
        near(original.named(name).value, value, 1e-10)
    variations = ({}, {"L_flare_1": 45}, {"aperture_w": 22}, {"cavity_w": 1.6},
                  {"cavity_L": 5.5}, {"thickness": 2.2}, {"slot_feed_w": .6},
                  {"L_flare_1": 45, "aperture_w": 22, "cavity_w": 1.6,
                   "cavity_L": 5.5, "thickness": 2.2, "slot_feed_w": .6})
    for variation in variations:
        inputs = independent | {n: Quantity(v, independent[n].dimension) for n, v in variation.items()}
        source_values = Expressions(variables, inputs)
        matlab_values = Expressions(scalar, inputs, dimensioned=False)
        for name in scalar:
            if name != "a":
                a, b = source_values.named(name), matlab_values.named(name)
                near(a.value, b.value, 1e-11)
    for target in (49, 50):
        roots = []
        for definitions, dimensioned in ((variables, True), (scalar, False)):
            lo, hi = 1., 200.
            for _ in range(80):
                midpoint = (lo + hi) / 2
                e = Expressions(definitions, independent | {"L_flare_1": Quantity(midpoint, LENGTH)}, dimensioned)
                if e.named("L_patch").value < target:
                    lo = midpoint
                else:
                    hi = midpoint
            root = (lo + hi) / 2
            e = Expressions(definitions, independent | {"L_flare_1": Quantity(root, LENGTH)}, dimensioned)
            near(e.named("L_patch").value, target, 1e-10)
            roots.append(root)
        near(*roots, tolerance=1e-10)
        print(f"  Source-equation numerical target {target} mm: L_flare_1={roots[0]:.12f} mm")
    print("  31 exact variable declarations; 19 default literals; 12 scalar MATLAB formulas vs source, 8 configurations")
    return original, geometry


def audit_coordinates(design, evaluator, geometry):
    coordinate_sections = list(design.walk("CoordinateSystems"))
    assert len(coordinate_sections) == 1
    by_id = {"1": ("Global", [0., 0., 0.])}
    expected = {"slot_t_td": ("Global", [.4158280681235947, 0, 6.4]),
                "slot_feed_td": ("Global", [-2.4993308607789606, 0, .66369670994107]),
                "patch_td": ("Global", [10, 0, 46.4]),
                "RelativeCS1": ("patch_td", [10, -1, 46.4])}
    for operation in coordinate_sections[0].children:
        parameters = operation.child("RelativeCSParameters")
        name = operation.child("Attributes").prop("Name")
        parent_name, parent_origin = by_id[operation.prop("ReferenceCoordSystemID")]
        local = [evaluator.expression(parameters.prop("Origin" + axis)).value for axis in "XYZ"]
        origin = [a + b for a, b in zip(local, parent_origin)]
        expected_parent, expected_origin = expected[name]
        assert parent_name == expected_parent
        for a, b in zip(origin, expected_origin):
            near(a, b, 1e-10)
        for prefix, vector in (("XAxis", [1, 0, 0]), ("YAxis", [0, 1, 0])):
            for axis, value in zip("XYZ", vector):
                near(evaluator.expression(parameters.prop(prefix + axis + "vec")).value, value)
        by_id[operation.prop("ID")] = (name, origin)
        m = re.search(r"g\.cs\." + name + r"\s*=\s*coordinateSystem\('([^']*)'", geometry)
        assert m and m.group(1) == parent_name
    assert "{'-x_feed','0mm','z_feed'}" in geometry
    print("  Four source coordinate systems: exact parents, axes, Global origins and negative feed X")


def audit_inventory(design):
    inventory = list(design.walk("ToplevelParts"))
    assert len(inventory) == 1
    parts = {part.child("Attributes").prop("Name"): part.child("Attributes") for part in inventory[0].children}
    expected = {"RadiatingSurface", "Vivaldi_1", "cable_in", "cable_out", "cable_in_1", "cable_out_1", "port1", "port2"}
    assert set(parts) == expected
    for name, attrs in parts.items():
        material = attrs.prop("MaterialValue").strip('"')
        assert material == ("aluminum" if name == "Vivaldi_1" else "copper" if name.startswith("cable") else "vacuum")
    boundaries = list(design.walk("Boundaries"))
    assert len(boundaries) == 1
    ports = [b for b in boundaries[0].children if b.prop("BoundType") == "Lumped Port"]
    assert {p.name for p in ports} == {"1", "2"}
    assert all(p.prop("Impedance") == "50ohm" for p in ports)
    assert sum(b.prop("BoundType") == "Radiation" for b in boundaries[0].children) == 1
    setup = [s for s in design.walk("Setup1") if s.prop("Frequency") == "5GHz"]
    assert len(setup) == 1 and setup[0].prop("MaximumPasses") == "50" and setup[0].prop("MinimumPasses") == "5"
    sweep = setup[0].child("Sweeps").child("Sweep")
    assert [sweep.prop(n) for n in ("RangeStart", "RangeEnd", "RangeStep", "Type")] == ["5GHz", "20GHz", "0.25GHz", "Discrete"]
    print("  Source metadata: 8 top-level parts/materials, two 50-ohm ports, Radiation, original setup/sweep")


def audit_protected_files(repository):
    names = subprocess.check_output(["git", "ls-tree", "-rz", "--name-only", "HEAD"], cwd=repository).decode().split("\0")
    # GUI/bridge code is intentionally editable during the debugging task.
    # The HFSS inputs and both numeric geometry/default modules must not change.
    math_files = {"vivaldiCalculateGeometry.m", "vivaldiDefaultParams.m",
                  "SingleElementBuilder/vivaldiBuilderGeometry.m",
                  "SingleElementBuilder/vivaldiBuilderDefaultParams.m"}
    protected = [name for name in names if name and (name.endswith(".aedt") or name in math_files)]
    for name in protected:
        original = subprocess.check_output(["git", "show", f"HEAD:{name}"], cwd=repository)
        present = (repository / name).read_bytes()
        assert hashlib.sha256(original).digest() == hashlib.sha256(present).digest(), f"Protected tracked file changed: {name}"
    print(f"  Original HFSS/math protection: {len(protected)} tracked files byte-identical to Git HEAD")


def main():
    core = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path,
                        default=core / "reference" / "17_10_2026_vivaldi.aedt")
    args = parser.parse_args()
    raw = args.reference.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SOURCE_SHA, "Reference differs from the verified 17/10 source"
    root, count = sections(raw.decode("ascii"))
    designs = [s for s in root.walk("HFSSModel") if s.prop("Name") == DESIGN]
    assert len(designs) == 1
    print("OFFLINE STATIC/NUMERICAL AUDIT — PYTHON; NO MATLAB/HFSS EXECUTION")
    evaluator, geometry = audit_variables(designs[0], core)
    audit_coordinates(designs[0], evaluator, geometry)
    audit_inventory(designs[0])
    audit_protected_files(core.parent)
    print(f"  Exact source SHA-256 verified; {count} nested AEDT sections balanced")
    print("PASS: source/data/static checks. MATLAB tests and real HFSS CAD/solver validation remain UNRUN.")


if __name__ == "__main__":
    main()
