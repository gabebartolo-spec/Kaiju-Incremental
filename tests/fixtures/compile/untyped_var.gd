extends RefCounted
## Deliberately broken: an untyped declaration. With the project's typing warnings
## set to errors this must fail to parse (tools/test_run_tests.sh checks it does).
## The .gdignore beside it keeps the editor and the smoke suite from loading it.

var hit_points = 10
