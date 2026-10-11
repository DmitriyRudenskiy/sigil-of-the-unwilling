# Spec Delta

## REMOVED Requirements

### Requirement: Репутация как победа
**Reason**: Reputation as the settlement victory meter is source-game behavior and conflicts with the campaign's stated end condition and Sign Prestige ledger.
**Migration**: Do not create a settlement-reputation victory path. Campaign outcomes remain owned by campaign progression and pressure/raid rules.

### Requirement: Враждебность леса и glade
**Reason**: The Forest Hostility/glade loop is a separate source-game threat model and would duplicate the campaign's state-based pressure system.
**Migration**: City threats use the canonical pressure accumulator, region history, and raid-source rules. Map nodes remain campaign-map content.

### Requirement: Штормы
**Reason**: The source-game storm-as-Resolve damage model would create a second threat clock and city-wellbeing rule.
**Migration**: Environmental pressure is resolved through campaign seasons/pressure and existing city/raid effects; any adapted storm building interaction must be expressed as a deterministic city modifier.

### Requirement: Prestige-уровни
**Reason**: Source-game difficulty Prestige levels are unrelated to the canonical Sign Prestige and are a naming/mechanics collision.
**Migration**: Campaign Sign Prestige remains the only Prestige system. Difficulty modifiers, if designed later, require a separate capability and shall not be attached to this settlement system.

### Requirement: Условия поражения
**Reason**: The former standalone settlement run's extinction/instability defeat conditions do not define campaign victory or defeat.
**Migration**: Campaign defeat remains governed by campaign party and city stock/raid rules; resident attrition can be added only as an explicit campaign behavior.

## ADDED Requirements

### Requirement: Campaign raid pressure remains the only city raid clock
City raids SHALL be generated and paced by the canonical campaign pressure system. Building and population effects MAY modify declared pressure inputs or defense values but SHALL NOT schedule raids by fixed settlement cycles or a separate Hostility meter.

#### Scenario: Building changes raid pressure
- **WHEN** a city building or population effect modifies a configured pressure input
- **THEN** the pressure system receives the explicit deterministic modifier
- **AND** the source is available in the raid explanation

#### Scenario: City turn without pressure threshold
- **WHEN** a campaign city turn resolves and the pressure accumulator has not crossed a configured threshold
- **THEN** no raid is generated solely because a source-game storm or calendar trigger fired

### Requirement: Satisfaction and Sign Prestige remain separate
City group satisfaction SHALL NOT award, spend, or store Sign Prestige unless a separately authorized Sign rule explicitly defines such a transaction.

#### Scenario: High satisfaction
- **WHEN** all city groups have high satisfaction
- **THEN** only the declared city and population effects occur
- **AND** Sign Prestige is unchanged absent an eligible Sign event
