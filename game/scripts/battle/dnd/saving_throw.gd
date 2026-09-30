class_name DNDSavingThrow

## D&D 5e Saving Throw System
# A d20 roll plus an ability modifier (and proficiency if the creature is
# proficient). Compared against a DC. Natural 20 always succeeds, natural 1
# always fails.

enum ThrowResult {
	FAILURE,
	SUCCESS,
	CRITICAL_SUCCESS,
	CRITICAL_FAILURE
}

class SaveResult:
	var result: ThrowResult = ThrowResult.FAILURE
	var d20: int = 0
	var total: int = 0
	var dc: int = 0


## Roll a saving throw.
## p_ability_mod: the relevant ability modifier.
## p_proficient: adds the proficiency bonus.
## p_dc: target DC.
static func roll(
	rng: RandomNumberGenerator,
	p_ability_mod: int,
	p_proficiency: int,
	p_proficient: bool,
	p_dc: int,
	p_d20: int = 0
) -> SaveResult:
	var r := SaveResult.new()
	r.dc = p_dc
	r.d20 = p_d20 if p_d20 > 0 else rng.randi_range(1, 20)
	var prof := p_proficiency if p_proficient else 0
	r.total = r.d20 + p_ability_mod + prof

	if r.d20 == 20:
		r.result = ThrowResult.CRITICAL_SUCCESS
	elif r.d20 == 1:
		r.result = ThrowResult.CRITICAL_FAILURE
	elif r.total >= p_dc:
		r.result = ThrowResult.SUCCESS
	else:
		r.result = ThrowResult.FAILURE
	return r


## Standard DC formula: 8 + proficiency + ability mod + situational bonus.
static func calculate_dc(p_proficiency: int, p_ability_mod: int, p_bonus: int = 0) -> int:
	return 8 + p_proficiency + p_ability_mod + p_bonus


## True for SUCCESS or CRITICAL_SUCCESS.
static func succeeded(r: SaveResult) -> bool:
	return r.result == ThrowResult.SUCCESS or r.result == ThrowResult.CRITICAL_SUCCESS
