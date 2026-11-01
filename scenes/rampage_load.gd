class_name RampageLoad
extends RefCounted
## The rampage's staged load before the kaiju (Rampage._ready): the sim, then the city.


## The sim (on a worker if setup_later) and then the city, a frame at a time when staged; false
## when the rampage left the tree first (the load stops).
static func sim_and_city(r: Rampage, stages: BuildStages) -> bool:
	if r.sim == null:  # setup_later: the sim builds on a worker, the loading screen draws
		r._build = SimOnWorker.new(r._later)
		if not await r._build.wait(r, stages):
			return false
		r._take_sim(r._build.take())
		r._build = null
	r._city = CityView.new(r.sim, r._fx_rng)
	r._city.stages = stages
	r.add_child(r._city)
	while not r._city.is_loaded:  # staged: the city builds itself over the next frames
		if not await stages.next(r, false):
			return false
	return true
