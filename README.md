# 🐾 Sure Animals

A FiveM animal farming resource — raise, feed, and sell animals on your server.

## What It Does

Players can hatch eggs, grow animals, feed them, and eventually sell them for in-game money. They can also add friends and visit each other's farms.

### Features

- **Egg Hatching** — Use egg items to add animals to your farm
- **Growth System** — Animals grow over time based on real hours
- **Feeding** — Feed your animals to keep their growth up (with cooldowns)
- **Selling** — Sell grown animals for money based on their age
- **Friends** — Add friends and interact with their farms
- **Multi-Framework** — Supports multiple FiveM frameworks
- **Locales** — Built-in localization support
- **Admin Commands** — Server commands for managing animal data

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)

## Installation

1. Drop `sure_animals` into your server's `resources` folder
2. Configure files in the `config/` folder to match your framework and preferences
3. Add `ensure sure_animals` to your `server.cfg`

## Configuration

All config files are in the `config/` directory:

- `config/shared/` — Public/shared settings (egg list, feed items, growth rates)
- `config/framework/` — Framework-specific setup (player lookups, item handling)

## Commands

| Command | Description |
|---|---|
| `/sure_animal help` | List available sub-commands |
| `/sure_animal get [identifier]` | View a player's farm data |

> Admin permissions are required for all commands.

## License

This project is licensed under **CC BY-NC-SA 4.0** — see the [LICENSE](LICENSE) file for details.

You're free to fork and improve this project, but **commercial use is not allowed**.
