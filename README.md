# Bedrock Shared Worlds

Use the same Minecraft Bedrock worlds on every account you sign in with on your Windows PC.

Nothing is copied. Each other account's worlds folder becomes a link to your main account's folder, so all accounts open the same worlds and it takes no extra disk space.

## Setup

1. Download `bedrock-shared-worlds.zip` from [Releases](../../releases/latest) and unzip it anywhere.
2. Make sure every account you want to use has signed in to Minecraft at least once.
3. Double-click `Share-Worlds.cmd`. It shows what it will change and asks before doing anything.

If Minecraft is open, it waits for you to close it. If Windows asks whether to run the file, choose Run.

## What gets shared

- `minecraftWorlds`
- `world_templates`
- `skin_packs`

Resource packs and behavior packs are already shared between accounts by Minecraft, so they don't need linking. Settings and custom skins stay separate for each account.

The main account is picked automatically (the one with the most worlds). Use `-MainId <folder name>` to pick it yourself.

## Options

Run these from a terminal, or pass them to `Share-Worlds.cmd`:

| Flag | What it does |
| --- | --- |
| `-DryRun` | Show what would change, change nothing |
| `-Status` | Show which accounts are linked |
| `-Merge` | If another account already has its own worlds, move them into the main account first instead of skipping it |
| `-Undo` | Remove the links and give each account an empty folder again |

## Good to know

- There is only one copy of each world. Deleting a world on any account deletes it for all of them.
- In single player, each world has one saved player, so a second account picks up the same inventory and position.
- Marketplace worlds and paid content stay locked to the account that bought them.
- Added a new account later? Sign in with it once, close the game, run `Share-Worlds.cmd` again.
- Folders that already have something in them are never deleted. `-Undo` removes only the links, never your worlds.

## Requirements

- Windows 10 or 11
- Minecraft Bedrock 1.21.120 or newer (stores data in `%APPDATA%\Minecraft Bedrock`)
- No admin rights needed

## License

MIT
