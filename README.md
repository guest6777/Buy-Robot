## ⚠️ Important: Materials & Models Folders + FastDL

Make sure to upload the **`materials`** and **`models`** folders to your server. Without them, some textures, icons, and models may appear as **missing/error** (purple and black checkerboard, or giant ERROR signs).

**Server paths:**
- `tf/materials/`
- `tf/models/`

### For FastDL (Recommended)

If you want all players to download the files automatically when connecting:

1. Upload the `materials` and `models` folders to your **FastDL server**
2. Make sure `sv_downloadurl` is set correctly in your `server.cfg`
3. Players will download everything automatically on join

> Without FastDL, players who don't have the files will see missing textures and models!

---

## ✅ No Modifications Required

This plugin works out of the box with **standard MvM missions** — no heavy game mode modifications like **SiegMvM** needed. You get the full Buy Robot experience without altering core MvM mechanics.

## ⚙️ Requirements (Defender Bots)

| Requirement |
|-------------|
| [TF2Attributes](https://github.com/FlaminSarge/tf2attributes) |
| [TF2 Econ Data](https://github.com/nosoop/SM-TFEconData) |
| [TF2 Utils](https://github.com/nosoop/SM-TFUtils) |
| [CBaseNPC](https://github.com/TF2-DMB/CBaseNPC) |
| [Actions](https://forums.alliedmods.net/showthread.php?t=336374) |
| [REST in Pawn (RIPExt)](https://github.com/ErikMinekus/sm-ripext) |
| [stocklib_officerspy](https://github.com/OfficerSpy/SM_Stock_OfficerSpy) *(Compilation only)* |

---

## 📜 Credits

| Plugin | Original Author |
|--------|-----------------|
| **Defender Bots** | [Officer Spy](https://github.com/OfficerSpy) |
| **Buy Robot** | [guest6777](https://github.com/guest6777) |

> Modified & Enhanced with **DeepSeek AI** 🤖

---

# Defender Bots & Buy Robot - Commands Tutorial

## 🎮 Player Commands

### Defender Bots

| Command | Description |
|---------|-------------|
| `!votebots` / `!vb` | Vote to enable bots for this round |
| `!botpref` / `!botpreferences` | Set your bot class/weapon preferences |
| `!viewbotchances` / `!botchances` | View class chances for next bot lineup |
| `!viewbotlineup` / `!botlineup` | View the next bot team lineup |
| `!rerollbotclasses` / `!rerollbots` | Reshuffle the bot class lineup |
| `!playwithbots` | Join BLUE team and play with bots |
| `!requestbot [class]` | Request an extra bot (optional class) |
| `!choosebotteam` / `!cbt` | Choose bot team lineup manually |
| `!redobots` | Repick bot team lineup |
| `!helpmenu` / `!bothelp` | Show help menu with all commands |

### Buy Robot

| Command | Description |
|---------|-------------|
| `!buyrobot` / `!br` / `!robotshop` | Open robot shop menu |
| `!points` | Check your current points |
| `!shopstatus` / `!ssh` | Check shop status (bot count, slots) |
| `!top` / `!top10` | View top 10 points ranking |
| `!rank` | View your personal rank |
| `!votesaxton` | Vote to toggle Saxton Hale AI (RED team) |
| `!votegray` | Vote to toggle Gray Mann AI (BLUE team) |
| `!queue` / `!waiting` | View waiting queue status |
| `!cancelqueue` | Remove your robots from waiting queue |
| `!lr` / `!listrobots` | List all active purchased robots |
| `!ri` / `!robotinfo` | View info of robot you're looking at |
| `!myrobots` / `!mr` | Manage your purchased robots |
| `!info` / `!status` | Server status and settings |

---

## 🔧 Admin Commands

### Defender Bots Admin

| Command | Description |
|---------|-------------|
| `!addbots <number>` | Add bots manually |
| `!purgebots` | Remove all bots |
| `!botmanager_stop` | Stop managing bots |
| `!view_bot_upgrades <player> [slot]` | View bot upgrades |

### Map Config Admin

| Command | Description |
|---------|-------------|
| `!addsniperhit` | Add sniper spot at current position |
| `!addnest` | Add engineer nest spot |
| `!listnests` | List all engineer nest spots |
| `!spots` | Toggle spot visualization |
| `!spotinfo` | Info of spot you're looking at |
| `!addteleporter` | Add teleporter entrance |
| `!listteleporter` | List teleporter spots |
| `!removeteleporter <id>` | Remove teleporter spot by ID |
| `!clearteleporter` | Clear all teleporter spots |

### Buy Robot Admin

| Command | Description |
|---------|-------------|
| `!givepoints <player> <amount>` | Give points to a player |
| `!resetpoints` | Reset all players' points |
| `!savepoints` | Save points to file |
| `!loadpoints` | Load points from file |
| `!resetpointsdata` | Reset all points data |
| `!addrobots` | Add robots without limits (menu) |
| `!purgerobots` | Remove all purchased robots |
| `!removeunitsbots` | Remove all Saxton Hale AI bots |
| `!ar` / `!adminrobots` | Show all purchased robots menu |

### Spawn Points Admin

| Command | Description |
|---------|-------------|
| `!addspawn` | Add spawn point at current position |
| `!listspawns` | List all spawn points |
| `!removespawn <id>` | Remove a spawn point by ID |
| `!clearspawns` | Clear all spawn points |
| `!savespawns` | Save spawn points to file |
| `!loadspawns` | Load spawn points from file |

## 💡 Quick Tips

- Use `!shopstatus` to see available bot slots
- Use `!points` to check your currency  
- Use `!top10` to see who has the most points
- Use `!votebots` to start a bot game
- Use `!requestbot scout` to request a specific class
- Use `!myrobots` to manage your purchased robots
- Use `!cancelqueue` to remove waiting robots
