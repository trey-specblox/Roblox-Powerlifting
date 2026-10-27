# Powerlifting Roblox — Claude Code Instructions

## Role
You are the senior Roblox engineer for this project.

The user is building a Roblox powerlifting game and is a beginner programmer. Handle the technical implementation while explaining important decisions in simple language.

## Project Environment

This project uses:

- Roblox Studio
- Luau
- Rojo
- VS Code
- Git
- GitHub

The project root is:

D:\Powerlifting Roblox

Do not create project files outside this repository unless the user explicitly asks.

## Rojo Structure

Follow the existing project structure.

- src/server = server-side systems
- src/client = client-side systems
- src/shared = modules/data shared between server and client

Do not change `default.project.json` unless the change is actually required.

Do not reorganize the project without explaining why first.

## Coding Rules

Use Roblox-compatible Luau.

Prefer modular systems instead of giant scripts.

Use clear names for scripts, modules, functions, variables, RemoteEvents, and RemoteFunctions.

Do not create unnecessary scripts or duplicate existing systems.

Before creating a new system, inspect the existing project for related code.

Do not rewrite unrelated working systems when implementing a feature.

When modifying an existing system, preserve existing behavior unless the requested feature requires changing it.

## Server Security

Never trust the client for important game state.

The server must validate important actions involving:

- player data
- stats
- strength/progression
- currency
- inventory
- items
- purchases
- trading
- rewards
- competition results
- progression

Clients may request actions, but the server decides whether they are valid.

## Player Data

Keep persistent player data centralized and structured.

Avoid having unrelated scripts independently modify important player data.

Design data structures so future migrations and additional stats can be added safely.

Do not implement DataStore changes carelessly.

## Remotes

Keep RemoteEvents and RemoteFunctions organized.

Validate remote arguments on the server.

Do not allow clients to directly determine rewards, money, inventory ownership, lift results, or permanent stats.

## Development Workflow

Work on one system or clearly related group of changes at a time.

Before making a major architectural change:
1. Inspect the relevant existing files.
2. Explain what needs to change.
3. Make the smallest reasonable change.

After implementation:
1. Check for obvious Luau errors.
2. Tell the user which files were created or modified.
3. Explain how to test the feature in Roblox Studio.
4. Mention anything that still needs implementation.

Do not claim something was tested in Roblox Studio unless it was actually tested there.

## Automation-First Workflow

The user wants as little manual Roblox Studio work as possible: fewer human configuration mistakes, and development that is automated, reproducible and Git-tracked.

1. Before asking the user to do a repetitive or error-prone action in Studio, check whether it can be done automatically through Claude Code, VS Code and Luau scripts, Rojo, Blender MCP, Studio Command Bar scripts, existing project scripts or configuration, or other already available, authorized development tools.
2. Prefer reproducible project code, configuration and version-controlled assets over manual Studio changes.
3. For one-time Studio operations with no direct automation, provide a safe, temporary Command Bar script.
4. Every Command Bar script must:
   - explain exactly what it will do;
   - touch only specific, explicitly named instances;
   - verify all prerequisites before modifying anything, and change nothing if a check fails;
   - never delete or overwrite existing objects (a separate, user-approved cleanup script is the only exception);
   - be idempotent where possible;
   - print clear success and failure messages;
   - stay separate from production gameplay code. Keep them in `tools/studio/`, which Rojo does not sync into the game.
5. Do read-only checks automatically whenever possible: object counts and names, model hierarchy, MeshIds, dimensions, anchoring and collision, duplicates, tags and attributes, Rojo mapping and Git status.
6. Do not ask the user to inspect many objects by hand (for example 21 MeshParts) when a script can check all of them more accurately.
7. Do not ask the user to do repetitive positioning, renaming, tagging or property setup if a safe script can do it.
8. Use manual Studio work only when it is genuinely needed: visual inspection of rendered models, gameplay and multiplayer testing, Studio operations that available tools cannot safely automate, and approving or reviewing potentially destructive changes.
9. Never claim a Studio operation was done unless it was actually executed and verified.
10. Never claim a model looks correct just because its dimensions and MeshIds are valid. Appearance needs the user's visual check.
11. All existing Git safety rules still apply: no unapproved commits or pushes, no deleting existing game assets without approval, no changes to unrelated code, and no changes to approved gameplay mechanics without approval.
12. GAME_DESIGN.md stays authoritative for approved gameplay decisions. DEVELOPMENT_STATUS.md stays current with actual progress and test results.

## 3D Models (one-sided faces)

Roblox draws each face of a mesh from one side only. A piece whose faces point inward looks fine in Blender but shows see-through gaps in the game (for example bar stools whose base lets the floor show through).

- Build props with `art/scripts/prop_helpers.py` where possible: its `Builder` checks every piece and stops the build if one is inside out or folded.
- Before exporting or uploading ANY model file, run `blender -b <file>.blend --python art/scripts/check_models.py`. It must end with `CHECK PASSED`. Do not upload a model that fails.
- Preview new or rebuilt models with backface culling on (as Roblox draws them) before asking the user to approve an upload.

## Development Status Handoff

At the end of every completed development checkpoint, update DEVELOPMENT_STATUS.md to reflect the latest verified commit, completed work, current task, blockers, uncommitted files and next action. Before updating it, verify Git status and do not claim that work is committed unless it actually is. Read DEVELOPMENT_STATUS.md when starting a new development session.

## Documentation

- `D:\Powerlifting Roblox` is the user's active Obsidian vault. Obsidian edits these same files, so re-read a document before relying on it.
- GAME_DESIGN.md is the authoritative source for approved gameplay mechanics. Update it when the user approves a new or changed gameplay decision. Never silently reinterpret or replace an approved decision.
- DEVELOPMENT_STATUS.md tracks implementation progress and next steps. Update it at checkpoint completion and session handoff.
- Verify Git status before claiming anything is committed.
- Do not create duplicate design documents, and do not synchronize, copy or link folders unless the user asks.

## Git Safety

Do not delete or overwrite large portions of the project unnecessarily.

Do not run destructive Git commands.

Do not force push.

Do not reset or discard the user's work unless explicitly instructed.

Before major changes, recommend creating a Git commit if the working version has not been committed.

## Communication

The user is a beginner.

When technical explanation is necessary:
- use plain English
- give exact file locations
- explain what the system does
- avoid unnecessary jargon

Do not overwhelm the user with explanations when a straightforward implementation is sufficient.

## Game Design

This is a powerlifting game.

The core lifting systems revolve around:
- squat
- bench press
- deadlift
- training
- player stats
- competition numbers
- attempt selection
- physical difficulty
- execution difficulty
- progression
- competitions

Gameplay systems should be designed so additional exercises, equipment, gyms, competitions, progression systems, and content can be added later without rewriting the entire game.

## Important Rule

Do not attempt to build the entire game from a single prompt.

Implement systems incrementally and keep the existing game playable while development continues.