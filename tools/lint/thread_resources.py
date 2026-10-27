#!/usr/bin/env python3
"""thread_resources.py: code that runs on a worker thread makes no render resource (debt list row 3, D-295).

The bench froze (PR #254, 2026-10-26) because a ShaderMaterial and an ImageTexture were made inside a
WorkerThreadPool task: on Forward+ the renderer sets such a resource up on the calling thread and races the
main thread's material update list. Workers lay out plain data (arrays, images, buffers); the main thread
makes every material, shader, mesh and texture. ThreadCheck (scenes/thread_check.gd) reports a breach at
runtime in a debug build; this lint stops it before it merges.

What it does, by reading the GDScript (no engine):
  1. Finds every worker entry point: the callable given to WorkerThreadPool.add_task / add_group_task and to
     Thread.start (a lambda, a method, or `method.bind(...)`; a Callable parameter is followed to the call
     sites that pass a lambda or method to that parameter).
  2. Walks what each entry point reaches: calls to this file's functions, `Class.f()` and `Class.new()` of
     project classes, and calls on a variable whose type is a project class (declared, or from `Class.new()`).
     A call that cannot be resolved is not followed (it is counted in --verbose); `call_deferred` is the hand-over
     back to the main thread and is never followed.
  3. Fails on any reached line that makes a render resource: `<Material|Shader|Mesh|Texture...>.new()`,
     `RenderingServer.*_create*()`, `ImageTexture.create_from_image()`, `SurfaceTool.commit()` (an ArrayMesh),
     `set_shader_parameter()` (queues a material update), or a call to a function that starts with
     `ThreadCheck.main_only(` (main thread only by its own word).
  A block under `if OS.get_thread_caller_id() == OS.get_main_thread_id():` runs on the main thread and is
  skipped. Put `# thread-ok: <why>` on a line to excuse it (the reason is required; a reviewer reads it).

Usage: python3 tools/lint/thread_resources.py [--root DIR] [--verbose]
       python3 tools/lint/thread_resources.py --selftest   (the planted defects in tests/fixtures/lint/thread_resources
                                                            are all caught, the clean one is not, the real tree is clean)
Exit 1 on any finding, listed as file:line with the path from the entry point.
"""
import os
import re
import sys

NL = "\n"
DIRS = ["sim", "scenes", "autoload", "tools"]
FIXTURES = os.path.join("tests", "fixtures", "lint", "thread_resources")
# Classes whose `.new()` sets up a renderer resource.
RESOURCE_CLASSES = (
    "Material|ShaderMaterial|StandardMaterial3D|BaseMaterial3D|ORMMaterial3D|CanvasItemMaterial|"
    "ParticleProcessMaterial|PanoramaSkyMaterial|ProceduralSkyMaterial|PhysicalSkyMaterial|Shader|"
    "Mesh|ArrayMesh|PrimitiveMesh|BoxMesh|QuadMesh|SphereMesh|CylinderMesh|CapsuleMesh|PlaneMesh|PrismMesh|"
    "TorusMesh|TextMesh|MultiMesh|ImageTexture|ImageTextureLayered|Texture2D|GradientTexture1D|GradientTexture2D|"
    "NoiseTexture2D|CanvasTexture|Environment|Sky"
)
RESOURCE_NEW = re.compile(r"\b(" + RESOURCE_CLASSES + r")\.new\s*\(")
FORBIDDEN = [
    (RESOURCE_NEW, "makes a {0} (renderer resource)"),
    (re.compile(r"\bRenderingServer\s*\.\s*(\w*_create\w*)\s*\("), "calls RenderingServer.{0}"),
    (re.compile(r"\bImageTexture\s*\.\s*(create_from_image)\s*\("), "calls ImageTexture.{0}"),
    (re.compile(r"\.(commit)\s*\(\s*\)"), "calls .{0}() (SurfaceTool makes an ArrayMesh; use commit_to_arrays)"),
    (re.compile(r"\.(set_shader_parameter)\s*\("), "calls .{0}() (queues a material update)"),
]
MAIN_GUARD = re.compile(r"^\s*if\s+OS\.get_thread_caller_id\(\)\s*==\s*OS\.get_main_thread_id\(\)\s*:")
THREAD_OK = re.compile(r"#\s*thread-ok:\s*\S")
KEYWORDS = {
    "if", "elif", "while", "for", "match", "return", "await", "and", "or", "not", "in", "is", "as", "func",
    "var", "const", "assert", "preload", "load", "print", "push_error", "push_warning", "str", "int", "float",
    "bool", "range", "min", "max", "mini", "maxi", "minf", "maxf", "abs", "absf", "clamp", "clampf", "clampi",
    "len", "typeof", "Vector2", "Vector3", "Vector2i", "Vector3i", "Color", "Array", "Dictionary", "Callable",
    "Transform3D", "Basis", "Quaternion", "Rect2", "AABB", "Plane", "floori", "ceili", "roundi", "lerp", "lerpf",
    "sqrt", "sin", "cos", "atan2", "pow", "snappedf", "signf", "signi", "wrapf", "wrapi", "randi", "randf",
}
CALL = re.compile(r"(?<![\w.])(?:(\w+)\s*\.\s*)?(\w+)\s*\(")
ANY_CALL = re.compile(r"(\w+)\s*\.\s*(\w+)\s*\(")


class Func:
    def __init__(self, path, name, line, indent, params, body_start, body_lines, cls):
        self.path, self.name, self.line, self.indent = path, name, line, indent
        self.params = params  # name -> type ("" when untyped)
        self.body_start = body_start  # 1-based line of body_lines[0]
        self.body_lines = body_lines
        self.cls = cls

    def label(self):
        return "%s:%d %s()" % (self.path, self.line, self.name)


def strip_line(text):
    """Code of a line: comments cut and string contents blanked (so a quoted name never matches)."""
    out, quote, i = [], None, 0
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
                out.append(c)
        elif c in "\"'":
            quote = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def indent_of(raw):
    n = 0
    for c in raw:
        if c == "\t":
            n += 4
        elif c == " ":
            n += 1
        else:
            break
    return n


def parse_params(sig):
    params = {}
    inner = sig[sig.find("(") + 1 : sig.rfind(")")] if ")" in sig else sig[sig.find("(") + 1 :]
    depth, cur = 0, ""
    parts = []
    for c in inner:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += c
    parts.append(cur)
    for part in parts:
        m = re.match(r"\s*(\w+)\s*(?::\s*([\w.\[\]]+))?", part)
        if m:
            params[m.group(1)] = (m.group(2) or "").split("[")[0]
    return params


class Project:
    def __init__(self, root, files):
        self.root = root
        self.funcs = []  # every Func
        self.by_file = {}  # path -> {name: [Func]}
        self.class_file = {}  # class_name -> path
        self.extends = {}  # path -> base class name
        self.members = {}  # path -> {var name: type}
        self.lines = {}  # path -> [raw lines]
        for path in files:
            self.load(path)

    def load(self, path):
        with open(os.path.join(self.root, path), encoding="utf-8", errors="replace") as fh:
            raw = fh.read().split("\n")
        self.lines[path] = raw
        members = self.members.setdefault(path, {})
        cls_stack = []
        i = 0
        while i < len(raw):
            line = raw[i]
            code = strip_line(line)
            m = re.match(r"\s*class_name\s+(\w+)", code)
            if m:
                self.class_file[m.group(1)] = path
            m = re.match(r"\s*extends\s+(\w+)", code)
            if m and path not in self.extends:
                self.extends[path] = m.group(1)
            m = re.match(r"(\s*)class\s+(\w+)", code)
            if m:
                cls_stack = [c for c in cls_stack if c[0] < indent_of(line)] + [(indent_of(line), m.group(2))]
            m = re.match(r"(\s*)(?:static\s+)?var\s+(\w+)\s*(?::\s*(\w+))?\s*(?::=|=)?\s*(?:(\w+)\.new\()?", code)
            if m and indent_of(line) == 0 + (4 * len(cls_stack) if cls_stack else 0):
                members[m.group(2)] = m.group(3) or m.group(4) or ""
            m = re.match(r"(\s*)(?:static\s+)?func\s+(\w+)\s*\(", code)
            if m:
                ind = indent_of(line)
                sig = code
                j = i
                while sig.count("(") > sig.count(")") and j + 1 < len(raw):
                    j += 1
                    sig += " " + strip_line(raw[j])
                cls_stack = [c for c in cls_stack if c[0] < ind]
                body = []
                k = j + 1
                # a one-line body: `func f() -> void: x()`
                tail = re.search(r"\)\s*(?:->\s*[\w.\[\]]+)?\s*:\s*(\S.*)$", sig)
                body_start = j + 2
                if tail:
                    body.append(" " * (ind + 4) + tail.group(1))
                    body_start = j + 1
                while k < len(raw):
                    s = raw[k]
                    if s.strip() and indent_of(s) <= ind and not s.strip().startswith("#"):
                        break
                    body.append(s)
                    k += 1
                f = Func(path, m.group(2), i + 1, ind, parse_params(sig), body_start, body, cls_stack[-1][1] if cls_stack else "")
                self.funcs.append(f)
                self.by_file.setdefault(path, {}).setdefault(f.name, []).append(f)
                i = k
                continue
            i += 1

    def find(self, path, name, seen=None):
        """Functions called `name` in `path` or, climbing `extends`, in its project base classes."""
        seen = seen or set()
        if path in seen:
            return []
        seen.add(path)
        found = list(self.by_file.get(path, {}).get(name, []))
        if found:
            return found
        base = self.extends.get(path)
        if base and base in self.class_file:
            return self.find(self.class_file[base], name, seen)
        return []

    def type_map(self, f):
        """Variable name -> project class for a function: members, parameters, annotated and `Class.new()` locals."""
        types = {k: v for k, v in self.members.get(f.path, {}).items() if v}
        types.update({k: v for k, v in f.params.items() if v})
        for raw in f.body_lines:
            code = strip_line(raw)
            m = re.match(r"\s*var\s+(\w+)\s*(?::\s*(\w+))?\s*(?::=|=)\s*(?:(\w+)\.new\()?", code)
            if m and (m.group(2) or m.group(3)):
                types[m.group(1)] = m.group(2) or m.group(3)
        return types


def balanced(text, start):
    """The text between the parenthesis at text[start] and its match, and the index after it."""
    depth, i = 0, start
    while i < len(text):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[start + 1 : i], i + 1
        i += 1
    return text[start + 1 :], len(text)


def split_args(text):
    """Top-level comma-separated arguments of a call's inner text: [(argument, offset of its first character)]."""
    out, depth, cur, start = [], 0, "", 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            out.append((cur, start))
            cur, start = "", i + 1
        else:
            cur += c
    out.append((cur, start))
    res = []
    for arg, off in out:
        res.append((arg.strip(), off + len(arg) - len(arg.lstrip())))
    return res


def body_text(f):
    """The function's code with its source line numbers: [(line, code)], main-thread blocks removed."""
    out, skip_ind = [], None
    for n, raw in enumerate(f.body_lines):
        line_no = f.body_start + n
        if not raw.strip():
            continue
        ind = indent_of(raw)
        if skip_ind is not None:
            if ind > skip_ind:
                continue
            skip_ind = None
        if MAIN_GUARD.match(raw):
            skip_ind = ind
            continue
        if THREAD_OK.search(raw):
            continue
        out.append((line_no, strip_line(raw)))
    return out


class Linter:
    def __init__(self, project, verbose=False):
        self.p = project
        self.verbose = verbose
        self.findings = []
        self.unresolved = 0
        self.guarded = {f for f in project.funcs if self.starts_main_only(f)}
        self.expanded = set()

    @staticmethod
    def starts_main_only(f):
        for raw in f.body_lines:
            code = strip_line(raw).strip()
            if code:
                return code.startswith("ThreadCheck.main_only(")
        return False

    # -- entry points -------------------------------------------------------------------------------------
    def entries(self):
        """Yield (label, kind, payload): ('lambda', (func, code lines)), ('func', Func) or ('param', (func, name))."""
        out = []
        for f in self.p.funcs:
            joined = "\n".join(strip_line(r) for r in f.body_lines)
            line_of = lambda idx: f.body_start + joined[:idx].count("\n")
            threads = set(re.findall(r"\bvar\s+(\w+)\s*(?::\s*Thread)?\s*(?::=|=)\s*Thread\.new\s*\(", joined))
            sites = [(m.start(), m.end() - 1) for m in re.finditer(r"WorkerThreadPool\s*\.\s*add_(?:group_)?task\s*\(", joined)]
            for t in threads:
                sites += [(m.start(), m.end() - 1) for m in re.finditer(r"\b%s\s*\.\s*start\s*\(" % re.escape(t), joined)]
            for start, paren in sites:
                inner, _ = balanced(joined, paren)
                args = split_args(inner)
                if not args or not args[0][0]:
                    continue
                out.append(self.entry_of(f, args[0][0], line_of(paren + 1 + args[0][1])))
        return [e for e in out if e]

    def entry_of(self, f, arg, line, strict=True):
        label = "%s:%d (worker entry in %s)" % (f.path, line, f.name)
        if arg.startswith("func"):
            m = re.match(r"func\s*\(", arg)
            _, after = balanced(arg, m.end() - 1)
            colon = arg.find(":", after - 1)
            first = line + arg[: colon + 1].count(NL)
            code = arg[colon + 1 :] if colon >= 0 else ""
            return (label, "lambda", (f, [(first + i, t) for i, t in enumerate(code.split(NL))]))
        m = re.match(r"(?:(\w+)\s*\.\s*)?(\w+)(?:\s*\.\s*bind\s*\(.*)?$", arg, re.S)
        if m:
            cls, name = m.group(1), m.group(2)
            if cls and cls in self.p.class_file:
                found = self.p.find(self.p.class_file[cls], name)
            elif cls in (None, "self"):
                found = self.p.find(f.path, name)
            else:
                found = []
            if found:
                return (label, "func", found)
            if not cls and f.params.get(name) == "Callable":
                return (label, "param", (f, name))
        if strict:
            self.unresolved += 1
            if self.verbose:
                print("note: %s: callable `%s` not resolved" % (label, arg[:60]))
        return None

    # -- walking -----------------------------------------------------------------------------------------
    def run(self):
        roots = []  # (label, [Func] or lambda payload)
        for label, kind, payload in self.entries():
            if kind == "param":
                roots += self.param_roots(label, *payload)
            else:
                roots.append((label, kind, payload))
        seen = set()
        for label, kind, payload in roots:
            self.run_root(label, kind, payload, seen)
        return self.findings

    def run_root(self, label, kind, payload, seen):
        if kind == "param":
            f, pname = payload
            if (f, pname) not in self.expanded:
                self.expanded.add((f, pname))
                for label2, kind2, payload2 in self.param_roots(label, f, pname):
                    self.run_root(label2, kind2, payload2, seen)
        elif kind == "lambda":
            f, code_lines = payload
            self.scan_code(f, code_lines, label, [label], seen)
        else:
            for f in payload:
                self.walk(f, [label], seen)

    def param_roots(self, label, f, pname):
        """A worker entry that is a Callable parameter of `f`: the callables its call sites pass in."""
        index = list(f.params).index(pname)
        roots = []
        pat = re.compile(r"(?<![\w])(?:\w+\s*\.\s*)?%s\s*\(" % re.escape(f.name))
        for g in self.p.funcs:
            joined = "\n".join(strip_line(r) for r in g.body_lines)
            for m in pat.finditer(joined):
                if g is f and joined[max(0, m.start() - 5) : m.start()].strip().endswith("func"):
                    continue
                inner, _ = balanced(joined, m.end() - 1)
                args = split_args(inner)
                if index < len(args) and args[index][0]:
                    line = g.body_start + joined[: m.end() + args[index][1]].count("\n")
                    e = self.entry_of(g, args[index][0], line, strict=False)
                    if e:
                        roots.append((label + " <- " + e[0], e[1], e[2]))
        return roots

    def walk(self, f, path, seen):
        if f in seen:
            return
        seen.add(f)
        if f in self.guarded:
            self.add(f, f.line, "is main-thread only (ThreadCheck.main_only) but a worker reaches it", path)
            return
        self.scan_code(f, body_text(f), path[0], path + [f.label()], seen)

    def scan_code(self, f, lines, label, path, seen):
        types = self.p.type_map(f)
        for line_no, code in lines:
            for pat, msg in FORBIDDEN:
                for m in pat.finditer(code):
                    self.add(f, line_no, msg.format(m.group(1)), path)
            for m in CALL.finditer(code):
                recv, name = m.group(1), m.group(2)
                if recv is None and name in KEYWORDS:
                    continue
                for g in self.resolve(f, types, recv, name):
                    self.walk(g, path, seen)
            for m in re.finditer(r"\b(\w+)\s*\.\s*bind\s*\(", code):
                for g in self.p.find(f.path, m.group(1)):
                    self.walk(g, path, seen)
            for m in re.finditer(r"\b(\w+)\s*\.\s*call\s*\(", code):
                if f.params.get(m.group(1)) == "Callable" and (f, m.group(1)) not in self.expanded:
                    self.expanded.add((f, m.group(1)))
                    for label2, kind, payload in self.param_roots(path[-1], f, m.group(1)):
                        self.run_root(label2, kind, payload, seen)

    def resolve(self, f, types, recv, name):
        if name == "new" and recv in self.p.class_file:
            return self.p.find(self.p.class_file[recv], "_init")
        if recv is None or recv == "self":
            return self.p.find(f.path, name)
        if recv in self.p.class_file:
            return self.p.find(self.p.class_file[recv], name)
        t = types.get(recv, "")
        if t in self.p.class_file:
            return self.p.find(self.p.class_file[t], name)
        return []

    def add(self, f, line, msg, path):
        key = (f.path, line, msg)
        if all(key != (x[0], x[1], x[2]) for x in self.findings):
            self.findings.append((f.path, line, msg, path))


def gd_files(root, dirs):
    for d in dirs:
        for dirpath, _, files in os.walk(os.path.join(root, d)):
            for fn in sorted(files):
                if fn.endswith(".gd"):
                    yield os.path.relpath(os.path.join(dirpath, fn), root).replace(os.sep, "/")


def lint(root, dirs, verbose=False):
    project = Project(root, list(gd_files(root, dirs)))
    linter = Linter(project, verbose)
    findings = linter.run()
    return findings, linter, project


def report(findings):
    for path, line, msg, trail in sorted(findings):
        print("%s:%d: %s" % (path, line, msg))
        print("    reached from: " + "\n                  -> ".join(trail))


def selftest(root):
    fx = os.path.join(root, FIXTURES)
    if not os.path.isdir(fx):
        print("selftest: no fixtures in %s" % FIXTURES)
        return 1
    bad = 0
    findings, _, _ = lint(root, [FIXTURES])
    hit_lines = {}
    for path, line, _, _ in findings:
        hit_lines.setdefault(os.path.basename(path), []).append(line)
    for fn in sorted(os.listdir(fx)):
        if not fn.endswith(".gd"):
            continue
        got = hit_lines.get(fn, [])
        if fn.startswith("planted_") and not got:
            print("FAIL: planted defect not caught: %s" % fn)
            bad = 1
        elif not fn.startswith("planted_") and got:
            print("FAIL: clean fixture flagged: %s at lines %s" % (fn, got))
            bad = 1
        else:
            print("ok: %s %s" % (fn, "caught at line %s" % got if got else "clean"))
    findings, _, _ = lint(root, DIRS)
    if findings:
        print("FAIL: the real tree has findings")
        report(findings)
        bad = 1
    else:
        print("ok: the real tree is clean")
    print("selftest: %s" % ("FAIL" if bad else "PASS"))
    return bad


def main():
    root = "."
    args = sys.argv[1:]
    if "--root" in args:
        root = args[args.index("--root") + 1]
    if "--selftest" in args:
        return selftest(root)
    findings, linter, project = lint(root, DIRS, "--verbose" in args)
    if "--verbose" in args:
        print("%d files, %d functions, %d unresolved worker callables" % (len(project.lines), len(project.funcs), linter.unresolved))
    if findings:
        print("thread_resources: a worker thread makes render resources (the freeze of #254):")
        report(findings)
        print("Workers lay out plain data; the main thread makes every material, mesh, shader and texture.")
        return 1
    print("thread_resources: OK (no worker-thread path makes a render resource)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
