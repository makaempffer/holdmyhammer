extends Object

class_name CraftedItem

var name: String
var item_type: String
var damage: int
var durability: int
var quality: float

func _init(name: String, item_type: String, damage: int, durability: int, quality: float):
	self.name = name
	self.item_type = item_type
	self.damage = damage
	self.durability = durability
	self.quality = quality
