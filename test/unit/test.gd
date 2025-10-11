extends SceneTree

func _init():
    var media_keys = MediaKeys.new()
    add_child(media_keys)
    print("MediaKeys node added")
    quit()
