# force_evidence

Evidence archive for police. At the evidence locker an officer searches a citizen by citizen ID or by first and last name, picks them from the results, and opens that citizen's evidence stash. Every citizen has one stash, shared by all lockers and stored by your inventory.

Free and open source. Works on ESX Legacy, QBCore and QBox.

## Features

- Search by citizen ID (citizenid on QBCore / QBox, identifier on ESX) or by the start of the first and last name
- One evidence stash per citizen, opened on the server: the client never sends a stash id, and only citizens from the officer's own search can be opened
- Server-side checks: job and minimum grade per locker, optional duty, distance to the locker, search cooldown and result lifetime
- Search results show name, ID and date of birth only
- Access is printed to the server console and fired as the server event `force_evidence:lockerOpened`
- ox_target, qb-target or [E] with the ox_lib text UI
- English and Swedish locales

## Supported inventories

| Inventory | Support |
| --- | --- |
| ox_inventory (ESX, QBCore, QBox) | Full. The stash is restricted to the locker jobs and the locker coordinates by ox_inventory itself. |
| qb-inventory 2.x | Full, opened on the server through `OpenInventory`. |
| qb-inventory 1.x and forks (lj, ps) | Works, but these versions open stashes from the client and let any client open any stash name. Update if you can. |
| ESX default inventory | Not supported: it has no stashes. Use ox_inventory. |
| Other inventories | Add an opener in `server/custom/inventory.lua`. |

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql) (reads the framework's character table; no tables of its own)
- OneSync
- ESX Legacy, QBCore or QBox (other frameworks through the `custom.lua` bridge files)
- An inventory from the table above
- Optional: ox_target or qb-target

## Installation

1. Put the folder in your resources as `force_evidence`.
2. Add `ensure force_evidence` to `server.cfg` below `ensure ox_lib` and `ensure oxmysql`. The order relative to your framework, inventory and target resource doesn't matter.
3. Edit `config.lua`: lockers, jobs and stash size.

## Documentation

https://docs.forcedevelopments.com/free-resources/force_evidence/introduction

## License

Apache 2.0, see [LICENSE](LICENSE).
