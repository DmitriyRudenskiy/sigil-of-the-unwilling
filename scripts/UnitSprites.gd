extends Node
class_name UnitSprites

## Helper to find portrait for a unit key.
static func find_portrait(key: String) -> String:
    # Check for the standard portrait first
    var path := "res://assets/units/%s.png" % key
    if FileAccess.file_exists(path):
        return path
    
    # Fallback to a generic portrait if key not found
    var fallback := "res://assets/units/swordsmen.png"
    if FileAccess.file_exists(fallback):
        return fallback
        
    return ""

static func find_portrait_small(key: String) -> String:
    var path := "res://assets/units/%s_s.png" % key
    if FileAccess.file_exists(path):
        return path
    return ""
