extends Node
## Planted defect for tools/lint/thread_resources.py: a group task's bound method reaches a helper
## that makes an ImageTexture, two calls down.

var _images: Array[Image] = []


func start() -> int:
	return WorkerThreadPool.add_group_task(_build_one.bind(3), 8)


func _build_one(n: int) -> void:
	_images.append(_make(n))


func _make(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_R8)
	_dress(img)
	return img


func _dress(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)
