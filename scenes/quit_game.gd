class_name QuitGame
extends RefCounted
## Leaving the game (b2-29: quitting froze the last frame on screen for 2-3 seconds while the
## engine freed the city). The window goes first, so the player sees the game close at once and
## the teardown runs unseen behind it.


## Hides the window, then quits. The title's and the end card's QUIT buttons and the window's
## own close request (Alt+F4, the X) all come here.
static func now(tree: SceneTree) -> void:
	tree.root.hide()
	tree.quit()
