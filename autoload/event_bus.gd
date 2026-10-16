extends Node
## Cross-screen signals. Sim code never touches this; presentation and flow do.

@warning_ignore("unused_signal")
signal run_started(species_id: String)
@warning_ignore("unused_signal")
signal run_ended(result: Dictionary)
@warning_ignore("unused_signal")
signal upgrade_bought(id: String)
