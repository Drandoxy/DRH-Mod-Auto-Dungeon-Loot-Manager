# Auto Dungeon / Loot Manager

<!-- drh:show -->
Manage dungeon rewards and optionally continue or restart after the results.

- Adds a native Restart button to the exit menu and a second button to the results screen.
- Default Next button chooses Next or Restart as the main results button and the automatic action.
- Auto Next / Restart waits 0â€“10 seconds after rewards are handled; the default delay is 6 seconds. Manual Next, Restart or Exit cancels it for that run.
- Automatically handle loot keeps or discards chest types using your saved rules. With it off, choose loot manually; the timer waits until all reward dialogs close.
- Skip loot and results animations speeds up results counting and loot reveals, and dismisses the level-up Sweet popup. Turn this setting off to keep Sweet popups for manual dismissal. The dungeon victory animation plays normally.
- Ctrl + Shift + R restarts the current dungeon. The shortcut is registered through the Mod API and appears in Settings â†’ Controls.
- Settings â†’ Mods contains the options; changes save automatically. The previous Friends Only setting is kept on re-entry.

Based on Danny's [Quick Dungeon Restart](https://github.com/rendable/DRH-Mod-Quick-Dungeon-Restart) and [Instant Victory Reveal](https://github.com/rendable/DRH-Mod-Instant-Victory-Reveal), and iClawSuit's [Summary Chest Rules](https://github.com/clawsuit/DRH-Mod-SummaryChestRules). Disable those three mods when using Auto Dungeon / Loot Manager to avoid competing summary handlers.
<!-- /drh:show -->

## Preview

### Restart from the exit menu

<table>
<tr>
  <td align="center"><a href="docs/images/restart-standard.png"><img src="docs/images/restart-standard.png" alt="Standard dungeon restart" width="410"></a><br><sub>Standard dungeon restart</sub></td>
  <td align="center"><a href="docs/images/restart-ultimate.png"><img src="docs/images/restart-ultimate.png" alt="Ultimate Rampage restart" width="410"></a><br><sub>Ultimate Rampage restart</sub></td>
</tr>
</table>

### Settings

<table>
<tr>
  <td align="center"><a href="docs/images/settings-automation.png"><img src="docs/images/settings-automation.png" alt="Automation, countdown and animations" width="265"></a></td>
  <td align="center"><a href="docs/images/settings-chests.png"><img src="docs/images/settings-chests.png" alt="Chest rules" width="265"></a></td>
  <td align="center"><a href="docs/images/settings-item-boxes.png"><img src="docs/images/settings-item-boxes.png" alt="Legendary chests and item boxes" width="265"></a></td>
</tr>
</table>

### Results screen

<table>
<tr>
  <td align="center"><a href="docs/images/results-restart.png"><img src="docs/images/results-restart.png" alt="Restart as the default" width="240"></a><br><sub>Restart as the default "Next" button in settings</sub></td>
  <td align="center"><a href="docs/images/results-next.png"><img src="docs/images/results-next.png" alt="Next as the default" width="240"></a><br><sub>Next as the default "Next" button in settings</sub></td>
</tr>
</table>

## Rewards

All chest types are kept by default. Common, uncommon, rare, legendary, small item boxes and royal item boxes have separate rules. Unknown rewards are kept. A keep request waits for server confirmation and the account refresh; full storage, transaction errors and timeouts pause automation without discarding the chest. With Full Inventory loaded, auto loot can try to keep a chest even when the standard storage check would block it. The server must still accept the request.

Early restart has the same completion-XP and treasure loss as leaving normally. Re-entry uses normal matchmaking for the same dungeon type; the server chooses its instance and layout.

## Compatibility

DRH 18 and Mod API 1.4.0 or compatible later 1.x. This mod uses game internals (`extends`) and can need updates after a game change.


## License

[MIT](LICENSE).

## Validation

Launcher validation and isolated Haxe countdown, reward and level-up dismissal checks pass. Run `tests/run.ps1 -Haxe <path-to-haxe.exe>` to reproduce them.

The Restart control and dungeon/floor title also support the separate death/revive exit confirmation. That popup is discovered through its small native navigation graph, since ActorReviveState does not retain it on the HUD. Native Cancel closes the confirmation before the usual server-confirmed restart exit flow.
