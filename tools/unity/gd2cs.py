#!/usr/bin/env python3
"""Translates sim/*.gd into plain C# that behaves the same, bit for bit (D-470 U2).

    python tools/unity/gd2cs.py            # writes unity/Assets/Scripts/Sim/Game/*.cs
    python tools/unity/gd2cs.py --check    # exit 1 when the output on disk is stale

Godot stays the working game until the port reaches parity, so sim/ keeps moving: re-running this
carries a fix over. At the switch (U6) the output becomes the source and this file goes. Whatever
GDScript means that C# does not (64-bit int, Dictionary order, 32-bit vector parts) lives in
Sim/Runtime; this only maps the syntax, and the types it can see.
"""
import argparse
import glob
import os
import re
import sys
from collections import namedtuple

from gdtoolkit.parser import parser
from lark import Token, Tree

SKIP = {"sim_teardown.gd"}  # breaks RefCounted cycles; the C# garbage collector has none to break
OUT = "unity/Assets/Scripts/Sim/Game"
# Methods whose C# body is written here: the GDScript idiom is right for Godot and wrong for C#. The
# golden logs still hold these to Godot's numbers on every tick (D-470).
REWRITTEN = {
    # GDScript's Array(slice).max() runs natively; in C# it is a heap copy of each row, every tick.
    ("WaterBasin", "deepest"): """float[] d = depth.Raw;
float most = 0f;
for (long j = r.position.y; j < r.end.y; j++)
{
    long end = j * nx + r.end.x;
    for (long k = j * nx + r.position.x; k < end; k++)
    {
        if (d[k] > most) most = d[k];
    }
}
return most;""",
}

KEYWORDS = set(
    """abstract as base bool break byte case catch char checked class const continue decimal default
    delegate do double else enum event explicit extern false finally fixed float for foreach goto if
    implicit in int interface internal is lock long namespace new null object operator out override
    params private protected public readonly ref return sbyte sealed short sizeof stackalloc static
    string struct switch this throw true try typeof uint ulong unchecked unsafe ushort using virtual
    void volatile while""".split()
)
STRUCTS = {
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i", "AABB",
    "Basis", "Transform3D", "Quaternion", "Color",
}
PACKED = {
    "PackedByteArray": "int", "PackedInt32Array": "int", "PackedInt64Array": "int",
    "PackedFloat32Array": "float", "PackedFloat64Array": "float", "PackedStringArray": "String",
    "PackedVector2Array": "Vector2", "PackedVector3Array": "Vector3",
}
RUNTIME_CLASSES = {
    "RandomNumberGenerator", "Mutex", "Callable", "WeakRef", "RefCounted", "FileAccess", "JSON",
    "ClassDB", "WorkerThreadPool", "Time", "Geometry2D", "SimTeardown",
}
PROPS = {
    "Vector2": dict(x="float", y="float"),
    "Vector2i": dict(x="int", y="int"),
    "Vector3": dict(x="float", y="float", z="float"),
    "Vector3i": dict(x="int", y="int", z="int"),
    "Vector4": dict(x="float", y="float", z="float", w="float"),
    "Vector4i": dict(x="int", y="int", z="int", w="int"),
    "Rect2": dict(position="Vector2", size="Vector2", end="Vector2"),
    "Rect2i": dict(position="Vector2i", size="Vector2i", end="Vector2i"),
    "AABB": dict(position="Vector3", size="Vector3", end="Vector3"),
    "Basis": dict(x="Vector3", y="Vector3", z="Vector3"),
    "Transform3D": dict(basis="Basis", origin="Vector3"),
    "RandomNumberGenerator": dict(seed="int", state="int"),
    "Color": dict(r="float", g="float", b="float", a="float"),
}
GLOBAL_RET = {
    **{n: "float" for n in """absf acos angle_difference atan2 ceilf clampf cos deg_to_rad exp float
       floor floorf fposmod lerpf maxf minf move_toward pow roundf signf sin sinh smoothstep snappedf
       sqrt tan wrapf""".split()},
    **{n: "int" for n in """absi ceili clampi floori hash int maxi mini posmod roundi signi
       typeof""".split()},
    **{n: "bool" for n in "is_equal_approx is_same".split()},
    "str": "String",
}
METHOD_RET = {
    **{n: "float" for n in """length length_squared distance_to distance_squared_to dot angle angle_to
       randf randf_range get_area to_float""".split()},
    **{n: "int" for n in """size randi randi_range get_16 get_32 decode_s16 get_instance_id
       find""".split()},
    **{n: "bool" for n in """is_empty has has_point has_area intersects any all is_zero_approx
       begins_with is_same is_equal_approx has_method class_exists file_exists
       is_point_in_polygon""".split()},
    **{n: "String" for n in "substr replace repeat get_string_from_ascii".split()},
}
SAME_RET = set(
    """normalized rotated lerp floor ceil abs clamp orthogonal limit_length move_toward slerp grow
    grow_individual merge expand intersection duplicate filter slice min max merged
    orthonormalized""".split()
)
Method = namedtuple("Method", "name ret params static node")
Param = namedtuple("Param", "name type default")


def camel(name):
    if name.upper() == name and any(c.isalpha() for c in name) and len(name) > 1:
        return name
    lead = "_" if name.startswith("_") else ""
    parts = name.strip("_").split("_")
    out = lead + parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    return "@" + out if out in KEYWORDS else out


def pascal(name):
    if name == "reveal":  # upgrade_tree.gd has func reveal() and enum Reveal, one name in C#.
        return "RevealOf"
    lead = "_" if name.startswith("_") else ""
    return lead + "".join(p[:1].upper() + p[1:] for p in name.strip("_").split("_"))


def strtod(text):
    """Godot's built_in_strtod (core/string/ustring.cpp): GDScript literals and JSON numbers go
    through it, and it is not correctly rounded."""
    text = text.replace("_", "")
    mant, _, exp_part = text.lower().partition("e")
    int_part, _, frac_part = mant.partition(".")
    digits = int_part + frac_part
    dec_pt = len(int_part)
    size = len(digits)
    frac_exp = dec_pt - 18 if size > 18 else dec_pt - size
    digits = digits[:18]
    if not digits:
        return 0.0
    high, low = digits[:-9] or "0", digits[-9:]
    fraction = 1.0e9 * int(high) + int(low)
    exp = frac_exp + (int(exp_part) if exp_part else 0)
    negative = exp < 0
    exp = min(abs(exp), 511)
    dbl = 1.0
    power = 0
    while exp:
        if exp & 1:
            dbl *= 10.0 ** (2**power)
        exp >>= 1
        power += 1
    return fraction / dbl if negative else fraction * dbl


def float_literal(text):
    exact = strtod(text)
    clean = text.replace("_", "")
    if float(clean) == exact:
        out = clean
        if out.endswith("."):
            out += "0"
        if out.startswith("."):
            out = "0" + out
        return out
    return repr(exact)


def line_of(node):
    if isinstance(node, Token):
        return node.line
    meta = getattr(node, "meta", None)
    if meta is not None and not getattr(meta, "empty", True):
        return meta.line
    for kid in node.children:
        if kid is not None and not isinstance(kid, str) or isinstance(kid, Token):
            found = line_of(kid)
            if found:
                return found
    return 0


def kids(node):
    return [k for k in node.children if k is not None and not is_trailing(k)]


def is_trailing(node):
    return isinstance(node, Tree) and node.data == "trailing_comma"


def is_tree(node, *names):
    return isinstance(node, Tree) and node.data in names


class ClassInfo:
    def __init__(self, name, outer, tree, path):
        self.name = name  # dotted: AirWing.Heli
        self.short = name.split(".")[-1]
        self.outer = outer
        self.tree = tree
        self.path = path
        self.base = None
        self.fields = {}
        self.consts = {}
        self.methods = {}
        self.enums = {}
        self.inner = {}
        self.aliases = {}
        self.subclassed = set()


class Project:
    def __init__(self, paths):
        self.classes = {}
        self.top = []
        self.warnings = []
        for path in paths:
            with open(path, encoding="utf-8") as f:
                src = f.read()
            tree = parser.parse(src, gather_metadata=True)
            name = None
            for kid in tree.children:
                if is_tree(kid, "classname_stmt"):
                    name = str(kid.children[0])
            if name is None:
                name = pascal(os.path.basename(path)[:-3])
            info = self.declare(name, None, tree, path)
            info.src = src
            self.top.append(info)
        for info in list(self.classes.values()):
            self.scan(info)
        for info in self.classes.values():
            base = self.base_of(info)
            while base is not None:
                base.subclassed.update(info.methods)
                base = self.base_of(base)

    def declare(self, name, outer, tree, path):
        info = ClassInfo(name, outer, tree, path)
        self.classes[name] = info
        for kid in tree.children:
            if is_tree(kid, "class_def"):
                inner = str(kid.children[0])
                info.inner[inner] = self.declare(f"{name}.{inner}", info, kid, path)
        return info

    def base_of(self, info):
        return self.classes.get(info.base) if info.base else None

    def scan(self, info):
        for kid in kids(info.tree):
            if is_tree(kid, "extends_stmt"):
                base = str(kid.children[0])
                if base != "RefCounted":
                    info.base = base
            elif is_tree(kid, "class_var_stmt", "static_class_var_stmt"):
                decl = kid.children[0]
                if decl.data == "class_var_stmt":
                    decl = decl.children[0]
                name = str(decl.children[0])
                hint = str(decl.children[1]) if decl.data.startswith("class_var_typed") else None
                info.fields[name] = (hint, decl, kid.data == "static_class_var_stmt")
            elif is_tree(kid, "const_stmt"):
                decl = kid.children[0]
                name = str(decl.children[0])
                hint = str(decl.children[1]) if decl.data == "const_typed_assigned" else None
                value = decl.children[-1]
                preload = self.preload_target(value)
                if preload:
                    info.aliases[name] = preload
                else:
                    info.consts[name] = (hint, value)
            elif is_tree(kid, "enum_stmt"):
                decl = kid.children[0]
                if decl.data == "enum_named":
                    info.enums[str(decl.children[0])] = decl.children[-1]
                else:
                    info.enums[None] = decl.children[-1]
            elif is_tree(kid, "func_def", "static_func_def"):
                static = kid.data == "static_func_def"
                fn = kid.children[0] if static else kid
                info.methods[str(fn.children[0].children[0])] = self.method(fn, static)

    @staticmethod
    def preload_target(value):
        node = value
        while is_tree(node, "expr"):
            node = node.children[0]
        if is_tree(node, "standalone_call") and str(node.children[0]) == "preload":
            text = str(node.children[1].children[0]).strip('"')
            return pascal(os.path.basename(text)[:-3])
        return None

    @staticmethod
    def method(fn, static):
        header = fn.children[0]
        params = []
        for arg in kids(header.children[1]):
            name = str(arg.children[0])
            if arg.data == "func_arg_typed":
                rest = arg.children[2:]
                params.append(Param(name, str(arg.children[1]), rest[0] if rest else None))
            elif arg.data == "func_arg_inf":
                params.append(Param(name, None, arg.children[1]))
            else:
                rest = arg.children[1:]
                params.append(Param(name, "Variant", rest[0] if rest else None))
        ret = str(header.children[2]) if len(header.children) > 2 and header.children[2] else None
        return Method(str(header.children[0]), ret, params, static, fn)


class Scope:
    def __init__(self):
        self.names = {}
        self.inner = set()


# GDScript's Basis() is identity and Color() opaque black; a C# struct's new T() is all zeros.
NOT_ZERO = {
    "Basis": "Basis.IDENTITY",
    "Transform3D": "Transform3D.IDENTITY",
    "Quaternion": "Quaternion.IDENTITY",
    "Color": "new Color(0f, 0f, 0f, 1f)",
}


class Emitter:
    def __init__(self, project, info):
        self.p = project
        self.cls = info
        self.out = []
        self.ind = 0
        self.scopes = []
        self.fn_ret = None
        self.in_lambda = 0
        self.temp = 0
        self.comments = sorted(self.collect_comments(info.src), key=lambda c: c[0])
        self.next_comment = 0

    # ---------- comments ----------
    @staticmethod
    def collect_comments(src):
        tree = parser.parse_comments(src)
        lines = src.split("\n")
        out = []
        for tok in tree.children:
            text = str(tok)
            line = tok.line
            trailing = lines[line - 1].lstrip()[:1] != "#"
            out.append((line, text.lstrip("#").strip(), trailing))
        return out

    def flush_comments(self, line):
        while self.next_comment < len(self.comments):
            at, text, _ = self.comments[self.next_comment]
            if at > line:
                break
            self.w("// " + text if text else "//")
            self.next_comment += 1

    def w(self, text=""):
        self.out.append(("    " * self.ind + text) if text else "")

    # ---------- names and types ----------
    def find_class(self, name):
        """The ClassInfo a name means from inside this class, or None."""
        info = self.cls
        head, _, rest = name.partition(".")
        while info is not None:
            if head in info.inner:
                found = info.inner[head]
                return self.p.classes.get(f"{found.name}.{rest}") if rest else found
            if head in info.aliases:
                head = info.aliases[head]
            info = info.outer
        return self.p.classes.get(name) or self.p.classes.get(head if not rest else f"{head}.{rest}")

    def is_enum(self, name):
        head, _, rest = name.rpartition(".")
        owner = self.find_class(head) if head else None
        if owner is not None:
            return rest in owner.enums
        info = self.cls
        while info is not None:
            if name in info.enums:
                return True
            info = info.outer
        return False

    def canon(self, hint):
        if hint is None:
            return None
        hint = hint.replace(" ", "")
        if hint.startswith("Array["):
            return f"Array[{self.canon(hint[6:-1])}]"
        if hint.startswith("Dictionary["):
            return "Dictionary"
        if self.is_enum(hint):
            return "int"
        found = self.find_class(hint)
        return found.name if found else hint

    def cs_type(self, ty):
        if ty is None:
            return "var"
        ty = self.canon(ty)
        simple = {
            "int": "long", "float": "double", "bool": "bool", "String": "string",
            "StringName": "string", "Dictionary": "GDict", "Array": "GArray<Variant>",
            "Object": "RefCounted", "void": "void",
        }
        if ty in simple:
            return simple[ty]
        if ty.startswith("Array["):
            return f"GArray<{self.cs_type(ty[6:-1])}>"
        return ty

    def default_of(self, ty):
        ty = self.canon(ty)
        if ty == "String":
            return '""'
        if ty == "Callable":
            return "new Callable()"
        if ty in ("Dictionary", "Array") or ty.startswith("Array[") or ty in PACKED:
            return f"new {self.cs_type(ty)}()"
        if ty in STRUCTS or ty in ("int", "float", "bool", "Variant"):
            return "default"
        return "null"

    def field_of(self, cname, name):
        info = self.p.classes.get(cname) if cname else None
        while info is not None:
            if name in info.fields:
                hint, decl, static = info.fields[name]
                return info, hint, decl, static
            info = self.p.base_of(info)
        return None

    def method_of(self, cname, name):
        info = self.p.classes.get(cname) if cname else None
        while info is not None:
            if name in info.methods:
                return info, info.methods[name]
            info = self.p.base_of(info)
        return None

    def const_of(self, cname, name):
        info = self.p.classes.get(cname) if cname else None
        while info is not None:
            if name in info.consts:
                return info, info.consts[name]
            info = self.p.base_of(info)
        return None

    def here_field(self, name):
        info = self.cls
        while info is not None:
            got = self.field_of(info.name, name)
            if got:
                return got
            info = info.outer
        return None

    def here_method(self, name):
        info = self.cls
        while info is not None:
            got = self.method_of(info.name, name)
            if got:
                return got
            info = info.outer
        return None

    def here_const(self, name):
        info = self.cls
        while info is not None:
            got = self.const_of(info.name, name)
            if got:
                return got
            info = info.outer
        return None

    def field_type(self, owner, name):
        got = self.field_of(owner, name)
        if not got:
            return None
        info, hint, decl, _ = got
        sub = Emitter.__new__(Emitter)
        sub.__dict__.update(self.__dict__)
        sub.cls = info
        sub.scopes = []
        if hint:
            return sub.canon(hint)
        if decl.data == "class_var_inf":
            return sub.ex(decl.children[1])[1]
        return None

    def const_type(self, owner, name):
        got = self.const_of(owner, name)
        if not got:
            return None
        info, (hint, value) = got
        sub = Emitter.__new__(Emitter)
        sub.__dict__.update(self.__dict__)
        sub.cls = info
        sub.scopes = []
        return sub.canon(hint) if hint else sub.ex(value)[1]

    def method_ret(self, owner, name):
        got = self.method_of(owner, name)
        if not got:
            return None
        info, m = got
        sub = Emitter.__new__(Emitter)
        sub.__dict__.update(self.__dict__)
        sub.cls = info
        return sub.canon(m.ret)

    # ---------- scopes ----------
    def push(self):
        self.scopes.append(Scope())

    def pop(self):
        scope = self.scopes.pop()
        if self.scopes:
            parent = self.scopes[-1]
            parent.inner |= scope.inner
            parent.inner |= {cs for cs, _ in scope.names.values()}

    def declare(self, name, ty):
        cs = camel(name)
        base, n = cs, 2
        while self.taken(cs):
            cs = f"{base}{n}"
            n += 1
        self.scopes[-1].names[name] = (cs, ty)
        return cs

    def taken(self, cs):
        if cs in self.scopes[-1].inner:
            return True
        return any(cs == c for s in self.scopes for c, _ in s.names.values())

    def local(self, name):
        for scope in reversed(self.scopes):
            if name in scope.names:
                return scope.names[name]
        return None

    # ---------- expressions ----------
    def ex(self, n, expect=None):
        """(C# code, GDScript type or None)."""
        if isinstance(n, Token):
            return self.token(n, expect)
        handler = getattr(self, "x_" + str(n.data), None)
        if handler is not None:
            return handler(n, expect)
        if n.data in BINARY:
            return self.binary(n)
        raise SystemExit(f"{self.cls.path}:{line_of(n)}: no rule for {n.data}")

    def token(self, t, expect):
        kind = t.type
        text = str(t)
        if kind == "NUMBER":
            if re.fullmatch(r"[+-]?[\d_]+", text):
                return text.replace("_", ""), "int"
            sign = "-" if text.startswith("-") else ""
            return sign + float_literal(text.lstrip("+-")), "float"
        if kind in ("HEX", "BIN"):
            return text.replace("_", "") + "L", "int"
        return self.name(text)

    def name(self, text):
        if text == "true" or text == "false":
            return text, "bool"
        if text == "null":
            return "null", None
        if text == "self":
            return "this", self.cls.name
        got = self.local(text)
        if got:
            return got
        if text in ("PI", "TAU", "INF", "NAN"):
            return "Gd." + text, "float"
        if text.startswith("TYPE_"):
            return "Gd." + text, "int"
        field = self.here_field(text)
        if field:
            return camel(text), self.field_type(field[0].name, text)
        const = self.here_const(text)
        if const:
            return text, self.const_type(const[0].name, text)
        method = self.here_method(text)
        if method:
            return self.callable_of(pascal(text), method[1]), "Callable"
        info = self.cls
        while info is not None:
            if text in info.enums:
                return text, "enum:" + text
            if text in info.aliases:
                return info.aliases[text], "class:" + info.aliases[text]
            info = info.outer
        info = self.cls
        while info is not None:
            for owner_enum in info.enums.get(None, Tree("x", [])).children:
                if is_tree(owner_enum, "enum_element") and str(owner_enum.children[0]) == text:
                    return text, "int"
            info = info.outer
        found = self.find_class(text)
        if found:
            return text, "class:" + found.name
        if text in STRUCTS or text in PACKED or text in RUNTIME_CLASSES:
            return text, "class:" + text
        raise SystemExit(f"{self.cls.path}: unknown name {text}")

    def callable_of(self, target, m):
        args = ", ".join(f"a_[{i}]" for i in range(len(m.params)))
        if m.ret == "void":
            return f"new Callable(a_ => {{ {target}({args}); return default(Variant); }})"
        return f"new Callable(a_ => {target}({args}))"

    def x_expr(self, n, expect):
        return self.ex(n.children[0], expect)

    def x_par_expr(self, n, expect):
        code, ty = self.ex(n.children[0], expect)
        return f"({code})", ty

    def x_string(self, n, expect):
        text = str(n.children[0])
        if text.startswith('"""') or text.startswith("'''"):
            text = '"' + text[3:-3].replace('"', '\\"').replace("\n", "\\n") + '"'
        elif text.startswith("'"):
            text = '"' + text[1:-1].replace('"', '\\"') + '"'
        return text, "String"

    def x_rstring(self, n, expect):
        return '@"' + str(n.children[0])[2:-1].replace('"', '""') + '"', "String"

    def x_array(self, n, expect):
        items = kids(n)
        expect = self.canon(expect)
        if expect and expect.startswith("Array["):
            elem = expect[6:-1]
            if not items:
                return f"new {self.cs_type(expect)}()", expect
            body = ", ".join(self.ex(i, elem)[0] for i in items)
            return f"new {self.cs_type(expect)} {{ {body} }}", expect
        codes = [self.ex(i)[0] for i in items]
        body = ", ".join("default(Variant)" if c == "null" else c for c in codes)
        return f"Gd.Arr({body})", "Array"

    def x_dict(self, n, expect):
        pairs = kids(n)
        if not pairs:
            return "new GDict()", "Dictionary"
        body = []
        for pair in pairs:
            if pair.data != "c_dict_element":
                raise SystemExit(f"{self.cls.path}:{line_of(pair)}: Lua-style dictionary")
            body.append(f"{{ {self.ex(pair.children[0])[0]}, {self.ex(pair.children[1])[0]} }}")
        return "new GDict { " + ", ".join(body) + " }", "Dictionary"

    def x_subscr_expr(self, n, expect):
        base, ty = self.ex(n.children[0])
        index, _ = self.ex(n.children[1])
        elem = None
        if ty:
            if ty.startswith("Array["):
                elem = ty[6:-1]
            elif ty in PACKED:
                elem = PACKED[ty]
            elif ty == "String":
                elem = "String"
            elif ty in ("Dictionary", "Array"):
                elem = "Variant"
            elif ty in ("Vector2", "Vector3"):
                elem = "float"
            elif ty in ("Vector2i", "Vector3i", "Vector4i"):
                elem = "int"
        if ty == "String":
            return f"{base}.At({index})", elem
        return f"{base}[{index}]", elem

    def chain(self, n):
        """getattr children as nested (base, attr) steps: every attr but the last, then the last."""
        parts = [c for c in n.children if not (isinstance(c, Token) and str(c) == ".")]
        return parts[0], [str(p) for p in parts[1:]]

    def x_getattr(self, n, expect):
        base, attrs = self.chain(n)
        code, ty = self.ex(base) if not self.is_super(base) else ("base", self.cls.base)
        for attr in attrs:
            code, ty = self.member(code, ty, attr)
        return code, ty

    @staticmethod
    def is_super(node):
        return isinstance(node, Token) and str(node) == "super"

    def member(self, code, ty, attr):
        if ty and ty.startswith("enum:"):
            return f"{code}.{attr}", "int"
        if ty and ty.startswith("class:"):
            owner = ty[6:]
            info = self.p.classes.get(owner)
            if info:
                if attr in info.inner:
                    return f"{code}.{attr}", "class:" + info.inner[attr].name
                if attr in info.enums:
                    return f"{code}.{attr}", "enum:" + attr
                if self.const_of(owner, attr):
                    return f"{code}.{attr}", self.const_type(owner, attr)
                if self.field_of(owner, attr):
                    return f"{code}.{camel(attr)}", self.field_type(owner, attr)
                got = self.method_of(owner, attr)
                if got:
                    return self.callable_of(f"{code}.{pascal(attr)}", got[1]), "Callable"
                raise SystemExit(f"{self.cls.path}: {owner} has no {attr}")
            return f"{code}.{attr}" if attr.upper() == attr else f"{code}.{pascal(attr)}", owner
        if ty in PROPS and attr in PROPS[ty]:
            return f"{code}.{attr}", PROPS[ty][attr]
        if ty and self.field_of(ty, attr):
            return f"{code}.{camel(attr)}", self.field_type(ty, attr)
        if ty and self.const_of(ty, attr):
            return f"{code}.{attr}", self.const_type(ty, attr)
        if ty and self.method_of(ty, attr):
            got = self.method_of(ty, attr)
            return self.callable_of(f"{code}.{pascal(attr)}", got[1]), "Callable"
        return f"{code}.{camel(attr)}", None

    def args(self, nodes, params=None, elem=None):
        out = []
        for i, a in enumerate(nodes):
            want = elem
            if params and i < len(params):
                want = params[i].type
            if want in (None, "Variant") and self.is_null(a):
                out.append("default(Variant)")
                continue
            out.append(self.ex(a, want)[0])
        return ", ".join(out)

    def x_standalone_call(self, n, expect):
        name = str(n.children[0])
        rest = kids(n)[1:]
        if name in STRUCTS or name in PACKED:
            if not rest and name in NOT_ZERO:
                return NOT_ZERO[name], name
            return f"new {name}({self.args(rest)})", name
        if name == "Array":
            return f"new GArray<Variant>({self.args(rest)})", "Array"
        if name == "Callable":
            return "new Callable()", "Callable"
        if name == "super":
            return f"base.{pascal(self.func_name)}({self.args(rest)})", None
        method = self.here_method(name)
        if method:
            owner, m = method
            return f"{pascal(name)}({self.args(rest, m.params)})", self.canon(m.ret)
        return f"Gd.{pascal(name)}({self.args(rest)})", GLOBAL_RET.get(name)

    def x_getattr_call(self, n, expect):
        target = n.children[0]
        rest = kids(n)[1:]
        base, attrs = self.chain(target)
        method = attrs[-1]
        if self.is_super(base) and len(attrs) == 1:
            return f"base.{pascal(method)}({self.args(rest)})", self.method_ret(self.cls.base, method)
        code, ty = self.ex(base)
        for attr in attrs[:-1]:
            code, ty = self.member(code, ty, attr)
        if method == "new":
            if ty and ty.startswith("class:"):
                owner = ty[6:]
                got = self.method_of(owner, "_init")
                return f"new {code}({self.args(rest, got[1].params if got else None)})", owner
            raise SystemExit(f"{self.cls.path}:{line_of(n)}: .new on {code}")
        if ty and ty.startswith("class:"):
            owner = ty[6:]
            got = self.method_of(owner, method)
            if got:
                return (
                    f"{code}.{pascal(method)}({self.args(rest, got[1].params)})",
                    self.method_ret(owner, method),
                )
            ret = METHOD_RET.get(method)
            if owner == "Vector2" and method == "from_angle":
                ret = "Vector2"
            return f"{code}.{pascal(method)}({self.args(rest)})", ret
        if ty and self.method_of(ty, method):
            got = self.method_of(ty, method)
            return (
                f"{code}.{pascal(method)}({self.args(rest, got[1].params)})",
                self.method_ret(ty, method),
            )
        elem = None
        if ty and ty.startswith("Array[") and method in ("append", "push_back", "push_front"):
            elem = ty[6:-1]
        return f"{code}.{pascal(method)}({self.args(rest, None, elem)})", self.builtin_ret(ty, method)

    @staticmethod
    def builtin_ret(ty, method):
        if method in METHOD_RET:
            return METHOD_RET[method]
        if method in SAME_RET:
            return ty
        if ty and method == "cross":
            return "float" if ty == "Vector2" else ty
        if ty and method in ("pop_back", "pop_front", "back", "front"):
            return ty[6:-1] if ty.startswith("Array[") else None
        if method == "get_center":
            return "Vector2" if ty == "Rect2" else None
        if method == "keys":
            return "Array"
        return None

    def x_lambda(self, n, expect):
        header = n.children[0]
        kids_h = [k for k in header.children if k is not None]
        args = next(k for k in kids_h if is_tree(k, "func_args"))
        ret = None
        for k in kids_h:
            if isinstance(k, Token) and k.type == "TYPE_HINT":
                ret = str(k)
        self.push()
        names = {}
        lines = []
        for i, arg in enumerate(kids(args)):
            name = str(arg.children[0])
            ty = str(arg.children[1]) if arg.data == "func_arg_typed" else "Variant"
            cs = self.declare(name, self.canon(ty))
            names[name] = cs
            lines.append(f"{self.cs_type(ty)} {cs} = a_[{i}];")
        saved_out, saved_ret = self.out, self.fn_ret
        self.out = []
        self.ind += 1
        self.in_lambda += 1
        self.fn_ret = ret or "Variant"
        for line in lines:
            self.w(line)
        self.block_stmts(n.children[1:])
        if not self.ends_in_return(n.children[1:]) or ret in (None, "void"):
            if not self.ends_in_return(n.children[1:]):
                self.w("return default(Variant);")
        body = self.out
        self.in_lambda -= 1
        self.ind -= 1
        self.out, self.fn_ret = saved_out, saved_ret
        self.pop()
        pad = "    " * self.ind
        return "new Callable(a_ =>\n" + pad + "{\n" + "\n".join(body) + "\n" + pad + "})", "Callable"

    @staticmethod
    def ends_in_return(stmts):
        real = [s for s in stmts if isinstance(s, Tree) and s.data != "annotation"]
        return bool(real) and real[-1].data == "return_stmt"

    def is_bool_node(self, n):
        if isinstance(n, Tree):
            if n.data in BOOL_NODES:
                return True
            if n.data in ("expr", "par_expr"):
                return self.is_bool_node(n.children[0])
        return False

    def cond(self, n):
        code, ty = self.ex(n)
        if self.is_bool_node(n) or ty == "bool":
            return code
        return f"Gd.Truthy({code})"

    def binary(self, n):
        parts = n.children
        op = str(parts[1])
        if str(n.data).endswith("mdr_expr") and op == "%":
            left, lty = self.ex(parts[0])
            if lty == "String":
                return f"Gd.Format({left}, {self.ex(parts[2])[0]})", "String"
        code, ty = self.ex(parts[0])
        first_literal = self.is_int_literal(parts[0])
        for i in range(1, len(parts), 2):
            op = str(parts[i])
            right, rty = self.ex(parts[i + 1])
            shift = op in ("<<", ">>")
            if first_literal and (shift or self.is_int_literal(parts[i + 1])):
                code += "L"
            first_literal = False
            code = f"{code} {op} (int)({right})" if shift else f"{code} {op} {right}"
            ty = self.merge_type(ty, rty, op)
        if "shift" in n.data or "bitw" in n.data:
            code = f"({code})"
        return code, ty

    @staticmethod
    def is_int_literal(n):
        while is_tree(n, "expr"):
            n = n.children[0]
        return isinstance(n, Token) and n.type == "NUMBER" and re.fullmatch(r"[+-]?[\d_]+", str(n))

    @staticmethod
    def merge_type(a, b, op):
        if a is None or b is None:
            return None
        if a == b:
            if a == "Vector2i" and op == "/":
                return a
            return a
        if {a, b} == {"int", "float"}:
            return "float"
        vectors = ("Vector2", "Vector3", "Vector2i", "Vector3i", "Vector4", "Vector4i")
        for v, s in ((a, b), (b, a)):
            if v in vectors and s in ("int", "float"):
                if s == "float" and v.endswith("i"):
                    return v[:-1]
                return v
        if a in vectors and b in vectors:
            return None
        return None

    def x_comparison(self, n, expect):
        left, lty = self.ex(n.children[0])
        op = str(n.children[1])
        right, rty = self.ex(n.children[2])
        if self.is_null(n.children[2]) or self.is_null(n.children[0]):
            value, vty = (right, rty) if self.is_null(n.children[0]) else (left, lty)
            known = vty and vty != "Variant" and vty != "None"
            if known:
                return f"{value} {op} null", "bool"
            prefix = "!" if op == "!=" else ""
            return f"{prefix}Gd.IsNull({value})", "bool"
        if self.is_int_literal(n.children[0]) and self.is_int_literal(n.children[2]):
            left += "L"
        return f"{left} {op} {right}", "bool"

    x_asless_comparison = x_comparison

    @staticmethod
    def is_null(n):
        while is_tree(n, "expr"):
            n = n.children[0]
        return isinstance(n, Token) and str(n) == "null"

    def x_content_test(self, n, expect):
        left, _ = self.ex(n.children[0])
        right, _ = self.ex(n.children[2])
        negated = is_tree(n.children[1], "not_in_op")
        return f"{'!' if negated else ''}Gd.In({left}, {right})", "bool"

    x_asless_content_test = x_content_test

    def logic(self, n, op):
        parts = [self.cond(p) for p in n.children[0::2]]
        return f" {op} ".join(parts), "bool"

    def x_and_test(self, n, expect):
        return self.logic(n, "&&")

    x_asless_and_test = x_and_test

    def x_or_test(self, n, expect):
        code, ty = self.logic(n, "||")
        return f"({code})", ty

    x_asless_or_test = x_or_test

    def x_asless_actual_not_test(self, n, expect):
        inner = n.children[1]
        code = self.cond(inner)
        if re.fullmatch(r"[\w.@]+(\([^()]*\))?", code):
            return f"!{code}", "bool"
        return f"!({code})", "bool"

    def x_asless_actual_neg_expr(self, n, expect):
        code, ty = self.ex(n.children[1])
        return f"-{code}", ty

    def x_asless_actual_bitw_not(self, n, expect):
        code, ty = self.ex(n.children[1])
        return f"(~{code})", ty

    def x_test_expr(self, n, expect):
        a, aty = self.ex(n.children[0], expect)
        c = self.cond(n.children[2])
        b, bty = self.ex(n.children[4], expect)
        if a == "null":
            aty = bty
        if b == "null":
            bty = aty
        ty = aty if aty == bty else ("float" if {aty, bty} == {"int", "float"} else None)
        return f"({c} ? {a} : {b})", ty

    x_asless_test_expr = x_test_expr

    def x_actual_type_cast(self, n, expect):
        code, _ = self.ex(n.children[0])
        ty = self.canon(str(n.children[-1]))
        if ty in STRUCTS or ty in ("int", "float", "bool", "String", "Vector2"):
            return f"(({self.cs_type(ty)}){code})", ty
        if self.cs_type(ty).startswith("GArray"):
            return f"(({self.cs_type(ty)}){code})", ty
        return f"({code} as {self.cs_type(ty)})", ty

    def x_type_test(self, n, expect):
        code, _ = self.ex(n.children[0])
        op = str(n.children[1])
        ty = self.canon(str(n.children[2]))
        test = f"Gd.Is<{self.cs_type(ty)}>({code})"
        return (f"!({test})" if "not" in op else test), "bool"

    x_asless_type_test = x_type_test

    def x_assnmnt_expr(self, n, expect):
        left, lty = self.ex(n.children[0])
        op = str(n.children[1])
        right, rty = self.ex(n.children[2], lty)
        if lty and rty and lty != rty and lty in self.p.classes and rty in self.p.classes:
            right = f"({self.cs_type(lty)})({right})"  # GDScript downcasts a base class on its own.
        return f"{left} {op} {right}", None

    # ---------- statements ----------
    def block_stmts(self, stmts):
        for s in stmts:
            self.stmt(s)

    def block(self, stmts):
        self.w("{")
        self.ind += 1
        self.push()
        self.block_stmts(stmts)
        self.pop()
        self.ind -= 1
        self.w("}")

    def stmt(self, s):
        if s is None or is_tree(s, "annotation"):
            return
        self.flush_comments(line_of(s))
        getattr(self, "s_" + str(s.data))(s)

    def s_pass_stmt(self, s):
        pass

    def s_break_stmt(self, s):
        self.w("break;")

    def s_continue_stmt(self, s):
        self.w("continue;")

    def s_expr_stmt(self, s):
        node = s.children[0]
        while is_tree(node, "expr"):
            node = node.children[0]
        if is_tree(node, "assnmnt_expr") and self.struct_in_subscript(node):
            return
        code, _ = self.ex(node)
        if is_tree(node, "par_expr"):
            code = code[1:-1]  # a C# statement cannot be wrapped in parentheses
        self.w(code + ";")

    def struct_in_subscript(self, node):
        """arr[i].x = v writes back in GDScript; a C# indexer hands out a copy."""
        left = node.children[0]
        if not is_tree(left, "getattr"):
            return False
        base, attrs = self.chain(left)
        if not is_tree(base, "subscr_expr"):
            return False
        holder, hty = self.ex(base)
        if hty not in STRUCTS:
            return False
        self.temp += 1
        temp = f"held{self.temp}"
        code = temp
        ty = hty
        for attr in attrs:
            code, ty = self.member(code, ty, attr)
        right, _ = self.ex(node.children[2], ty)
        self.w(f"var {temp} = {holder};")
        self.w(f"{code} {node.children[1]} {right};")
        self.w(f"{holder} = {temp};")
        return True

    def s_return_stmt(self, s):
        if not s.children or s.children[0] is None:
            self.w("return default(Variant);" if self.in_lambda else "return;")
            return
        code, _ = self.ex(s.children[0], self.fn_ret)
        self.w(f"return {code};")

    def s_func_var_stmt(self, s):
        decl = s.children[0]
        name = str(decl.children[0])
        kind = decl.data
        if kind == "func_var_typed":
            ty = self.canon(str(decl.children[1]))
            cs = self.declare(name, ty)
            self.w(f"{self.cs_type(ty)} {cs} = {self.default_of(ty)};")
        elif kind == "func_var_typed_assgnd":
            ty = self.canon(str(decl.children[1]))
            code, _ = self.ex(decl.children[2], ty)
            cs = self.declare(name, ty)
            self.w(f"{self.cs_type(ty)} {cs} = {code};")
        elif kind == "func_var_inf":
            code, ty = self.ex(decl.children[1])
            if ty and (ty.startswith("class:") or ty.startswith("enum:")):
                ty = None
            cs = self.declare(name, ty)
            explicit = ty in ("int", "float", "Array", "Dictionary")
            self.w(f"{self.cs_type(ty) if explicit else 'var'} {cs} = {code};")
        elif kind == "func_var_assigned":
            code, _ = self.ex(decl.children[1], "Variant")
            cs = self.declare(name, "Variant")
            self.w(f"Variant {cs} = {code};")
        else:
            cs = self.declare(name, "Variant")
            self.w(f"Variant {cs} = default;")

    def s_const_stmt(self, s):
        decl = s.children[0]
        name = str(decl.children[0])
        hint = str(decl.children[1]) if decl.data == "const_typed_assigned" else None
        code, ty = self.ex(decl.children[-1], hint)
        ty = self.canon(hint) if hint else ty
        cs = self.declare(name, ty)
        self.w(f"{self.cs_type(ty)} {cs} = {code};")

    def s_if_stmt(self, s):
        first = True
        for branch in s.children:
            if branch is None:
                continue
            if branch.data == "else_branch":
                self.w("else")
                self.block(branch.children)
                continue
            word = "if" if first else "else if"
            self.w(f"{word} ({self.cond(branch.children[0])})")
            self.block(branch.children[1:])
            first = False

    def s_while_stmt(self, s):
        self.w(f"while ({self.cond(s.children[0])})")
        self.block(s.children[1:])

    def iterable(self, node):
        inner = node
        while is_tree(inner, "expr"):
            inner = inner.children[0]
        code, ty = self.ex(inner)
        if ty == "int" or ty == "float":
            return f"Gd.Range({code})"
        if ty and (ty.startswith("Array") or ty in PACKED or ty == "Dictionary"):
            return code
        if is_tree(inner, "standalone_call") and str(inner.children[0]) == "range":
            return code
        return f"Gd.Iter({code})"

    def s_for_stmt(self, s):
        self.loop(str(s.children[0]), None, s.children[1], s.children[2:])

    def s_for_stmt_typed(self, s):
        self.loop(str(s.children[0]), str(s.children[1]), s.children[2], s.children[3:])

    def loop(self, name, hint, source, body):
        it = self.iterable(source)
        ty = self.canon(hint) if hint else None
        self.push()
        cs = self.declare(name, ty)
        writes = any(self.assigns(b, name) for b in body)
        ctype = self.cs_type(ty) if ty else "var"
        held = f"{cs}Held" if writes else cs
        self.w(f"foreach ({ctype} {held} in {it})")
        self.w("{")
        self.ind += 1
        if writes:
            self.w(f"{ctype} {cs} = {held};")
        self.push()
        self.block_stmts(body)
        self.pop()
        self.ind -= 1
        self.w("}")
        self.pop()

    def assigns(self, node, name):
        if not isinstance(node, Tree):
            return False
        if node.data == "assnmnt_expr":
            left = node.children[0]
            if isinstance(left, Token) and str(left) == name:
                return True
        return any(self.assigns(k, name) for k in node.children)

    def s_match_stmt(self, s):
        self.temp += 1
        temp = f"matched{self.temp}"
        code, ty = self.ex(s.children[0])
        self.w(f"var {temp} = {code};")
        first = True
        for branch in s.children[1:]:
            pattern, body = branch.children[0], branch.children[1:]
            test = self.pattern(pattern, temp)
            if test is None:
                if first:
                    self.block(body)
                else:
                    self.w("else")
                    self.block(body)
                break
            self.w(f"{'if' if first else 'else if'} ({test})")
            self.block(body)
            first = False

    def pattern(self, pattern, temp):
        node = pattern.children[0]
        items = node.children if is_tree(node, "list_pattern") else [node]
        tests = []
        for item in items:
            if is_tree(item, "wildcard_pattern"):
                return None
            tests.append(f"{temp} == {self.pattern_value(item)}")
        return " || ".join(tests)

    def pattern_value(self, item):
        if is_tree(item, "attr_pattern"):
            parts = [str(p) for p in item.children if str(p) != "."]
            code, ty = self.name(parts[0])
            for attr in parts[1:]:
                code, ty = self.member(code, ty, attr)
            return code
        return self.ex(item)[0]

    # ---------- class members ----------
    def params(self, m):
        """C# parameter list, or the overloads a non-literal default needs."""
        out = []
        for p in m.params:
            ty = self.param_type(p)
            out.append((ty, camel(p.name), p))
        return out

    def param_type(self, p):
        if p.type:
            return self.canon(p.type)
        return self.ex(p.default)[1]

    @staticmethod
    def literal_default(node):
        while is_tree(node, "expr"):
            node = node.children[0]
        if isinstance(node, Token):
            return node.type in ("NUMBER", "HEX", "BIN") or str(node) in ("true", "false", "null")
        return is_tree(node, "string") or (
            is_tree(node, "asless_actual_neg_expr") and isinstance(node.children[1], Token)
        )

    def emit_method(self, m, node, static):
        name = m.name
        self.func_name = name
        params = self.params(m)
        all_literal = all(p.default is None or self.literal_default(p.default) for _, _, p in params)
        self.push()
        decls = []
        for ty, cs, p in params:
            self.scopes[-1].names[p.name] = (cs, ty)
            text = f"{self.cs_type(ty)} {cs}"
            if p.default is not None and all_literal:
                value, _ = self.ex(p.default, ty)
                if ty == "float" and re.fullmatch(r"-?\d+", value):
                    value += ".0"
                text += f" = {value}"
            decls.append(text)
        sig = ", ".join(decls)
        self.fn_ret = self.canon(m.ret) if m.ret else "Variant"
        body = node.children[1:]
        if name == "_init":
            self.emit_ctor(sig, body, params, all_literal)
        else:
            mods = "public static" if static else "public"
            if not static:
                base = self.p.base_of(self.cls)
                if base and self.method_of(base.name, name):
                    mods += " override"
                elif name in self.cls.subclassed:
                    mods += " virtual"
            self.w(f"{mods} {self.cs_type(self.fn_ret)} {pascal(name)}({sig})")
            written = REWRITTEN.get((self.cls.name, name))
            if written:
                self.w("{")
                self.ind += 1
                for line in written.splitlines():
                    self.w(line)
                self.ind -= 1
                self.w("}")
            else:
                self.block_stmts_braced(body)
            if not all_literal:
                self.overloads(m, params, mods.replace(" virtual", "").replace(" override", ""))
        self.pop()

    def block_stmts_braced(self, body):
        self.w("{")
        self.ind += 1
        self.push()
        self.block_stmts(body)
        self.pop()
        self.ind -= 1
        self.w("}")

    def overloads(self, m, params, mods):
        first = next(i for i, (_, _, p) in enumerate(params) if p.default is not None)
        for keep in range(len(params) - 1, first - 1, -1):
            sig = ", ".join(f"{self.cs_type(t)} {c}" for t, c, _ in params[:keep])
            passed = [c for _, c, _ in params[:keep]]
            passed += [self.ex(p.default, t)[0] for t, _, p in params[keep:]]
            call = f"{pascal(m.name)}({', '.join(passed)})"
            self.w(
                f"{mods} {self.cs_type(self.fn_ret)} {pascal(m.name)}({sig}) => {call};"
            )

    def emit_ctor(self, sig, body, params, all_literal):
        short = self.cls.short
        chain = ""
        stmts = list(body)
        if stmts and is_tree(stmts[0], "expr_stmt"):
            node = stmts[0].children[0]
            while is_tree(node, "expr"):
                node = node.children[0]
            if is_tree(node, "standalone_call") and str(node.children[0]) == "super":
                chain = f" : base({self.args(kids(node)[1:])})"
                stmts = stmts[1:]
        self.w(f"public {short}({sig}){chain}")
        self.w("{")
        self.ind += 1
        self.w("_InitFields();")
        self.push()
        self.block_stmts(stmts)
        self.pop()
        self.ind -= 1
        self.w("}")
        if not all_literal:
            first = next(i for i, (_, _, p) in enumerate(params) if p.default is not None)
            for keep in range(len(params) - 1, first - 1, -1):
                sig2 = ", ".join(f"{self.cs_type(t)} {c}" for t, c, _ in params[:keep])
                passed = [c for _, c, _ in params[:keep]]
                passed += [self.ex(p.default, t)[0] for t, _, p in params[keep:]]
                self.w(f"public {short}({sig2}) : this({', '.join(passed)}) {{ }}")

    def uses_instance(self, node):
        if isinstance(node, Token):
            if node.type != "NAME":
                return False
            text = str(node)
            if text == "self":
                return True
            field = self.here_field(text)
            if field and not field[3]:
                return True
            method = self.here_method(text)
            return bool(method and not method[1].static)
        if isinstance(node, Tree):
            if node.data in ("getattr",):
                return self.uses_instance(node.children[0])
            if node.data == "getattr_call":
                return any(self.uses_instance(k) for k in node.children)
            return any(self.uses_instance(k) for k in node.children if k is not None)
        return False

    def emit_field(self, name, hint, decl, static, prologue):
        cs = camel(name)
        mods = "public static" if static else "public"
        children = decl.children
        value = None
        if decl.data == "class_var_typed_assgnd":
            value = children[2]
        elif decl.data == "class_var_inf":
            value = children[1]
        elif decl.data == "class_var_assigned":
            value = children[1]
        ty = self.field_type(self.cls.name, name)
        if ty is None and decl.data in ("class_var_empty", "class_var_assigned"):
            ty = "Variant"
        if ty is None:
            raise SystemExit(f"{self.cls.path}: cannot infer type of var {name}")
        ctype = self.cs_type(ty)
        if value is None:
            default = self.default_of(ty)
            if default == "default" or default == "null":
                self.w(f"{mods} {ctype} {cs};")
            else:
                self.w(f"{mods} {ctype} {cs} = {default};")
            return
        if not static and self.uses_instance(value):
            self.w(f"{mods} {ctype} {cs};")
            prologue.append((cs, value, ty))
            return
        self.push()
        code, _ = self.ex(value, ty)
        self.pop()
        if code == "null" and ctype == "Variant":
            code = "default"
        self.w(f"{mods} {ctype} {cs} = {code};")

    def emit_property(self, name, hint, decl, body, static):
        cs = camel(name)
        ty = self.canon(hint)
        mods = "public static" if static else "public"
        self.w(f"{mods} {self.cs_type(ty)} {cs}")
        self.w("{")
        self.ind += 1
        for part in body.children:
            if part.data == "property_custom_getter":
                self.w("get")
                self.fn_ret = ty
                stmts = [k for k in part.children if is_tree(k, *STATEMENTS)]
                self.block_stmts_braced(stmts)
            elif part.data == "property_custom_setter":
                self.w("set")
                self.push()
                self.scopes[-1].names[str(part.children[1])] = ("value", ty)
                self.fn_ret = "void"
                stmts = [k for k in part.children if is_tree(k, *STATEMENTS)]
                self.block_stmts_braced(stmts)
                self.pop()
        self.ind -= 1
        self.w("}")

    def emit_enum(self, name, body):
        elements = [e for e in kids(body) if is_tree(e, "enum_element")]
        if name:
            self.w(f"public static class {name}")
            self.w("{")
            self.ind += 1
        value = 0
        for e in elements:
            if len(e.children) > 1 and e.children[1] is not None:
                value = int(str(self.ex(e.children[1])[0]).rstrip("L"), 0)
            self.w(f"public const long {e.children[0]} = {value};")
            value += 1
        if name:
            self.ind -= 1
            self.w("}")

    def emit_const(self, name, hint, value):
        ty = self.canon(hint) if hint else self.const_type(self.cls.name, name)
        if ty is None:
            raise SystemExit(f"{self.cls.path}: cannot infer type of const {name}")
        code, _ = self.ex(value, ty)
        simple = ty in ("int", "float", "bool", "String") and not self.has_call(value)
        word = "const" if simple else "static readonly"
        self.w(f"public {word} {self.cs_type(ty)} {name} = {code};")

    def has_call(self, node):
        if isinstance(node, Tree):
            if node.data in ("standalone_call", "getattr_call"):
                return True
            return any(self.has_call(k) for k in node.children if k is not None)
        return False

    def emit_class(self):
        info = self.cls
        base = info.base or "RefCounted"
        self.w(f"public class {info.short} : {base}")
        self.w("{")
        self.ind += 1
        self.w(f"public static implicit operator {info.short}(Variant v) => ({info.short})v.Obj;")
        self.w("")
        prologue = []
        members = kids(info.tree)
        i = 0
        while i < len(members):
            kid = members[i]
            i += 1
            if not isinstance(kid, Tree):
                continue
            if kid.data in ("classname_stmt", "extends_stmt", "annotation", "pass_stmt"):
                continue
            self.flush_comments(line_of(kid))
            if kid.data in ("class_var_stmt", "static_class_var_stmt"):
                decl = kid.children[0]
                static = kid.data == "static_class_var_stmt"
                if decl.data == "class_var_stmt":
                    decl = decl.children[0]
                name = str(decl.children[0])
                hint = str(decl.children[1]) if decl.data.startswith("class_var_typed") else None
                if i < len(members) and is_tree(members[i], "property_body_def"):
                    self.emit_property(name, hint, decl, members[i], static)
                    i += 1
                else:
                    self.emit_field(name, hint, decl, static, prologue)
            elif kid.data == "const_stmt":
                decl = kid.children[0]
                name = str(decl.children[0])
                if name in info.aliases:
                    continue
                hint = str(decl.children[1]) if decl.data == "const_typed_assigned" else None
                self.emit_const(name, hint, decl.children[-1])
            elif kid.data == "enum_stmt":
                decl = kid.children[0]
                if decl.data == "enum_named":
                    self.emit_enum(str(decl.children[0]), decl.children[-1])
                else:
                    self.emit_enum(None, decl.children[-1])
            elif kid.data in ("func_def", "static_func_def"):
                self.w("")
                static = kid.data == "static_func_def"
                fn = kid.children[0] if static else kid
                m = info.methods[str(fn.children[0].children[0])]
                self.emit_method(m, fn, static)
            elif kid.data == "class_def":
                self.w("")
                inner = info.inner[str(kid.children[0])]
                sub = Emitter.__new__(Emitter)
                sub.__dict__.update(self.__dict__)
                sub.cls = inner
                sub.scopes = []
                sub.out = self.out
                sub.emit_class()
                self.next_comment = sub.next_comment
                self.temp = sub.temp
            else:
                raise SystemExit(f"{info.path}:{line_of(kid)}: no rule for member {kid.data}")
        self.w("")
        base_info = self.p.base_of(info)
        new = "new " if base_info else ""
        self.w(f"{new}void _InitFields()")
        self.w("{")
        self.ind += 1
        self.push()
        for cs, value, ty in prologue:
            code, _ = self.ex(value, ty)
            self.w(f"{cs} = {code};")
        self.pop()
        self.ind -= 1
        self.w("}")
        if "_init" not in info.methods:
            self.default_ctors(info)
        self.ind -= 1
        self.w("}")

    def default_ctors(self, info):
        got = self.method_of(info.base, "_init") if info.base else None
        if got and got[1].params:
            owner, m = got
            sub = Emitter.__new__(Emitter)
            sub.__dict__.update(self.__dict__)
            sub.cls = owner
            sub.scopes = [Scope()]
            sig = ", ".join(f"{sub.cs_type(sub.param_type(p))} {camel(p.name)}" for p in m.params)
            names = ", ".join(camel(p.name) for p in m.params)
            self.w(f"public {info.short}({sig}) : base({names}) {{ _InitFields(); }}")
        else:
            self.w(f"public {info.short}() {{ _InitFields(); }}")


BINARY = {
    "arith_expr", "asless_arith_expr", "mdr_expr", "asless_mdr_expr", "shift_expr",
    "asless_shift_expr", "bitw_or", "asless_bitw_or", "bitw_xor", "asless_bitw_xor", "bitw_and",
    "asless_bitw_and",
}
BOOL_NODES = {
    "comparison", "asless_comparison", "and_test", "asless_and_test", "or_test", "asless_or_test",
    "asless_actual_not_test", "content_test", "asless_content_test", "type_test",
    "asless_type_test",
}
STATEMENTS = {
    "pass_stmt", "return_stmt", "func_var_stmt", "break_stmt", "continue_stmt", "expr_stmt",
    "const_stmt", "if_stmt", "while_stmt", "for_stmt", "for_stmt_typed", "match_stmt",
}


def captured_writes(project):
    """GDScript lambdas copy the locals they capture; C# shares them. Lists the locals where that
    could differ: written inside the lambda, or after it in the same function."""
    found = []

    def assigned(node, out):
        if isinstance(node, Tree):
            if node.data == "assnmnt_expr" and isinstance(node.children[0], Token):
                out.append((str(node.children[0]), line_of(node)))
            for k in node.children:
                assigned(k, out)

    def names(node, out):
        if isinstance(node, Token) and node.type == "NAME":
            out.add(str(node))
        elif isinstance(node, Tree):
            for k in node.children:
                names(k, out)

    def lambdas(node, out):
        if isinstance(node, Tree):
            if node.data == "lambda":
                out.append(node)
            for k in node.children:
                lambdas(k, out)

    def locals_of(node, out):
        if isinstance(node, Tree):
            if node.data.startswith("func_var_") and node.data != "func_var_stmt":
                out.add(str(node.children[0]))
            if node.data.startswith("for_stmt"):
                out.add(str(node.children[0]))
            if node.data.startswith("func_arg_"):
                out.add(str(node.children[0]))
            for k in node.children:
                locals_of(k, out)

    for info in project.classes.values():
        for m in info.methods.values():
            found_lambdas = []
            lambdas(m.node, found_lambdas)
            for lam in found_lambdas:
                used = set()
                names(lam, used)
                outer_locals = set()
                locals_of(m.node, outer_locals)
                inner_locals = set()
                locals_of(lam, inner_locals)
                captured = (used & outer_locals) - inner_locals
                writes = []
                assigned(m.node, writes)
                start = line_of(lam)
                for name, at in writes:
                    if name in captured and at >= start:
                        found.append(f"{info.path}:{at}: lambda captures {name}, written at/after")
    return found


def generate(paths):
    project = Project(paths)
    files = {}
    for info in project.top:
        emitter = Emitter(project, info)
        emitter.emit_class()
        emitter.flush_comments(10**9)
        source = os.path.basename(info.path)
        body = "\n".join(emitter.out)
        files[f"{info.short}.cs"] = (
            f"// Generated from sim/{source} by tools/unity/gd2cs.py; do not edit until the switch"
            f" (D-470 U6).\n// See Sim/Runtime for what the types below mean.\n"
            f"namespace Kaiju.Sim\n{{\n" + indent(body) + "\n}\n"
        )
    return files, captured_writes(project)


def indent(text):
    return "\n".join(("    " + line) if line else "" for line in text.split("\n"))


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--check", action="store_true", help="fail when the output on disk is stale")
    opts = args.parse_args()
    paths = [p for p in sorted(glob.glob("sim/*.gd")) if os.path.basename(p) not in SKIP]
    files, notes = generate([p.replace("\\", "/") for p in paths])
    for note in notes:
        print("review:", note)
    if opts.check:
        stale = []
        for name, text in files.items():
            path = os.path.join(OUT, name)
            if not os.path.exists(path) or open(path, encoding="utf-8").read() != text:
                stale.append(name)
        if stale:
            print("stale:", " ".join(stale))
            return 1
        print(f"{len(files)} files current")
        return 0
    os.makedirs(OUT, exist_ok=True)
    for name, text in files.items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print(f"{len(files)} files written, {sum(t.count(chr(10)) for t in files.values())} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
