def is_3:
	env.version
	| startswith("3")
;
def minor:
	env.version
	| split(".")[1]
	| tonumber
;
