extends Node
# Simple behavior tree node definitions for demonstration.
class_name BT

class BTNode:
	func tick(actor: Node, delta: float) -> String:
		return "failure" # success, running, failure

class SelectorNode extends BTNode:
	var children: Array
	func _init(_children: Array = []):
		children = _children
	func tick(actor, delta):
		for c in children:
			var r = c.tick(actor, delta)
			if r == "success" or r == "running":
				return r
		return "failure"

class SequenceNode extends BTNode:
	var children: Array
	var current: int = 0
	func _init(_children: Array = []):
		children = _children
	func tick(actor, delta):
		while current < children.size():
			var r = children[current].tick(actor, delta)
			if r == "running":
				return "running"
			elif r == "failure":
				current = 0
				return "failure"
			current += 1
		if current >= children.size():
			current = 0
			return "success"
		return "running"

class ActionNode extends BTNode:
	var fn: Callable
	func _init(_fn: Callable):
		fn = _fn
	func tick(actor, delta):
		return fn.call(actor, delta)

class ConditionNode extends BTNode:
	var predicate: Callable
	func _init(_predicate: Callable):
		predicate = _predicate
	func tick(actor, delta):
		if predicate.call(actor):
			return "success"
		return "failure"
