class_name ConvoyRoute
extends RefCounted
## A tank's route and drive state (Convoy, D-066): one per tank, by id, in Convoy.routes.

var path: Array[Vector2] = []  # waypoints still to drive, the post last
var edges: Array[int] = []  # the road each leg runs along (-1: off the plan)
var goal := Vector2(INF, INF)
var reserve := false  # its post is a reserve post, out of range
var edge := -1  # the road it is on now
var column := -1
var replan_t := 0.0
var stuck_t := 0.0
var skip: Dictionary = {}  # roads it was held up on: left out of its next plan
var retreating := false
var give_to := -1  # an older tank it is backing up for
var yield_t := 0.0
var yield_all := 0.0  # how long it has been giving way this time
var heading := Vector2.ZERO  # the way it last drove
var front := Vector2.ZERO  # where its hull points: the pose the view draws
var reversing := false  # backing off with its front still to the kaiju


## At its next waypoint: on to the one after.
func arrive() -> void:
	path.remove_at(0)
	edges.remove_at(0)
	retreating = retreating and not path.is_empty()
