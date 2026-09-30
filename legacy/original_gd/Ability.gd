The user wants to add several specialized classes and abilities. Since `Ability.gd` is the base class for all abilities, the specific logic for "The Cartographer", "The Chrono-Stitcher", etc., belongs in specialized `Ability` child scripts (e.g., `TerrainAbility.gd`, `TimeAbility.gd`) rather than the base class itself.

However, to support the complex interactions described (like swapping tiles, altering turn orders, or reflecting spells), the base `Ability` class needs a more flexible resolution signature. Currently, `resolve` only returns a `float` and takes a single `target`. Complex abilities need to target multiple tiles, handle coordinate swaps, and interact with the `CombatManager` or `Grid`.

I will update the `resolve` method and the `Ability` definition to allow for more complex interactions, enabling the specialized subclasses to implement the requested mechanics.

<<<PSEDIT name="Ability.gd" note="Updating resolve signature and adding support for complex targets to enable the new specialized class mechanics.">>>