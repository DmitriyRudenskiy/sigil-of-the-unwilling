# Knowledge Graph & Data Relationships

This document explains how we use **Graphify** to manage the complex relationships within the project's data and code.

## Why a Knowledge Graph?
As the project grows, it becomes difficult to track how different systems interact (e.g., how a specific spell interacts with a biome-specific resource). Instead of searching through dozens of files (Grepping), we use a **Knowledge Graph** to visualize and query these connections.

## Key Capabilities
1. **Traceability**: If a change is made to the `SpellCaster` system, we can instantly see which `Resource` types or `Biomes` are affected.
2. **Discovery**: New developers can use `graphify query` to ask questions like:
   - *"What connects the Water biome to the Swamp biome?"*
   - *"What are the dependencies for the HeroInventory?"*
3. **Rationale Tracking**: By extracting `# NOTE:` and `# WHY:` comments from our scripts, the graph stores the *intent* behind the code, not just the code itself.

## Integration Workflow
1. **Extraction**: Run `/graphify .` to parse the codebase, `.md` files, and PDF/image assets.
2. **Persistence**: The resulting `graph.json` is stored in `graphify-out/` and serves as the primary source for AI-assisted queries.
3. **Querying**: Use the CLI to perform:
   - `graphify explain <Concept>`: Get a summary of a specific system.
   - `graphify path <A> <B>`: Find the shortest path of dependencies between two objects.
   - `graphify query "<Question>"`: Get a scoped subgraph based on natural language.

## Data Integrity
- **EXTRACTED**: Connections found directly in the source code (e.g., imports, explicit references).
- **INFERRED**: Connections resolved by Graphify's resolution engine (e.g., a function call that implies a dependency).
- **AMBIGUOUS**: Connections with low confidence that require manual verification.
