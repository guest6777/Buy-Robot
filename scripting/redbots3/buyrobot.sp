ConVar g_cvBuyEnable;
ConVar g_cvBuyMaxBots;
ConVar g_cvBuyPointsPerKill;
ConVar g_cvBuyRobotSounds;
ConVar g_cvBuyRobotFootsteps;
ConVar g_cvBuyDefaultLives;
ConVar g_cvBuyNotifyLives;
ConVar g_cvBuyNotifyKills;
ConVar g_cvBuyAllowDefenderBots;
ConVar g_cvBuyMaxPerBot;
ConVar g_cvBuyInterval;
ConVar g_cvBuyNotifyDefenderPurchase;
ConVar g_cvBuyNotifyHumanPurchase;
ConVar g_cvBuyKickOnWaveEnd;
ConVar g_cvBuyWaveBonusEnable;
ConVar g_cvBuyWaveBonusChance;
ConVar g_cvBuyWaveBonusCount;
ConVar g_cvBuyUseCustomLoadouts;
ConVar g_cvBuyUseUpgrades;
ConVar g_cvBuySaxtonAI;
ConVar g_cvBuySaxtonDelay;
ConVar g_cvGrayMannAI;
ConVar g_cvGrayMannDelay;
ConVar g_cvBuyRemoveUnitsBots;
ConVar g_cvMaxBossPerTeam;
ConVar g_cvMaxWaitingQueueTotal;
ConVar g_cvMaxWaitingQueuePerPlayer;
ConVar g_cvBuyEnableHats;
ConVar g_cvBuyEnableDefenderHats;
ConVar g_cvPriceSoldier;
ConVar g_cvPricePyro;
ConVar g_cvPriceDemoman;
ConVar g_cvPriceHeavy;
ConVar g_cvPriceEngineer;
ConVar g_cvPriceMedic;
ConVar g_cvPriceSpy;
ConVar g_cvPriceScout;
ConVar g_cvPriceSniper;

Handle g_hBuyAutoTimer = INVALID_HANDLE;
Handle g_hValidationTimer = INVALID_HANDLE;
Handle hEquipWearable = null;
ArrayList g_hBuyQueue;
ArrayList g_hBuyRobotHats;
bool bWaveBeginProcessed = false;
float fLastWaveBeginTime = 0.0;
float g_flLastSendTime = 0.0;
int g_iWaveBonusCounter = 0;
int g_iWaveFailCounterTick;
Handle g_hGrayMannTimer = INVALID_HANDLE;
float g_flLastSendTime2 = 0.0;
int g_iWaveBonusCounter2 = 0;
float g_flLastAnySendTime = 0.0;

int g_iBuyPlayerPoints[MAXPLAYERS + 1];
int g_iBuyRobotLives[MAXPLAYERS + 1];
int g_iBuyRobotOwner[MAXPLAYERS + 1];
float g_flBuyLastBotBuyTime[MAXPLAYERS + 1];
float m_flNextSnipeFireTime[MAXPLAYERS + 1];

Handle g_hSpawnCheckTimer = INVALID_HANDLE;
float g_flLastPosition[MAXPLAYERS + 1][3];
float g_flStuckTime[MAXPLAYERS + 1];

int g_iBuyRobotHatIndex[MAXPLAYERS + 1];
int g_iWaitingForRename[MAXPLAYERS + 1];

static const char g_sPointsFile[] = "configs/defenderbots/buyrobot/points.txt";
static KeyValues g_hPointsKV = null;

#define SPAWN_TYPE_RED   0
#define SPAWN_TYPE_BLUE  1

#define BUY_CATEGORY_SINGLE    0
#define BUY_CATEGORY_SQUAD     1
#define BUY_CATEGORY_GIANT     2
#define BUY_CATEGORY_BOSS      3

#define BUY_PRICE_SINGLE_MULT  1.0
#define BUY_PRICE_SQUAD_MULT   5.0
#define BUY_PRICE_GIANT_MULT   3.0
#define BUY_PRICE_BOSS_MULT    15.0

#define VALIDATION_INTERVAL    30.0

ArrayList g_hWaitingQueue = null;

static ArrayList g_hSpawnPoints;
static ArrayList g_hSpawnAngles;
static ConVar g_cvBuyUseCustomSpawns;
static char g_sSpawnConfigFile[PLATFORM_MAX_PATH];
static char g_sSystemTime[32];
static TFTeam g_tempAddTeam;
static int g_iSelectedSpawnType = SPAWN_TYPE_RED;
static ConVar g_cvBuySpawnDefaultColor;

bool g_bSaxtonVoteOnCooldown = false;
bool g_bGrayVoteOnCooldown = false;
#define VOTE_COOLDOWNAI 60.0

float g_flLastTeleportTime[MAXPLAYERS + 1];
#define TELEPORT_COOLDOWN 30.0

bool g_bRobotFrozen[MAXPLAYERS + 1];

static ArrayList m_adtBlacklist = null;
static char g_sBlacklistFile[PLATFORM_MAX_PATH];

#define GIANTSCOUT_SND_LOOP         "mvm/giant_scout/giant_scout_loop.wav"
#define GIANTSOLDIER_SND_LOOP       "mvm/giant_soldier/giant_soldier_loop.wav"
#define GIANTPYRO_SND_LOOP          "mvm/giant_pyro/giant_pyro_loop.wav"
#define GIANTDEMOMAN_SND_LOOP       "mvm/giant_demoman/giant_demoman_loop.wav"
#define GIANTHEAVY_SND_LOOP         ")mvm/giant_heavy/giant_heavy_loop.wav"
#define SOUND_GUN_FIRE               ")mvm/giant_heavy/giant_heavy_gunfire.wav"
#define SOUND_GUN_SPIN               ")mvm/giant_heavy/giant_heavy_gunspin.wav"
#define SOUND_WIND_UP                ")mvm/giant_heavy/giant_heavy_gunwindup.wav"
#define SOUND_WIND_DOWN              ")mvm/giant_heavy/giant_heavy_gunwinddown.wav"
#define SOUND_GRENADE                "^mvm/giant_demoman/giant_demoman_grenade_shoot.wav"
#define SOUND_ROCKET                 "mvm/giant_soldier/giant_soldier_rocket_shoot.wav"
#define SOUND_EXPLOSION              "mvm/giant_soldier/giant_soldier_rocket_explode.wav"
#define SOUND_FLAME_START             "^mvm/giant_pyro/giant_pyro_flamethrower_start.wav"
#define SOUND_FLAME_LOOP              "^mvm/giant_pyro/giant_pyro_flamethrower_loop.wav"
#define SOUND_DEATH                  "mvm/giant_common/giant_common_explodes_01.wav"

enum struct WaitingPurchase
{
    int buyer;
    char class[32];
    int lives;
    char prefix[32];
    TFTeam team;
    int price;
    int botCount;
    int category;
    
    void Reset()
    {
        this.buyer = 0;
        this.class = "";
        this.lives = 0;
        this.prefix = "";
        this.team = TFTeam_Red;
        this.price = 0;
        this.botCount = 0;
        this.category = 0;
    }
}

bool IsHalloweenActive()
{
    return (GetConVarInt(FindConVar("tf_forced_holiday")) == 2);
}

void BuyRobot_LoadAllPoints()
{
    if (g_hPointsKV != null)
        delete g_hPointsKV;
    
    g_hPointsKV = new KeyValues("BuyRobotPoints");
    
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), g_sPointsFile);
    
    if (FileExists(filePath))
    {
        g_hPointsKV.ImportFromFile(filePath);
        LogMessage("[BuyRobot] Points loaded from %s", filePath);
    }
    else
    {
        LogMessage("[BuyRobot] No points file found at %s, creating new one", filePath);
    }
}

void BuyRobot_SaveAllPoints()
{
    if (g_hPointsKV == null)
        return;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClientIndex(i) && !IsFakeClient(i))
        {
            char steamId[32];
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            
            if (strlen(steamId) > 0)
            {
                char playerName[MAX_NAME_LENGTH];
                GetClientName(i, playerName, sizeof(playerName));
                
                g_hPointsKV.JumpToKey(steamId, true);
                g_hPointsKV.SetNum("points", g_iBuyPlayerPoints[i]);
                g_hPointsKV.SetString("name", playerName);
                g_hPointsKV.Rewind();
            }
        }
    }
    
    g_hPointsKV.Rewind();
    if (g_hPointsKV.GotoFirstSubKey())
    {
        do
        {
            int points = g_hPointsKV.GetNum("points", 0);
            if (points <= 0)
            {
                g_hPointsKV.DeleteThis();
                g_hPointsKV.Rewind();
            }
        } while (g_hPointsKV.GotoNextKey());
    }
    g_hPointsKV.Rewind();
    
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), g_sPointsFile);
    
    char folderPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/buyrobot");
    if (!DirExists(folderPath))
    {
        CreateDirectory(folderPath, 511);
    }
    
    g_hPointsKV.ExportToFile(filePath);
}

void BuyRobot_LoadPlayerPoints(int client)
{
    if (!IsValidClientIndex(client) || IsFakeClient(client))
        return;
    
    if (g_hPointsKV == null)
        BuyRobot_LoadAllPoints();
    
    char steamId[32];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    
    if (strlen(steamId) > 0)
    {
        g_hPointsKV.JumpToKey(steamId);
        int points = g_hPointsKV.GetNum("points", 0);
        g_iBuyPlayerPoints[client] = points;
        g_hPointsKV.Rewind();
        
        if (points > 0)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You have \x07FFD700%d\x01 saved points!", points);
        }
    }
}

void BuyRobot_SavePlayerPoints(int client)
{
    if (!IsValidClientIndex(client) || IsFakeClient(client))
        return;
    
    if (g_hPointsKV == null)
        g_hPointsKV = new KeyValues("BuyRobotPoints");
    
    char steamId[32];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    
    if (strlen(steamId) > 0)
    {
        char playerName[MAX_NAME_LENGTH];
        GetClientName(client, playerName, sizeof(playerName));
        
        g_hPointsKV.JumpToKey(steamId, true);
        g_hPointsKV.SetNum("points", g_iBuyPlayerPoints[client]);
        g_hPointsKV.SetString("name", playerName);
        g_hPointsKV.Rewind();
    }
}

void BuyRobot_ResetAllPointsData()
{
    if (g_hPointsKV != null)
    {
        delete g_hPointsKV;
        g_hPointsKV = new KeyValues("BuyRobotPoints");
    }
    
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), g_sPointsFile);
    
    if (FileExists(filePath))
    {
        DeleteFile(filePath);
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClientIndex(i) && !IsFakeClient(i))
        {
            g_iBuyPlayerPoints[i] = 0;
        }
    }
    
    LogMessage("[BuyRobot] All points data reset");
}

void LoadBlacklist()
{
    BuildPath(Path_SM, g_sBlacklistFile, sizeof(g_sBlacklistFile), "configs/defenderbots/buyrobot/blacklist.txt");
    
    if (m_adtBlacklist == null)
        m_adtBlacklist = new ArrayList(32);
    else
        m_adtBlacklist.Clear();
    
    if (!FileExists(g_sBlacklistFile))
    {
        File hFile = OpenFile(g_sBlacklistFile, "w");
        if (hFile)
        {
            hFile.WriteLine("// Player Blacklist (one SteamID2 per line)");
            hFile.WriteLine("// Example: STEAM_0:0:12345678");
            hFile.WriteLine("// Blacklisted players will not appear in /top10 or /rank");
            delete hFile;
        }
        return;
    }
    
    File hFile = OpenFile(g_sBlacklistFile, "r");
    if (!hFile) return;
    
    char line[32];
    while (ReadFileLine(hFile, line, sizeof(line)))
    {
        TrimString(line);
        if (strlen(line) > 0 && line[0] != '/')
        {
            m_adtBlacklist.PushString(line);
        }
    }
    delete hFile;
}

bool IsPlayerBlacklisted(const char[] steamId)
{
    if (m_adtBlacklist == null)
        return false;
    
    for (int i = 0; i < m_adtBlacklist.Length; i++)
    {
        char blacklistedId[64];
        m_adtBlacklist.GetString(i, blacklistedId, sizeof(blacklistedId));
        
        if (StrEqual(steamId, blacklistedId, false))
            return true;
    }
    return false;
}

void BuyRobot_Init()
{
    if (g_hBuyAutoTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBuyAutoTimer);
        g_hBuyAutoTimer = INVALID_HANDLE;
    }
    
    if (g_hValidationTimer != INVALID_HANDLE)
    {
        KillTimer(g_hValidationTimer);
        g_hValidationTimer = INVALID_HANDLE;
    }

    if (g_hWaitingQueue != null)
    {
    	delete g_hWaitingQueue;
    }
    g_hWaitingQueue = new ArrayList(256);
    
    g_cvBuyEnable = CreateConVar("sm_buyrobot_enable", "1", "Enable buying robots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyMaxBots = CreateConVar("sm_buyrobot_maxbots", "10", "Maximum purchased bots", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvBuyPointsPerKill = CreateConVar("sm_buyrobot_points_per_kill", "3", "Points gained for killing", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvBuyRobotSounds = CreateConVar("sm_buyrobot_sounds", "1", "Enable robot sounds", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyRobotFootsteps = CreateConVar("sm_buyrobot_footsteps", "1", "Enable robot footstep sounds", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyDefaultLives = CreateConVar("sm_buyrobot_default_lives", "3", "Lives for purchased robots", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvBuyNotifyLives = CreateConVar("sm_buyrobot_notify_lives", "1", "Notify when robot loses a life", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyNotifyKills = CreateConVar("sm_buyrobot_notify_kills", "1", "Notify owner when their robot kills an enemy", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyAllowDefenderBots = CreateConVar("sm_buyrobot_allow_defender_bots", "1", "Allow Defender bots to purchase", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyMaxPerBot = CreateConVar("sm_buyrobot_max_per_bot", "1", "Maximum alive robots per Defender bot", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvBuyInterval = CreateConVar("sm_buyrobot_interval", "15.0", "Interval between bot purchases", FCVAR_NOTIFY, true, 15.0, true, 120.0);
    g_cvBuyNotifyDefenderPurchase = CreateConVar("sm_buyrobot_notify_defender", "1", "Notify when defender bots purchase robots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyNotifyHumanPurchase = CreateConVar("sm_buyrobot_notify_human", "1", "Notify when human players purchase robots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyKickOnWaveEnd = CreateConVar("sm_buyrobot_kick_on_wave_end", "1", "Remove purchased robots when wave ends", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyWaveBonusEnable = CreateConVar("sm_buyrobot_wave_bonus_enable", "1", "Enable wave bonus reinforcements", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyWaveBonusChance = CreateConVar("sm_buyrobot_wave_bonus_chance", "20", "Chance for wave bonus (0-100)", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    g_cvBuyWaveBonusCount = CreateConVar("sm_buyrobot_wave_bonus_count", "5", "Number of bonus robots", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvBuyUseCustomSpawns = CreateConVar("sm_buyrobot_use_custom_spawns", "1", "Use custom spawn points for robots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyUseCustomLoadouts = CreateConVar("sm_buyrobot_use_custom_loadouts", "0", "Allow purchased robots to use custom loadouts", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyUseUpgrades = CreateConVar("sm_buyrobot_use_upgrades", "0", "Allow purchased robots to buy upgrades (Mann Co.)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuySaxtonAI = CreateConVar("sm_buyrobot_saxton_ai", "0", "Enable Saxton Hale AI to send reinforcements based on team strength (Mann Co.)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuySaxtonDelay = CreateConVar("sm_buyrobot_saxton_delay", "20.0", "Delay in seconds between Saxton Hale AI reinforcements", FCVAR_NOTIFY, true, 1.0, true, 120.0);
    g_cvBuyRemoveUnitsBots = CreateConVar("sm_buyrobot_remove_units_bots", "1", "Remove Saxton Hale AI bots when wave completes or fails", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvGrayMannAI = CreateConVar("sm_buyrobot_gray_mann_ai", "0", "Enable Gray Mann AI to send reinforcements based on team strength (Invaders)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvGrayMannDelay = CreateConVar("sm_buyrobot_gray_mann_delay", "20.0", "Delay in seconds between Gray Mann reinforcements", FCVAR_NOTIFY, true, 1.0, true, 120.0);
    g_cvBuySpawnDefaultColor = CreateConVar("sm_buyrobot_spawn_default_color", "0", "Default spawn color (0=Red, 1=Blue)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvMaxBossPerTeam = CreateConVar("sm_buyrobot_max_boss_per_team", "1", "Maximum Boss robots allowed per team", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    g_cvMaxWaitingQueueTotal = CreateConVar("sm_buyrobot_max_queue_total", "50", "Maximum total robots in waiting queue", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvMaxWaitingQueuePerPlayer = CreateConVar("sm_buyrobot_max_queue_per_player", "5", "Maximum robots per player in waiting queue", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvBuyEnableHats = CreateConVar("sm_buyrobot_enable_hats", "0", "Enable random hats for purchased robots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvBuyEnableDefenderHats = CreateConVar("sm_buyrobot_enable_defender_hats", "0", "Enable random hats for Defender bots", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPriceSoldier = CreateConVar("sm_buyrobot_price_soldier", "36", "Price for Soldier robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPricePyro = CreateConVar("sm_buyrobot_price_pyro", "36", "Price for Pyro robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceDemoman = CreateConVar("sm_buyrobot_price_demoman", "36", "Price for Demoman robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceHeavy = CreateConVar("sm_buyrobot_price_heavy", "46", "Price for Heavy robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceEngineer = CreateConVar("sm_buyrobot_price_engineer", "42", "Price for Engineer robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceMedic = CreateConVar("sm_buyrobot_price_medic", "42", "Price for Medic robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceSpy = CreateConVar("sm_buyrobot_price_spy", "36", "Price for Spy robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceScout = CreateConVar("sm_buyrobot_price_scout", "26", "Price for Scout robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    g_cvPriceSniper = CreateConVar("sm_buyrobot_price_sniper", "42", "Price for Sniper robot", FCVAR_NOTIFY, true, 1.0, true, 500.0);
    
    RegConsoleCmd("sm_buyrobot", BuyRobot_Command);
    RegConsoleCmd("sm_br", BuyRobot_Command);
    RegConsoleCmd("sm_robotshop", BuyRobot_Command);
    RegConsoleCmd("sm_rsh", BuyRobot_Command);
    RegConsoleCmd("sm_points", BuyRobot_ShowPoints);
    RegConsoleCmd("sm_shopstatus", BuyRobot_ShopStatus);
    RegConsoleCmd("sm_ssh", BuyRobot_ShopStatus);
    RegConsoleCmd("sm_top", Command_ShowTopPoints);
    RegConsoleCmd("sm_top10", Command_ShowTopPoints);
    RegConsoleCmd("sm_rank", Command_ShowRank);
    RegConsoleCmd("sm_votesaxton", Command_VoteSaxton);
    RegConsoleCmd("sm_votegray", Command_VoteGray);
    RegConsoleCmd("sm_bothelp", Command_BotHelp);
    RegConsoleCmd("sm_helpmenu", Command_BotHelp);
    RegConsoleCmd("sm_info", Command_ServerInfo);
    RegConsoleCmd("sm_status", Command_ServerInfo);
    RegConsoleCmd("sm_queue", Command_ShowQueue);
    RegConsoleCmd("sm_waiting", Command_ShowQueue);
    RegConsoleCmd("sm_cancelqueue", Command_CancelQueue);
    RegConsoleCmd("sm_lr", Command_ListRobots);
    RegConsoleCmd("sm_listrobots", Command_ListRobots);
    RegConsoleCmd("sm_ri", Command_RobotInfo);
    RegConsoleCmd("sm_robotinfo", Command_RobotInfo);
    RegConsoleCmd("sm_myrobots", Command_MyRobots);
    RegConsoleCmd("sm_mr", Command_MyRobots);
    RegAdminCmd("sm_givepoints", BuyRobot_GivePoints, ADMFLAG_GENERIC, "Give points to a player");
    RegAdminCmd("sm_resetpoints", BuyRobot_ResetPoints, ADMFLAG_GENERIC, "Reset all points");
    RegAdminCmd("sm_savepoints", Command_SavePoints, ADMFLAG_GENERIC, "Save all points to file");
    RegAdminCmd("sm_loadpoints", Command_LoadPoints, ADMFLAG_GENERIC, "Load all points from file");
    RegAdminCmd("sm_resetpointsdata", Command_ResetPointsData, ADMFLAG_GENERIC, "Reset all points data (clears file)");
    RegAdminCmd("sm_addrobots", BuyRobot_AddRobotsCmd, ADMFLAG_GENERIC, "Add robots without limits");
    RegAdminCmd("sm_purgerobots", BuyRobot_PurgeRobotsCmd, ADMFLAG_GENERIC, "Remove all purchased robots");
    RegAdminCmd("sm_removeunitsbots", Command_RemoveUnitsBots, ADMFLAG_GENERIC, "Remove all Saxton Hale AI bots");
    RegAdminCmd("sm_ar", Command_AdminRobots, ADMFLAG_GENERIC, "Admin: Show all purchased robots menu");
    RegAdminCmd("sm_adminrobots", Command_AdminRobots, ADMFLAG_GENERIC, "Admin: Show all purchased robots menu");
    RegAdminCmd("sm_addspawn", Command_AddSpawn, ADMFLAG_GENERIC, "Add current position as spawn point");
    RegAdminCmd("sm_listspawns", Command_ListSpawns, ADMFLAG_GENERIC, "List all spawn points");
    RegAdminCmd("sm_removespawn", Command_RemoveSpawn, ADMFLAG_GENERIC, "Remove a spawn point by ID");
    RegAdminCmd("sm_clearspawns", Command_ClearSpawns, ADMFLAG_GENERIC, "Clear all spawn points");
    RegAdminCmd("sm_savespawns", Command_SaveSpawns, ADMFLAG_GENERIC, "Save spawn points to file");
    RegAdminCmd("sm_loadspawns", Command_LoadSpawns, ADMFLAG_GENERIC, "Load spawn points from file");
    
    HookEvent("player_death", BuyRobot_EventDeath);
    HookEvent("player_spawn", BuyRobot_EventSpawn);
    HookEvent("player_team", BuyRobot_EventTeamChange);
    HookEvent("mvm_begin_wave", BuyRobot_WaveBegin);
    HookEvent("mvm_wave_complete", BuyRobot_WaveEnd);
    HookEvent("mvm_wave_failed", BuyRobot_WaveEnd);
    HookEvent("mvm_wave_failed", BuyRobot_WaveFailed);
    HookEvent("mvm_mission_update", BuyRobot_OnMissionUpdate, EventHookMode_Pre);
    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    
    AddNormalSoundHook(BuyRobot_SoundHook);
    AddNormalSoundHook(BuyRobot_SoundHook_Death);
    AddNormalSoundHook(BuyRobot_GiantSoundHook);
    
    g_hValidationTimer = CreateTimer(VALIDATION_INTERVAL, BuyRobot_ValidationTimer, _, TIMER_REPEAT);
    g_hBuyQueue = new ArrayList(ByteCountToCells(256));
    g_hSpawnPoints = new ArrayList(4);
    g_hSpawnAngles = new ArrayList(3);
    BuyRobot_PrecacheWaveIcon();
    BuyRobot_PrecacheSpawnModel();
    BuyRobot_ForceDownloadMaterials();

    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    BuildPath(Path_SM, g_sSpawnConfigFile, sizeof(g_sSpawnConfigFile), "configs/defenderbots/buyrobot/spawns_%s.cfg", mapName);
    
    char folderPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/buyrobot");
    if (!DirExists(folderPath))
    {
        CreateDirectory(folderPath, 511);
    }

    GameData hTF2 = new GameData("sm-tf2.games");
    if (hTF2)
    {
        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetVirtual(hTF2.GetOffset("RemoveWearable") - 1);
        PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
        hEquipWearable = EndPrepSDKCall();
        delete hTF2;
    }
    
    if (hEquipWearable == null)
        LogError("[BuyRobot] Failed to create SDKCall for EquipWearable");

    g_hBuyRobotHats = new ArrayList();
    BuyRobot_PopulateHatsList();
    
    BuyRobot_LoadAllPoints();

    m_adtBlacklist = new ArrayList(32);
    LoadBlacklist();
}

public Action Command_ListRobots(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    int totalRobots = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i])
            totalRobots++;
    }
    
    if (totalRobots == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No purchased robots currently active!");
        return Plugin_Handled;
    }
    
    char line[256];
    
    PrintToChat(client, "\x0732CD32===== Purchased Robots (\x07FFD700%d\x0732CD32 total) =====\x01", totalRobots);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !g_bBuyIsPurchasedRobot[i])
            continue;
        
        char robotName[64];
        GetClientName(i, robotName, sizeof(robotName));
        
        char nameColor[8] = "FFD700";
        if (StrContains(robotName, "Giant") != -1)
            nameColor = "8B008B";
        else if (StrContains(robotName, "Boss") != -1)
            nameColor = "FF1493";
        
        char className[32];
        BuyRobot_GetRobotClassString(i, className, sizeof(className));
        
        TFTeam team = TF2_GetClientTeam(i);
        char teamName[32];
        char teamColor[8];
        if (team == TFTeam_Red)
        {
            teamName = "Mann Co. (RED)";
            teamColor = "FF4500";
        }
        else if (team == TFTeam_Blue)
        {
            teamName = "Invaders (BLUE)";
            teamColor = "42A5F5";
        }
        else
        {
            teamName = "Unknown";
            teamColor = "FFFFFF";
        }
        
        int health = GetClientHealth(i);
        int maxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, i);
        int lives = g_iBuyRobotLives[i];
        int maxLives = g_cvBuyDefaultLives.IntValue;
        
        int owner = g_iBuyRobotOwner[i];
        char ownerName[64] = "Server";
        char ownerDisplay[96];
        
        if (g_bBuyIsAIRobot[i])
        {
            if (team == TFTeam_Red)
                Format(ownerDisplay, sizeof(ownerDisplay), "Saxton Hale");
            else if (team == TFTeam_Blue)
                Format(ownerDisplay, sizeof(ownerDisplay), "Gray Mann");
            else
                Format(ownerDisplay, sizeof(ownerDisplay), "Unknown");
        }
        else if (owner > 0 && IsClientInGame(owner))
        {
            GetClientName(owner, ownerName, sizeof(ownerName));
            if (IsFakeClient(owner) && g_bIsDefenderBot[owner])
                Format(ownerDisplay, sizeof(ownerDisplay), "[BOT] %s", ownerName);
            else
                Format(ownerDisplay, sizeof(ownerDisplay), "%s", ownerName);
        }
        else
        {
            Format(ownerDisplay, sizeof(ownerDisplay), "Server");
        }
        
        char status[8];
        char statusColor[8];
        if (IsPlayerAlive(i))
        {
            status = "[+]";
            statusColor = "00FF00";
        }
        else
        {
            status = "[x]";
            statusColor = "FF0000";
        }
        
        char healthColor[8];
        float healthPercent = float(health) / float(maxHealth);
        if (healthPercent > 0.7)
            healthColor = "00FF00";
        else if (healthPercent > 0.3)
            healthColor = "FFA500";
        else
            healthColor = "FF0000";
        
        char livesColor[8];
        if (lives <= 0)
            livesColor = "FF0000";
        else if (lives == 1)
            livesColor = "FF4500";
        else if (lives == 2)
            livesColor = "FFA500";
        else
            livesColor = "FFD700";
        
        Format(line, sizeof(line), "\x07%s%s\x01 Robot: \x07%s%s\x01 - Class: \x07FFD700%s\x01 - Team: \x07%s%s\x01 - Health: \x07%s%d/%d\x01 - Lives: \x07%s%d\x01 - Owner: \x07FFD700%s\x01", 
               statusColor, status, nameColor, robotName, className, teamColor, teamName, healthColor, health, maxHealth, livesColor, lives, ownerDisplay);
        
        PrintToChat(client, line);
    }
    
    PrintToChat(client, "\x0732CD32=========================================\x01");
    
    return Plugin_Handled;
}

public Action Command_RobotInfo(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    int target = GetClientAimTarget(client, true);
    
    if (target <= 0 || target > MaxClients || !IsClientInGame(target))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Look at a robot to see its info!");
        return Plugin_Handled;
    }
    
    if (!g_bBuyIsPurchasedRobot[target])
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This is not a robot!");
        return Plugin_Handled;
    }
    
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    int lives = g_iBuyRobotLives[target];
    int owner = g_iBuyRobotOwner[target];
    TFClassType class = TF2_GetPlayerClass(target);
    int health = GetClientHealth(target);
    int maxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, target);
    TFTeam team = TF2_GetClientTeam(target);
    
    char className[32];
    BuyRobot_GetRobotClassString(target, className, sizeof(className));
    
    char ownerName[64] = "None";
    char ownerDisplay[96];
    
    if (owner > 0 && IsClientInGame(owner))
    {
        GetClientName(owner, ownerName, sizeof(ownerName));
        
        if (IsFakeClient(owner) && g_bIsDefenderBot[owner])
            Format(ownerDisplay, sizeof(ownerDisplay), "[BOT] %s", ownerName);
        else
            Format(ownerDisplay, sizeof(ownerDisplay), "%s", ownerName);
    }
    else if (g_bBuyIsAIRobot[target])
    {
        if (team == TFTeam_Red)
            Format(ownerDisplay, sizeof(ownerDisplay), "Saxton Hale");
        else if (team == TFTeam_Blue)
            Format(ownerDisplay, sizeof(ownerDisplay), "Gray Mann");
        else
            Format(ownerDisplay, sizeof(ownerDisplay), "Unknown");
    }
    else
    {
        Format(ownerDisplay, sizeof(ownerDisplay), "Server");
    }
    
    char teamName[32];
    if (team == TFTeam_Red)
        teamName = "Mann Co. (RED)";
    else if (team == TFTeam_Blue)
        teamName = "Invaders (BLUE)";
    else
        teamName = "Unknown";
    
    char giantText[32] = "";
    if (StrContains(robotName, "Giant") != -1)
        giantText = "[GIANT] ";
    else if (StrContains(robotName, "Boss") != -1)
        giantText = "[BOSS] ";
    
    Panel panel = new Panel();
    
    char title[128];
    Format(title, sizeof(title), "%sRobot Info", giantText);
    panel.SetTitle(title);
    
    char line[128];
    Format(line, sizeof(line), "Name: %s", robotName);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    Format(line, sizeof(line), "Class: %s", className);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    Format(line, sizeof(line), "Team: %s", teamName);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    Format(line, sizeof(line), "Health: %d / %d", health, maxHealth);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    Format(line, sizeof(line), "Lives: %d remaining", lives);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    Format(line, sizeof(line), "Owner: %s", ownerDisplay);
    panel.DrawItem(line, ITEMDRAW_RAWLINE);
    
    panel.DrawItem(" ", ITEMDRAW_SPACER);
    panel.DrawItem("Close", ITEMDRAW_CONTROL);
    
    panel.Send(client, MenuHandler_RobotInfo, 15);
    
    delete panel;
    
    return Plugin_Handled;
}

public int MenuHandler_RobotInfo(Menu menu, MenuAction action, int param1, int param2)
{
    return 0;
}

public Action Command_AdminRobots(int client, int args)
{
    if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You don't have access to this command!");
        return Plugin_Handled;
    }
    
    int totalRobots = 0;
    int totalAIBots = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i])
        {
            totalRobots++;
            if (g_bBuyIsAIRobot[i])
                totalAIBots++;
        }
    }
    
    if (totalRobots == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No robots currently active!");
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(MenuHandler_AdminRobots);
    menu.SetTitle("Admin: All Robots (%d total, %d AI)\n ", totalRobots, totalAIBots);
    
    char line[256];
    char info[16];
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !g_bBuyIsPurchasedRobot[i])
            continue;
        
        char robotName[64];
        GetClientName(i, robotName, sizeof(robotName));
        
        char className[32];
        BuyRobot_GetRobotClassString(i, className, sizeof(className));
        
        TFTeam team = TF2_GetClientTeam(i);
        char teamName[16];
        if (team == TFTeam_Red)
            teamName = "RED";
        else if (team == TFTeam_Blue)
            teamName = "BLUE";
        else
            teamName = "???";
        
        char ownerName[64];
        
        if (g_bBuyIsAIRobot[i])
        {
            if (team == TFTeam_Red)
                Format(ownerName, sizeof(ownerName), "Saxton Hale");
            else if (team == TFTeam_Blue)
                Format(ownerName, sizeof(ownerName), "Gray Mann");
            else
                Format(ownerName, sizeof(ownerName), "Unknown");
        }
        else
        {
            int owner = g_iBuyRobotOwner[i];
            if (owner > 0 && IsClientInGame(owner))
            {
                GetClientName(owner, ownerName, sizeof(ownerName));
                if (IsFakeClient(owner) && g_bIsDefenderBot[owner])
                    Format(ownerName, sizeof(ownerName), "[BOT] %s", ownerName);
            }
            else
            {
                Format(ownerName, sizeof(ownerName), "Server");
            }
        }
        
        Format(line, sizeof(line), "[%s] %s (%s) - %s", teamName, robotName, className, ownerName);
        
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, line);
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public int MenuHandler_AdminRobots(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        int target = StringToInt(info);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target])
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            Command_AdminRobots(client, 0);
            return 0;
        }
        
        ShowAdminRobotMenu(client, target);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowAdminRobotMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    Menu menu = new Menu(MenuHandler_AdminRobotActions);
    
    char title[128];
    Format(title, sizeof(title), "Admin: %s\n ", robotName);
    menu.SetTitle(title);
    
    char info[32];
    
    Format(info, sizeof(info), "%d|hat", target);
    if (g_cvBuyEnableHats.BoolValue)
        menu.AddItem(info, "Change Hat");
    else
        menu.AddItem(info, "Change Hat (Disabled)", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "%d|rename", target);
    menu.AddItem(info, "Rename Robot");
    
    Format(info, sizeof(info), "%d|taunt", target);
    menu.AddItem(info, "Make Robot Taunt");
    
    Format(info, sizeof(info), "%d|teleport", target);
    menu.AddItem(info, "Teleport to Me");
    
    Format(info, sizeof(info), "%d|freeze", target);
    if (g_bRobotFrozen[target])
        menu.AddItem(info, "Unfreeze Robot");
    else
        menu.AddItem(info, "Freeze Robot (Statue)");
    
    if (TF2_GetPlayerClass(target) == TFClass_Engineer)
    {
        Format(info, sizeof(info), "%d|build", target);
        menu.AddItem(info, "Move Nest (Crosshair)");
        
        Format(info, sizeof(info), "%d|togglehelp", target);
        if (g_bEngineerHelpDisabled[target])
            menu.AddItem(info, "Help Teammates [OFF]");
        else
            menu.AddItem(info, "Help Teammates [ON]");
    }
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminRobotActions(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        char actionType[16];
        strcopy(actionType, sizeof(actionType), parts[1]);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target])
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            Command_AdminRobots(client, 0);
            return 0;
        }
        
        if (StrEqual(actionType, "hat"))
        {
            if (!g_cvBuyEnableHats.BoolValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Hat system is currently disabled!");
                ShowAdminRobotMenu(client, target);
                return 0;
            }
            AdminShowHatMenu(client, target);
            return 0;
        }
        else if (StrEqual(actionType, "rename"))
        {
            AdminShowRenameMenu(client, target);
            return 0;
        }
        else if (StrEqual(actionType, "taunt"))
        {
            if (!IsPlayerAlive(target))
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robot is dead!");
                ShowAdminRobotMenu(client, target);
                return 0;
            }
            FakeClientCommand(target, "taunt");
            char robotName[64];
            GetClientName(target, robotName, sizeof(robotName));
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 \x07FFD700%s\x01 is taunting!", robotName);
            ShowAdminRobotMenu(client, target);
        }
        else if (StrEqual(actionType, "teleport"))
        {
            if (!IsPlayerAlive(target))
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robot is dead!");
                ShowAdminRobotMenu(client, target);
                return 0;
            }
            float pos[3];
            GetClientAbsOrigin(client, pos);
            pos[2] += 20.0;
            TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
            char robotName[64];
            GetClientName(target, robotName, sizeof(robotName));
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 \x07FFD700%s\x01 teleported to you!", robotName);
            ShowAdminRobotMenu(client, target);
        }
        else if (StrEqual(actionType, "freeze"))
        {
            g_bRobotFrozen[target] = !g_bRobotFrozen[target];
            if (g_bRobotFrozen[target])
                SetEntityMoveType(target, MOVETYPE_NONE);
            else
                SetEntityMoveType(target, MOVETYPE_WALK);
            ShowAdminRobotMenu(client, target);
        }
        else if (StrEqual(actionType, "build"))
        {
            CommandEngineerMoveNest(client, target, true);
            ShowAdminRobotMenu(client, target);
        }
        else if (StrEqual(actionType, "togglehelp"))
        {
            g_bEngineerHelpDisabled[target] = !g_bEngineerHelpDisabled[target];
            if (g_bEngineerHelpDisabled[target])
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Engineer help DISABLED!");
            else
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Engineer help ENABLED!");
            ShowAdminRobotMenu(client, target);
        }
        else if (StrEqual(actionType, "back"))
        {
            Command_AdminRobots(client, 0);
            return 0;
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_AdminRobots(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void AdminShowHatMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    TFClassType class = TF2_GetPlayerClass(target);
    
    Menu menu = new Menu(MenuHandler_AdminHatSelect);
    
    char title[128];
    Format(title, sizeof(title), "Admin Hat for: %s\n ", robotName);
    menu.SetTitle(title);
    
    char info[32];
    bool hatsEnabled = g_cvBuyEnableHats.BoolValue;
    
    if (hatsEnabled)
    {
        Format(info, sizeof(info), "%d|random", target);
        menu.AddItem(info, "Random Hat");
        
        Format(info, sizeof(info), "%d|remove", target);
        menu.AddItem(info, "Remove Hat");
    }
    else
    {
        menu.AddItem("", "Random Hat (Disabled)", ITEMDRAW_DISABLED);
        menu.AddItem("", "Remove Hat (Disabled)", ITEMDRAW_DISABLED);
    }
    
    Format(info, sizeof(info), "%d|back", target);
    menu.AddItem(info, "Back");
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminHatSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        char hatType[16];
        strcopy(hatType, sizeof(hatType), parts[1]);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target])
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robot no longer available!");
            Command_AdminRobots(client, 0);
            return 0;
        }
        
        if (StrEqual(hatType, "random"))
        {
            g_iBuyRobotHatIndex[target] = 0;
            BuyRobot_RemoveWearables(target);
            BuyRobot_EquipHat(target);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 New random hat applied!");
            AdminShowHatMenu(client, target);
        }
        else if (StrEqual(hatType, "remove"))
        {
            g_iBuyRobotHatIndex[target] = 0;
            BuyRobot_RemoveWearables(target);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Hat removed!");
            AdminShowHatMenu(client, target);
        }
        else if (StrEqual(hatType, "back"))
        {
            ShowAdminRobotMenu(client, target);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char info[32];
        menu.GetItem(0, info, sizeof(info));
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        ShowAdminRobotMenu(param1, target);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void AdminShowRenameMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Type the new name for \x07FFD700%s\x01 in chat:", robotName);
    
    g_iWaitingForRename[client] = target;
}

public int MenuHandler_AdminRename(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select || action == MenuAction_Cancel)
    {
        g_iWaitingForRename[param1] = 0;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_MyRobots(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    int ownedCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && g_iBuyRobotOwner[i] == client)
            ownedCount++;
    }
    
    if (ownedCount == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You don't have any purchased robots!");
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(MenuHandler_MyRobots);
    menu.SetTitle("Your Robots - Select to Customize\n ");
    
    char line[128];
    char info[16];
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !g_bBuyIsPurchasedRobot[i] || g_iBuyRobotOwner[i] != client)
            continue;
        
        char robotName[64];
        GetClientName(i, robotName, sizeof(robotName));
        
        char className[32];
        BuyRobot_GetRobotClassString(i, className, sizeof(className));
        
        Format(line, sizeof(line), "%s (%s)", robotName, className);
        
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, line);
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public int MenuHandler_MyRobots(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        int target = StringToInt(info);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target] || g_iBuyRobotOwner[target] != client)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            return 0;
        }
        
        ShowRobotCustomizeMenu(client, target);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowRobotCustomizeMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    Menu menu = new Menu(MenuHandler_RobotCustomize);
    
    char title[128];
    Format(title, sizeof(title), "Customize: %s\n ", robotName);
    menu.SetTitle(title);
    
    char info[32];

    Format(info, sizeof(info), "%d|hat", target);
    if (g_cvBuyEnableHats.BoolValue)
        menu.AddItem(info, "Change Hat");
    else
        menu.AddItem(info, "Change Hat (Disabled)", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "%d|rename", target);
    menu.AddItem(info, "Rename Robot");
    
    Format(info, sizeof(info), "%d|taunt", target);
    menu.AddItem(info, "Make Robot Taunt");
    
    Format(info, sizeof(info), "%d|teleport", target);
    menu.AddItem(info, "Teleport to Me");

    Format(info, sizeof(info), "%d|freeze", target);
    if (g_bRobotFrozen[target])
        menu.AddItem(info, "Unfreeze Robot");
    else
        menu.AddItem(info, "Freeze Robot (Statue)");
    
    if (TF2_GetPlayerClass(target) == TFClass_Engineer)
    {
        Format(info, sizeof(info), "%d|build", target);
        menu.AddItem(info, "Move Nest (Crosshair)");

        Format(info, sizeof(info), "%d|togglehelp", target);
        if (g_bEngineerHelpDisabled[target])
            menu.AddItem(info, "Help Teammates [OFF]");
        else
            menu.AddItem(info, "Help Teammates [ON]");
    }
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_RobotCustomize(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        char actionType[16];
        strcopy(actionType, sizeof(actionType), parts[1]);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target] || g_iBuyRobotOwner[target] != client)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            Command_MyRobots(client, 0);
            return 0;
        }
        
        if (StrEqual(actionType, "hat"))
        {
            if (!g_cvBuyEnableHats.BoolValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Hat system is currently disabled!");
                ShowRobotCustomizeMenu(client, target);
                return 0;
            }
            ShowHatMenu(client, target);
        }
        else if (StrEqual(actionType, "rename"))
        {
            ShowRenameMenu(client, target);
        }
        else if (StrEqual(actionType, "taunt"))
        {
            MakeRobotTaunt(client, target);
            ShowRobotCustomizeMenu(client, target);
        }
        else if (StrEqual(actionType, "teleport"))
        {
            TeleportRobotToOwner(client, target);
            ShowRobotCustomizeMenu(client, target);
        }
        else if (StrEqual(actionType, "freeze"))
        {
            g_bRobotFrozen[target] = !g_bRobotFrozen[target];
            if (g_bRobotFrozen[target])
                SetEntityMoveType(target, MOVETYPE_NONE);
            else
                SetEntityMoveType(target, MOVETYPE_WALK);
            ShowRobotCustomizeMenu(client, target);
        }
        else if (StrEqual(actionType, "build"))
        {
            CommandEngineerMoveNest(client, target);
            ShowRobotCustomizeMenu(client, target);
        }
        else if (StrEqual(actionType, "togglehelp"))
        {
            g_bEngineerHelpDisabled[target] = !g_bEngineerHelpDisabled[target];
            if (g_bEngineerHelpDisabled[target])
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Engineer will NO LONGER help teammates!");
            else
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Engineer will help teammates again!");
            ShowRobotCustomizeMenu(client, target);
        }
        else if (StrEqual(actionType, "back"))
        {
            Command_MyRobots(client, 0);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_MyRobots(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void MakeRobotTaunt(int client, int target)
{
    if (!IsPlayerAlive(target))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your robot is dead!");
        return;
    }
    
    FakeClientCommand(target, "taunt");
    
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    char nameColor[8] = "FFD700";
    if (StrContains(robotName, "Giant") != -1)
        nameColor = "8B008B";
    else if (StrContains(robotName, "Boss") != -1)
        nameColor = "FF1493";
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 \x07%s%s\x01 is taunting!", nameColor, robotName);
}

void ShowRenameMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    Menu menu = new Menu(MenuHandler_RenameRobot);
    
    char title[128];
    Format(title, sizeof(title), "Rename: %s\n \nType new name in chat (no spaces):\n ", robotName);
    menu.SetTitle(title);
    
    menu.AddItem("", "Type new name below:", ITEMDRAW_DISABLED);
    menu.AddItem("", " ", ITEMDRAW_SPACER);
    
    char info[16];
    IntToString(target, info, sizeof(info));
    menu.AddItem(info, "Cancel");
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    g_iWaitingForRename[client] = target;
}

void ShowHatMenu(int client, int target)
{
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    TFClassType class = TF2_GetPlayerClass(target);
    
    Menu menu = new Menu(MenuHandler_HatSelect);
    
    char title[128];
    Format(title, sizeof(title), "Change Hat for: %s\n ", robotName);
    menu.SetTitle(title);
    
    char info[32];
    bool hatsEnabled = g_cvBuyEnableHats.BoolValue;
    
    if (hatsEnabled)
    {
        Format(info, sizeof(info), "%d|random", target);
        menu.AddItem(info, "Random Hat");
        
        Format(info, sizeof(info), "%d|remove", target);
        menu.AddItem(info, "Remove Hat");
    }
    else
    {
        menu.AddItem("", "Random Hat (Hats Disabled)", ITEMDRAW_DISABLED);
        menu.AddItem("", "Remove Hat (Hats Disabled)", ITEMDRAW_DISABLED);
    }
    menu.AddItem("", " ", ITEMDRAW_SPACER);
    
    Format(info, sizeof(info), "%d|116", target); menu.AddItem(info, "Ghastly Gibus");
    Format(info, sizeof(info), "%d|125", target); menu.AddItem(info, "Cheater's Lament");
    Format(info, sizeof(info), "%d|126", target); menu.AddItem(info, "Bill's Hat");
    Format(info, sizeof(info), "%d|135", target); menu.AddItem(info, "Towering Pillar of Hats");
    Format(info, sizeof(info), "%d|137", target); menu.AddItem(info, "Noble Amassment of Hats");
    Format(info, sizeof(info), "%d|139", target); menu.AddItem(info, "Modest Pile of Hat");
    Format(info, sizeof(info), "%d|162", target); menu.AddItem(info, "Max's Severed Head");
    Format(info, sizeof(info), "%d|261", target); menu.AddItem(info, "Mann Co. Cap");
    Format(info, sizeof(info), "%d|279", target); menu.AddItem(info, "Ghastlier Gibus");
    Format(info, sizeof(info), "%d|287", target); menu.AddItem(info, "Spine-Chilling Skull");
    Format(info, sizeof(info), "%d|289", target); menu.AddItem(info, "Voodoo Juju");
    Format(info, sizeof(info), "%d|291", target); menu.AddItem(info, "Horrific Headsplitter");
    Format(info, sizeof(info), "%d|334", target); menu.AddItem(info, "Hat of Undeniable Wealth");
    Format(info, sizeof(info), "%d|341", target); menu.AddItem(info, "A Rather Festive Tree");
    Format(info, sizeof(info), "%d|345", target); menu.AddItem(info, "Athletic Supporter");
    Format(info, sizeof(info), "%d|408", target); menu.AddItem(info, "Humanitarian's Hachimaki");
    Format(info, sizeof(info), "%d|409", target); menu.AddItem(info, "Benefactor's Kanmuri");
    Format(info, sizeof(info), "%d|410", target); menu.AddItem(info, "Magnanimous Monarch");
    Format(info, sizeof(info), "%d|420", target); menu.AddItem(info, "Aperture Labs Hard Hat");
    Format(info, sizeof(info), "%d|470", target); menu.AddItem(info, "Lo-Fi Longwave");
    Format(info, sizeof(info), "%d|471", target); menu.AddItem(info, "Proof of Purchase");
    Format(info, sizeof(info), "%d|473", target); menu.AddItem(info, "Spiral Sallet");
    Format(info, sizeof(info), "%d|492", target); menu.AddItem(info, "Summer Hat");
    Format(info, sizeof(info), "%d|523", target); menu.AddItem(info, "Company Man");
    Format(info, sizeof(info), "%d|537", target); menu.AddItem(info, "Birthday Hat");
    Format(info, sizeof(info), "%d|538", target); menu.AddItem(info, "Killer Exclusive");
    Format(info, sizeof(info), "%d|584", target); menu.AddItem(info, "Ghastlierest Gibus");
    Format(info, sizeof(info), "%d|598", target); menu.AddItem(info, "Manniversary Paper Hat");
    Format(info, sizeof(info), "%d|634", target); menu.AddItem(info, "Point and Shoot");
    Format(info, sizeof(info), "%d|666", target); menu.AddItem(info, "The B.M.O.C.");
    Format(info, sizeof(info), "%d|667", target); menu.AddItem(info, "The Holiday Headcase");
    Format(info, sizeof(info), "%d|668", target); menu.AddItem(info, "The Full Head of Steam");
    Format(info, sizeof(info), "%d|671", target); menu.AddItem(info, "The Brown Bomber");
    Format(info, sizeof(info), "%d|675", target); menu.AddItem(info, "The Ebenezer");
    Format(info, sizeof(info), "%d|702", target); menu.AddItem(info, "The Warsworn Helmet");
    Format(info, sizeof(info), "%d|711", target); menu.AddItem(info, "Dueler");
    Format(info, sizeof(info), "%d|712", target); menu.AddItem(info, "Gifting Man From Gifting Land");
    Format(info, sizeof(info), "%d|713", target); menu.AddItem(info, "Philateler");
    Format(info, sizeof(info), "%d|756", target); menu.AddItem(info, "The Bolt Action Blitzer");
    Format(info, sizeof(info), "%d|785", target); menu.AddItem(info, "Robot Chicken Hat");
    Format(info, sizeof(info), "%d|817", target); menu.AddItem(info, "The Human Cannonball");
    Format(info, sizeof(info), "%d|920", target); menu.AddItem(info, "The Crone's Dome");
    Format(info, sizeof(info), "%d|921", target); menu.AddItem(info, "The Executioner");
    Format(info, sizeof(info), "%d|940", target); menu.AddItem(info, "Ghostly Gibus");
    Format(info, sizeof(info), "%d|941", target); menu.AddItem(info, "The Skull Island Topper");
    Format(info, sizeof(info), "%d|942", target); menu.AddItem(info, "The Cockfighter");
    Format(info, sizeof(info), "%d|944", target); menu.AddItem(info, "That '70s Chapeau");
    Format(info, sizeof(info), "%d|984", target); menu.AddItem(info, "Tough Stuff Muffs");
    Format(info, sizeof(info), "%d|993", target); menu.AddItem(info, "Antlers");
    Format(info, sizeof(info), "%d|994", target); menu.AddItem(info, "Mann Co. Online Cap");
    Format(info, sizeof(info), "%d|1014", target); menu.AddItem(info, "The Brutal Bouffant");
    Format(info, sizeof(info), "%d|1033", target); menu.AddItem(info, "The TF2VRH");
    Format(info, sizeof(info), "%d|1034", target); menu.AddItem(info, "The Conspiracy Cap");
    Format(info, sizeof(info), "%d|1035", target); menu.AddItem(info, "The Public Accessor");
    Format(info, sizeof(info), "%d|1067", target); menu.AddItem(info, "The Grandmaster");
    Format(info, sizeof(info), "%d|1122", target); menu.AddItem(info, "Towering Pillar of Summer Shades");
    Format(info, sizeof(info), "%d|1899", target); menu.AddItem(info, "World Traveler");
    Format(info, sizeof(info), "%d|30001", target); menu.AddItem(info, "Modest Metal Pile of Scrap");
    Format(info, sizeof(info), "%d|30003", target); menu.AddItem(info, "The Galvanized Gibus");
    Format(info, sizeof(info), "%d|30006", target); menu.AddItem(info, "Noble Nickel Amassment of Hats");
    Format(info, sizeof(info), "%d|30008", target); menu.AddItem(info, "Towering Titanium Pillar of Hats");
    Format(info, sizeof(info), "%d|30058", target); menu.AddItem(info, "The Crosslinker's Coil");
    Format(info, sizeof(info), "%d|30065", target); menu.AddItem(info, "The Hardy Laurel");
    Format(info, sizeof(info), "%d|30066", target); menu.AddItem(info, "The Brotherhood of Arms");
    Format(info, sizeof(info), "%d|30140", target); menu.AddItem(info, "The Virtual Viewfinder");
    Format(info, sizeof(info), "%d|30177", target); menu.AddItem(info, "Hong Kong Cone");
    Format(info, sizeof(info), "%d|30307", target); menu.AddItem(info, "Neckwear Headwear");
    Format(info, sizeof(info), "%d|30313", target); menu.AddItem(info, "The Kiss King");
    Format(info, sizeof(info), "%d|30329", target); menu.AddItem(info, "The Polar Pullover");
    Format(info, sizeof(info), "%d|30362", target); menu.AddItem(info, "The Law");
    Format(info, sizeof(info), "%d|30422", target); menu.AddItem(info, "Viva La France");
    Format(info, sizeof(info), "%d|30425", target); menu.AddItem(info, "Tipped Lid");
    Format(info, sizeof(info), "%d|30469", target); menu.AddItem(info, "Horace");
    Format(info, sizeof(info), "%d|30473", target); menu.AddItem(info, "The MK 50");
    Format(info, sizeof(info), "%d|30542", target); menu.AddItem(info, "Coldsnap Cap");
    Format(info, sizeof(info), "%d|30546", target); menu.AddItem(info, "Boxcar Bomber");
    Format(info, sizeof(info), "%d|30549", target); menu.AddItem(info, "Winter Woodsman");
    Format(info, sizeof(info), "%d|30567", target); menu.AddItem(info, "Crown of the Old Kingdom");
    Format(info, sizeof(info), "%d|30571", target); menu.AddItem(info, "Brimstone");
    Format(info, sizeof(info), "%d|30607", target); menu.AddItem(info, "Pocket Raiser");
    Format(info, sizeof(info), "%d|30623", target); menu.AddItem(info, "The Rotation Sensation");
    Format(info, sizeof(info), "%d|30640", target); menu.AddItem(info, "Captain Cardbeard Cutthroat");
    Format(info, sizeof(info), "%d|30643", target); menu.AddItem(info, "Potassium Bonnett");
    Format(info, sizeof(info), "%d|30646", target); menu.AddItem(info, "Captain Space Mann");
    Format(info, sizeof(info), "%d|30647", target); menu.AddItem(info, "Phononaut");
    
    menu.AddItem("", " ", ITEMDRAW_SPACER);
    menu.AddItem("", "=== Class-Specific Hats ===", ITEMDRAW_DISABLED);
    
    switch (class)
    {
        case TFClass_Scout:
        {
            Format(info, sizeof(info), "%d|52", target); menu.AddItem(info, "Batter's Helmet");
            Format(info, sizeof(info), "%d|106", target); menu.AddItem(info, "Bonk Helm");
            Format(info, sizeof(info), "%d|107", target); menu.AddItem(info, "Ye Olde Baker Boy");
            Format(info, sizeof(info), "%d|150", target); menu.AddItem(info, "Troublemaker's Tossle Cap");
            Format(info, sizeof(info), "%d|174", target); menu.AddItem(info, "Whoopee Cap");
            Format(info, sizeof(info), "%d|219", target); menu.AddItem(info, "The Milkman");
            Format(info, sizeof(info), "%d|249", target); menu.AddItem(info, "Bombing Run");
            Format(info, sizeof(info), "%d|324", target); menu.AddItem(info, "Flipped Trilby");
            Format(info, sizeof(info), "%d|346", target); menu.AddItem(info, "The Superfan");
            Format(info, sizeof(info), "%d|453", target); menu.AddItem(info, "Hero's Tail");
            Format(info, sizeof(info), "%d|539", target); menu.AddItem(info, "The El Jefe");
            Format(info, sizeof(info), "%d|614", target); menu.AddItem(info, "The Hot Dogger");
            Format(info, sizeof(info), "%d|617", target); menu.AddItem(info, "The Backwards Ballcap");
            Format(info, sizeof(info), "%d|633", target); menu.AddItem(info, "The Hermes");
            Format(info, sizeof(info), "%d|652", target); menu.AddItem(info, "The Big Elfin Deal");
            Format(info, sizeof(info), "%d|760", target); menu.AddItem(info, "The Front Runner");
            Format(info, sizeof(info), "%d|765", target); menu.AddItem(info, "The Cross-Comm Express");
            Format(info, sizeof(info), "%d|780", target); menu.AddItem(info, "The Fed-Fightin' Fedora");
            Format(info, sizeof(info), "%d|788", target); menu.AddItem(info, "The Void Monk Hair");
            Format(info, sizeof(info), "%d|846", target); menu.AddItem(info, "The Robot Running Man");
        }
        case TFClass_Soldier:
        {
            Format(info, sizeof(info), "%d|54", target); menu.AddItem(info, "Soldier's Stash");
            Format(info, sizeof(info), "%d|98", target); menu.AddItem(info, "Stainless Pot");
            Format(info, sizeof(info), "%d|99", target); menu.AddItem(info, "Tyrant's Helm");
            Format(info, sizeof(info), "%d|152", target); menu.AddItem(info, "Killer's Kabuto");
            Format(info, sizeof(info), "%d|183", target); menu.AddItem(info, "Sergeant's Drill Hat");
            Format(info, sizeof(info), "%d|227", target); menu.AddItem(info, "The Grenadier's Softcap");
            Format(info, sizeof(info), "%d|240", target); menu.AddItem(info, "Lumbricus Lid");
            Format(info, sizeof(info), "%d|250", target); menu.AddItem(info, "Chieftain's Challenge");
            Format(info, sizeof(info), "%d|251", target); menu.AddItem(info, "Stout Shako");
            Format(info, sizeof(info), "%d|252", target); menu.AddItem(info, "Dr's Dapper Topper");
            Format(info, sizeof(info), "%d|339", target); menu.AddItem(info, "Exquisite Rack");
            Format(info, sizeof(info), "%d|340", target); menu.AddItem(info, "Defiant Spartan");
            Format(info, sizeof(info), "%d|360", target); menu.AddItem(info, "Hero's Hachimaki");
            Format(info, sizeof(info), "%d|378", target); menu.AddItem(info, "The Team Captain");
            Format(info, sizeof(info), "%d|391", target); menu.AddItem(info, "Honcho's Headgear");
            Format(info, sizeof(info), "%d|395", target); menu.AddItem(info, "Furious Fukaamigasa");
            Format(info, sizeof(info), "%d|417", target); menu.AddItem(info, "Jumper's Jeepcap");
            Format(info, sizeof(info), "%d|434", target); menu.AddItem(info, "Brain Bucket");
            Format(info, sizeof(info), "%d|439", target); menu.AddItem(info, "Lord Cockswain's Pith Helmet");
            Format(info, sizeof(info), "%d|445", target); menu.AddItem(info, "Armored Authority");
        }
        case TFClass_Pyro:
        {
            Format(info, sizeof(info), "%d|51", target); menu.AddItem(info, "Pyro's Beanie");
            Format(info, sizeof(info), "%d|102", target); menu.AddItem(info, "Respectless Rubber Glove");
            Format(info, sizeof(info), "%d|105", target); menu.AddItem(info, "Brigade Helm");
            Format(info, sizeof(info), "%d|151", target); menu.AddItem(info, "Triboniophorus Tyrannus");
            Format(info, sizeof(info), "%d|182", target); menu.AddItem(info, "Vintage Merryweather");
            Format(info, sizeof(info), "%d|213", target); menu.AddItem(info, "The Attendant");
            Format(info, sizeof(info), "%d|247", target); menu.AddItem(info, "Old Guadalajara");
            Format(info, sizeof(info), "%d|248", target); menu.AddItem(info, "Napper's Respite");
            Format(info, sizeof(info), "%d|253", target); menu.AddItem(info, "Handyman's Handle");
            Format(info, sizeof(info), "%d|316", target); menu.AddItem(info, "Pyromancer's Mask");
            Format(info, sizeof(info), "%d|318", target); menu.AddItem(info, "Prancer's Pride");
            Format(info, sizeof(info), "%d|321", target); menu.AddItem(info, "Madame Dixie");
            Format(info, sizeof(info), "%d|377", target); menu.AddItem(info, "Hottie's Hoodie");
            Format(info, sizeof(info), "%d|394", target); menu.AddItem(info, "Connoisseur's Cap");
            Format(info, sizeof(info), "%d|435", target); menu.AddItem(info, "Dead Cone");
            Format(info, sizeof(info), "%d|481", target); menu.AddItem(info, "Stately Steel Toe");
            Format(info, sizeof(info), "%d|597", target); menu.AddItem(info, "The Bubble Pipe");
            Format(info, sizeof(info), "%d|612", target); menu.AddItem(info, "The Little Buddy");
            Format(info, sizeof(info), "%d|615", target); menu.AddItem(info, "The Birdcage");
            Format(info, sizeof(info), "%d|627", target); menu.AddItem(info, "The Flamboyant Flamenco");
        }
        case TFClass_DemoMan:
        {
            Format(info, sizeof(info), "%d|47", target); menu.AddItem(info, "Demoman's 'Fro");
            Format(info, sizeof(info), "%d|100", target); menu.AddItem(info, "Glengarry Bonnet");
            Format(info, sizeof(info), "%d|120", target); menu.AddItem(info, "Scottsman's Stove Pipe");
            Format(info, sizeof(info), "%d|146", target); menu.AddItem(info, "Hustler's Hallmark");
            Format(info, sizeof(info), "%d|179", target); menu.AddItem(info, "Tippler's Tricorne");
            Format(info, sizeof(info), "%d|216", target); menu.AddItem(info, "Rimmed Raincatcher");
            Format(info, sizeof(info), "%d|255", target); menu.AddItem(info, "Sober Stuntman");
            Format(info, sizeof(info), "%d|259", target); menu.AddItem(info, "Carouser's Capotain");
            Format(info, sizeof(info), "%d|306", target); menu.AddItem(info, "Scotch Bonnet");
            Format(info, sizeof(info), "%d|342", target); menu.AddItem(info, "Prince Tavish's Crown");
            Format(info, sizeof(info), "%d|359", target); menu.AddItem(info, "Samur-Eye");
            Format(info, sizeof(info), "%d|388", target); menu.AddItem(info, "Private Eye");
            Format(info, sizeof(info), "%d|390", target); menu.AddItem(info, "Reggaelator");
            Format(info, sizeof(info), "%d|403", target); menu.AddItem(info, "Sultan's Ceremonial");
            Format(info, sizeof(info), "%d|465", target); menu.AddItem(info, "Conjurer's Cowl");
            Format(info, sizeof(info), "%d|480", target); menu.AddItem(info, "Tam O'Shanter");
            Format(info, sizeof(info), "%d|514", target); menu.AddItem(info, "Mask of the Shaman");
            Format(info, sizeof(info), "%d|605", target); menu.AddItem(info, "The Tavish DeGroot Experience");
            Format(info, sizeof(info), "%d|607", target); menu.AddItem(info, "The Buccaneer's Bicorne");
            Format(info, sizeof(info), "%d|703", target); menu.AddItem(info, "The Bolgan");
        }
        case TFClass_Heavy:
        {
            Format(info, sizeof(info), "%d|49", target); menu.AddItem(info, "Football Helmet");
            Format(info, sizeof(info), "%d|96", target); menu.AddItem(info, "Officer's Ushanka");
            Format(info, sizeof(info), "%d|97", target); menu.AddItem(info, "Tough Guy's Toque");
            Format(info, sizeof(info), "%d|145", target); menu.AddItem(info, "Hound Dog");
            Format(info, sizeof(info), "%d|185", target); menu.AddItem(info, "Heavy Duty Rag");
            Format(info, sizeof(info), "%d|246", target); menu.AddItem(info, "Pugilist's Protector");
            Format(info, sizeof(info), "%d|254", target); menu.AddItem(info, "Hard Counter");
            Format(info, sizeof(info), "%d|290", target); menu.AddItem(info, "Cadaver's Cranium");
            Format(info, sizeof(info), "%d|292", target); menu.AddItem(info, "Poker Visor");
            Format(info, sizeof(info), "%d|309", target); menu.AddItem(info, "Big Chief");
            Format(info, sizeof(info), "%d|313", target); menu.AddItem(info, "Magnificent Mongolian");
            Format(info, sizeof(info), "%d|330", target); menu.AddItem(info, "Coupe D'isaster");
            Format(info, sizeof(info), "%d|358", target); menu.AddItem(info, "Dread Knot");
            Format(info, sizeof(info), "%d|378", target); menu.AddItem(info, "The Team Captain");
            Format(info, sizeof(info), "%d|427", target); menu.AddItem(info, "Capo's Capper");
            Format(info, sizeof(info), "%d|478", target); menu.AddItem(info, "Copper's Hard Top");
            Format(info, sizeof(info), "%d|515", target); menu.AddItem(info, "Pilotka");
            Format(info, sizeof(info), "%d|517", target); menu.AddItem(info, "Dragonborn Helmet");
            Format(info, sizeof(info), "%d|535", target); menu.AddItem(info, "Storm Spirit's Jolly Hat");
            Format(info, sizeof(info), "%d|585", target); menu.AddItem(info, "Cold War Luchador");
        }
        case TFClass_Engineer:
        {
            Format(info, sizeof(info), "%d|48", target); menu.AddItem(info, "Mining Light");
            Format(info, sizeof(info), "%d|94", target); menu.AddItem(info, "Texas Ten Gallon");
            Format(info, sizeof(info), "%d|95", target); menu.AddItem(info, "Engineer's Cap");
            Format(info, sizeof(info), "%d|148", target); menu.AddItem(info, "Hotrod");
            Format(info, sizeof(info), "%d|178", target); menu.AddItem(info, "Safe'n'Sound");
            Format(info, sizeof(info), "%d|322", target); menu.AddItem(info, "Buckaroo's Hat");
            Format(info, sizeof(info), "%d|338", target); menu.AddItem(info, "Industrial Festivizer");
            Format(info, sizeof(info), "%d|379", target); menu.AddItem(info, "Western Wear");
            Format(info, sizeof(info), "%d|382", target); menu.AddItem(info, "Big Country");
            Format(info, sizeof(info), "%d|384", target); menu.AddItem(info, "Professor's Peculiarity");
            Format(info, sizeof(info), "%d|389", target); menu.AddItem(info, "Ol' Geezer");
            Format(info, sizeof(info), "%d|399", target); menu.AddItem(info, "Hetman's Headpiece");
            Format(info, sizeof(info), "%d|436", target); menu.AddItem(info, "Pip-Boy");
            Format(info, sizeof(info), "%d|533", target); menu.AddItem(info, "Clockwerk's Helm");
            Format(info, sizeof(info), "%d|590", target); menu.AddItem(info, "The Brainiac Hairpiece");
            Format(info, sizeof(info), "%d|605", target); menu.AddItem(info, "The Pencil Pusher");
            Format(info, sizeof(info), "%d|628", target); menu.AddItem(info, "The Virtual Reality Headset");
            Format(info, sizeof(info), "%d|755", target); menu.AddItem(info, "The Texas Half-Pants");
            Format(info, sizeof(info), "%d|848", target); menu.AddItem(info, "The Tin-1000");
            Format(info, sizeof(info), "%d|988", target); menu.AddItem(info, "The Barnstormer");
        }
        case TFClass_Medic:
        {
            Format(info, sizeof(info), "%d|50", target); menu.AddItem(info, "Prussian Pickelhaube");
            Format(info, sizeof(info), "%d|101", target); menu.AddItem(info, "Vintage Tyrolean");
            Format(info, sizeof(info), "%d|104", target); menu.AddItem(info, "Otolaryngologist's Mirror");
            Format(info, sizeof(info), "%d|177", target); menu.AddItem(info, "Ze Goggles");
            Format(info, sizeof(info), "%d|184", target); menu.AddItem(info, "Gentleman's Gatsby");
            Format(info, sizeof(info), "%d|303", target); menu.AddItem(info, "Berliner's Bucket Helm");
            Format(info, sizeof(info), "%d|323", target); menu.AddItem(info, "German Gonzila");
            Format(info, sizeof(info), "%d|363", target); menu.AddItem(info, "Geisha Boy");
            Format(info, sizeof(info), "%d|378", target); menu.AddItem(info, "The Team Captain");
            Format(info, sizeof(info), "%d|381", target); menu.AddItem(info, "Medic's Mountain Cap");
            Format(info, sizeof(info), "%d|383", target); menu.AddItem(info, "Grimm Hatte");
            Format(info, sizeof(info), "%d|388", target); menu.AddItem(info, "Private Eye");
            Format(info, sizeof(info), "%d|398", target); menu.AddItem(info, "Doctor's Sack");
            Format(info, sizeof(info), "%d|467", target); menu.AddItem(info, "Planeswalker Helm");
            Format(info, sizeof(info), "%d|616", target); menu.AddItem(info, "The Surgeon's Stahlhelm");
            Format(info, sizeof(info), "%d|778", target); menu.AddItem(info, "The Gentlemen's Ushanka");
            Format(info, sizeof(info), "%d|867", target); menu.AddItem(info, "The Combat Medic's Crusher Cap");
            Format(info, sizeof(info), "%d|878", target); menu.AddItem(info, "The Foppish Physician");
            Format(info, sizeof(info), "%d|978", target); menu.AddItem(info, "Der Wintermantel");
            Format(info, sizeof(info), "%d|982", target); menu.AddItem(info, "Doc's Holiday");
        }
        case TFClass_Sniper:
        {
            Format(info, sizeof(info), "%d|53", target); menu.AddItem(info, "Trophy Belt");
            Format(info, sizeof(info), "%d|109", target); menu.AddItem(info, "Professional's Panama");
            Format(info, sizeof(info), "%d|158", target); menu.AddItem(info, "Shooter's Sola Topi");
            Format(info, sizeof(info), "%d|181", target); menu.AddItem(info, "Bloke's Bucket Hat");
            Format(info, sizeof(info), "%d|229", target); menu.AddItem(info, "Ol' Snaggletooth");
            Format(info, sizeof(info), "%d|314", target); menu.AddItem(info, "Larrikin Robin");
            Format(info, sizeof(info), "%d|344", target); menu.AddItem(info, "Crocleather Slouch");
            Format(info, sizeof(info), "%d|400", target); menu.AddItem(info, "Desert Marauder");
            Format(info, sizeof(info), "%d|518", target); menu.AddItem(info, "The Anger");
            Format(info, sizeof(info), "%d|600", target); menu.AddItem(info, "Your Worst Nightmare");
            Format(info, sizeof(info), "%d|618", target); menu.AddItem(info, "The Crocodile Smile");
            Format(info, sizeof(info), "%d|626", target); menu.AddItem(info, "The Swagman's Swatter");
            Format(info, sizeof(info), "%d|720", target); menu.AddItem(info, "The Bushman's Boonie");
            Format(info, sizeof(info), "%d|759", target); menu.AddItem(info, "The Fruit Shoot");
            Format(info, sizeof(info), "%d|762", target); menu.AddItem(info, "Flamingo Kid");
            Format(info, sizeof(info), "%d|779", target); menu.AddItem(info, "Liquidator's Lid");
            Format(info, sizeof(info), "%d|819", target); menu.AddItem(info, "The Lone Star");
            Format(info, sizeof(info), "%d|847", target); menu.AddItem(info, "The Bolted Bushman");
            Format(info, sizeof(info), "%d|877", target); menu.AddItem(info, "The Stovepipe Sniper Shako");
            Format(info, sizeof(info), "%d|981", target); menu.AddItem(info, "The Cold Killer");
        }
        case TFClass_Spy:
        {
            Format(info, sizeof(info), "%d|55", target); menu.AddItem(info, "Fancy Fedora");
            Format(info, sizeof(info), "%d|108", target); menu.AddItem(info, "Backbiter's Billycock");
            Format(info, sizeof(info), "%d|147", target); menu.AddItem(info, "Magistrate's Mullet");
            Format(info, sizeof(info), "%d|180", target); menu.AddItem(info, "Frenchman's Beret");
            Format(info, sizeof(info), "%d|223", target); menu.AddItem(info, "The Familiar Fez");
            Format(info, sizeof(info), "%d|319", target); menu.AddItem(info, "Detective Noir");
            Format(info, sizeof(info), "%d|361", target); menu.AddItem(info, "Noh Mercy");
            Format(info, sizeof(info), "%d|388", target); menu.AddItem(info, "Private Eye");
            Format(info, sizeof(info), "%d|397", target); menu.AddItem(info, "Charmer's Chapeau");
            Format(info, sizeof(info), "%d|437", target); menu.AddItem(info, "Janissary Ketche");
            Format(info, sizeof(info), "%d|459", target); menu.AddItem(info, "Cosa Nostra Cap");
            Format(info, sizeof(info), "%d|521", target); menu.AddItem(info, "Nanobalaclava");
            Format(info, sizeof(info), "%d|602", target); menu.AddItem(info, "The Counterfeit Billycock");
            Format(info, sizeof(info), "%d|622", target); menu.AddItem(info, "L'Inspecteur");
            Format(info, sizeof(info), "%d|637", target); menu.AddItem(info, "The Dashin' Hashshashin");
            Format(info, sizeof(info), "%d|789", target); menu.AddItem(info, "The Ninja Cowl");
            Format(info, sizeof(info), "%d|841", target); menu.AddItem(info, "The Stealth Steeler");
            Format(info, sizeof(info), "%d|872", target); menu.AddItem(info, "The Lacking Moral Fiber Mask");
            Format(info, sizeof(info), "%d|879", target); menu.AddItem(info, "The Distinguished Rogue");
            Format(info, sizeof(info), "%d|977", target); menu.AddItem(info, "The Cut-Throat Concierge");
        }
    }
    
    menu.AddItem("", " ", ITEMDRAW_SPACER);
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_HatSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        char hatType[16];
        strcopy(hatType, sizeof(hatType), parts[1]);
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target] || g_iBuyRobotOwner[target] != client)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            Command_MyRobots(client, 0);
            return 0;
        }
        
        if (StrEqual(hatType, "random"))
        {
            g_iBuyRobotHatIndex[target] = 0;
            BuyRobot_RemoveWearables(target);
            BuyRobot_EquipHat(target);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 New random hat applied to your robot!");
            ShowHatMenu(client, target);
        }
        else if (StrEqual(hatType, "remove"))
        {
            g_iBuyRobotHatIndex[target] = 0;
            BuyRobot_RemoveWearables(target);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Hat removed from your robot!");
            ShowHatMenu(client, target);
        }
        else if (StrEqual(hatType, "back"))
        {
            ShowRobotCustomizeMenu(client, target);
        }
        else
        {
            int hatIndex = StringToInt(hatType);
            g_iBuyRobotHatIndex[target] = hatIndex;
            BuyRobot_RemoveWearables(target);
            BuyRobot_EquipHat(target);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Hat applied to your robot!");
            ShowHatMenu(client, target);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char info[32];
        menu.GetItem(0, info, sizeof(info));
        char parts[2][16];
        ExplodeString(info, "|", parts, 2, 16);
        int target = StringToInt(parts[0]);
        ShowRobotCustomizeMenu(param1, target);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void TeleportRobotToOwner(int client, int target)
{
    if (!IsPlayerAlive(target))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your robot is dead! Wait for it to respawn.");
        return;
    }
    
    float currentTime = GetGameTime();
    if (currentTime - g_flLastTeleportTime[client] < TELEPORT_COOLDOWN)
    {
        int remaining = RoundToCeil(TELEPORT_COOLDOWN - (currentTime - g_flLastTeleportTime[client]));
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Cooldown! \x07FFD700%d\x01 seconds remaining.", remaining);
        return;
    }
    
    g_flLastTeleportTime[client] = currentTime;
    
    float ownerPos[3];
    GetClientAbsOrigin(client, ownerPos);
    ownerPos[2] += 20.0;
    
    float angles[3];
    GetClientEyeAngles(client, angles);
    angles[0] = 0.0;
    
    TeleportEntity(target, ownerPos, angles, NULL_VECTOR);
    
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    char nameColor[8] = "FFD700";
    if (StrContains(robotName, "Giant") != -1)
        nameColor = "8B008B";
    else if (StrContains(robotName, "Boss") != -1)
        nameColor = "FF1493";
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 \x07%s%s\x01 teleported to you!", nameColor, robotName);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (g_iWaitingForRename[client] > 0)
    {
        int target = g_iWaitingForRename[client];
        g_iWaitingForRename[client] = 0;
        
        bool isAdmin = GetUserAdmin(client) != INVALID_ADMIN_ID;
        
        if (!IsClientInGame(target) || !g_bBuyIsPurchasedRobot[target])
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is no longer available!");
            return Plugin_Handled;
        }
        
        if (!isAdmin && g_iBuyRobotOwner[target] != client)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot does not belong to you!");
            return Plugin_Handled;
        }
        
        char newName[64];
        strcopy(newName, sizeof(newName), sArgs);
        StripQuotes(newName);
        TrimString(newName);
        
        if (strlen(newName) < 3)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Name must be at least 3 characters!");
            return Plugin_Handled;
        }
        
        if (strlen(newName) > 32)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Name must be 32 characters or less!");
            return Plugin_Handled;
        }
        
        if (DoesAnyPlayerUseThisName(newName))
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This name is already in use!");
            return Plugin_Handled;
        }
        
        char oldName[64];
        GetClientName(target, oldName, sizeof(oldName));
        
        bool isGiant = (StrContains(oldName, "Giant") != -1);
        bool isBoss = (StrContains(oldName, "Boss") != -1);
        
        char finalName[64];
        if (isGiant)
            Format(finalName, sizeof(finalName), "Giant %s", newName);
        else if (isBoss)
            Format(finalName, sizeof(finalName), "Boss %s", newName);
        else
            strcopy(finalName, sizeof(finalName), newName);
        
        SetClientName(target, finalName);
        
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robot renamed to: \x07FFD700%s\x01", finalName);
        
        if (isAdmin)
            Command_AdminRobots(client, 0);
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public int MenuHandler_RenameRobot(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        g_iWaitingForRename[param1] = 0;
    }
    else if (action == MenuAction_Cancel)
    {
        g_iWaitingForRename[param1] = 0;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action BuyRobot_Command(int client, int args)
{
    if (!BuyRobot_CanUseMenu(client)) return Plugin_Handled;
    if (!g_cvBuyEnable.BoolValue) return Plugin_Handled;
    
    TFTeam team = TF2_GetClientTeam(client);
    
    if (team != TFTeam_Red && team != TFTeam_Blue)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You must be on \x07FF4500Mann Co.\x01 or \x0742A5F5Invaders\x01 team!");
        return Plugin_Handled;
    }
    
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
    {
        if (team == TFTeam_Blue)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Invaders team can only buy robots during the wave!");
            return Plugin_Handled;
        }
        
        if (g_cvBuyKickOnWaveEnd.BoolValue)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You can only buy robots during the wave!");
            return Plugin_Handled;
        }
        
        BuyRobot_ShowMainMenu(client, team);
        return Plugin_Handled;
    }
    
    BuyRobot_ShowMainMenu(client, team);
    return Plugin_Handled;
}

public Action BuyRobot_ShowPoints(int client, int args)
{
    if (IsValidClientIndex(client))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You have \x07FFD700%d\x01 points!", g_iBuyPlayerPoints[client]);
    }
    return Plugin_Handled;
}

public Action Command_ShowTopPoints(int client, int args)
{
    if (!IsValidClientIndex(client)) return Plugin_Handled;
    BuyRobot_ShowTop10(client);
    return Plugin_Handled;
}

public Action Command_ShowRank(int client, int args)
{
    if (!IsValidClientIndex(client)) return Plugin_Handled;
    
    int rank = BuyRobot_GetPlayerRank(client);
    int total = BuyRobot_GetTotalPlayersWithPoints();
    
    if (rank == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You don't have any points yet!");
    }
    else
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your rank: \x07FFD700#%d\x01 of \x07FFD700%d\x01 players (\x07FFD700%d\x01 points)", 
            rank, total, g_iBuyPlayerPoints[client]);
    }
    
    return Plugin_Handled;
}

public int MenuHandler_VoteSaxton(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_VoteEnd)
    {
        char item[2];
        menu.GetItem(param1, item, sizeof(item));
        int choice = StringToInt(item);
        
        if (choice == 1)
        {
            g_cvBuySaxtonAI.SetInt(1);
            PrintToChatAll("\x07FF4500[Vote]\x01 Saxton Hale AI (Mann Co.) has been ENABLED!");
            LogMessage("[BuyRobot] Saxton Hale AI (Mann Co.) enabled by vote.");
            
            if (GameRules_GetRoundState() == RoundState_RoundRunning)
            {
                CreateTimer(0.5, Timer_SaxtonAI, _, TIMER_REPEAT);
                PrintToChatAll("\x07FF4500[Saxton Hale]\x01 Reinforcements may now arrive!");
            }
        }
        else
        {
            g_cvBuySaxtonAI.SetInt(0);
            PrintToChatAll("\x07FF4500[Vote]\x01 Saxton Hale AI (Mann Co.) has been DISABLED!");
            LogMessage("[BuyRobot] Saxton Hale AI (Mann Co.) disabled by vote.");
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int MenuHandler_VoteGray(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_VoteEnd)
    {
        char item[2];
        menu.GetItem(param1, item, sizeof(item));
        int choice = StringToInt(item);
        
        if (choice == 1)
        {
            g_cvGrayMannAI.SetInt(1);
            PrintToChatAll("\x075A9BDF[Vote]\x01 Gray Mann AI (Invaders) has been ENABLED!");
            LogMessage("[BuyRobot] Gray Mann AI (Invaders) enabled by vote.");
            
            if (GameRules_GetRoundState() == RoundState_RoundRunning)
            {
                CreateTimer(0.5, Timer_GrayMann, _, TIMER_REPEAT);
                PrintToChatAll("\x075A9BDF[Gray Mann]\x01 Reinforcements may now arrive!");
            }
        }
        else
        {
            g_cvGrayMannAI.SetInt(0);
            PrintToChatAll("\x075A9BDF[Vote]\x01 Gray Mann AI (Invaders) has been DISABLED!");
            LogMessage("[BuyRobot] Gray Mann AI (Invaders) disabled by vote.");
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_VoteSaxton(int client, int args)
{
    if (!IsValidClientIndex(client))
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 You cannot use this command.");
        return Plugin_Handled;
    }
    
    if (g_bSaxtonVoteOnCooldown)
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 Vote is on cooldown. Please wait 60 seconds.");
        return Plugin_Handled;
    }
    
    if (IsVoteInProgress())
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 A vote is already in progress.");
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(MenuHandler_VoteSaxton);
    menu.SetTitle("Enable Saxton Hale AI (Mann Co.)?");
    menu.AddItem("1", "Yes, enable Saxton Hale AI");
    menu.AddItem("0", "No, disable Saxton Hale AI");
    menu.ExitButton = true;
    
    int[] players = new int[MaxClients];
    int total = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            players[total++] = i;
        }
    }
    
    if (total == 0)
    {
        delete menu;
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 No players to vote.");
        return Plugin_Handled;
    }
    
    g_bSaxtonVoteOnCooldown = true;
    CreateTimer(VOTE_COOLDOWNAI, Timer_ResetSaxtonCooldown);
    
    VoteMenu(menu, players, total, 20);
    PrintToChatAll("\x07FF4500[Vote]\x01 %N started a vote to change Saxton Hale AI (Mann Co.).", client);
    
    return Plugin_Handled;
}

public Action Command_VoteGray(int client, int args)
{
    if (!IsValidClientIndex(client))
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 You cannot use this command.");
        return Plugin_Handled;
    }
    
    if (g_bGrayVoteOnCooldown)
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 Vote is on cooldown. Please wait 60 seconds.");
        return Plugin_Handled;
    }
    
    if (IsVoteInProgress())
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 A vote is already in progress.");
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(MenuHandler_VoteGray);
    menu.SetTitle("Enable Gray Mann AI (Invaders)?");
    menu.AddItem("1", "Yes, enable Gray Mann AI");
    menu.AddItem("0", "No, disable Gray Mann AI");
    menu.ExitButton = true;
    
    int[] players = new int[MaxClients];
    int total = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            players[total++] = i;
        }
    }
    
    if (total == 0)
    {
        delete menu;
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 No players to vote.");
        return Plugin_Handled;
    }
    
    g_bGrayVoteOnCooldown = true;
    CreateTimer(VOTE_COOLDOWNAI, Timer_ResetGrayCooldown);
    
    VoteMenu(menu, players, total, 20);
    PrintToChatAll("\x075A9BDF[Vote]\x01 %N started a vote to change Gray Mann AI (Invaders).", client);
    
    return Plugin_Handled;
}

public Action Timer_ResetSaxtonCooldown(Handle timer)
{
    g_bSaxtonVoteOnCooldown = false;
    return Plugin_Stop;
}

public Action Timer_ResetGrayCooldown(Handle timer)
{
    g_bGrayVoteOnCooldown = false;
    return Plugin_Stop;
}

public Action Command_BotHelp(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    Menu menu = new Menu(MenuHandler_HelpMain);
    menu.SetTitle("Defender Bots & Buy Robot - Help Menu\n ");
    menu.AddItem("info", "Server Stats");
    menu.AddItem("defender", "Defender Bots Commands");
    menu.AddItem("buyrobot", "Buy Robot Commands");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public int MenuHandler_HelpMain(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "close"))
        {
        }
        else if (StrEqual(info, "info"))
        {
            Command_ServerInfo(param1, 0);
        }
        else if (StrEqual(info, "defender"))
        {
            ShowDefenderHelpMenu(param1);
        }
        else if (StrEqual(info, "buyrobot"))
        {
            ShowBuyRobotHelpMenu(param1);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void AddToWaitingQueue(int buyer, const char[] class, int lives, const char[] prefix, TFTeam team, int price, int botCount, int category)
{
    char data[256];
    Format(data, sizeof(data), "%d|%s|%d|%s|%d|%d|%d|%d", 
        GetClientUserId(buyer), class, lives, prefix, view_as<int>(team), price, botCount, category);
    
    g_hWaitingQueue.PushString(data);
    
    if (g_hWaitingQueue.Length == 1)
    {
        CreateTimer(3.0, Timer_ProcessWaitingQueue, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

int GetWaitingCountForPlayer(int client)
{
    int count = 0;
    int userId = GetClientUserId(client);
    
    for (int i = 0; i < g_hWaitingQueue.Length; i++)
    {
        char data[256];
        g_hWaitingQueue.GetString(i, data, sizeof(data));
        
        char parts[8][32];
        ExplodeString(data, "|", parts, 8, 32);
        int queueUserId = StringToInt(parts[0]);
        
        if (queueUserId == userId)
            count++;
    }
    
    return count;
}

int GetTotalWaitingCount()
{
    return g_hWaitingQueue.Length;
}

void ClearWaitingQueueForPlayer(int client)
{
    int userId = GetClientUserId(client);
    
    for (int i = g_hWaitingQueue.Length - 1; i >= 0; i--)
    {
        char data[256];
        g_hWaitingQueue.GetString(i, data, sizeof(data));
        
        char parts[8][32];
        ExplodeString(data, "|", parts, 8, 32);
        int queueUserId = StringToInt(parts[0]);
        
        if (queueUserId == userId)
        {
            g_hWaitingQueue.Erase(i);
        }
    }
}

public Action Timer_ProcessWaitingQueue(Handle timer)
{
    if (g_hWaitingQueue == null || g_hWaitingQueue.Length == 0)
        return Plugin_Stop;
    
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return Plugin_Continue;
    
    int currentBots = BuyRobot_GetPurchasedCount();
    int maxBots = g_cvBuyMaxBots.IntValue;
    
    if (currentBots >= maxBots)
        return Plugin_Continue;
    
    int slotsAvailable = maxBots - currentBots;
    int processed = 0;
    
    for (int i = 0; i < g_hWaitingQueue.Length && processed < slotsAvailable; i++)
    {
        char data[256];
        g_hWaitingQueue.GetString(i, data, sizeof(data));
        
        char parts[8][32];
        ExplodeString(data, "|", parts, 8, 32);
        
        int buyerId = StringToInt(parts[0]);
        char class[32]; strcopy(class, sizeof(class), parts[1]);
        int lives = StringToInt(parts[2]);
        char prefix[32]; strcopy(prefix, sizeof(prefix), parts[3]);
        TFTeam team = view_as<TFTeam>(StringToInt(parts[4]));
        int botCount = StringToInt(parts[6]);
        
        if (currentBots + botCount <= maxBots)
        {
            g_hWaitingQueue.Erase(i);
            i--;
            
            int buyer = GetClientOfUserId(buyerId);
            
            if (buyer > 0 && IsClientInGame(buyer))
            {
                for (int j = 0; j < botCount; j++)
                {
                    BuyRobot_CreateBot(class, buyer, lives, prefix, false, team);
                }
                
                char className[32];
                BuyRobot_GetClassName(class, className, sizeof(className));
                PrintToChat(buyer, "\x0732CD32[Buy Robot]\x01 Your %s has spawned from the waiting queue!", className);
            }
            
            currentBots += botCount;
            processed += botCount;
        }
    }
    
    if (g_hWaitingQueue.Length > 0)
        return Plugin_Continue;
    
    return Plugin_Stop;
}

public Action Command_ShowQueue(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    if (g_hWaitingQueue == null || g_hWaitingQueue.Length == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Waiting queue is empty.");
        return Plugin_Handled;
    }
    
    int userQueueCount = GetWaitingCountForPlayer(client);
    int totalQueue = g_hWaitingQueue.Length;
    int currentBots = BuyRobot_GetPurchasedCount();
    int maxBots = g_cvBuyMaxBots.IntValue;
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Bots: %d/%d | Queue: %d total | Your queue: %d/%d", 
        currentBots, maxBots, totalQueue, userQueueCount, g_cvMaxWaitingQueuePerPlayer.IntValue);
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Use !cancelqueue to remove your waiting robots.");
    
    return Plugin_Handled;
}

public Action Command_CancelQueue(int client, int args)
{
    if (!IsValidClientIndex(client))
        return Plugin_Handled;
    
    int waitingCount = GetWaitingCountForPlayer(client);
    if (waitingCount == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You have no robots in the waiting queue.");
        return Plugin_Handled;
    }
    
    ClearWaitingQueueForPlayer(client);
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your %d waiting robots have been removed.", waitingCount);
    
    return Plugin_Handled;
}

void ShowDefenderHelpMenu(int client)
{
    Menu menu = new Menu(MenuHandler_DefenderHelp);
    menu.SetTitle("Defender Bots Commands\n ");
    menu.AddItem("sm_votebots", "Vote to enable bots");
    menu.AddItem("sm_botpref", "Set bot preferences");
    menu.AddItem("sm_viewbotchances", "View bot class chances");
    menu.AddItem("sm_viewbotlineup", "View next bot lineup");
    menu.AddItem("sm_rerollbotclasses", "Reshuffle bot lineup");
    menu.AddItem("sm_playwithbots", "Join BLUE and play with bots");
    menu.AddItem("sm_requestbot", "Request extra bot");
    menu.AddItem("sm_choosebotteam", "Choose bot team lineup");
    menu.AddItem("sm_redobots", "Repick bot team lineup");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_DefenderHelp(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "close"))
        {
        }
        else if (strlen(info) > 0)
        {
            FakeClientCommand(param1, info);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_BotHelp(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowBuyRobotHelpMenu(int client)
{
    Menu menu = new Menu(MenuHandler_BuyRobotHelp);
    menu.SetTitle("Buy Robot Commands\n ");
    menu.AddItem("sm_robotshop", "Open robot shop");
    menu.AddItem("sm_points", "Check your points");
    menu.AddItem("sm_shopstatus", "Check shop status");
    menu.AddItem("sm_ri", "View info of robot you're looking at");
    menu.AddItem("sm_lr", "List all active purchased robots");
    menu.AddItem("sm_mr", "Manage your purchased robots");
    menu.AddItem("sm_top", "View top 10 players");
    menu.AddItem("sm_rank", "View your rank");
    menu.AddItem("sm_votesaxton", "Vote to toggle Saxton Hale AI for (Mann Co. Team)");
    menu.AddItem("sm_votegray", "Vote to toggle Gray Mann AI for (Invaders Team)");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BuyRobotHelp(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "close"))
        {
        }
        else if (StrEqual(info, "sm_ri"))
        {
            Command_RobotInfo(param1, 0);
        }
        else if (StrEqual(info, "sm_lr"))
        {
            Command_ListRobots(param1, 0);
        }
        else if (StrEqual(info, "sm_mr"))
        {
            Command_MyRobots(param1, 0);
        }
        else if (strlen(info) > 0)
        {
            FakeClientCommand(param1, info);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_BotHelp(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_ServerInfo(int client, int args)
{
    char serverName[128];
    GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    int redHumans = 0;
    int redDefenderBots = 0;
    int redBuyBots = 0;
    int blueHumans = 0;
    int blueBuyBots = 0;
    int blueMvMBots = 0;
    int spectators = 0;
    int specBots = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        if (IsClientSourceTV(i) || IsClientReplay(i))
            continue;
        
        TFTeam team = TF2_GetClientTeam(i);
        
        if (team == TFTeam_Red)
        {
            if (IsFakeClient(i))
            {
                if (g_bBuyIsPurchasedRobot[i])
                    redBuyBots++;
                else if (g_bIsDefenderBot[i])
                    redDefenderBots++;
            }
            else
            {
                redHumans++;
            }
        }
        else if (team == TFTeam_Blue)
        {
            if (IsFakeClient(i))
            {
                if (g_bBuyIsPurchasedRobot[i])
                    blueBuyBots++;
                else
                    blueMvMBots++;
            }
            else
            {
                blueHumans++;
            }
        }
        else if (team == TFTeam_Spectator)
        {
            if (IsFakeClient(i))
                specBots++;
            else
                spectators++;
        }
    }
    
    int totalRed = redHumans + redDefenderBots + redBuyBots;
    int totalBlue = blueHumans + blueBuyBots + blueMvMBots;
    int totalBots = redDefenderBots + redBuyBots + blueBuyBots + blueMvMBots + specBots;
    int totalHumans = redHumans + blueHumans + spectators;
    int totalPlayers = totalHumans + totalBots;
    
    Menu menu = new Menu(MenuHandler_ServerInfo);
    char title[256];
    Format(title, sizeof(title), "%s\n \n", serverName);
    menu.SetTitle(title);
    
    char info[256];
    
    Format(info, sizeof(info), "Map: %s", mapName);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "Players: %d/%d | Humans: %d | Bots: %d", totalPlayers, MaxClients, totalHumans, totalBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    menu.AddItem("", " ", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "=== Mann Co. (RED): %d Total ===", totalRed);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  Humans: %d", redHumans);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  Defender Bots: %d", redDefenderBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  Purchased Bots: %d", redBuyBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    menu.AddItem("", " ", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "=== Invaders (BLUE): %d Total ===", totalBlue);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  Humans: %d", blueHumans);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  Purchased Bots: %d", blueBuyBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "  MvM Bots: %d", blueMvMBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    menu.AddItem("", " ", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "Spectators: %d Humans, %d Bots", spectators, specBots);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    menu.AddItem("", " ", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "=== Defender Bots Config ===");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Mode: %d | Lineup: %d", redbots_manager_mode.IntValue, redbots_manager_bot_lineup_mode.IntValue);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Custom Loadouts: %s", redbots_manager_use_custom_loadouts.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Bot Upgrades: %s", redbots_manager_bot_use_upgrades.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    
    menu.AddItem("", " ", ITEMDRAW_DISABLED);
    
    Format(info, sizeof(info), "=== Buy Robot Config ===");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Shop: %s | Max Bots: %d", g_cvBuyEnable.BoolValue ? "ON" : "OFF", g_cvBuyMaxBots.IntValue);
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Custom Loadouts: %s", g_cvBuyUseCustomLoadouts.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Bot Upgrades (Mann Co.): %s", g_cvBuyUseUpgrades.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Robot Hats: %s", g_cvBuyEnableHats.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Defender Hats: %s", g_cvBuyEnableDefenderHats.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Saxton AI (Mann Co.): %s", g_cvBuySaxtonAI.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);
    Format(info, sizeof(info), "Gray Mann AI (Invaders): %s", g_cvGrayMannAI.BoolValue ? "ON" : "OFF");
    menu.AddItem("", info, ITEMDRAW_DISABLED);

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public int MenuHandler_ServerInfo(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        if (StrEqual(info, "close"))
        {
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_BotHelp(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action BuyRobot_ShopStatus(int client, int args)
{
    if (IsValidClientIndex(client))
    {
        if (!g_cvBuyKickOnWaveEnd.BoolValue)
        {
            int count = BuyRobot_GetPurchasedCount();
            int max = g_cvBuyMaxBots.IntValue;
            int remaining = max - count;
            
            char slotColor[32];
            GetSlotColor(remaining, max, slotColor, sizeof(slotColor));
            
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robots: \x07FFD700%d/%d\x01 (%s%d\x01 slots left)", count, max, slotColor, remaining);
            
            if (IsFakeClient(client) && g_bIsDefenderBot[client] && !g_bBuyIsPurchasedRobot[client])
            {
                int owned = BuyRobot_CountOwnedBots(client);
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your robots: \x07FFD700%d/%d", owned, g_cvBuyMaxPerBot.IntValue);
            }
            return Plugin_Handled;
        }
        
        if (GameRules_GetRoundState() != RoundState_RoundRunning)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Shop is only available during the wave!");
            return Plugin_Handled;
        }
        
        int count = BuyRobot_GetPurchasedCount();
        int max = g_cvBuyMaxBots.IntValue;
        int remaining = max - count;
        
        char slotColor[32];
        GetSlotColor(remaining, max, slotColor, sizeof(slotColor));
        
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Robots: \x07FFD700%d/%d\x01 (%s%d\x01 slots left)", count, max, slotColor, remaining);
        
        if (IsFakeClient(client) && g_bIsDefenderBot[client] && !g_bBuyIsPurchasedRobot[client])
        {
            int owned = BuyRobot_CountOwnedBots(client);
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your robots: \x07FFD700%d/%d", owned, g_cvBuyMaxPerBot.IntValue);
        }
    }
    return Plugin_Handled;
}

void GetSlotColor(int remaining, int max, char[] color, int size)
{
    float percent = float(remaining) / float(max) * 100.0;
    
    if (remaining <= 0)
    {
        strcopy(color, size, "\x07FF0000");
    }
    else if (percent <= 25.0)
    {
        strcopy(color, size, "\x07FF4500");
    }
    else if (percent <= 50.0)
    {
        strcopy(color, size, "\x07FFA500");
    }
    else
    {
        strcopy(color, size, "\x07FFD700");
    }
}

public Action BuyRobot_GivePoints(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 Usage: sm_givepoints <name> <amount>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_TARGET_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    char pointsStr[16];
    GetCmdArg(2, pointsStr, sizeof(pointsStr));
    int points = StringToInt(pointsStr);
    
    if (points <= 0) return Plugin_Handled;
    
    int targets[MAXPLAYERS];
    char targetNameList[MAX_TARGET_LENGTH];
    bool tn_is_ml;
    
    int targetCount = ProcessTargetString(targetName, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE, targetNameList, sizeof(targetNameList), tn_is_ml);
    
    if (targetCount <= 0)
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 No matching client found.");
        return Plugin_Handled;
    }
    
    for (int i = 0; i < targetCount; i++)
    {
        g_iBuyPlayerPoints[targets[i]] += points;
        BuyRobot_SavePlayerPoints(targets[i]);
	BuyRobot_SaveAllPoints();
        LogAction(client, targets[i], "\"%L\" gave %d points to \"%L\"", client, points, targets[i]);
        
        if (targets[i] != client && IsValidClientIndex(targets[i]))
        {
            PrintToChat(targets[i], "\x0732CD32[Buy Robot]\x01 You received \x07FFD700%d\x01 points!", points);
        }
    }
    
    BuyRobot_SaveAllPoints();
    ReplyToCommand(client, "%d points given to %d player(s)", points, targetCount);
    return Plugin_Handled;
}

public Action BuyRobot_ResetPoints(int client, int args)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClientIndex(i) && !IsFakeClient(i))
        {
            g_iBuyPlayerPoints[i] = 0;
            BuyRobot_SavePlayerPoints(i);
	    BuyRobot_SaveAllPoints();
        }
        else
        {
            g_iBuyPlayerPoints[i] = 0;
        }
    }
    BuyRobot_SaveAllPoints();
    ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 All points have been reset");
    return Plugin_Handled;
}

public Action Command_SavePoints(int client, int args)
{
    BuyRobot_SaveAllPoints();
    ReplyToCommand(client, "[BuyRobot] Points saved to file.");
    return Plugin_Handled;
}

public Action Command_LoadPoints(int client, int args)
{
    BuyRobot_LoadAllPoints();
    ReplyToCommand(client, "[BuyRobot] Points loaded from file.");
    return Plugin_Handled;
}

public Action Command_ResetPointsData(int client, int args)
{
    BuyRobot_ResetAllPointsData();
    ReplyToCommand(client, "[BuyRobot] All points data has been reset.");
    return Plugin_Handled;
}

void BuyRobot_ShowMainMenu(int client, TFTeam team)
{
    Menu menu = new Menu(BuyRobot_MenuMainHandler);
    int currentBots = BuyRobot_GetPurchasedCount();
    int maxBots = g_cvBuyMaxBots.IntValue;
    
    menu.SetTitle("Robot Shop\nPoints: %d\nRobots: %d/%d\n ", g_iBuyPlayerPoints[client], currentBots, maxBots);
    menu.AddItem("single", "Single Robot");
    menu.AddItem("squad", "Squad (5 robots)");
    menu.AddItem("giant", "Giant Robot");
    menu.AddItem("boss", "Boss Robot");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int BuyRobot_MenuMainHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[32];
        menu.GetItem(param2, item, sizeof(item));
        
        TFTeam team = TF2_GetClientTeam(client);
        
        if (StrEqual(item, "single")) BuyRobot_ShowClassMenu(client, BUY_CATEGORY_SINGLE, team);
        else if (StrEqual(item, "squad")) BuyRobot_ShowClassMenu(client, BUY_CATEGORY_SQUAD, team);
        else if (StrEqual(item, "giant")) BuyRobot_ShowClassMenu(client, BUY_CATEGORY_GIANT, team);
        else if (StrEqual(item, "boss")) BuyRobot_ShowClassMenu(client, BUY_CATEGORY_BOSS, team);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void BuyRobot_ShowClassMenu(int client, int category, TFTeam team)
{
    int points = g_iBuyPlayerPoints[client];
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = BuyRobot_GetPurchasedCount();
    int remainingSlots = maxBots - currentBots;
    
    if (category == BUY_CATEGORY_BOSS)
    {
        int bossCount = GetCurrentBossCountForTeam(team);
        if (bossCount >= g_cvMaxBossPerTeam.IntValue)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your team already has a Boss robot! Only 1 Boss allowed per team.");
            BuyRobot_ShowMainMenu(client, team);
            return;
        }
    }
    
    float priceMult;
    int botCount;
    char categoryPrefix[32];
    char categorySuffix[32];
    
    if (category == BUY_CATEGORY_SINGLE)
    {
        priceMult = BUY_PRICE_SINGLE_MULT;
        botCount = 1;
        categoryPrefix = "";
        categorySuffix = "";
    }
    else if (category == BUY_CATEGORY_SQUAD)
    {
        priceMult = BUY_PRICE_SQUAD_MULT;
        botCount = 5;
        categoryPrefix = "";
        categorySuffix = " Squad";
    }
    else if (category == BUY_CATEGORY_GIANT)
    {
        priceMult = BUY_PRICE_GIANT_MULT;
        botCount = 1;
        categoryPrefix = "Giant ";
        categorySuffix = "";
    }
    else if (category == BUY_CATEGORY_BOSS)
    {
        priceMult = BUY_PRICE_BOSS_MULT;
        botCount = 1;
        categoryPrefix = "Boss ";
        categorySuffix = "";
    }
    else
    {
        return;
    }
    
    if (remainingSlots < botCount)
    {
        int waitingCount = GetWaitingCountForPlayer(client);
        if (waitingCount + botCount > g_cvMaxWaitingQueuePerPlayer.IntValue)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You already have %d robots in waiting queue (max %d)!", 
                waitingCount, g_cvMaxWaitingQueuePerPlayer.IntValue);
            BuyRobot_ShowMainMenu(client, team);
            return;
        }
        PrintToChat(client, "\x07FFD700[Buy Robot]\x01 Bot limit reached! Your purchase will be queued. (Queue: %d/%d)", 
            waitingCount + botCount, g_cvMaxWaitingQueuePerPlayer.IntValue);
    }
    
    Menu menu = new Menu(BuyRobot_MenuClassHandler);
    menu.SetTitle("Choose Class\nPoints: %d\nRobots: %d/%d\n ", points, currentBots, maxBots);
    
    char display[64], info[64];
    int totalPrice;
    
    totalPrice = RoundFloat(g_cvPriceScout.IntValue * priceMult);
    Format(display, sizeof(display), "%sScout%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "scout %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceSoldier.IntValue * priceMult);
    Format(display, sizeof(display), "%sSoldier%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "soldier %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPricePyro.IntValue * priceMult);
    Format(display, sizeof(display), "%sPyro%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "pyro %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceDemoman.IntValue * priceMult);
    Format(display, sizeof(display), "%sDemoman%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "demoman %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceHeavy.IntValue * priceMult);
    Format(display, sizeof(display), "%sHeavy%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "heavyweapons %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceEngineer.IntValue * priceMult);
    Format(display, sizeof(display), "%sEngineer%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "engineer %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceMedic.IntValue * priceMult);
    Format(display, sizeof(display), "%sMedic%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "medic %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceSniper.IntValue * priceMult);
    Format(display, sizeof(display), "%sSniper%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "sniper %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    totalPrice = RoundFloat(g_cvPriceSpy.IntValue * priceMult);
    Format(display, sizeof(display), "%sSpy%s (%d points)", categoryPrefix, categorySuffix, totalPrice);
    Format(info, sizeof(info), "spy %d %d %d %d", totalPrice, botCount, category, view_as<int>(team));
    menu.AddItem(info, display, points >= totalPrice ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int BuyRobot_MenuClassHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[96];
        menu.GetItem(param2, item, sizeof(item));
        
        char class[32];
        int price, botCount, category, teamInt;
        char parts[5][32];
        ExplodeString(item, " ", parts, 5, 32);
        strcopy(class, sizeof(class), parts[0]);
        price = StringToInt(parts[1]);
        botCount = StringToInt(parts[2]);
        category = StringToInt(parts[3]);
        teamInt = StringToInt(parts[4]);
        TFTeam team = view_as<TFTeam>(teamInt);
        
        if (!IsValidClientIndex(client)) return 0;
        if (TF2_GetClientTeam(client) != team)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You must be on this team!");
            return 0;
        }
        
        if (category == BUY_CATEGORY_BOSS)
        {
            int bossCount = GetCurrentBossCountForTeam(team);
            if (bossCount >= g_cvMaxBossPerTeam.IntValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your team already has a Boss robot! Only 1 Boss allowed per team.");
                BuyRobot_ShowClassMenu(client, category, team);
                return 0;
            }
        }
        
        if (g_iBuyPlayerPoints[client] < price)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You need \x07FFD700%d\x01 points", price);
            BuyRobot_ShowClassMenu(client, category, team);
            return 0;
        }
        
        if (GetClientCount() + botCount - 1 >= MaxClients)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Server is full!");
            BuyRobot_ShowClassMenu(client, category, team);
            return 0;
        }
        
        int currentBots = BuyRobot_GetPurchasedCount();
        int maxBots = g_cvBuyMaxBots.IntValue;
        
        if (currentBots + botCount > maxBots)
        {
            int waitingCount = GetWaitingCountForPlayer(client);
            if (waitingCount + botCount > g_cvMaxWaitingQueuePerPlayer.IntValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You already have %d robots in waiting queue (max %d)!", 
                    waitingCount, g_cvMaxWaitingQueuePerPlayer.IntValue);
                BuyRobot_ShowClassMenu(client, category, team);
                return 0;
            }
            
            if (g_hWaitingQueue.Length + botCount > g_cvMaxWaitingQueueTotal.IntValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Waiting queue is full! Try again later.");
                BuyRobot_ShowClassMenu(client, category, team);
                return 0;
            }
            
            g_iBuyPlayerPoints[client] -= price;
            BuyRobot_SavePlayerPoints(client);
            BuyRobot_SaveAllPoints();
            
            int lives = (category == BUY_CATEGORY_GIANT || category == BUY_CATEGORY_BOSS) ? 1 : g_cvBuyDefaultLives.IntValue;
            
            char namePrefix[32];
            if (category == BUY_CATEGORY_GIANT)
                strcopy(namePrefix, sizeof(namePrefix), "Giant");
            else if (category == BUY_CATEGORY_BOSS)
                strcopy(namePrefix, sizeof(namePrefix), "Boss");
            else
                namePrefix[0] = '\0';
            
            for (int i = 0; i < botCount; i++)
            {
                AddToWaitingQueue(client, class, lives, namePrefix, team, price, 1, category);
            }
            
            char className[32];
            BuyRobot_GetClassName(class, className, sizeof(className));
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Bot limit reached! %d %s added to waiting queue. (Your queue: %d/%d)", 
                botCount, className, waitingCount + botCount, g_cvMaxWaitingQueuePerPlayer.IntValue);
            
            if (g_cvBuyNotifyHumanPurchase.BoolValue)
            {
                char teamColor[16];
                char teamName[16];
                if (team == TFTeam_Red)
                {
                    teamColor = "\x07FF4500";
                    teamName = "Mann Co.";
                }
                else
                {
                    teamColor = "\x0742A5F5";
                    teamName = "Invaders";
                }
                
                if (category == BUY_CATEGORY_GIANT)
                {
                    PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought a \x078B008BGiant %s\x01 robot for %s%s\x01 team! [QUEUED]", 
                                    client, className, teamColor, teamName);
                }
                else if (category == BUY_CATEGORY_BOSS)
                {
                    PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought a \x07FF1493Boss %s\x01 robot for %s%s\x01 team! [QUEUED]", 
                                    client, className, teamColor, teamName);
                }
                else
                {
                    PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought \x07FFD700%d %s\x01 robot(s) for %s%s\x01 team! [QUEUED]", 
                                    client, botCount, className, teamColor, teamName);
                }
            }
            
            BuyRobot_ShowMainMenu(client, team);
            return 0;
        }
        
        g_iBuyPlayerPoints[client] -= price;
        BuyRobot_SavePlayerPoints(client);
        BuyRobot_SaveAllPoints();
        int lives = (category == BUY_CATEGORY_GIANT || category == BUY_CATEGORY_BOSS) ? 1 : g_cvBuyDefaultLives.IntValue;
        
        char namePrefix[32];
        if (category == BUY_CATEGORY_GIANT)
            strcopy(namePrefix, sizeof(namePrefix), "Giant");
        else if (category == BUY_CATEGORY_BOSS)
            strcopy(namePrefix, sizeof(namePrefix), "Boss");
        else
            namePrefix[0] = '\0';
        
        for (int i = 0; i < botCount; i++)
        {
            BuyRobot_CreateBot(class, client, lives, namePrefix, false, team);
        }
        
        char className[32];
        BuyRobot_GetClassName(class, className, sizeof(className));
        
        if (g_cvBuyNotifyHumanPurchase.BoolValue)
        {
            char teamColor[16];
            char teamName[16];
            if (team == TFTeam_Red)
            {
                teamColor = "\x07FF4500";
                teamName = "Mann Co.";
            }
            else
            {
                teamColor = "\x0742A5F5";
                teamName = "Invaders";
            }
            
            if (category == BUY_CATEGORY_GIANT)
            {
                PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought a \x078B008BGiant %s\x01 robot for %s%s\x01 team! (\x07FFD700%d\x01 points)", 
                                client, className, teamColor, teamName, price);
            }
            else if (category == BUY_CATEGORY_BOSS)
            {
                PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought a \x07FF1493Boss %s\x01 robot for %s%s\x01 team! (\x07FFD700%d\x01 points)", 
                                client, className, teamColor, teamName, price);
            }
            else
            {
                PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%N\x01 bought \x07FFD700%d %s\x01 robot(s) for %s%s\x01 team!", 
                                client, botCount, className, teamColor, teamName);
            }
        }
        
        BuyRobot_ShowMainMenu(client, team);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (IsValidClientIndex(param1)) 
            BuyRobot_ShowMainMenu(param1, TF2_GetClientTeam(param1));
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void BuyRobot_CreateBot(const char[] class, int buyer, int lives, const char[] prefix = "", bool bSaxtonAI = false, TFTeam team = TFTeam_Red)
{
    char command[256];
    
    char teamStr[8];
    if (team == TFTeam_Red)
        teamStr = "red";
    else
        teamStr = "blue";
    
    int uniqueID = GetRandomInt(100000, 999999);
    
    if (buyer == 0)
    {
        Format(command, sizeof(command), "tf_bot_add 1 %s %s expert noquota bot_tmp_%d BOT_BONUS_%d", class, teamStr, uniqueID, uniqueID);
    }
    else
    {
        Format(command, sizeof(command), "tf_bot_add 1 %s %s expert noquota bot_tmp_%d BOT_BUY_%d_%d", class, teamStr, uniqueID, buyer, uniqueID);
    }
    
    ServerCommand(command);
    
    DataPack pack = new DataPack();
    pack.WriteCell(buyer);
    pack.WriteString(class);
    pack.WriteCell(lives);
    pack.WriteString(prefix);
    pack.WriteCell(bSaxtonAI);
    pack.WriteCell(view_as<int>(team));
    pack.WriteCell(uniqueID);
    CreateTimer(0.1, BuyRobot_SetupBot, pack, TIMER_FLAG_NO_MAPCHANGE);
}

public Action BuyRobot_SetupBot(Handle timer, DataPack pack)
{
    pack.Reset();
    int buyer = pack.ReadCell();
    char class[32];
    pack.ReadString(class, sizeof(class));
    int lives = pack.ReadCell();
    char prefix[32];
    pack.ReadString(prefix, sizeof(prefix));
    bool bSaxtonAI = pack.ReadCell();
    int teamInt = pack.ReadCell();
    TFTeam team = view_as<TFTeam>(teamInt);
    int uniqueID = pack.ReadCell();
    delete pack;
    
    char searchTag[32];
    if (buyer == 0)
        Format(searchTag, sizeof(searchTag), "BOT_BONUS_%d", uniqueID);
    else
        Format(searchTag, sizeof(searchTag), "BOT_BUY_%d_%d", buyer, uniqueID);
    
    int found = -1;
    int attempts = 0;
    int maxAttempts = 10;
    
    while (found == -1 && attempts < maxAttempts)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && IsFakeClient(i) && !IsClientSourceTV(i))
            {
                char name[64];
                GetClientName(i, name, sizeof(name));
                if (StrContains(name, searchTag) != -1)
                {
                    found = i;
                    break;
                }
            }
        }
        
        if (found == -1)
        {
            attempts++;
            if (attempts < maxAttempts)
            {
                DataPack retryPack = new DataPack();
                retryPack.WriteCell(buyer);
                retryPack.WriteString(class);
                retryPack.WriteCell(lives);
                retryPack.WriteString(prefix);
                retryPack.WriteCell(bSaxtonAI);
                retryPack.WriteCell(teamInt);
                retryPack.WriteCell(uniqueID);
                CreateTimer(0.3, BuyRobot_SetupBot, retryPack, TIMER_FLAG_NO_MAPCHANGE);
                return Plugin_Stop;
            }
        }
    }
    
    if (found == -1) return Plugin_Stop;
    
    int client = found;
    
    g_bBuyIsPurchasedRobot[client] = true;
    g_bBuyIsAIRobot[client] = bSaxtonAI;
    
    g_iBuyRobotLives[client] = lives;
    g_iBuyRobotOwner[client] = buyer;
    
    TF2_ChangeClientTeam(client, team);
    
    if (IsHalloweenActive())
    {
        BuyRobot_EquipZombieCosmetic(client);
    }
    else
    {
        BuyRobot_ApplyModel(client);
    }

    BuyRobot_EquipHat(client);
    
    char className[32];
    BuyRobot_GetClassName(class, className, sizeof(className));
    
    if (strlen(prefix) > 0 && StrEqual(prefix, "Giant"))
    {
        char giantName[64];
        Format(giantName, sizeof(giantName), "Giant %s", className);
        SetClientName(client, giantName);
    }
    else if (strlen(prefix) > 0 && StrEqual(prefix, "Boss"))
    {
        char bossName[64];
        Format(bossName, sizeof(bossName), "Boss %s", className);
        SetClientName(client, bossName);
    }
    else
    {
        SetClientName(client, className);
    }
    
    bool isGiant = (strlen(prefix) > 0 && StrContains(prefix, "Giant") != -1);
    if (isGiant)
        BuyRobot_ApplyGiantAttributes(client);
    
    bool isBoss = (strlen(prefix) > 0 && StrContains(prefix, "Boss") != -1);
    if (isBoss)
        BuyRobot_ApplyBossAttributes(client);
    
    TF2_RespawnPlayer(client);

    if (team == TFTeam_Blue)
    {
        CreateTimer(0.1, Timer_AddToWaveBar, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    bool useUpgrades = g_cvBuyUseUpgrades.BoolValue;
    if (!useUpgrades || isGiant || isBoss || (team == TFTeam_Blue))
    {
        BuyRobot_ApplyAttributes(client);
        RemovePowerUpCanteen(client);
    }
    
    BuyRobot_ApplyInfiniteMetal(client);

    if (TF2_GetPlayerClass(client) == TFClass_Engineer && TF2_GetClientTeam(client) == TFTeam_Red)
    {
        CreateTimer(0.5, Timer_InfiniteSentryAmmo, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Stop;
}

public Action Timer_AddToWaveBar(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsPlayerAlive(client) && g_bBuyIsPurchasedRobot[client])
    {
        if (TF2_GetClientTeam(client) == TFTeam_Blue)
        {
            AddRobotToWaveBar(client);
        }
    }
    return Plugin_Stop;
}

void BuyRobot_ApplyInfiniteMetal(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    TFClassType class = TF2_GetPlayerClass(client);
    if (class == TFClass_Engineer)
    {
        if (TF2Attrib_IsValidAttributeName("maxammo metal increased"))
            TF2Attrib_SetByName(client, "maxammo metal increased", 999.0);
        
        if (TF2Attrib_IsValidAttributeName("metal regen"))
            TF2Attrib_SetByName(client, "metal regen", 999.0);
    }
}

void BuyRobot_ApplyAttributes(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (isGiant || isBoss) return;
    
    TFClassType class = TF2_GetPlayerClass(client);
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
    
    TF2Attrib_SetByName(client, "dmg taken from fire reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from blast reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from bullets reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from crit reduced", 0.8);
    TF2Attrib_SetByName(client, "ubercharge rate bonus", 2.0);
    TF2Attrib_SetByName(client, "mult cloak meter regen rate", 3.0);
    TF2Attrib_SetByName(client, "cloak consume rate decreased", 2.0);
    TF2Attrib_SetByName(client, "construction rate increased", 3.0);
    TF2Attrib_SetByName(client, "engy building health bonus", 2.5);
    TF2Attrib_SetByName(client, "repair rate increased", 1.5);
}

void BuyRobot_ApplyGiantAttributes(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    CreateTimer(0.1, Timer_ApplyGiantScale, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.1, Timer_ApplyGiantStats, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyGiantScale(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client] || !IsPlayerAlive(client)) return Plugin_Stop;
    
    SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.8);
    UpdatePlayerHitbox(client, 1.8);
    
    return Plugin_Stop;
}

public Action Timer_ApplyGiantStats(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    
    TFClassType class = TF2_GetPlayerClass(client);
    
    int health = 3000;
    float speed = 0.5;
    float forceReduct = 0.4;
    float airblastVuln = 0.4;
    float footstep = 0.0;
    
    switch (class)
    {
        case TFClass_Soldier:
        {
            health = 3800;
            speed = 0.5;
            forceReduct = 0.4;
            airblastVuln = 0.4;
            footstep = 3.0;
        }
        case TFClass_Pyro:
        {
            health = 3000;
            speed = 0.5;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 6.0;
        }
        case TFClass_Scout:
        {
            health = 1600;
            speed = 1.0;
            forceReduct = 0.7;
            airblastVuln = 0.7;
            footstep = 5.0;
        }
        case TFClass_DemoMan:
        {
            health = 3300;
            speed = 0.5;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 4.0;
        }
        case TFClass_Heavy:
        {
            health = 5000;
            speed = 0.45;
            forceReduct = 0.3;
            airblastVuln = 0.3;
            footstep = 2.0;
        }
        case TFClass_Medic:
        {
            health = 3000;
            speed = 0.5;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "health regen", 24.0);
            TF2Attrib_SetByName(client, "heal rate bonus", 5.0);
            TF2Attrib_SetByName(client, "ubercharge rate bonus", 2.0);
        }
        case TFClass_Engineer:
        {
            health = 2800;
            speed = 1.2;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 3.0;
            TF2Attrib_SetByName(client, "engy building health bonus", 6.6);
            TF2Attrib_SetByName(client, "construction rate increased", 5.0);
            TF2Attrib_SetByName(client, "engy sentry damage bonus", 2.0);
            TF2Attrib_SetByName(client, "engy dispenser radius increased", 7.0);
            TF2Attrib_SetByName(client, "engy sentry radius increased", 2.5);
            TF2Attrib_SetByName(client, "repair rate increased", 3.0);
        }
        case TFClass_Spy:
        {
            health = 2000;
            speed = 1.5;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "armor piercing", 75.0);
            TF2Attrib_SetByName(client, "damage bonus while disguised", 1.75);
            TF2Attrib_SetByName(client, "add cloak on hit", 20.0);
            TF2Attrib_SetByName(client, "add cloak on kill", 100.0);
            TF2Attrib_SetByName(client, "mult cloak meter regen rate", 3.0);
            TF2Attrib_SetByName(client, "cloak consume rate decreased", 2.0);
            TF2Attrib_SetByName(client, "critboost on kill", 5.0);
        }
        case TFClass_Sniper:
        {
            health = 2500;
            speed = 0.8;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "sniper charge per sec", 5.0);
            TF2Attrib_SetByName(client, "sniper full charge damage bonus", 2.0);
            TF2Attrib_SetByName(client, "critboost on kill", 5.0);
            TF2Attrib_SetByName(client, "aiming no flinch", 1.0);
            TF2Attrib_SetByName(client, "minicrits become crits", 1.0);
            TF2Attrib_SetByName(client, "sniper penetrate players when charged", 1.0);
            TF2Attrib_SetByName(client, "explosive sniper shot", 1.0);
        }
    }
    
    int iNewHealth = health - GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
    
    TF2Attrib_SetByName(client, "dmg taken from fire reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from blast reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from bullets reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from crit reduced", 0.5);
    TF2Attrib_SetByName(client, "damage force reduction", forceReduct);
    TF2Attrib_SetByName(client, "health from packs decreased", 0.0);
    TF2Attrib_SetByName(client, "move speed bonus", speed);
    TF2Attrib_SetByName(client, "airblast vulnerability multiplier", airblastVuln);
    TF2Attrib_SetByName(client, "max health additive bonus", float(iNewHealth));
    TF2Attrib_SetByName(client, "override footstep sound set", footstep);
    
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
    
    if (class == TFClass_Engineer)
    {
        CreateTimer(0.5, Timer_ApplyBuildingGiant, GetClientUserId(client), TIMER_REPEAT);
    }
    
    if (class == TFClass_Heavy && weapon != -1)
        TF2Attrib_SetByName(weapon, "aiming movespeed increased", 2.0);
    
    SetEntProp(client, Prop_Send, "m_iHealth", health);
    SetEntProp(client, Prop_Data, "m_iHealth", health);
    SetEntProp(client, Prop_Send, "m_bIsMiniBoss", 1);
    
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.1);
    
    Timer_PlayGiantLoop(INVALID_HANDLE, userid);
    
    return Plugin_Stop;
}

void BuyRobot_ApplyBossAttributes(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    CreateTimer(0.1, Timer_ApplyGiantScale, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.1, Timer_ApplyBossStats, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyBossStats(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    
    TFClassType class = TF2_GetPlayerClass(client);
    
    int health = 30000;
    float speed = 0.7;
    float forceReduct = 0.4;
    float airblastVuln = 0.4;
    float footstep = 0.0;
    
    switch (class)
    {
        case TFClass_Soldier:
        {
            health = 32000;
            speed = 0.7;
            forceReduct = 0.4;
            airblastVuln = 0.4;
            footstep = 3.0;
        }
        case TFClass_Pyro:
        {
            health = 30000;
            speed = 0.7;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 6.0;
        }
        case TFClass_Scout:
        {
            health = 22000;
            speed = 2.0;
            forceReduct = 0.7;
            airblastVuln = 0.7;
            footstep = 5.0;
        }
        case TFClass_DemoMan:
        {
            health = 33000;
            speed = 0.7;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 4.0;
        }
        case TFClass_Heavy:
        {
            health = 50000;
            speed = 0.65;
            forceReduct = 0.3;
            airblastVuln = 0.3;
            footstep = 2.0;
        }
        case TFClass_Medic:
        {
            health = 30000;
            speed = 0.7;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "health regen", 50.0);
            TF2Attrib_SetByName(client, "heal rate bonus", 7.0);
            TF2Attrib_SetByName(client, "ubercharge rate bonus", 2.3);
        }
        case TFClass_Engineer:
        {
            health = 28000;
            speed = 1.4;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 3.0;
            TF2Attrib_SetByName(client, "engy building health bonus", 11.0);
            TF2Attrib_SetByName(client, "construction rate increased", 9.0);
            TF2Attrib_SetByName(client, "engy sentry damage bonus", 3.6);
            TF2Attrib_SetByName(client, "engy dispenser radius increased", 10.0);
            TF2Attrib_SetByName(client, "engy sentry radius increased", 3.2);
            TF2Attrib_SetByName(client, "repair rate increased", 5.0);
        }
        case TFClass_Spy:
        {
            health = 20000;
            speed = 1.7;
            forceReduct = 0.6;
            airblastVuln = 0.6;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "armor piercing", 75.0);
            TF2Attrib_SetByName(client, "damage bonus while disguised", 1.75);
            TF2Attrib_SetByName(client, "add cloak on hit", 20.0);
            TF2Attrib_SetByName(client, "add cloak on kill", 100.0);
            TF2Attrib_SetByName(client, "mult cloak meter regen rate", 3.0);
            TF2Attrib_SetByName(client, "cloak consume rate decreased", 2.0);
            TF2Attrib_SetByName(client, "critboost on kill", 5.0);
        }
        case TFClass_Sniper:
        {
            health = 25000;
            speed = 1.0;
            forceReduct = 0.5;
            airblastVuln = 0.5;
            footstep = 0.0;
            TF2Attrib_SetByName(client, "sniper charge per sec", 5.0);
            TF2Attrib_SetByName(client, "sniper full charge damage bonus", 2.0);
            TF2Attrib_SetByName(client, "critboost on kill", 5.0);
            TF2Attrib_SetByName(client, "aiming no flinch", 1.0);
            TF2Attrib_SetByName(client, "minicrits become crits", 1.0);
            TF2Attrib_SetByName(client, "sniper penetrate players when charged", 1.0);
            TF2Attrib_SetByName(client, "explosive sniper shot", 1.0);
        }
    }
    
    int iNewHealth = health - GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
    
    TF2Attrib_SetByName(client, "dmg taken from fire reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from blast reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from bullets reduced", 0.8);
    TF2Attrib_SetByName(client, "dmg taken from crit reduced", 0.3);
    TF2Attrib_SetByName(client, "damage force reduction", forceReduct);
    TF2Attrib_SetByName(client, "health from packs decreased", 0.0);
    TF2Attrib_SetByName(client, "move speed bonus", speed);
    TF2Attrib_SetByName(client, "airblast vulnerability multiplier", airblastVuln);
    TF2Attrib_SetByName(client, "max health additive bonus", float(iNewHealth));
    TF2Attrib_SetByName(client, "override footstep sound set", footstep);
    
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
	TF2Attrib_SetByName(weapon, "damage bonus", 3.6);
        TF2Attrib_SetByName(weapon, "fire rate bonus", 0.3);
        TF2Attrib_SetByName(weapon, "faster reload rate", 0.1);
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
	TF2Attrib_SetByName(weapon2, "damage bonus", 3.6);
        TF2Attrib_SetByName(weapon2, "fire rate bonus", 0.3);
        TF2Attrib_SetByName(weapon2, "faster reload rate", 0.1);
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
    
    int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
    if (melee != -1) 
    {
	TF2Attrib_SetByName(melee, "damage bonus", 3.6);
        TF2Attrib_SetByName(melee, "fire rate bonus", 0.3);
    }
    
    if (class == TFClass_Engineer)
    {
        CreateTimer(0.5, Timer_ApplyBuildingGiant, GetClientUserId(client), TIMER_REPEAT);
    }
    
    if (class == TFClass_Heavy && weapon != -1)
        TF2Attrib_SetByName(weapon, "aiming movespeed increased", 2.0);
    
    SetEntProp(client, Prop_Send, "m_iHealth", health);
    SetEntProp(client, Prop_Data, "m_iHealth", health);
    SetEntProp(client, Prop_Send, "m_bIsMiniBoss", 1);
    
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.1);
    
    Timer_PlayGiantLoop(INVALID_HANDLE, userid);
    
    CreateTimer(0.1, Timer_ApplyBossEffects, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Stop;
}

public Action Timer_ApplyBossEffects(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client] || !IsPlayerAlive(client)) return Plugin_Stop;
    
    TF2_AddCondition(client, TFCond_CritCanteen, 999.0);
    TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, 999.0);
    TF2_AddCondition(client, TFCond_Kritzkrieged, 999.0);
    
    return Plugin_Stop;
}

int BuyRobot_CountOwnedBots(int owner)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && g_iBuyRobotOwner[i] == owner && IsPlayerAlive(i))
        {
            count++;
        }
    }
    return count;
}

public Action Timer_ApplyBuildingGiant(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client] || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    if (StrContains(clientName, "Giant") == -1 && StrContains(clientName, "Boss") == -1)
        return Plugin_Stop;
    
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") != client)
            continue;
        
        int objType = TF2_GetObjectType(ent);
        
        if (objType == TFObject_Sentry)
        {
            SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 1.3);
            SetVariantString("1.3");
            AcceptEntityInput(ent, "SetModelScale");
        }
        
        if (objType == TFObject_Dispenser)
        {
            SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 1.1);
            SetVariantString("1.1");
            AcceptEntityInput(ent, "SetModelScale");
        }
    }
    
    return Plugin_Continue;
}

void BuyRobot_ApplyModel(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    TFClassType class = TF2_GetPlayerClass(client);
    char modelPath[PLATFORM_MAX_PATH];
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (isGiant || isBoss)
    {
        switch (class)
        {
            case TFClass_Heavy:    modelPath = "models/bots/heavy_boss/bot_heavy_boss.mdl";
            case TFClass_Scout:    modelPath = "models/bots/scout_boss/bot_scout_boss.mdl";
            case TFClass_Soldier:  modelPath = "models/bots/soldier_boss/bot_soldier_boss.mdl";
            case TFClass_DemoMan:  modelPath = "models/bots/demo_boss/bot_demo_boss.mdl";
            case TFClass_Pyro:     modelPath = "models/bots/pyro_boss/bot_pyro_boss.mdl";
            default: return;
        }
    }
    else
    {
        switch (class)
        {
            case TFClass_Soldier:  modelPath = "models/bots/soldier/bot_soldier.mdl";
            case TFClass_Pyro:     modelPath = "models/bots/pyro/bot_pyro.mdl";
            case TFClass_DemoMan:  modelPath = "models/bots/demo/bot_demo.mdl";
            case TFClass_Heavy:    modelPath = "models/bots/heavy/bot_heavy.mdl";
            case TFClass_Engineer: modelPath = "models/bots/engineer/bot_engineer.mdl";
            case TFClass_Medic:    modelPath = "models/bots/medic/bot_medic.mdl";
            case TFClass_Spy:      modelPath = "models/bots/spy/bot_spy.mdl";
            case TFClass_Scout:    modelPath = "models/bots/scout/bot_scout.mdl";
            case TFClass_Sniper:   modelPath = "models/bots/sniper/bot_sniper.mdl";
            default: return;
        }
    }
    
    SetVariantString(modelPath);
    AcceptEntityInput(client, "SetCustomModel");
    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

void BuyRobot_EquipZombieCosmetic(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client])
        return;
    
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
        {
            int idx = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
            if (idx >= 5617 && idx <= 5625)
            {
                AcceptEntityInput(ent, "Kill");
            }
        }
    }
    
    TFClassType class = TF2_GetPlayerClass(client);
    int iDefIndex;
    
    switch (class)
    {
        case TFClass_Scout:    iDefIndex = 5617;
        case TFClass_Soldier:  iDefIndex = 5618;
        case TFClass_Pyro:     iDefIndex = 5624;
        case TFClass_DemoMan:  iDefIndex = 5620;
        case TFClass_Heavy:    iDefIndex = 5619;
        case TFClass_Engineer: iDefIndex = 5621;
        case TFClass_Medic:    iDefIndex = 5622;
        case TFClass_Sniper:   iDefIndex = 5625;
        case TFClass_Spy:      iDefIndex = 5623;
        default: return;
    }
    
    int soul = CreateEntityByName("tf_wearable");
    if (soul != -1)
    {
        char entclass[64];
        GetEntityNetClass(soul, entclass, sizeof(entclass));
        SetEntData(soul, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), iDefIndex);
        SetEntData(soul, FindSendPropInfo(entclass, "m_bInitialized"), 1);
        SetEntData(soul, FindSendPropInfo(entclass, "m_iEntityLevel"), 6);
        SetEntData(soul, FindSendPropInfo(entclass, "m_iEntityQuality"), 13);
        SetEntProp(soul, Prop_Send, "m_bValidatedAttachedEntity", 1);
        
        DispatchSpawn(soul);
        
        if (hEquipWearable != null && soul != -1 && IsValidEntity(soul))
            SDKCall(hEquipWearable, client, soul);
    }
}

public Action BuyRobot_SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (Ent < 1 || Ent > MaxClients || !IsClientInGame(Ent) || !g_bBuyIsPurchasedRobot[Ent]) 
        return Plugin_Continue;
    
    int client = Ent;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);

    if (isGiant || isBoss) 
        return Plugin_Continue;
    
    if (g_cvBuyRobotFootsteps.BoolValue && StrContains(sound, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(client) != TFClass_Medic)
    {
        int rand = GetRandomInt(1, 18);
        char newSound[PLATFORM_MAX_PATH];
        Format(newSound, sizeof(newSound), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
        
        EmitSoundToAll(newSound, client, _, _, _, 0.25, GetRandomInt(95, 100));
        strcopy(sound, PLATFORM_MAX_PATH, newSound);
        return Plugin_Changed;
    }
    
    if (g_cvBuyRobotSounds.BoolValue && StrContains(sound, "vo/", false) != -1 && StrContains(sound, "announcer", false) == -1)
    {
        char newSound[PLATFORM_MAX_PATH];
        strcopy(newSound, sizeof(newSound), sound);
        
        ReplaceString(newSound, sizeof(newSound), "vo/", "vo/mvm/norm/", false);
        ReplaceString(newSound, sizeof(newSound), ".wav", ".mp3", false);
        
        char classname[32], classname_mvm[32];
        BuyRobot_GetClassNameForSound(TF2_GetPlayerClass(client), classname, sizeof(classname));
        Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
        ReplaceString(newSound, sizeof(newSound), classname, classname_mvm, false);
        
        char fileCheck[PLATFORM_MAX_PATH];
        Format(fileCheck, sizeof(fileCheck), "sound/%s", newSound);
        
        if (FileExists(fileCheck, true))
        {
            strcopy(sound, PLATFORM_MAX_PATH, newSound);
            return Plugin_Changed;
        }
        else
        {
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}

public Action BuyRobot_SoundHook_Death(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], 
                                        int &entity, int &channel, float &volume, int &level, 
                                        int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (StrContains(sample, "mvm_player_died", false) != -1)
    {
        if (entity > 0 && entity <= MaxClients && IsClientInGame(entity))
        {
            if (g_bBuyIsPurchasedRobot[entity])
            {
                return Plugin_Stop;
            }
        }
    }
    
    return Plugin_Continue;
}
public Action BuyRobot_GiantSoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (Ent < 1 || Ent > MaxClients || !IsClientInGame(Ent)) 
        return Plugin_Continue;
    
    int client = Ent;
    
    if (!g_bBuyIsPurchasedRobot[client]) return Plugin_Continue;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (!isGiant && !isBoss) return Plugin_Continue;
    
    if (TF2_GetPlayerClass(client) == TFClass_Medic || TF2_GetPlayerClass(client) == TFClass_Spy || TF2_GetPlayerClass(client) == TFClass_Engineer || TF2_GetPlayerClass(client) == TFClass_Sniper)
    {
    	if (StrContains(sound, "vo/", false) != -1)
    	{
       	    return Plugin_Stop;
    	}
    }
    
    if (StrContains(sound, "vo/", false) == -1 || StrContains(sound, "announcer", false) != -1) return Plugin_Continue;
    
    char newSound[PLATFORM_MAX_PATH];
    strcopy(newSound, sizeof(newSound), sound);
    
    ReplaceString(newSound, sizeof(newSound), "vo/", "vo/mvm/mght/", false);
    ReplaceString(newSound, sizeof(newSound), ".wav", ".mp3", false);
    
    char classname[32], classname_mvm[32];
    BuyRobot_GetClassNameForSound(TF2_GetPlayerClass(client), classname, sizeof(classname));
    Format(classname_mvm, sizeof(classname_mvm), "%s_mvm_m", classname);
    ReplaceString(newSound, sizeof(newSound), classname, classname_mvm, false);
    
    char fileCheck[PLATFORM_MAX_PATH];
    Format(fileCheck, sizeof(fileCheck), "sound/%s", newSound);
    
    if (FileExists(fileCheck, true))
    {
        EmitSoundToAll(newSound, client, channel, level, flags, volume, pitch);
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_PlayGiantLoop(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    
    TFClassType class = TF2_GetPlayerClass(client);
    
    switch(class)
    {
        case TFClass_Scout:
            EmitSoundToAll(GIANTSCOUT_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
        case TFClass_Soldier:
            EmitSoundToAll(GIANTSOLDIER_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
        case TFClass_DemoMan:
            EmitSoundToAll(GIANTDEMOMAN_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
        case TFClass_Heavy:
            EmitSoundToAll(GIANTHEAVY_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
        case TFClass_Pyro:
            EmitSoundToAll(GIANTPYRO_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
        case TFClass_Spy:
            EmitSoundToAll(GIANTSCOUT_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 0.25);
        case TFClass_Medic, TFClass_Engineer, TFClass_Sniper:
            EmitSoundToAll(GIANTSOLDIER_SND_LOOP, client, _, SNDLEVEL_DISHWASHER, SND_CHANGEVOL, 1.0);
    }
    
    return Plugin_Stop;
}

public Action BuyRobot_KickBot(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    delete pack;
    
    if (IsValidClientIndex(victim) && g_bBuyIsPurchasedRobot[victim])
    {
        if (IsPlayerAlive(victim))
        {
            ForcePlayerSuicide(victim);
        }
        
        CreateTimer(6.0, Timer_RemoveBotAfterRagdoll, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if (g_hWaitingQueue != null && g_hWaitingQueue.Length > 0)
    {
        if (GameRules_GetRoundState() == RoundState_RoundRunning)
        {
            Timer_ProcessWaitingQueue(null);
        }
    }
    
    return Plugin_Stop;
}

public Action Timer_RemoveBotAfterRagdoll(Handle timer, int userid)
{
    int victim = GetClientOfUserId(userid);
    
    if (victim > 0 && IsClientInGame(victim))
    {
        KickClient(victim, "Out of lives");
        BuyRobot_CleanupBot(victim);
    }
    
    return Plugin_Stop;
}

public Action BuyRobot_EventSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!g_bBuyIsPurchasedRobot[client]) return Plugin_Continue;
    
    TFTeam team = TF2_GetClientTeam(client);
    
    if (IsHalloweenActive())
    {
        BuyRobot_EquipZombieCosmetic(client);
    }
    else
    {
        BuyRobot_ApplyModel(client);
    }

    BuyRobot_EquipHat(client);
  
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    bool useUpgrades = g_cvBuyUseUpgrades.BoolValue;
    if (!useUpgrades || isGiant || isBoss || (team == TFTeam_Blue))
    {
        BuyRobot_ApplyAttributes(client);
        RemovePowerUpCanteen(client);
    }
    
    BuyRobot_ApplyInfiniteMetal(client);

    if (TF2_GetPlayerClass(client) == TFClass_Engineer && TF2_GetClientTeam(client) == TFTeam_Red)
    {
        CreateTimer(0.5, Timer_InfiniteSentryAmmo, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    
    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
    
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1)
    {
        TF2Util_SetPlayerActiveWeapon(client, weapon);
    }
    
    if (isGiant)
    {
        BuyRobot_ApplyGiantAttributes(client);
    }
    
    if (isBoss)
    {
        BuyRobot_ApplyBossAttributes(client);
    }
    
    if (g_cvBuyUseCustomLoadouts.BoolValue && !useUpgrades)
    {
        CreateTimer(0.3, Timer_ReapplyWeaponsAttributes, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if (g_cvBuyUseCustomSpawns.BoolValue && g_hSpawnPoints.Length > 0)
    {
        CreateTimer(0.1, Timer_ForceSpawnTeleport, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Continue;
}

public Action Timer_ReapplyWeaponsAttributes(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client] || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (!isGiant || !isBoss)
    {
        BuyRobot_ReapplyWeaponsAttributes(client);
    }
    
    BuyRobot_ApplyInfiniteMetal(client);

    if (TF2_GetPlayerClass(client) == TFClass_Engineer && TF2_GetClientTeam(client) == TFTeam_Red)
    {
        CreateTimer(0.5, Timer_InfiniteSentryAmmo, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if (isGiant)
    {
        BuyRobot_ReapplyGiantWeaponsAttributes(client);
    }
    
    if (isBoss)
    {
        BuyRobot_ReapplyBossWeaponsAttributes(client);
    }
    
    return Plugin_Stop;
}

void BuyRobot_ReapplyWeaponsAttributes(int client)
{
    TFClassType class = TF2_GetPlayerClass(client);
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
}

void BuyRobot_ReapplyGiantWeaponsAttributes(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
}

void BuyRobot_ReapplyBossWeaponsAttributes(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (weapon != -1) 
    {
	TF2Attrib_SetByName(weapon, "damage bonus", 3.6);
        TF2Attrib_SetByName(weapon, "fire rate bonus", 0.3);
        TF2Attrib_SetByName(weapon, "faster reload rate", 0.1);
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo primary increased"))
            TF2Attrib_SetByName(weapon, "maxammo primary increased", 999.0);
    }
    
    int weapon2 = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (weapon2 != -1) 
    {
	TF2Attrib_SetByName(weapon2, "damage bonus", 3.6);
        TF2Attrib_SetByName(weapon2, "fire rate bonus", 0.3);
        TF2Attrib_SetByName(weapon2, "faster reload rate", 0.1);
        if (TF2Attrib_IsValidAttributeName("ammo regen"))
            TF2Attrib_SetByName(weapon2, "ammo regen", 999.0);
        else if (TF2Attrib_IsValidAttributeName("maxammo secondary increased"))
            TF2Attrib_SetByName(weapon2, "maxammo secondary increased", 999.0);
    }
    
    int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
    if (melee != -1) 
    {
	TF2Attrib_SetByName(melee, "damage bonus", 3.6);
        TF2Attrib_SetByName(melee, "fire rate bonus", 0.3);
    }
}

public Action Timer_ForceSpawnTeleport(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    if (!g_cvBuyUseCustomSpawns.BoolValue || g_hSpawnPoints.Length == 0) return Plugin_Stop;
    
    TFTeam team = TF2_GetClientTeam(client);
    
    if (team == TFTeam_Blue)
    {
        bool hasTeleporterExit = false;
        
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
        {
            if (TF2_GetObjectMode(ent) != TFObjectMode_Exit)
                continue;
            
            if (TF2_IsBuilding(ent) || TF2_HasSapper(ent))
                continue;
            
            int builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
            if (builder <= 0 || !IsClientInGame(builder))
                continue;
                
            if (GetClientTeam(builder) == view_as<int>(TFTeam_Blue))
            {
                hasTeleporterExit = true;
                break;
            }
        }
        
        if (hasTeleporterExit)
        {
            return Plugin_Stop;
        }
    }
    
    int targetType = (team == TFTeam_Red) ? SPAWN_TYPE_RED : SPAWN_TYPE_BLUE;
    
    ArrayList validSpawns = new ArrayList();
    float posWithType[4];
    
    for (int i = 0; i < g_hSpawnPoints.Length; i++)
    {
        g_hSpawnPoints.GetArray(i, posWithType);
        if (RoundFloat(posWithType[3]) == targetType)
        {
            validSpawns.Push(i);
        }
    }
    
    if (validSpawns.Length == 0)
    {
        delete validSpawns;
        return Plugin_Stop;
    }
    
    int randomIndex = validSpawns.Get(GetRandomInt(0, validSpawns.Length - 1));
    g_hSpawnPoints.GetArray(randomIndex, posWithType);
    
    float ang[3];
    if (g_hSpawnAngles.Length > randomIndex)
        g_hSpawnAngles.GetArray(randomIndex, ang);
    else
        ang = {0.0, 0.0, 0.0};
    
    float spawnPos[3];
    spawnPos[0] = posWithType[0];
    spawnPos[1] = posWithType[1];
    spawnPos[2] = posWithType[2];
    
    TeleportEntity(client, spawnPos, ang, NULL_VECTOR);
    EmitSoundToAll("mvm/mvm_tele_deliver.wav", client, SNDCHAN_STATIC, SNDLEVEL_NORMAL, _, 1.0);
    TF2_AddCondition(client, TFCond_Ubercharged, 3.0);
    
    delete validSpawns;
    return Plugin_Stop;
}

public Action BuyRobot_EventDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int basePoints = g_cvBuyPointsPerKill.IntValue;
    int points = basePoints;
    bool isGiant = false;
    bool isBoss = false;
    
    if (victim > 0 && victim <= MaxClients && IsClientInGame(victim))
    {
        if (TF2_IsMiniBoss(victim) && !IsSentryBusterRobot(victim))
        {
            char victimName[64];
            GetClientName(victim, victimName, sizeof(victimName));
            
            if (g_bBuyIsPurchasedRobot[victim] && StrContains(victimName, "Boss") != -1)
            {
                isBoss = true;
                points = basePoints * 15;
            }
            else
            {
                isGiant = true;
                points = basePoints * 3;
            }
        }
    }
    
    if (attacker > 0 && attacker <= MaxClients && attacker != victim && IsValidClientIndex(attacker))
    {
        if (g_bBuyIsPurchasedRobot[attacker])
        {
            int owner = g_iBuyRobotOwner[attacker];
            char attackerName[64];
            GetClientName(attacker, attackerName, sizeof(attackerName));
            bool isGiantBot = (StrContains(attackerName, "Giant") != -1);
            bool isBossBot = (StrContains(attackerName, "Boss") != -1);
            
            if (owner > 0 && owner <= MaxClients && IsClientInGame(owner))
            {
                g_iBuyPlayerPoints[owner] += points;
                BuyRobot_SavePlayerPoints(owner);
                BuyRobot_SaveAllPoints();
                
                if (g_cvBuyNotifyKills.BoolValue)
                {
                    char victimName[64];
                    GetClientName(victim, victimName, sizeof(victimName));
                    int victimTeam = GetClientTeam(victim);
                    
                    if (isBoss)
                    {
                        if (isBossBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x0742A5F5%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x07FF0000%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                        }
                        else if (isGiantBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                        }
                        else
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts (x15 BONUS!)", attackerName, victimName, points);
                        }
                    }
                    else if (isGiant)
                    {
                        if (isBossBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x0742A5F5%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x07FF0000%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                        }
                        else if (isGiantBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                        }
                        else
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts (x3 bonus!)", attackerName, victimName, points);
                        }
                    }
                    else
                    {
                        if (isBossBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x0742A5F5%s\x01 +%d pts", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 killed \x07FF0000%s\x01 +%d pts", attackerName, victimName, points);
                        }
                        else if (isGiantBot)
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts", attackerName, victimName, points);
                        }
                        else
                        {
                            if (victimTeam == view_as<int>(TFTeam_Blue))
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x0742A5F5%s\x01 +%d pts", attackerName, victimName, points);
                            else
                                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 killed \x07FF0000%s\x01 +%d pts", attackerName, victimName, points);
                        }
                    }
                }
            }
        }
        else if (g_bIsDefenderBot[attacker])
        {
            g_iBuyPlayerPoints[attacker] += points;
            BuyRobot_SavePlayerPoints(attacker);
            BuyRobot_SaveAllPoints();
            
            char victimName[64];
            GetClientName(victim, victimName, sizeof(victimName));
            int victimTeam = GetClientTeam(victim);
            
            if (isBoss)
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts (x15 BONUS!)", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts (x15 BONUS!)", victimName, points);
            }
            else if (isGiant)
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts (x3 bonus!)", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts (x3 bonus!)", victimName, points);
            }
            else
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts", victimName, points);
            }
        }
        else if (!IsFakeClient(attacker))
        {
            g_iBuyPlayerPoints[attacker] += points;
            BuyRobot_SavePlayerPoints(attacker);
            BuyRobot_SaveAllPoints();
            
            char victimName[64];
            GetClientName(victim, victimName, sizeof(victimName));
            int victimTeam = GetClientTeam(victim);
            
            if (isBoss)
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts (x15 BONUS!)", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts (x15 BONUS!)", victimName, points);
            }
            else if (isGiant)
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts (x3 bonus!)", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts (x3 bonus!)", victimName, points);
            }
            else
            {
                if (victimTeam == view_as<int>(TFTeam_Blue))
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x0742A5F5%s\x01 +%d pts", victimName, points);
                else
                    PrintToChat(attacker, "\x0732CD32[Buy Robot]\x01 Killed \x07FF0000%s\x01 +%d pts", victimName, points);
            }
        }
    }
    
    if (victim > 0 && victim <= MaxClients && g_bBuyIsPurchasedRobot[victim])
    {
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "entity_revive_marker")) != -1)
        {
            if (GetEntPropEnt(ent, Prop_Send, "m_hOwner") == victim)
            {
                AcceptEntityInput(ent, "Kill");
            }
        }
        
        char victimName[64];
        GetClientName(victim, victimName, sizeof(victimName));
        
        bool isVictimGiant = (StrContains(victimName, "Giant") != -1);
        bool isVictimBoss = (StrContains(victimName, "Boss") != -1);
        
        if (isVictimGiant || isVictimBoss)
        {
            g_iBuyRobotLives[victim] = 0;
            
            if (TF2_GetClientTeam(victim) == TFTeam_Blue)
            {
                RemoveRobotFromWaveBar(victim);
            }
            
            int owner = g_iBuyRobotOwner[victim];
            
            if (g_cvBuyNotifyLives.BoolValue && IsValidClientIndex(owner))
            {
                if (isVictimBoss)
                    PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x07FF1493%s\x01 was destroyed and removed!", victimName);
                else
                    PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 was destroyed and removed!", victimName);
            }
            
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(victim));
            CreateTimer(0.1, BuyRobot_KickBot, pack, TIMER_FLAG_NO_MAPCHANGE);
            return Plugin_Continue;
        }
        
        g_iBuyRobotLives[victim]--;
        
        int owner = g_iBuyRobotOwner[victim];
        
        if (g_iBuyRobotLives[victim] <= 0)
        {
            if (TF2_GetClientTeam(victim) == TFTeam_Blue)
            {
                RemoveRobotFromWaveBar(victim);
            }
            
            if (g_cvBuyNotifyLives.BoolValue && IsValidClientIndex(owner))
            {
                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 has run out of lives and will be removed!", victimName);
            }
            
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(victim));
            CreateTimer(0.1, BuyRobot_KickBot, pack, TIMER_FLAG_NO_MAPCHANGE);
        }
        else
        {
            if (g_cvBuyNotifyLives.BoolValue && IsValidClientIndex(owner))
            {
                PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 lost a life! Remaining: \x07FFD700%d\x01 | Respawning in 5 seconds...", victimName, g_iBuyRobotLives[victim]);
            }
            
            CreateTimer(5.0, Timer_RespawnAtSpawnPoint, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
        }
    }

    if (g_hWaitingQueue != null && g_hWaitingQueue.Length > 0)
    {
        if (GameRules_GetRoundState() == RoundState_RoundRunning)
        {
            Timer_ProcessWaitingQueue(null);
        }
    }
    
    return Plugin_Continue;
}

public Action BuyRobot_EventTeamChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = event.GetInt("team");
    
    if (!g_bBuyIsPurchasedRobot[client])
        return Plugin_Continue;
    
    if (team == view_as<int>(TFTeam_Spectator))
    {
        BuyRobot_CleanupBot(client);
    }
    
    return Plugin_Continue;
}

public void BuyRobot_CleanupBot(int client)
{
    if (!IsClientInGame(client)) return;

if (g_bBuyIsPurchasedRobot[client] && TF2_GetClientTeam(client) == TFTeam_Blue && IsPlayerAlive(client))
{
    RemoveRobotFromWaveBar(client);
}
    
    g_bBuyIsPurchasedRobot[client] = false;
    g_bBuyIsAIRobot[client] = false;
    g_iBuyRobotLives[client] = 0;
    g_iBuyRobotOwner[client] = 0;
    g_iBuyRobotHatIndex[client] = 0;
    g_bIsDefenderBot[client] = false;
    g_bChoosingBotClasses[client] = false;
    g_bEngineerHelpDisabled[client] = false;
    g_bRobotFrozen[client] = false;
    CleanupEngineerNest(client);
    BuyRobot_RemoveWearables(client);
    ResetLoadouts(client);
  
    g_bHeavyWindDown[client] = false;
    g_bHeavyLocked1[client] = false;
    g_bHeavyLocked2[client] = false;
    g_bHeavyLocked3[client] = false;
    g_bPyroLocked1[client] = false;
    g_bPyroLocked2[client] = false;
    
    StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunwindup.wav");
    StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
    StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
    StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunwinddown.wav");
    StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_start.wav");
    StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_loop.wav");
    StopSound(client, SNDCHAN_AUTO, GIANTSCOUT_SND_LOOP);
    StopSound(client, SNDCHAN_AUTO, GIANTSOLDIER_SND_LOOP);
    StopSound(client, SNDCHAN_AUTO, GIANTPYRO_SND_LOOP);
    StopSound(client, SNDCHAN_AUTO, GIANTDEMOMAN_SND_LOOP);
    StopSound(client, SNDCHAN_AUTO, GIANTHEAVY_SND_LOOP);
    
    if (g_hWaitingQueue != null && g_hWaitingQueue.Length > 0)
    {
        if (GameRules_GetRoundState() == RoundState_RoundRunning)
        {
            CreateTimer(0.5, Timer_ProcessWaitingQueueDelayed, _, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action Timer_ProcessWaitingQueueDelayed(Handle timer)
{
    Timer_ProcessWaitingQueue(null);
    return Plugin_Stop;
}

public Action BuyRobot_ValidationTimer(Handle timer)
{
    if (timer != g_hValidationTimer) return Plugin_Stop;
    BuyRobot_ValidateBots();
    return Plugin_Continue;
}

void BuyRobot_ValidateBots()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsClientSourceTV(i) || IsClientReplay(i))
        {
            if (g_bBuyIsPurchasedRobot[i])
            {
                g_bBuyIsPurchasedRobot[i] = false;
                g_iBuyRobotLives[i] = 0;
                g_iBuyRobotOwner[i] = 0;
            }
            continue;
        }
    }
}

public Action Timer_SaxtonAI(Handle timer)
{
    if (!g_cvBuySaxtonAI.BoolValue)
        return Plugin_Stop;
    
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return Plugin_Stop;
    
    CheckAndSendSaxtonHale();
    
    return Plugin_Continue;
}

public Action Timer_GrayMann(Handle timer)
{
    if (!g_cvGrayMannAI.BoolValue)
        return Plugin_Continue;

    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return Plugin_Continue;
    
    CheckAndSendGrayMann();
    
    return Plugin_Continue;
}

int GetTotalBotsCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        if (IsFakeClient(i) && g_bBuyIsPurchasedRobot[i] && (TF2_GetClientTeam(i) == TFTeam_Red || TF2_GetClientTeam(i) == TFTeam_Blue))
            count++;
    }
    return count;
}

void CheckAndSendSaxtonHale()
{
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return;
    
    int maxDefenders = GetConVarInt(FindConVar("tf_mvm_defenders_team_size"));
    if (maxDefenders <= 0)
        return;
    
    int currentDefenders = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i))
            currentDefenders++;
    }
    
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = GetTotalBotsCount();
    int availablePurchaseSlots = maxBots - currentBots;
    
    if (availablePurchaseSlots <= 0)
        return;
    
    int enemyCount = 0;
    int enemyGiantCount = 0;
    int enemyBossCount = 0;
    int redGiantCount = 0;
    int redBossCount = 0;
    int humanCount = 0;
    int defenderCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        int team = TF2_GetClientTeam(i);
        
        if (team == TFTeam_Blue)
        {
            if (IsPlayerAlive(i))
            {
                enemyCount++;
                if (TF2_IsMiniBoss(i))
                {
                    char name[64];
                    GetClientName(i, name, sizeof(name));
                    if (StrContains(name, "Boss") != -1)
                        enemyBossCount++;
                    else
                        enemyGiantCount++;
                }
            }
        }
        else if (team == TFTeam_Red)
        {
            if (IsFakeClient(i) && g_bBuyIsPurchasedRobot[i])
            {
                char name[64];
                GetClientName(i, name, sizeof(name));
                if (StrContains(name, "Boss") != -1)
                    redBossCount++;
                else if (StrContains(name, "Giant") != -1)
                    redGiantCount++;
            }
            else if (IsFakeClient(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i])
            {
                defenderCount++;
            }
            else if (!IsFakeClient(i))
            {
                humanCount++;
            }
        }
    }
    
    int totalRed = humanCount + defenderCount + redGiantCount + redBossCount;
    
    if (totalRed >= enemyCount)
        return;
    
    int shortage = enemyCount - totalRed;
    if (shortage < 1)
        return;
    
    int giantsNeeded = enemyGiantCount - redGiantCount;
    int bossesNeeded = enemyBossCount - redBossCount;
    
    if (giantsNeeded < 0) giantsNeeded = 0;
    if (bossesNeeded < 0) bossesNeeded = 0;
    
    int maxBossAllowed = g_cvMaxBossPerTeam.IntValue;
    int currentRedBoss = GetCurrentBossCountForTeam(TFTeam_Red);
    int bossSpace = maxBossAllowed - currentRedBoss;
    if (bossSpace < 0) bossSpace = 0;
    if (bossesNeeded > bossSpace) bossesNeeded = bossSpace;
    
    int botsToAdd = shortage;
    if (botsToAdd < 2) botsToAdd = 2;
    if (botsToAdd > availablePurchaseSlots) botsToAdd = availablePurchaseSlots;
    
    if (giantsNeeded > botsToAdd) giantsNeeded = botsToAdd;
    if (bossesNeeded > botsToAdd - giantsNeeded) bossesNeeded = botsToAdd - giantsNeeded;
    
    float currentTime = GetGameTime();
    float delay = g_cvBuySaxtonDelay.FloatValue;
    
    if (currentTime - g_flLastSendTime >= delay && currentTime - g_flLastAnySendTime >= 1.0 && botsToAdd > 0)
    {
        SendSaxtonHale(botsToAdd, giantsNeeded, bossesNeeded);
        g_flLastSendTime = currentTime;
        g_flLastAnySendTime = currentTime;
        g_iWaveBonusCounter++;
    }
}

void SendSaxtonHale(int count, int giantsToSend, int bossesToSend)
{
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = GetTotalBotsCount();
    int availableSlots = maxBots - currentBots;
    
    if (availableSlots <= 0)
        return;
    
    if (count > availableSlots)
        count = availableSlots;
    if (giantsToSend > count) giantsToSend = count;
    if (bossesToSend > count - giantsToSend) bossesToSend = count - giantsToSend;
    
    int maxBossAllowed = g_cvMaxBossPerTeam.IntValue;
    int currentRedBoss = GetCurrentBossCountForTeam(TFTeam_Red);
    int bossSpace = maxBossAllowed - currentRedBoss;
    if (bossSpace < 0) bossSpace = 0;
    if (bossesToSend > bossSpace) bossesToSend = bossSpace;
    
    char classes[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
    
    int classCount[9] = {0,0,0,0,0,0,0,0,0};
    int created = 0;
    
for (int i = 0; i < bossesToSend; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "Boss", true, TFTeam_Red);
    created++;
    classCount[selected]++;
}

for (int i = 0; i < giantsToSend; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "Giant", true, TFTeam_Red);
    created++;
    classCount[selected]++;
}

int normalToAdd = count - giantsToSend - bossesToSend;
if (normalToAdd < 0) normalToAdd = 0;

for (int i = 0; i < normalToAdd; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "", true, TFTeam_Red);
    created++;
    classCount[selected]++;
}
    
    if (created == 0)
        return;
    
    char classList[256];
    classList[0] = '\0';
    bool first = true;
    
    for (int i = 0; i < 9; i++)
    {
        if (classCount[i] > 0)
        {
            char displayName[32];
            BuyRobot_GetClassName(classes[i], displayName, sizeof(displayName));
            
            if (!first)
                StrCat(classList, sizeof(classList), ", ");
            
            if (classCount[i] > 1)
                Format(classList, sizeof(classList), "%s%d %s", classList, classCount[i], displayName);
            else
                Format(classList, sizeof(classList), "%s%s", classList, displayName);
            
            first = false;
        }
    }
    
    char finalMessage[512];
    char messages[5][256];
    
    if (bossesToSend > 0)
    {
        messages[0] = "\x07FF4500Saxton Hale\x01: Sending reinforcements: %s + \x07FF1493%d BOSS Robot(s)\x01!";
        messages[1] = "\x07FF4500Saxton Hale\x01: Reinforcements inbound: %s + \x07FF1493%d BOSS(s)\x01!";
        messages[2] = "\x07FF4500Saxton Hale\x01: Deploying: %s + \x07FF1493%d BOSS Robot(s)\x01!";
        messages[3] = "\x07FF4500Saxton Hale\x01: Backup arriving: %s + \x07FF1493%d BOSS(s)\x01!";
        messages[4] = "\x07FF4500Saxton Hale\x01: Extra unit(s): %s + \x07FF1493%d BOSS Robot(s)\x01!";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, bossesToSend);
    }
    else if (giantsToSend > 0)
    {
        messages[0] = "\x07FF4500Saxton Hale\x01: Sending reinforcements: %s + \x078B008B%d Giant Robot(s)\x01!";
        messages[1] = "\x07FF4500Saxton Hale\x01: Reinforcements inbound: %s + \x078B008B%d Giant(s)\x01!";
        messages[2] = "\x07FF4500Saxton Hale\x01: Deploying: %s + \x078B008B%d Giant Robot(s)\x01!";
        messages[3] = "\x07FF4500Saxton Hale\x01: Backup arriving: %s + \x078B008B%d Giant(s)\x01!";
        messages[4] = "\x07FF4500Saxton Hale\x01: Extra unit(s): %s + \x078B008B%d Giant Robot(s)\x01!";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, giantsToSend);
    }
    else
    {
        messages[0] = "\x07FF4500Saxton Hale\x01: Sending reinforcements: %s, %d unit(s)";
        messages[1] = "\x07FF4500Saxton Hale\x01: Reinforcements inbound: %s, %d unit(s)";
        messages[2] = "\x07FF4500Saxton Hale\x01: Deploying: %s, %d unit(s)";
        messages[3] = "\x07FF4500Saxton Hale\x01: Backup arriving: %s, %d unit(s)";
        messages[4] = "\x07FF4500Saxton Hale\x01: Extra unit(s): %s, %d unit(s)";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, created);
    }
    
    PrintToChatAll("%s", finalMessage);
}

void CheckAndSendGrayMann()
{
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return;
    
    int maxInvaders = GetConVarInt(FindConVar("tf_mvm_max_invaders"));
    if (maxInvaders <= 0)
        return;
    
    int currentInvaders = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
            currentInvaders++;
    }
    
    int availableSlots = maxInvaders - currentInvaders;
    if (availableSlots <= 0)
        return;
    
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = GetTotalBotsCount();
    int availablePurchaseSlots = maxBots - currentBots;
    
    if (availablePurchaseSlots <= 0)
        return;
    
    int redCount = 0;
    int redGiantCount = 0;
    int redBossCount = 0;
    int blueCount = 0;
    int blueGiantCount = 0;
    int blueBossCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        int team = TF2_GetClientTeam(i);
        
        if (team == TFTeam_Red)
        {
            if (IsPlayerAlive(i))
            {
                redCount++;
                if (TF2_IsMiniBoss(i))
                {
                    char name[64];
                    GetClientName(i, name, sizeof(name));
                    if (StrContains(name, "Boss") != -1)
                        redBossCount++;
                    else
                        redGiantCount++;
                }
            }
        }
        else if (team == TFTeam_Blue)
        {
            if (IsPlayerAlive(i))
            {
                blueCount++;
                if (g_bBuyIsPurchasedRobot[i] && TF2_IsMiniBoss(i))
                {
                    char name[64];
                    GetClientName(i, name, sizeof(name));
                    if (StrContains(name, "Boss") != -1)
                        blueBossCount++;
                    else if (StrContains(name, "Giant") != -1)
                        blueGiantCount++;
                }
            }
        }
    }
    
    int totalBlue = blueCount + blueGiantCount + blueBossCount;
    
    if (totalBlue >= redCount)
        return;
    
    int shortage = redCount - totalBlue;
    if (shortage < 1)
        return;
    
    int giantsNeeded = redGiantCount - blueGiantCount;
    int bossesNeeded = redBossCount - blueBossCount;
    
    if (giantsNeeded < 0) giantsNeeded = 0;
    if (bossesNeeded < 0) bossesNeeded = 0;
    
    int maxBossAllowed = g_cvMaxBossPerTeam.IntValue;
    int currentBlueBoss = GetCurrentBossCountForTeam(TFTeam_Blue);
    int bossSpace = maxBossAllowed - currentBlueBoss;
    if (bossSpace < 0) bossSpace = 0;
    if (bossesNeeded > bossSpace) bossesNeeded = bossSpace;
    
    int botsToAdd = shortage;
    if (botsToAdd < 2) botsToAdd = 2;
    if (botsToAdd > availablePurchaseSlots) botsToAdd = availablePurchaseSlots;
    if (botsToAdd > availableSlots) botsToAdd = availableSlots;
    
    if (giantsNeeded > botsToAdd) giantsNeeded = botsToAdd;
    if (bossesNeeded > botsToAdd - giantsNeeded) bossesNeeded = botsToAdd - giantsNeeded;
    
    float currentTime = GetGameTime();
    float delay = g_cvGrayMannDelay.FloatValue;
    
    if (currentTime - g_flLastSendTime2 >= delay && currentTime - g_flLastAnySendTime >= 1.0 && botsToAdd > 0)
    {
        SendGrayMann(botsToAdd, giantsNeeded, bossesNeeded);
        g_flLastSendTime2 = currentTime;
        g_flLastAnySendTime = currentTime;
        g_iWaveBonusCounter2++;
    }
}

void SendGrayMann(int count, int giantsToSend, int bossesToSend)
{
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = GetTotalBotsCount();
    int availableSlots = maxBots - currentBots;
    
    if (availableSlots <= 0)
        return;
    
    if (count > availableSlots)
        count = availableSlots;
    if (giantsToSend > count) giantsToSend = count;
    if (bossesToSend > count - giantsToSend) bossesToSend = count - giantsToSend;
    
    int maxBossAllowed = g_cvMaxBossPerTeam.IntValue;
    int currentBlueBoss = GetCurrentBossCountForTeam(TFTeam_Blue);
    int bossSpace = maxBossAllowed - currentBlueBoss;
    if (bossSpace < 0) bossSpace = 0;
    if (bossesToSend > bossSpace) bossesToSend = bossSpace;
    
    char classes[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
    
    int classCount[9] = {0,0,0,0,0,0,0,0,0};
    int created = 0;
    
for (int i = 0; i < bossesToSend; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "Boss", true, TFTeam_Blue);
    created++;
    classCount[selected]++;
}

for (int i = 0; i < giantsToSend; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "Giant", true, TFTeam_Blue);
    created++;
    classCount[selected]++;
}

int normalToAdd = count - giantsToSend - bossesToSend;
if (normalToAdd < 0) normalToAdd = 0;

for (int i = 0; i < normalToAdd; i++)
{
    if (GetTotalBotsCount() >= maxBots) break;
    int selected = GetRandomInt(0, sizeof(classes) - 1);
    
    BuyRobot_CreateBot(classes[selected], 0, 1, "", true, TFTeam_Blue);
    created++;
    classCount[selected]++;
}
    
    if (created == 0)
        return;
    
    char classList[256];
    classList[0] = '\0';
    bool first = true;
    
    for (int i = 0; i < 9; i++)
    {
        if (classCount[i] > 0)
        {
            char displayName[32];
            BuyRobot_GetClassName(classes[i], displayName, sizeof(displayName));
            
            if (!first)
                StrCat(classList, sizeof(classList), ", ");
            
            if (classCount[i] > 1)
                Format(classList, sizeof(classList), "%s%d %s", classList, classCount[i], displayName);
            else
                Format(classList, sizeof(classList), "%s%s", classList, displayName);
            
            first = false;
        }
    }
    
    char finalMessage[512];
    char messages[5][256];
    
    if (bossesToSend > 0)
    {
        messages[0] = "\x075A9BDFGray Mann\x01: Sending reinforcements: %s + \x07FF1493%d BOSS Robot(s)\x01!";
        messages[1] = "\x075A9BDFGray Mann\x01: Reinforcements inbound: %s + \x07FF1493%d BOSS(s)\x01!";
        messages[2] = "\x075A9BDFGray Mann\x01: Deploying: %s + \x07FF1493%d BOSS Robot(s)\x01!";
        messages[3] = "\x075A9BDFGray Mann\x01: Backup arriving: %s + \x07FF1493%d BOSS(s)\x01!";
        messages[4] = "\x075A9BDFGray Mann\x01: Extra unit(s): %s + \x07FF1493%d BOSS Robot(s)\x01!";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, bossesToSend);
    }
    else if (giantsToSend > 0)
    {
        messages[0] = "\x075A9BDFGray Mann\x01: Sending reinforcements: %s + \x078B008B%d Giant Robot(s)\x01!";
        messages[1] = "\x075A9BDFGray Mann\x01: Reinforcements inbound: %s + \x078B008B%d Giant(s)\x01!";
        messages[2] = "\x075A9BDFGray Mann\x01: Deploying: %s + \x078B008B%d Giant Robot(s)\x01!";
        messages[3] = "\x075A9BDFGray Mann\x01: Backup arriving: %s + \x078B008B%d Giant(s)\x01!";
        messages[4] = "\x075A9BDFGray Mann\x01: Extra unit(s): %s + \x078B008B%d Giant Robot(s)\x01!";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, giantsToSend);
    }
    else
    {
        messages[0] = "\x075A9BDFGray Mann\x01: Sending reinforcements: %s, %d unit(s)";
        messages[1] = "\x075A9BDFGray Mann\x01: Reinforcements inbound: %s, %d unit(s)";
        messages[2] = "\x075A9BDFGray Mann\x01: Deploying: %s, %d unit(s)";
        messages[3] = "\x075A9BDFGray Mann\x01: Backup arriving: %s, %d unit(s)";
        messages[4] = "\x075A9BDFGray Mann\x01: Extra unit(s): %s, %d unit(s)";
        Format(finalMessage, sizeof(finalMessage), messages[GetRandomInt(0, 4)], classList, created);
    }
    
    PrintToChatAll("%s", finalMessage);
}

public void BuyRobot_WaveBegin(Event event, const char[] name, bool dontBroadcast)
{
    if (bWaveBeginProcessed && (GetGameTime() - fLastWaveBeginTime) < 5.0)
    {
        return;
    }
    
    BuyRobot_SpawnCheck_Start();
    
    bWaveBeginProcessed = true;
    fLastWaveBeginTime = GetGameTime();
    g_flLastSendTime = GetGameTime();
    g_flLastSendTime2 = GetGameTime();
    g_flLastAnySendTime = GetGameTime();
    
    CreateTimer(10.0, BuyRobot_ResetWaveBeginFlag);
    
    if (g_hBuyAutoTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBuyAutoTimer);
        g_hBuyAutoTimer = INVALID_HANDLE;
    }
    
    if (g_cvBuyAllowDefenderBots.BoolValue)
    {
        if (g_hBuyAutoTimer != INVALID_HANDLE)
        {
            KillTimer(g_hBuyAutoTimer);
            g_hBuyAutoTimer = INVALID_HANDLE;
        }
        
        g_hBuyAutoTimer = CreateTimer(15.0, BuyRobot_AutoBuy, _, TIMER_REPEAT);
    }
    
    if (g_cvBuySaxtonAI.BoolValue)
    {
        CreateTimer(0.5, Timer_SaxtonAI, _, TIMER_REPEAT);
    }
    
    if (g_cvGrayMannAI.BoolValue)
    {
        CreateTimer(0.5, Timer_GrayMann, _, TIMER_REPEAT);
    }
    
if (g_cvBuyWaveBonusEnable.BoolValue)
{
    int currentBots = BuyRobot_GetPurchasedCount();
    int maxBots = g_cvBuyMaxBots.IntValue;
    
    if (currentBots >= maxBots)
    {
        char messages[5][256];
        
        messages[0] = "\x07FF4500Saxton Hale\x01: I wanted to send reinforcements but we're at max capacity! (%d/%d robots)";
        messages[1] = "\x07FF4500Saxton Hale\x01: Sorry lads, no room for more robots! (%d/%d)";
        messages[2] = "\x07FF4500Saxton Hale\x01: The robot bay is full! Can't send more! (%d/%d)";
        messages[3] = "\x07FF4500Saxton Hale\x01: We're packed to the brim! (%d/%d robots already!)";
        messages[4] = "\x07FF4500Saxton Hale\x01: Maybe next wave! No space left! (%d/%d)";
        
        int random = GetRandomInt(0, 4);
        PrintToChatAll(messages[random], currentBots, maxBots);
        return;
    }
    
    int availableSlots = maxBots - currentBots;
    int chance = g_cvBuyWaveBonusChance.IntValue;
    
    if (GetRandomInt(1, 100) <= chance)
    {
        int bonusCount = g_cvBuyWaveBonusCount.IntValue;
        
        if (bonusCount > availableSlots)
        {
            bonusCount = availableSlots;
        }
        
        if (bonusCount > 0)
        {
            char classes[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
            int classCount[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};
            
            for (int i = 0; i < bonusCount; i++)
            {
                int randomClass = GetRandomInt(0, sizeof(classes) - 1);
                char className[32];
                BuyRobot_GetClassName(classes[randomClass], className, sizeof(className));
                
                BuyRobot_CreateBot(classes[randomClass], 0, 1, className, true, TFTeam_Red);
                classCount[randomClass]++;
            }
            
            char classList[256];
            classList[0] = '\0';
            bool first = true;
            
            for (int i = 0; i < 9; i++)
            {
                if (classCount[i] > 0)
                {
                    char displayName[32];
                    BuyRobot_GetClassName(classes[i], displayName, sizeof(displayName));
                    
                    if (!first)
                        StrCat(classList, sizeof(classList), ", ");
                    
                    if (classCount[i] > 1)
                        Format(classList, sizeof(classList), "%s%d %s", classList, classCount[i], displayName);
                    else
                        Format(classList, sizeof(classList), "%s%s", classList, displayName);
                    
                    first = false;
                }
            }
            
            char successMessages[5][256];
            
            successMessages[0] = "\x07FF4500Saxton Hale\x01: I sent reinforcements: %s!";
            successMessages[1] = "\x07FF4500Saxton Hale\x01: Here's %s to smash those tin cans!";
            successMessages[2] = "\x07FF4500Saxton Hale\x01: Sent %s to show Gray Mann who's boss!";
            successMessages[3] = "\x07FF4500Saxton Hale\x01: %s incoming! Now THAT'S Australian!";
            successMessages[4] = "\x07FF4500Saxton Hale\x01: Don't worry, I sent %s to help!";
            
            int random = GetRandomInt(0, 4);
            PrintToChatAll(successMessages[random], classList);
        }
    }
}
}

public Action BuyRobot_ResetWaveBeginFlag(Handle timer)
{
    bWaveBeginProcessed = false;
    return Plugin_Stop;
}

public void BuyRobot_WaveEnd(Event event, const char[] name, bool dontBroadcast)
{
    BuyRobot_SpawnCheck_Stop();
    
    if (g_hBuyAutoTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBuyAutoTimer);
        g_hBuyAutoTimer = INVALID_HANDLE;
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
        {
            KickClient(i, "Wave ended");
            BuyRobot_CleanupBot(i);
        }
    }
    
    if (g_cvBuyKickOnWaveEnd.BoolValue)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && !g_bBuyIsAIRobot[i] && TF2_GetClientTeam(i) == TFTeam_Red)
            {
                KickClient(i, "Wave ended");
                BuyRobot_CleanupBot(i);
            }
        }
    }
    
    if (g_cvBuyRemoveUnitsBots.BoolValue)
    {
        RemoveUnitsAIBots();
    }
}

public void BuyRobot_WaveFailed(Event event, const char[] name, bool dontBroadcast)
{
    g_iWaveFailCounterTick++;
    
    if (g_iWaveFailCounterTick == 1)
    {
        CreateTimer(0.1, Timer_ForceRefreshModels, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    CreateTimer(0.5, Timer_ResetWaveFailCounter, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ResetWaveFailCounter(Handle timer)
{
    g_iWaveFailCounterTick = 0;
    return Plugin_Stop;
}

public Action BuyRobot_OnMissionUpdate(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvBuyEnable.BoolValue || !g_cvBuyAllowDefenderBots.BoolValue)
    {
        return Plugin_Continue;
    }
    
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
    {
        return Plugin_Continue;
    }
    
    if (g_hBuyAutoTimer != INVALID_HANDLE)
    {
        CreateTimer(0.5, Timer_CheckBuyTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckBuyTimer(Handle timer)
{
    if (!g_cvBuyEnable.BoolValue || !g_cvBuyAllowDefenderBots.BoolValue)
    {
        return Plugin_Stop;
    }
    
    if (g_hBuyAutoTimer == INVALID_HANDLE)
    {
        if (GameRules_GetRoundState() == RoundState_RoundRunning)
        {
            g_hBuyAutoTimer = CreateTimer(15.0, BuyRobot_AutoBuy, _, TIMER_REPEAT);
        }
    }
    
    return Plugin_Stop;
}

public Action BuyRobot_AutoBuy(Handle timer)
{
    BuyRobot_ValidateBots();
    
    if (GameRules_GetRoundState() != RoundState_RoundRunning) 
    {
        if (g_hBuyAutoTimer != INVALID_HANDLE)
        {
            KillTimer(g_hBuyAutoTimer);
            g_hBuyAutoTimer = INVALID_HANDLE;
        }
        return Plugin_Stop;
    }
    
    if (!g_cvBuyEnable.BoolValue || !g_cvBuyAllowDefenderBots.BoolValue) 
    {
        return Plugin_Continue;
    }
    
    int currentBots = BuyRobot_GetPurchasedCount();
    if (currentBots >= g_cvBuyMaxBots.IntValue) 
    {
        return Plugin_Continue;
    }
    
    float interval = g_cvBuyInterval.FloatValue;
    int maxOwned = g_cvBuyMaxPerBot.IntValue;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClientIndex(i) || !IsFakeClient(i)) continue;
        
        if (!g_bIsDefenderBot[i] || g_bBuyIsPurchasedRobot[i]) continue;
        
        if (TF2_GetClientTeam(i) != TFTeam_Red || !IsPlayerAlive(i)) continue;
        if (GetGameTime() - g_flBuyLastBotBuyTime[i] < interval) continue;
        
        int ownedBots = BuyRobot_CountOwnedBots(i);
        if (ownedBots >= maxOwned) continue;
        
        int points = g_iBuyPlayerPoints[i];
        
        bool bought = false;
        
        int giantPrice = RoundFloat(g_cvPriceSoldier.IntValue * BUY_PRICE_GIANT_MULT);
        if (!bought && points >= giantPrice && GetRandomInt(1, 100) <= 30)
        {
            BuyRobot_DoBotBuy(i, BUY_CATEGORY_GIANT);
            g_flBuyLastBotBuyTime[i] = GetGameTime();
            bought = true;
        }
        
        if (!bought)
        {
            char allClasses[9][32] = {"soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "scout", "sniper"};
            int prices[9];
            
            prices[0] = g_cvPriceSoldier.IntValue;
            prices[1] = g_cvPricePyro.IntValue;
            prices[2] = g_cvPriceDemoman.IntValue;
            prices[3] = g_cvPriceHeavy.IntValue;
            prices[4] = g_cvPriceEngineer.IntValue;
            prices[5] = g_cvPriceMedic.IntValue;
            prices[6] = g_cvPriceSpy.IntValue;
            prices[7] = g_cvPriceScout.IntValue;
            prices[8] = g_cvPriceSniper.IntValue;
            
            ArrayList affordable = new ArrayList();
            for (int j = 0; j < 9; j++)
            {
                if (points >= prices[j])
                {
                    affordable.Push(j);
                }
            }
            
            if (affordable.Length > 0)
            {
                BuyRobot_DoBotBuy(i, BUY_CATEGORY_SINGLE);
                g_flBuyLastBotBuyTime[i] = GetGameTime();
                bought = true;
            }
            
            delete affordable;
        }
    }
    
    return Plugin_Continue;
}

void BuyRobot_DoBotBuy(int bot, int category)
{
    char class[32];
    int price;
    int lives;
    char prefix[32];
    TFTeam team = TFTeam_Red;
    
    if (category == BUY_CATEGORY_BOSS)
    {
        int bossCount = GetCurrentBossCountForTeam(team);
        if (bossCount >= g_cvMaxBossPerTeam.IntValue)
            return;
    }
    
    if (category == BUY_CATEGORY_GIANT)
    {
        char giantClasses[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
        strcopy(class, sizeof(class), giantClasses[GetRandomInt(0, sizeof(giantClasses) - 1)]);
        
        price = RoundFloat(BuyRobot_GetClassPrice(class) * BUY_PRICE_GIANT_MULT);
        lives = 1;
        strcopy(prefix, sizeof(prefix), "Giant");
    }
    else if (category == BUY_CATEGORY_BOSS)
    {
        char bossClasses[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
        strcopy(class, sizeof(class), bossClasses[GetRandomInt(0, sizeof(bossClasses) - 1)]);
        
        price = RoundFloat(BuyRobot_GetClassPrice(class) * BUY_PRICE_BOSS_MULT);
        lives = 1;
        strcopy(prefix, sizeof(prefix), "Boss");
    }
    else
    {
        char classes[][] = {"scout", "soldier", "pyro", "demoman", "heavyweapons", "engineer", "medic", "spy", "sniper"};
        strcopy(class, sizeof(class), classes[GetRandomInt(0, sizeof(classes) - 1)]);
        
        price = BuyRobot_GetClassPrice(class);
        lives = g_cvBuyDefaultLives.IntValue;
        strcopy(prefix, sizeof(prefix), "");
    }
    
    if (GetMaxEntities() - GetEntityCount() < 3) return;
    if (GetClientCount() + 1 > MaxClients) return;
    if (BuyRobot_GetPurchasedCount() + 1 > g_cvBuyMaxBots.IntValue) return;
    if (g_iBuyPlayerPoints[bot] < price) return;
    
    g_iBuyPlayerPoints[bot] -= price;
    BuyRobot_SavePlayerPoints(bot);
    BuyRobot_SaveAllPoints();
    
    if (g_cvBuyNotifyDefenderPurchase.BoolValue)
    {
        char botName[MAX_NAME_LENGTH];
        GetClientName(bot, botName, sizeof(botName));
        
        char className[32];
        BuyRobot_GetClassName(class, className, sizeof(className));
        
        if (category == BUY_CATEGORY_GIANT)
        {
            PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%s\x01 bought a \x078B008BGiant %s\x01 robot!", botName, className);
        }
        else if (category == BUY_CATEGORY_BOSS)
        {
            PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%s\x01 bought a \x07FF1493Boss %s\x01 robot!", botName, className);
        }
        else
        {
            PrintToChatAll("\x0732CD32[Buy Robot]\x01 \x07FFD700%s\x01 bought a \x07FFD700%s\x01 robot!", botName, className);
        }
    }
    
    BuyRobot_CreateBot(class, bot, lives, prefix, false, team);
}

bool BuyRobot_CanUseMenu(int client)
{
    if (!IsValidClientIndex(client)) return false;
    
    if (!IsFakeClient(client)) return true;
    
    if (g_cvBuyAllowDefenderBots.BoolValue && IsFakeClient(client) && g_bIsDefenderBot[client] && !g_bBuyIsPurchasedRobot[client])
    {
        return true;
    }
    
    return false;
}

int BuyRobot_GetPurchasedCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i]) count++;
    return count;
}

int BuyRobot_GetClassPrice(const char[] class)
{
    if (StrEqual(class, "soldier")) return g_cvPriceSoldier.IntValue;
    if (StrEqual(class, "pyro")) return g_cvPricePyro.IntValue;
    if (StrEqual(class, "demoman")) return g_cvPriceDemoman.IntValue;
    if (StrEqual(class, "heavyweapons")) return g_cvPriceHeavy.IntValue;
    if (StrEqual(class, "engineer")) return g_cvPriceEngineer.IntValue;
    if (StrEqual(class, "medic")) return g_cvPriceMedic.IntValue;
    if (StrEqual(class, "spy")) return g_cvPriceSpy.IntValue;
    if (StrEqual(class, "scout")) return g_cvPriceScout.IntValue;
    if (StrEqual(class, "sniper")) return g_cvPriceSniper.IntValue;
    
    return g_cvPriceSoldier.IntValue;
}

void BuyRobot_GetClassName(const char[] class, char[] buffer, int maxlen)
{
    if (StrEqual(class, "scout")) strcopy(buffer, maxlen, "Scout");
    else if (StrEqual(class, "soldier")) strcopy(buffer, maxlen, "Soldier");
    else if (StrEqual(class, "pyro")) strcopy(buffer, maxlen, "Pyro");
    else if (StrEqual(class, "demoman")) strcopy(buffer, maxlen, "Demoman");
    else if (StrEqual(class, "heavyweapons")) strcopy(buffer, maxlen, "Heavy");
    else if (StrEqual(class, "engineer")) strcopy(buffer, maxlen, "Engineer");
    else if (StrEqual(class, "medic")) strcopy(buffer, maxlen, "Medic");
    else if (StrEqual(class, "spy")) strcopy(buffer, maxlen, "Spy");
    else if (StrEqual(class, "sniper")) strcopy(buffer, maxlen, "Sniper");
    else strcopy(buffer, maxlen, "Robot");
}

void BuyRobot_GetClassNameForSound(TFClassType class, char[] buffer, int maxlen)
{
    switch (class)
    {
        case TFClass_Soldier: strcopy(buffer, maxlen, "soldier");
        case TFClass_Pyro: strcopy(buffer, maxlen, "pyro");
        case TFClass_DemoMan: strcopy(buffer, maxlen, "demoman");
        case TFClass_Heavy: strcopy(buffer, maxlen, "heavy");
        case TFClass_Engineer: strcopy(buffer, maxlen, "engineer");
        case TFClass_Medic: strcopy(buffer, maxlen, "medic");
        case TFClass_Spy: strcopy(buffer, maxlen, "spy");
        case TFClass_Scout: strcopy(buffer, maxlen, "scout");
        case TFClass_Sniper: strcopy(buffer, maxlen, "sniper");
        default: strcopy(buffer, maxlen, "robot");
    }
}

void BuyRobot_GetRobotClassString(int client, char[] buffer, int maxlen)
{
    TFClassType class = TF2_GetPlayerClass(client);
    switch (class)
    {
        case TFClass_Soldier: strcopy(buffer, maxlen, "Soldier");
        case TFClass_Pyro: strcopy(buffer, maxlen, "Pyro");
        case TFClass_DemoMan: strcopy(buffer, maxlen, "Demoman");
        case TFClass_Heavy: strcopy(buffer, maxlen, "Heavy");
        case TFClass_Engineer: strcopy(buffer, maxlen, "Engineer");
        case TFClass_Medic: strcopy(buffer, maxlen, "Medic");
        case TFClass_Spy: strcopy(buffer, maxlen, "Spy");
        case TFClass_Scout: strcopy(buffer, maxlen, "Scout");
        case TFClass_Sniper: strcopy(buffer, maxlen, "Sniper");
        default: strcopy(buffer, maxlen, "Unknown");
    }
}

void BuyRobot_RemoveAll()
{
    int removed = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i])
        {
            KickClient(i, "Wave ended");
            BuyRobot_CleanupBot(i);
            removed++;
        }
    }
}

void RemoveUnitsAIBots()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        if (g_bBuyIsAIRobot[i])
        {
            KickClient(i, "Wave ended");
            BuyRobot_CleanupBot(i);
        }
    }
    
    if (g_hWaitingQueue != null && g_hWaitingQueue.Length > 0)
    {
        if (GameRules_GetRoundState() == RoundState_RoundRunning)
        {
            CreateTimer(0.5, Timer_ProcessWaitingQueueDelayed, _, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

void BuyRobot_PrecacheSounds()
{
    for (int i = 1; i <= 18; i++)
    {
        char snd[PLATFORM_MAX_PATH];
        Format(snd, sizeof(snd), "mvm/player/footsteps/robostep_%s%i.wav", (i < 10) ? "0" : "", i);
        
        char fileCheck[PLATFORM_MAX_PATH];
        Format(fileCheck, sizeof(fileCheck), "sound/%s", snd);
        
        if (FileExists(fileCheck, true))
        {
            PrecacheSound(snd, true);
        }
    }
    
    char classes[][] = {"soldier", "pyro", "demoman", "heavy", "engineer", "medic", "spy", "scout", "spy"};
    char voicelines[][] = {"_pain01", "_pain02", "_autoonfire01", "_specialcompleted01", "_moveup01", "_battlecry01"};
    
    for (int c = 0; c < sizeof(classes); c++)
    {
        for (int v = 0; v < sizeof(voicelines); v++)
        {
            char snd[PLATFORM_MAX_PATH];
            Format(snd, sizeof(snd), "vo/mvm/norm/%s_mvm%s.mp3", classes[c], voicelines[v]);
            
            char fileCheck[PLATFORM_MAX_PATH];
            Format(fileCheck, sizeof(fileCheck), "sound/%s", snd);
            
            if (FileExists(fileCheck, true))
            {
                PrecacheSound(snd, true);
            }
        }
    }
    
    PrecacheSound("mvm/mvm_tele_deliver.wav", true);
    
    PrecacheSound(GIANTSCOUT_SND_LOOP, true);
    PrecacheSound(GIANTSOLDIER_SND_LOOP, true);
    PrecacheSound(GIANTPYRO_SND_LOOP, true);
    PrecacheSound(GIANTDEMOMAN_SND_LOOP, true);
    PrecacheSound(GIANTHEAVY_SND_LOOP, true);
    PrecacheSound(SOUND_GUN_FIRE, true);
    PrecacheSound(SOUND_GUN_SPIN, true);
    PrecacheSound(SOUND_WIND_UP, true);
    PrecacheSound(SOUND_WIND_DOWN, true);
    PrecacheSound(SOUND_GRENADE, true);
    PrecacheSound(SOUND_ROCKET, true);
    PrecacheSound(SOUND_EXPLOSION, true);
    PrecacheSound(SOUND_FLAME_START, true);
    PrecacheSound(SOUND_FLAME_LOOP, true);
    PrecacheSound(SOUND_DEATH, true);
    
    char giantClasses[][] = {"soldier", "pyro", "demoman", "heavy", "scout"};
    char giantVoicelines[][] = {"_pain01", "_pain02", "_autoonfire01", "_specialcompleted01", "_moveup01", "_battlecry01", "_cheers01", "_positivevocalization01"};
    
    for (int c = 0; c < sizeof(giantClasses); c++)
    {
        for (int v = 0; v < sizeof(giantVoicelines); v++)
        {
            char snd[PLATFORM_MAX_PATH];
            Format(snd, sizeof(snd), "vo/mvm/mght/%s_mvm_m%s.mp3", giantClasses[c], giantVoicelines[v]);
            
            char fileCheck[PLATFORM_MAX_PATH];
            Format(fileCheck, sizeof(fileCheck), "sound/%s", snd);
            
            if (FileExists(fileCheck, true))
            {
                PrecacheSound(snd, true);
            }
        }
    }
}

void BuyRobot_PrecacheSpawnModel()
{
    char modelPath[PLATFORM_MAX_PATH] = "models/props_mvm/robot_spawnpoint.mdl";
    
    PrecacheModel(modelPath, true);
    
    AddFileToDownloadsTable("models/props_mvm/robot_spawnpoint.dx80.vtx");
    AddFileToDownloadsTable("models/props_mvm/robot_spawnpoint.dx90.vtx");
    AddFileToDownloadsTable("models/props_mvm/robot_spawnpoint.mdl");
    AddFileToDownloadsTable("models/props_mvm/robot_spawnpoint.vvd");
}

void BuyRobot_PrecacheWaveIcon()
{
    AddFileToDownloadsTable("materials/hud/leaderboard_class_blu2_lite.vmt");
    AddFileToDownloadsTable("materials/hud/leaderboard_class_blu2_lite.vtf");
    PrecacheGeneric("materials/hud/leaderboard_class_blu2_lite.vmt", true);
    PrecacheGeneric("materials/hud/leaderboard_class_blu2_lite.vtf", true);
}

void BuyRobot_ForceDownloadMaterials()
{
    static const char files[][] = {
        "materials/models/props_mvm/blank.vmt",
        "materials/models/props_mvm/blank.vtf",
        "materials/models/props_mvm/bluedottedcircle.vmt",
        "materials/models/props_mvm/bluedottedcircle.vtf",
        "materials/models/props_mvm/bluedottedcircle_dark.vmt",
        "materials/models/props_mvm/bluerobothead.vmt",
        "materials/models/props_mvm/bluerobothead.vtf",
        "materials/models/props_mvm/bluerobothead_dark.vmt",
        "materials/models/props_mvm/bluetransparent.vmt",
        "materials/models/props_mvm/bluetransparent.vtf",
        "materials/models/props_mvm/bluetransparent_dark.vmt",
        "materials/models/props_mvm/graydottedcircle.vmt",
        "materials/models/props_mvm/graydottedcircle.vtf",
        "materials/models/props_mvm/graydottedcircle_dark.vmt",
        "materials/models/props_mvm/grayrobothead.vmt",
        "materials/models/props_mvm/grayrobothead.vtf",
        "materials/models/props_mvm/grayrobothead_dark.vmt",
        "materials/models/props_mvm/graytransparent.vmt",
        "materials/models/props_mvm/graytransparent.vtf",
        "materials/models/props_mvm/graytransparent_dark.vmt",
        "materials/models/props_mvm/holo_projector_spawn.vmt",
        "materials/models/props_mvm/holo_projector_spawn.vtf",
        "materials/models/props_mvm/reddottedcircle.vmt",
        "materials/models/props_mvm/reddottedcircle.vtf",
        "materials/models/props_mvm/reddottedcircle_dark.vmt",
        "materials/models/props_mvm/redrobothead.vmt",
        "materials/models/props_mvm/redrobothead.vtf",
        "materials/models/props_mvm/redrobothead_dark.vmt",
        "materials/models/props_mvm/redtransparent.vmt",
        "materials/models/props_mvm/redtransparent.vtf",
        "materials/models/props_mvm/redtransparent_dark.vmt",
        "materials/models/props_mvm/spawnpoint_beam_blue.vmt",
        "materials/models/props_mvm/spawnpoint_beam_blue.vtf",
        "materials/models/props_mvm/spawnpoint_beam_gray.vmt",
        "materials/models/props_mvm/spawnpoint_beam_gray.vtf",
        "materials/models/props_mvm/spawnpoint_beam_red.vmt",
        "materials/models/props_mvm/spawnpoint_beam_red.vtf"
    };
    
    for (int i = 0; i < sizeof(files); i++)
    {
        AddFileToDownloadsTable(files[i]);
        PrecacheGeneric(files[i], true);
    }
}

void BuyRobot_SetMission(int client, int mission)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client]) return;
    
    Handle hSetMission = null;
    
    if (hSetMission == null)
    {
        Handle hGameConf = LoadGameConfigFile("tf2.defenderbots");
        if (hGameConf != null)
        {
            StartPrepSDKCall(SDKCall_Player);
            if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFBot::SetMission"))
            {
                PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
                PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
                hSetMission = EndPrepSDKCall();
            }
            delete hGameConf;
        }
    }
    
    if (hSetMission != null)
    {
        SDKCall(hSetMission, client, mission, false);
    }
}

void BuyRobot_Cleanup()
{
    if (g_hBuyAutoTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBuyAutoTimer);
        g_hBuyAutoTimer = INVALID_HANDLE;
    }
    
    if (g_hValidationTimer != INVALID_HANDLE)
    {
        KillTimer(g_hValidationTimer);
        g_hValidationTimer = INVALID_HANDLE;
    }
    
    if (g_hBuyQueue != null)
    {
        g_hBuyQueue.Clear();
        delete g_hBuyQueue;
        g_hBuyQueue = null;
    }
    
    g_hBuyQueue = new ArrayList(ByteCountToCells(256));
    
    BuyRobot_RemoveAll();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iBuyPlayerPoints[i] = 0;
        g_flBuyLastBotBuyTime[i] = 0.0;
        g_bBuyIsPurchasedRobot[i] = false;
        g_iBuyRobotLives[i] = 0;
        g_iBuyRobotOwner[i] = 0;
    }
}

public Action Timer_RespawnAtSpawnPoint(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    
    TF2_RespawnPlayer(client);
    
    int owner = g_iBuyRobotOwner[client];
    if (g_cvBuyNotifyLives.BoolValue && IsValidClientIndex(owner))
    {
        char robotName[64];
        GetClientName(client, robotName, sizeof(robotName));
        PrintToChat(owner, "\x0732CD32[Buy Robot]\x01 Your robot \x078B008B%s\x01 has respawned!", robotName);
    }
    
    if (g_cvBuyUseCustomSpawns.BoolValue && g_hSpawnPoints.Length > 0)
    {
        CreateTimer(0.1, Timer_TeleportToSpawnPoint, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Stop;
}

public Action Timer_TeleportToSpawnPoint(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !g_bBuyIsPurchasedRobot[client]) return Plugin_Stop;
    if (!g_cvBuyUseCustomSpawns.BoolValue || g_hSpawnPoints.Length == 0) return Plugin_Stop;
    
    TFTeam team = TF2_GetClientTeam(client);
    int targetType = (team == TFTeam_Red) ? SPAWN_TYPE_RED : SPAWN_TYPE_BLUE;
    
    ArrayList validSpawns = new ArrayList();
    float posWithType[4];
    
    for (int i = 0; i < g_hSpawnPoints.Length; i++)
    {
        g_hSpawnPoints.GetArray(i, posWithType);
        if (RoundFloat(posWithType[3]) == targetType)
        {
            validSpawns.Push(i);
        }
    }
    
    if (validSpawns.Length == 0)
    {
        delete validSpawns;
        return Plugin_Stop;
    }
    
    int randomIndex = validSpawns.Get(GetRandomInt(0, validSpawns.Length - 1));
    g_hSpawnPoints.GetArray(randomIndex, posWithType);
    
    float ang[3];
    if (g_hSpawnAngles.Length > randomIndex)
        g_hSpawnAngles.GetArray(randomIndex, ang);
    else
        ang = {0.0, 0.0, 0.0};
    
    float spawnPos[3];
    spawnPos[0] = posWithType[0];
    spawnPos[1] = posWithType[1];
    spawnPos[2] = posWithType[2];
    
    TeleportEntity(client, spawnPos, ang, NULL_VECTOR);
    EmitSoundToAll("mvm/mvm_tele_deliver.wav", client, SNDCHAN_STATIC, SNDLEVEL_NORMAL, _, 1.0);
    TF2_AddCondition(client, TFCond_Ubercharged, 3.0);
    
    delete validSpawns;
    return Plugin_Stop;
}

void UpdatePlayerHitbox(int client, float scale)
{
    float vecPlayerMin[3] = {-24.5, -25.5, 0.0};
    float vecPlayerMax[3] = {24.5, 24.5, 83.0};
    
    ScaleVector(vecPlayerMin, scale);
    ScaleVector(vecPlayerMax, scale);
    
    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecPlayerMin);
    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecPlayerMax);
}

public Action Command_RemoveUnitsBots(int client, int args)
{
    RemoveUnitsAIBots();
    ReplyToCommand(client, "[BuyRobot] Saxton AI and Gray AI bots removed.");
    return Plugin_Handled;
}

public Action BuyRobot_PurgeRobotsCmd(int client, int args)
{
    int removed = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i])
        {
            KickClient(i, "Purged by admin");
            BuyRobot_CleanupBot(i);
            removed++;
        }
    }
    
    if (removed > 0)
    {
        ShowActivity2(client, "[SM] ", "Purged %d purchased robot(s).", removed);
        
        if (g_hWaitingQueue != null && g_hWaitingQueue.Length > 0)
        {
            if (GameRules_GetRoundState() == RoundState_RoundRunning)
            {
                CreateTimer(0.5, Timer_ProcessWaitingQueueDelayed, _, TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
    else
    {
        ReplyToCommand(client, "[SM] No purchased robots found.");
    }
    
    return Plugin_Handled;
}

public Action BuyRobot_AddRobotsCmd(int client, int args)
{
    if (!CheckCommandAccess(client, "sm_addrobots", ADMFLAG_GENERIC))
    {
        ReplyToCommand(client, "\x0732CD32[Buy Robot]\x01 You do not have access to this command.");
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(MenuHandler_AddRobotsTeam);
    menu.SetTitle("Add Robots - Choose Team");
    menu.AddItem("red", "Mann Co. Team");
    menu.AddItem("blue", "Invaders Team");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

static void ShowAddRobotsTeamMenu(int client)
{
    Menu menu = new Menu(MenuHandler_AddRobotsTeam);
    menu.SetTitle("Add Robots - Choose Team");
    menu.AddItem("red", "Mann Co. Team");
    menu.AddItem("blue", "Invaders Team");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddRobotsTeam(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[32];
        menu.GetItem(param2, item, sizeof(item));
        
        g_tempAddTeam = StrEqual(item, "red") ? TFTeam_Red : TFTeam_Blue;
        ShowAddRobotsMainMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

static void ShowAddRobotsMainMenu(int client)
{
    Menu menu = new Menu(MenuHandler_AddRobotsMain);
    char teamName[64];
    if (g_tempAddTeam == TFTeam_Red)
        teamName = "Mann Co.";
    else
        teamName = "Invaders";
    
    menu.SetTitle("Add Robots - %s Team\nChoose Category", teamName);
    menu.AddItem("single", "Single Robots");
    menu.AddItem("squad", "Squads (5 robots)");
    menu.AddItem("giant", "Giant Robots");
    menu.AddItem("boss", "Boss Robots");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddRobotsMain(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[32];
        menu.GetItem(param2, item, sizeof(item));
        
        int category;
        if (StrEqual(item, "single"))
            category = BUY_CATEGORY_SINGLE;
        else if (StrEqual(item, "squad"))
            category = BUY_CATEGORY_SQUAD;
        else if (StrEqual(item, "giant"))
            category = BUY_CATEGORY_GIANT;
        else
            category = BUY_CATEGORY_BOSS;
        
        ShowAddRobotsClassMenu(client, category);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowAddRobotsClassMenu(int client, int category)
{
    int maxBots = g_cvBuyMaxBots.IntValue;
    int currentBots = BuyRobot_GetPurchasedCount();
    int remainingSlots = maxBots - currentBots;
    
    if (category == BUY_CATEGORY_BOSS)
    {
        int bossCount = GetCurrentBossCountForTeam(g_tempAddTeam);
        if (bossCount >= g_cvMaxBossPerTeam.IntValue)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This team already has a Boss robot! Only 1 Boss allowed per team.");
            ShowAddRobotsMainMenu(client);
            return;
        }
    }
    
    int botCount;
    char categoryPrefix[32];
    char categorySuffix[32];
    char menuTitle[128];
    
    if (category == BUY_CATEGORY_SINGLE)
    {
        botCount = 1;
        categoryPrefix = "";
        categorySuffix = "";
        Format(menuTitle, sizeof(menuTitle), "Single Robots\nRobots: %d/%d\n ", currentBots, maxBots);
    }
    else if (category == BUY_CATEGORY_SQUAD)
    {
        botCount = 5;
        categoryPrefix = "";
        categorySuffix = " Squad";
        Format(menuTitle, sizeof(menuTitle), "Squads (5 robots)\nRobots: %d/%d\n ", currentBots, maxBots);
    }
    else if (category == BUY_CATEGORY_GIANT)
    {
        botCount = 1;
        categoryPrefix = "Giant ";
        categorySuffix = "";
        Format(menuTitle, sizeof(menuTitle), "Giant Robots\nRobots: %d/%d\n ", currentBots, maxBots);
    }
    else if (category == BUY_CATEGORY_BOSS)
    {
        botCount = 1;
        categoryPrefix = "Boss ";
        categorySuffix = "";
        Format(menuTitle, sizeof(menuTitle), "Boss Robots\nRobots: %d/%d\n ", currentBots, maxBots);
    }
    else
    {
        return;
    }
    
    if (remainingSlots < botCount)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 You only have \x07FFD700%d\x01 slots left! (Robots: \x07FFD700%d/%d\x01)", remainingSlots, currentBots, maxBots);
        ShowAddRobotsTeamMenu(client);
        return;
    }
    
    Menu menu = new Menu(MenuHandler_AddRobotsClass);
    menu.SetTitle(menuTitle);
    
    char display[64], info[64];
    
    Format(display, sizeof(display), "%sScout%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "scout %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sSoldier%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "soldier %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sPyro%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "pyro %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sDemoman%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "demoman %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sHeavy%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "heavyweapons %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sEngineer%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "engineer %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sMedic%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "medic %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sSniper%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "sniper %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    Format(display, sizeof(display), "%sSpy%s", categoryPrefix, categorySuffix);
    Format(info, sizeof(info), "spy %d %d %d", category, botCount, view_as<int>(g_tempAddTeam));
    menu.AddItem(info, display);
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddRobotsClass(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[96];
        menu.GetItem(param2, item, sizeof(item));
        
        char class[32];
        int category, botCount, teamInt;
        char parts[4][32];
        ExplodeString(item, " ", parts, 4, 32);
        strcopy(class, sizeof(class), parts[0]);
        category = StringToInt(parts[1]);
        botCount = StringToInt(parts[2]);
        teamInt = StringToInt(parts[3]);
        TFTeam team = view_as<TFTeam>(teamInt);
        
        if (category == BUY_CATEGORY_BOSS)
        {
            int bossCount = GetCurrentBossCountForTeam(team);
            if (bossCount >= g_cvMaxBossPerTeam.IntValue)
            {
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This team already has a Boss robot! Only 1 Boss allowed per team.");
                ShowAddRobotsClassMenu(client, category);
                return 0;
            }
        }
        
        int lives = (category == BUY_CATEGORY_GIANT || category == BUY_CATEGORY_BOSS) ? 1 : g_cvBuyDefaultLives.IntValue;
        char prefix[32];
        
        if (category == BUY_CATEGORY_GIANT)
            strcopy(prefix, sizeof(prefix), "Giant");
        else if (category == BUY_CATEGORY_BOSS)
            strcopy(prefix, sizeof(prefix), "Boss");
        else
            prefix[0] = '\0';
        
        if (GetClientCount() + botCount - 1 >= MaxClients)
        {
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Server is full!");
            ShowAddRobotsClassMenu(client, category);
            return 0;
        }
        
        for (int i = 0; i < botCount; i++)
        {
            BuyRobot_CreateBot(class, 0, lives, prefix, false, team);
        }
        
        char className[32];
        BuyRobot_GetClassName(class, className, sizeof(className));
        
        if (category == BUY_CATEGORY_GIANT)
        {
            if (team == TFTeam_Red)
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x078B008BGiant %s\x01 robot(s) for \x07FF4500Mann Co.\x01 team", botCount, className);
            else
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x078B008BGiant %s\x01 robot(s) for \x0742A5F5Invaders\x01 team", botCount, className);
        }
        else if (category == BUY_CATEGORY_BOSS)
        {
            if (team == TFTeam_Red)
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x07FF1493Boss %s\x01 robot(s) for \x07FF4500Mann Co.\x01 team", botCount, className);
            else
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x07FF1493Boss %s\x01 robot(s) for \x0742A5F5Invaders\x01 team", botCount, className);
        }
        else
        {
            if (team == TFTeam_Red)
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x07FF4500%s\x01 robot(s) for \x07FF4500Mann Co.\x01 team", botCount, className);
            else
                PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Added \x07FFD700%d \x0742A5F5%s\x01 robot(s) for \x0742A5F5Invaders\x01 team", botCount, className);
        }
        
        Menu continueMenu = new Menu(MenuHandler_AddRobotsContinue);
        continueMenu.SetTitle("Add more robots?");
        continueMenu.AddItem("yes", "Yes");
        continueMenu.AddItem("no", "No");
        continueMenu.ExitButton = false;
        continueMenu.Display(client, MENU_TIME_FOREVER);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (IsValidClientIndex(param1))
            ShowAddRobotsMainMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public int MenuHandler_AddRobotsContinue(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[8];
        menu.GetItem(param2, item, sizeof(item));
        
        if (StrEqual(item, "yes"))
        {
            Menu teamMenu = new Menu(MenuHandler_AddRobotsTeam);
            teamMenu.SetTitle("Add Robots - Choose Team");
            teamMenu.AddItem("red", "Mann Co. Team");
            teamMenu.AddItem("blue", "Invaders Team");
            teamMenu.ExitButton = true;
            teamMenu.Display(client, MENU_TIME_FOREVER);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

void LoadSpawnPoints()
{
    if (g_hSpawnPoints != null)
        g_hSpawnPoints.Clear();
    if (g_hSpawnAngles != null)
        g_hSpawnAngles.Clear();
    
    if (!FileExists(g_sSpawnConfigFile))
    {
        LogMessage("[BuyRobot] No spawn file found: %s", g_sSpawnConfigFile);
        return;
    }
    
    File hFile = OpenFile(g_sSpawnConfigFile, "r");
    if (hFile == null)
    {
        LogError("[BuyRobot] Failed to open spawn file: %s", g_sSpawnConfigFile);
        return;
    }
    
    char line[256];
    float posWithType[4];
    float ang[3];
    int validSpawns = 0;
    int invalidSpawns = 0;
    
    while (!IsEndOfFile(hFile) && ReadFileLine(hFile, line, sizeof(line)))
    {
        TrimString(line);
        if (strlen(line) == 0 || line[0] == '#') continue;
        
        char parts[8][32];
        int numParts = ExplodeString(line, " ", parts, 8, 32);
        
        if (numParts >= 4)
        {
            float x = StringToFloat(parts[0]);
            float y = StringToFloat(parts[1]);
            float z = StringToFloat(parts[2]);
            int spawnType = StringToInt(parts[3]);
            
            if (x == 0.0 && y == 0.0 && z == 0.0)
            {
                invalidSpawns++;
                continue;
            }
            
            posWithType[0] = x;
            posWithType[1] = y;
            posWithType[2] = z;
            posWithType[3] = float(spawnType);
            
            if (numParts >= 7)
            {
                ang[0] = StringToFloat(parts[4]);
                ang[1] = StringToFloat(parts[5]);
                ang[2] = StringToFloat(parts[6]);
            }
            else
            {
                ang[0] = 0.0;
                ang[1] = 0.0;
                ang[2] = 0.0;
            }
            
            g_hSpawnPoints.PushArray(posWithType);
            g_hSpawnAngles.PushArray(ang);
            validSpawns++;
        }
    }
    
    delete hFile;
    
    LogMessage("[BuyRobot] Loaded %d valid spawn points, ignored %d invalid spawns from %s", 
        validSpawns, invalidSpawns, g_sSpawnConfigFile);
    
    if (invalidSpawns > 0)
    {
        LogMessage("[BuyRobot] Re-saving spawn file without invalid entries");
        SaveSpawnPoints();
    }
}

void SaveSpawnPoints()
{
    UpdateSystemTime();
    
    File hFile = OpenFile(g_sSpawnConfigFile, "w");
    if (hFile == null) return;
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    hFile.WriteLine("// BuyRobot Spawn Points for map: %s", mapName);
    hFile.WriteLine("// Generated on: %s", g_sSystemTime);
    hFile.WriteLine("// Format: x y z type pitch yaw roll");
    hFile.WriteLine("// type: 0 = Red (Mann Co.), 1 = Blue (Invaders)");
    hFile.WriteLine("");
    
    float posWithType[4];
    float ang[3];
    for (int i = 0; i < g_hSpawnPoints.Length; i++)
    {
        g_hSpawnPoints.GetArray(i, posWithType);
        g_hSpawnAngles.GetArray(i, ang);
        
        hFile.WriteLine("%.2f %.2f %.2f %d %.2f %.2f %.2f", 
            posWithType[0], posWithType[1], posWithType[2], 
            RoundFloat(posWithType[3]), ang[0], ang[1], ang[2]);
    }
    
    delete hFile;
}

void CreateSpawnPointEntity(float pos[3], float angles[3], int id, int spawnType = SPAWN_TYPE_RED)
{
    int ent = CreateEntityByName("prop_dynamic");
    if (ent != -1)
    {
        DispatchKeyValue(ent, "model", "models/props_mvm/robot_spawnpoint.mdl");
        DispatchKeyValue(ent, "solid", "0");
        DispatchKeyValue(ent, "DefaultAnim", "idle");
        DispatchKeyValue(ent, "rendermode", "5");
        DispatchKeyValue(ent, "renderamt", "255");
        
        TeleportEntity(ent, pos, angles, NULL_VECTOR);
        DispatchSpawn(ent);
        ActivateEntity(ent);
        
        SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);
        
        if (spawnType == SPAWN_TYPE_BLUE)
        {
            SetEntProp(ent, Prop_Send, "m_nSkin", 1);
            SetVariantString("blue");
            AcceptEntityInput(ent, "SetSkin");
        }
        else
        {
            SetEntProp(ent, Prop_Send, "m_nSkin", 0);
            SetVariantString("red");
            AcceptEntityInput(ent, "SetSkin");
        }
        
        char targetname[32];
        Format(targetname, sizeof(targetname), "robot_spawnpoint_%d_%s", id, (spawnType == SPAWN_TYPE_RED) ? "red" : "blue");
        DispatchKeyValue(ent, "targetname", targetname);
        
        SetVariantString("idle");
        AcceptEntityInput(ent, "SetAnimation");
        
        int nobuild = CreateEntityByName("func_nobuild");
        if (nobuild != -1)
        {
            DispatchKeyValue(nobuild, "StartDisabled", "0");
            DispatchSpawn(nobuild);
            
            float min[3] = {-80.0, -80.0, 0.0};
            float max[3] = {80.0, 80.0, 10.0};
            
            TeleportEntity(nobuild, pos, angles, NULL_VECTOR);
            SetEntPropVector(nobuild, Prop_Send, "m_vecMins", min);
            SetEntPropVector(nobuild, Prop_Send, "m_vecMaxs", max);
            SetEntProp(nobuild, Prop_Send, "m_nSolidType", 2);
            
            SetVariantString(targetname);
            AcceptEntityInput(nobuild, "SetParent");
        }
    }
}

public Action Timer_RemoveParticle(Handle timer, int entRef)
{
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
    {
        AcceptEntityInput(ent, "Kill");
    }
    return Plugin_Stop;
}

void RemoveAllSpawnpointModels()
{
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
    {
        char targetname[64];
        GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrContains(targetname, "robot_spawnpoint_") != -1)
        {
            AcceptEntityInput(ent, "Kill");
        }
    }
    
    ent = -1;
    while ((ent = FindEntityByClassname(ent, "info_particle_system")) != -1)
    {
        char targetname[64];
        GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrEqual(targetname, "spawn_particle"))
        {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

void RefreshAllSpawnpointModels()
{
    RemoveAllSpawnpointModels();
    CreateTimer(0.2, Timer_CreateSpawnModelsDelayed, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CreateSpawnModelsDelayed(Handle timer)
{
    float posWithType[4];
    float pos[3];
    float ang[3];
    for (int i = 0; i < g_hSpawnPoints.Length; i++)
    {
        g_hSpawnPoints.GetArray(i, posWithType);
        g_hSpawnAngles.GetArray(i, ang);
        pos[0] = posWithType[0];
        pos[1] = posWithType[1];
        pos[2] = posWithType[2];
        CreateSpawnPointEntity(pos, ang, i, RoundFloat(posWithType[3]));
    }
    return Plugin_Stop;
}

public Action Timer_ForceRefreshModels(Handle timer)
{
    if (g_hSpawnPoints.Length > 0)
    {
        RemoveAllSpawnpointModels();
        CreateTimer(0.1, Timer_CreateSpawnModels, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Stop;
}

public Action Timer_CreateSpawnModels(Handle timer)
{
    RefreshAllSpawnpointModels();
    return Plugin_Stop;
}

public Action Command_AddSpawn(int client, int args)
{
    if (!IsValidClientIndex(client)) return Plugin_Handled;
    
    Menu menu = new Menu(MenuHandler_SpawnType);
    menu.SetTitle("Choose Spawn Point Color");
    menu.AddItem("red", "Red (Mann Co.)");
    menu.AddItem("blue", "Blue (Invaders)");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public int MenuHandler_SpawnType(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char item[16];
        menu.GetItem(param2, item, sizeof(item));
        
        int spawnType = StrEqual(item, "red") ? SPAWN_TYPE_RED : SPAWN_TYPE_BLUE;
        
        float pos[3];
        GetClientAbsOrigin(client, pos);
        
        pos[2] += 100.0;
        TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
        pos[2] -= 100.0;
        
        float ang[3];
        GetClientEyeAngles(client, ang);
        ang[0] = 0.0;
        ang[2] = 0.0;
        
        float posWithType[4];
        posWithType[0] = pos[0];
        posWithType[1] = pos[1];
        posWithType[2] = pos[2];
        posWithType[3] = float(spawnType);
        
        g_hSpawnPoints.PushArray(posWithType);
        g_hSpawnAngles.PushArray(ang);
        
        CreateSpawnPointEntity(pos, ang, g_hSpawnPoints.Length - 1, spawnType);
        SaveSpawnPoints();
        
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Spawn point #%d added (%s)", 
            g_hSpawnPoints.Length - 1, (spawnType == SPAWN_TYPE_RED) ? "Red" : "Blue");
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_ListSpawns(int client, int args)
{
    if (!IsValidClientIndex(client)) return Plugin_Handled;
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    if (g_hSpawnPoints.Length == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No spawn points defined for map %s.", mapName);
        return Plugin_Handled;
    }
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Spawn points for %s (%d):", mapName, g_hSpawnPoints.Length);
    
    float posWithType[4];
    float pos[3];
    for (int i = 0; i < g_hSpawnPoints.Length; i++)
    {
        g_hSpawnPoints.GetArray(i, posWithType);
        pos[0] = posWithType[0];
        pos[1] = posWithType[1];
        pos[2] = posWithType[2];
        int spawnType = RoundFloat(posWithType[3]);
        PrintToChat(client, "#%d: %.1f %.1f %.1f [%s]", i, pos[0], pos[1], pos[2], 
            (spawnType == SPAWN_TYPE_RED) ? "Red" : "Blue");
    }
    
    return Plugin_Handled;
}

public Action Command_RemoveSpawn(int client, int args)
{
    if (!IsValidClientIndex(client)) return Plugin_Handled;
    
    if (args < 1)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Usage: sm_removespawn <id>");
        return Plugin_Handled;
    }
    
    char idStr[16];
    GetCmdArg(1, idStr, sizeof(idStr));
    int id = StringToInt(idStr);
    
    if (id < 0 || id >= g_hSpawnPoints.Length)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Invalid spawn ID.");
        return Plugin_Handled;
    }
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    int ent = -1;
    char targetname[32];
    Format(targetname, sizeof(targetname), "robot_spawnpoint_%d", id);
    
    while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
    {
        char name[64];
        GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
        if (StrEqual(name, targetname))
        {
            AcceptEntityInput(ent, "Kill");
            break;
        }
    }
    
    g_hSpawnPoints.Erase(id);
    g_hSpawnAngles.Erase(id);
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Spawn point #%d removed from map %s.", id, mapName);
    
    SaveSpawnPoints();
    RefreshAllSpawnpointModels();
    
    return Plugin_Handled;
}

public Action Command_ClearSpawns(int client, int args)
{
    g_hSpawnPoints.Clear();
    g_hSpawnAngles.Clear();
    RemoveAllSpawnpointModels();
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 All spawn points cleared.");
    SaveSpawnPoints();
    return Plugin_Handled;
}

public Action Command_SaveSpawns(int client, int args)
{
    SaveSpawnPoints();
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Spawn points saved to file.");
    return Plugin_Handled;
}

public Action Command_LoadSpawns(int client, int args)
{
    LoadSpawnPoints();
    CreateTimer(0.1, Timer_ForceRefreshModels, _, TIMER_FLAG_NO_MAPCHANGE);
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Loaded %d spawn points.", g_hSpawnPoints.Length);
    return Plugin_Handled;
}

void UpdateSystemTime()
{
    int timestamp = GetTime();
    FormatTime(g_sSystemTime, sizeof(g_sSystemTime), "%Y-%m-%d %H:%M:%S", timestamp);
}

void RemovePowerUpCanteen(int client)
{
    if (!IsValidClientIndex(client) || !g_bBuyIsPurchasedRobot[client])
        return;
    
    int actionSlot = GetPlayerWeaponSlot(client, TFWeaponSlot_Item1);
    if (actionSlot != -1)
    {
        char classname[64];
        GetEntityClassname(actionSlot, classname, sizeof(classname));
        
        if (StrEqual(classname, "tf_powerup_bottle", false))
        {
            TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
        }
    }
    
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "tf_powerup_bottle")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
        {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

static Action Timer_CheckStuckBot(Handle timer)
{
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return Plugin_Continue;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsFakeClient(i) || !g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (TF2_GetClientTeam(i) != TFTeam_Blue)
            continue;
        
        if (!IsPlayerAlive(i))
            continue;
        
        float origin[3];
        GetClientAbsOrigin(i, origin);
        
        if (TF2Util_IsPointInRespawnRoom(origin, i))
        {
            float currentPos[3];
            GetClientAbsOrigin(i, currentPos);
            
            if (g_flLastPosition[i][0] == currentPos[0] && 
                g_flLastPosition[i][1] == currentPos[1] && 
                g_flLastPosition[i][2] == currentPos[2])
            {
                if (g_flStuckTime[i] == 0.0)
                {
                    g_flStuckTime[i] = GetGameTime();
                }
                else if (GetGameTime() - g_flStuckTime[i] >= 10.0)
                {
                    ForcePlayerSuicide(i);
                    CreateTimer(0.5, Timer_KickStuckBot, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
                    g_flStuckTime[i] = 0.0;
                }
            }
            else
            {
                g_flStuckTime[i] = 0.0;
                g_flLastPosition[i] = currentPos;
            }
        }
        else
        {
            g_flStuckTime[i] = 0.0;
            g_flLastPosition[i] = NULL_VECTOR;
        }
    }
    
    return Plugin_Continue;
}

static Action Timer_KickStuckBot(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && g_bBuyIsPurchasedRobot[client])
    {
        KickClient(client, "Stuck in spawn");
        BuyRobot_CleanupBot(client);
    }
    return Plugin_Stop;
}

void BuyRobot_SpawnCheck_Start()
{
    if (g_hSpawnCheckTimer != INVALID_HANDLE)
    {
        KillTimer(g_hSpawnCheckTimer);
        g_hSpawnCheckTimer = INVALID_HANDLE;
    }
    
    g_hSpawnCheckTimer = CreateTimer(3.0, Timer_CheckStuckBot, _, TIMER_REPEAT);
}

void BuyRobot_SpawnCheck_Stop()
{
    if (g_hSpawnCheckTimer != INVALID_HANDLE)
    {
        KillTimer(g_hSpawnCheckTimer);
        g_hSpawnCheckTimer = INVALID_HANDLE;
    }
}

public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && !IsFakeClient(client))
    {
        CreateTimer(2.0, Timer_LoadPointsDelayed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_LoadPointsDelayed(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && !IsFakeClient(client))
    {
        if (g_hPointsKV == null)
        {
            BuyRobot_LoadAllPoints();
        }
        
        BuyRobot_LoadPlayerPoints(client);
    }
    return Plugin_Stop;
}

public Action Timer_DelayedPointsLoad(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            BuyRobot_LoadPlayerPoints(i);
        }
    }
    return Plugin_Stop;
}

public void OnClientPostAdminCheck(int client)
{
    if (!IsFakeClient(client) && IsClientInGame(client))
    {
        CreateTimer(1.0, Timer_LoadPointsDelayed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && !IsFakeClient(client))
    {
        BuyRobot_SavePlayerPoints(client);
        BuyRobot_SaveAllPoints();
	ClearWaitingQueueForPlayer(client);
    }
}

void BuyRobot_ShowTop10(int client)
{
    if (g_hPointsKV == null)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No points data available.");
        return;
    }
    
    ArrayList names = new ArrayList(64);
    ArrayList pointsList = new ArrayList();
    
    g_hPointsKV.Rewind();
    if (g_hPointsKV.GotoFirstSubKey())
    {
        do
        {
            char steamId[32];
            g_hPointsKV.GetSectionName(steamId, sizeof(steamId));
            
            if (IsPlayerBlacklisted(steamId))
                continue;
            
            int playerPoints = g_hPointsKV.GetNum("points", 0);
            
            if (playerPoints > 0)
            {
                char playerName[64];
                g_hPointsKV.GetString("name", playerName, sizeof(playerName));
                
                if (strlen(playerName) == 0)
                    Format(playerName, sizeof(playerName), "%s", steamId);
                
                names.PushString(playerName);
                pointsList.Push(playerPoints);
            }
        } while (g_hPointsKV.GotoNextKey());
    }
    g_hPointsKV.Rewind();
    
    if (names.Length == 0)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No points data available.");
        delete names;
        delete pointsList;
        return;
    }
    
    for (int i = 0; i < pointsList.Length - 1; i++)
    {
        for (int j = i + 1; j < pointsList.Length; j++)
        {
            if (pointsList.Get(j) > pointsList.Get(i))
            {
                int tempPoints = pointsList.Get(i);
                pointsList.Set(i, pointsList.Get(j));
                pointsList.Set(j, tempPoints);
                
                char tempName[64];
                names.GetString(i, tempName, sizeof(tempName));
                char tempName2[64];
                names.GetString(j, tempName2, sizeof(tempName2));
                names.SetString(i, tempName2);
                names.SetString(j, tempName);
            }
        }
    }
    
    PrintToChat(client, "\x0732CD32===== Top 10 Points Ranking =====\x01");
    
    int maxDisplay = pointsList.Length < 10 ? pointsList.Length : 10;
    
    for (int i = 0; i < maxDisplay; i++)
    {
        char playerName[64];
        names.GetString(i, playerName, sizeof(playerName));
        int playerPoints = pointsList.Get(i);
        
        if (i == 0)
            PrintToChat(client, "\x07FFD700#%d - %s - %d points", i + 1, playerName, playerPoints);
        else if (i == 1)
            PrintToChat(client, "\x07C0C0C0#%d - %s - %d points", i + 1, playerName, playerPoints);
        else if (i == 2)
            PrintToChat(client, "\x07CD7F32#%d - %s - %d points", i + 1, playerName, playerPoints);
        else
            PrintToChat(client, "#%d - %s - %d points", i + 1, playerName, playerPoints);
    }
    
    PrintToChat(client, "\x0732CD32=========================\x01");
    
    delete names;
    delete pointsList;
}

int BuyRobot_GetPlayerRank(int client)
{
    if (!IsValidClientIndex(client) || IsFakeClient(client))
        return 0;
    
    if (g_hPointsKV == null)
        return 0;
    
    char clientSteamId[32];
    GetClientAuthId(client, AuthId_Steam2, clientSteamId, sizeof(clientSteamId));
    
    if (strlen(clientSteamId) == 0)
        return 0;
    
    if (IsPlayerBlacklisted(clientSteamId))
        return 0;
    
    int clientPoints = g_iBuyPlayerPoints[client];
    if (clientPoints <= 0)
        return 0;
    
    int rank = 1;
    
    g_hPointsKV.Rewind();
    if (g_hPointsKV.GotoFirstSubKey())
    {
        do
        {
            char steamId[32];
            g_hPointsKV.GetSectionName(steamId, sizeof(steamId));
            
            if (IsPlayerBlacklisted(steamId))
                continue;
            
            int playerPoints = g_hPointsKV.GetNum("points", 0);
            
            if (playerPoints > clientPoints)
                rank++;
        } while (g_hPointsKV.GotoNextKey());
    }
    g_hPointsKV.Rewind();
    
    return rank;
}

int BuyRobot_GetTotalPlayersWithPoints()
{
    if (g_hPointsKV == null)
        return 0;
    
    int count = 0;
    
    g_hPointsKV.Rewind();
    if (g_hPointsKV.GotoFirstSubKey())
    {
        do
        {
            int playerPoints = g_hPointsKV.GetNum("points", 0);
            if (playerPoints > 0)
                count++;
        } while (g_hPointsKV.GotoNextKey());
    }
    g_hPointsKV.Rewind();
    
    return count;
}

int GetCurrentBossCountForTeam(TFTeam team)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && IsPlayerAlive(i))
        {
            if (TF2_GetClientTeam(i) == team)
            {
                char clientName[64];
                GetClientName(i, clientName, sizeof(clientName));
                if (StrContains(clientName, "Boss") != -1)
                    count++;
            }
        }
    }
    return count;
}

public Action Timer_InfiniteSentryAmmo(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    if (!g_bBuyIsPurchasedRobot[client])
        return Plugin_Stop;
    
    if (TF2_GetPlayerClass(client) != TFClass_Engineer)
        return Plugin_Stop;
    
    int sentry = GetObjectOfType(client, TFObject_Sentry);
    if (sentry != -1)
    {
        SetEntProp(sentry, Prop_Send, "m_iAmmoShells", 200);
        SetEntProp(sentry, Prop_Send, "m_iAmmoRockets", 20);
    }
    
    return Plugin_Continue;
}

void BuyRobot_PopulateHatsList()
{
    if (g_hBuyRobotHats == null)
        g_hBuyRobotHats = new ArrayList();
    else
        g_hBuyRobotHats.Clear();

    g_hBuyRobotHats.Push(116); g_hBuyRobotHats.Push(125); g_hBuyRobotHats.Push(126); g_hBuyRobotHats.Push(134);
    g_hBuyRobotHats.Push(135); g_hBuyRobotHats.Push(136); g_hBuyRobotHats.Push(137); g_hBuyRobotHats.Push(138);
    g_hBuyRobotHats.Push(139); g_hBuyRobotHats.Push(162); g_hBuyRobotHats.Push(189); g_hBuyRobotHats.Push(260);
    g_hBuyRobotHats.Push(261); g_hBuyRobotHats.Push(263); g_hBuyRobotHats.Push(279); g_hBuyRobotHats.Push(287);
    g_hBuyRobotHats.Push(289); g_hBuyRobotHats.Push(291); g_hBuyRobotHats.Push(302); g_hBuyRobotHats.Push(332);
    g_hBuyRobotHats.Push(333); g_hBuyRobotHats.Push(334); g_hBuyRobotHats.Push(341); g_hBuyRobotHats.Push(345);
    g_hBuyRobotHats.Push(408); g_hBuyRobotHats.Push(409); g_hBuyRobotHats.Push(410); g_hBuyRobotHats.Push(420);
    g_hBuyRobotHats.Push(470); g_hBuyRobotHats.Push(471); g_hBuyRobotHats.Push(473); g_hBuyRobotHats.Push(492);
    g_hBuyRobotHats.Push(523); g_hBuyRobotHats.Push(537); g_hBuyRobotHats.Push(538); g_hBuyRobotHats.Push(576);
    g_hBuyRobotHats.Push(578); g_hBuyRobotHats.Push(579); g_hBuyRobotHats.Push(580); g_hBuyRobotHats.Push(584);
    g_hBuyRobotHats.Push(598); g_hBuyRobotHats.Push(634); g_hBuyRobotHats.Push(666); g_hBuyRobotHats.Push(667);
    g_hBuyRobotHats.Push(668); g_hBuyRobotHats.Push(671); g_hBuyRobotHats.Push(675); g_hBuyRobotHats.Push(702);
    g_hBuyRobotHats.Push(711); g_hBuyRobotHats.Push(712); g_hBuyRobotHats.Push(713); g_hBuyRobotHats.Push(756);
    g_hBuyRobotHats.Push(785); g_hBuyRobotHats.Push(817); g_hBuyRobotHats.Push(920); g_hBuyRobotHats.Push(921);
    g_hBuyRobotHats.Push(940); g_hBuyRobotHats.Push(941); g_hBuyRobotHats.Push(942); g_hBuyRobotHats.Push(944);
    g_hBuyRobotHats.Push(984); g_hBuyRobotHats.Push(993); g_hBuyRobotHats.Push(994); g_hBuyRobotHats.Push(1014);
    g_hBuyRobotHats.Push(1033); g_hBuyRobotHats.Push(1034); g_hBuyRobotHats.Push(1035); g_hBuyRobotHats.Push(1067);
    g_hBuyRobotHats.Push(1122); g_hBuyRobotHats.Push(1899); g_hBuyRobotHats.Push(30001); g_hBuyRobotHats.Push(30003);
    g_hBuyRobotHats.Push(30006); g_hBuyRobotHats.Push(30008); g_hBuyRobotHats.Push(30058); g_hBuyRobotHats.Push(30065);
    g_hBuyRobotHats.Push(30066); g_hBuyRobotHats.Push(30140); g_hBuyRobotHats.Push(30177); g_hBuyRobotHats.Push(30307);
    g_hBuyRobotHats.Push(30313); g_hBuyRobotHats.Push(30329); g_hBuyRobotHats.Push(30362); g_hBuyRobotHats.Push(30422);
    g_hBuyRobotHats.Push(30425); g_hBuyRobotHats.Push(30469); g_hBuyRobotHats.Push(30473); g_hBuyRobotHats.Push(30542);
    g_hBuyRobotHats.Push(30546); g_hBuyRobotHats.Push(30549); g_hBuyRobotHats.Push(30567); g_hBuyRobotHats.Push(30571);
    g_hBuyRobotHats.Push(30607); g_hBuyRobotHats.Push(30623); g_hBuyRobotHats.Push(30640); g_hBuyRobotHats.Push(30643);
    g_hBuyRobotHats.Push(30646); g_hBuyRobotHats.Push(30647);
    g_hBuyRobotHats.Push(52); g_hBuyRobotHats.Push(106); g_hBuyRobotHats.Push(107); g_hBuyRobotHats.Push(111);
    g_hBuyRobotHats.Push(150); g_hBuyRobotHats.Push(174); g_hBuyRobotHats.Push(219); g_hBuyRobotHats.Push(249);
    g_hBuyRobotHats.Push(324); g_hBuyRobotHats.Push(346); g_hBuyRobotHats.Push(453); g_hBuyRobotHats.Push(539);
    g_hBuyRobotHats.Push(614); g_hBuyRobotHats.Push(617); g_hBuyRobotHats.Push(633); g_hBuyRobotHats.Push(652);
    g_hBuyRobotHats.Push(760); g_hBuyRobotHats.Push(765); g_hBuyRobotHats.Push(780); g_hBuyRobotHats.Push(788);
    g_hBuyRobotHats.Push(846);
    g_hBuyRobotHats.Push(54); g_hBuyRobotHats.Push(98); g_hBuyRobotHats.Push(99); g_hBuyRobotHats.Push(152);
    g_hBuyRobotHats.Push(183); g_hBuyRobotHats.Push(227); g_hBuyRobotHats.Push(240); g_hBuyRobotHats.Push(250);
    g_hBuyRobotHats.Push(251); g_hBuyRobotHats.Push(252); g_hBuyRobotHats.Push(339); g_hBuyRobotHats.Push(340);
    g_hBuyRobotHats.Push(360); g_hBuyRobotHats.Push(378); g_hBuyRobotHats.Push(391); g_hBuyRobotHats.Push(395);
    g_hBuyRobotHats.Push(417); g_hBuyRobotHats.Push(434); g_hBuyRobotHats.Push(439); g_hBuyRobotHats.Push(445);
    g_hBuyRobotHats.Push(516); g_hBuyRobotHats.Push(575); g_hBuyRobotHats.Push(611); g_hBuyRobotHats.Push(631);
    g_hBuyRobotHats.Push(641); g_hBuyRobotHats.Push(701); g_hBuyRobotHats.Push(719); g_hBuyRobotHats.Push(721);
    g_hBuyRobotHats.Push(732); g_hBuyRobotHats.Push(764); g_hBuyRobotHats.Push(766); g_hBuyRobotHats.Push(829);
    g_hBuyRobotHats.Push(844); g_hBuyRobotHats.Push(945); g_hBuyRobotHats.Push(980); g_hBuyRobotHats.Push(1021);
    g_hBuyRobotHats.Push(51); g_hBuyRobotHats.Push(102); g_hBuyRobotHats.Push(105); g_hBuyRobotHats.Push(151);
    g_hBuyRobotHats.Push(175); g_hBuyRobotHats.Push(182); g_hBuyRobotHats.Push(213); g_hBuyRobotHats.Push(247);
    g_hBuyRobotHats.Push(248); g_hBuyRobotHats.Push(253); g_hBuyRobotHats.Push(316); g_hBuyRobotHats.Push(318);
    g_hBuyRobotHats.Push(321); g_hBuyRobotHats.Push(335); g_hBuyRobotHats.Push(377); g_hBuyRobotHats.Push(394);
    g_hBuyRobotHats.Push(435); g_hBuyRobotHats.Push(481); g_hBuyRobotHats.Push(570); g_hBuyRobotHats.Push(571);
    g_hBuyRobotHats.Push(596); g_hBuyRobotHats.Push(597); g_hBuyRobotHats.Push(612); g_hBuyRobotHats.Push(615);
    g_hBuyRobotHats.Push(627); g_hBuyRobotHats.Push(644); g_hBuyRobotHats.Push(745); g_hBuyRobotHats.Push(753);
    g_hBuyRobotHats.Push(761); g_hBuyRobotHats.Push(783); g_hBuyRobotHats.Push(820); g_hBuyRobotHats.Push(842);
    g_hBuyRobotHats.Push(854); g_hBuyRobotHats.Push(937); g_hBuyRobotHats.Push(949); g_hBuyRobotHats.Push(950);
    g_hBuyRobotHats.Push(976); g_hBuyRobotHats.Push(1020); g_hBuyRobotHats.Push(1031); g_hBuyRobotHats.Push(1038);
    g_hBuyRobotHats.Push(47); g_hBuyRobotHats.Push(100); g_hBuyRobotHats.Push(120); g_hBuyRobotHats.Push(146);
    g_hBuyRobotHats.Push(179); g_hBuyRobotHats.Push(216); g_hBuyRobotHats.Push(255); g_hBuyRobotHats.Push(259);
    g_hBuyRobotHats.Push(306); g_hBuyRobotHats.Push(342); g_hBuyRobotHats.Push(359); g_hBuyRobotHats.Push(388);
    g_hBuyRobotHats.Push(390); g_hBuyRobotHats.Push(403); g_hBuyRobotHats.Push(465); g_hBuyRobotHats.Push(480);
    g_hBuyRobotHats.Push(514); g_hBuyRobotHats.Push(605); g_hBuyRobotHats.Push(607); g_hBuyRobotHats.Push(703);
    g_hBuyRobotHats.Push(771); g_hBuyRobotHats.Push(776); g_hBuyRobotHats.Push(786); g_hBuyRobotHats.Push(830);
    g_hBuyRobotHats.Push(845); g_hBuyRobotHats.Push(874); g_hBuyRobotHats.Push(876); g_hBuyRobotHats.Push(935);
    g_hBuyRobotHats.Push(986); g_hBuyRobotHats.Push(1012); g_hBuyRobotHats.Push(1019); g_hBuyRobotHats.Push(1029);
    g_hBuyRobotHats.Push(49); g_hBuyRobotHats.Push(96); g_hBuyRobotHats.Push(97); g_hBuyRobotHats.Push(145);
    g_hBuyRobotHats.Push(185); g_hBuyRobotHats.Push(246); g_hBuyRobotHats.Push(254); g_hBuyRobotHats.Push(290);
    g_hBuyRobotHats.Push(292); g_hBuyRobotHats.Push(309); g_hBuyRobotHats.Push(313); g_hBuyRobotHats.Push(330);
    g_hBuyRobotHats.Push(358); g_hBuyRobotHats.Push(378); g_hBuyRobotHats.Push(380); g_hBuyRobotHats.Push(427);
    g_hBuyRobotHats.Push(478); g_hBuyRobotHats.Push(485); g_hBuyRobotHats.Push(515); g_hBuyRobotHats.Push(517);
    g_hBuyRobotHats.Push(524); g_hBuyRobotHats.Push(535); g_hBuyRobotHats.Push(585); g_hBuyRobotHats.Push(601);
    g_hBuyRobotHats.Push(603); g_hBuyRobotHats.Push(613); g_hBuyRobotHats.Push(635); g_hBuyRobotHats.Push(757);
    g_hBuyRobotHats.Push(777); g_hBuyRobotHats.Push(840); g_hBuyRobotHats.Push(866); g_hBuyRobotHats.Push(876);
    g_hBuyRobotHats.Push(946); g_hBuyRobotHats.Push(952); g_hBuyRobotHats.Push(985); g_hBuyRobotHats.Push(989);
    g_hBuyRobotHats.Push(991); g_hBuyRobotHats.Push(1012); g_hBuyRobotHats.Push(1018); g_hBuyRobotHats.Push(1028);
    g_hBuyRobotHats.Push(48); g_hBuyRobotHats.Push(94); g_hBuyRobotHats.Push(95); g_hBuyRobotHats.Push(118);
    g_hBuyRobotHats.Push(148); g_hBuyRobotHats.Push(178); g_hBuyRobotHats.Push(322); g_hBuyRobotHats.Push(338);
    g_hBuyRobotHats.Push(379); g_hBuyRobotHats.Push(382); g_hBuyRobotHats.Push(384); g_hBuyRobotHats.Push(386);
    g_hBuyRobotHats.Push(389); g_hBuyRobotHats.Push(399); g_hBuyRobotHats.Push(436); g_hBuyRobotHats.Push(484);
    g_hBuyRobotHats.Push(519); g_hBuyRobotHats.Push(520); g_hBuyRobotHats.Push(533); g_hBuyRobotHats.Push(590);
    g_hBuyRobotHats.Push(591); g_hBuyRobotHats.Push(605); g_hBuyRobotHats.Push(606); g_hBuyRobotHats.Push(628);
    g_hBuyRobotHats.Push(646); g_hBuyRobotHats.Push(670); g_hBuyRobotHats.Push(755); g_hBuyRobotHats.Push(784);
    g_hBuyRobotHats.Push(848); g_hBuyRobotHats.Push(948); g_hBuyRobotHats.Push(986); g_hBuyRobotHats.Push(988);
    g_hBuyRobotHats.Push(1008); g_hBuyRobotHats.Push(1009); g_hBuyRobotHats.Push(1010); g_hBuyRobotHats.Push(1012);
    g_hBuyRobotHats.Push(1017); g_hBuyRobotHats.Push(1065); g_hBuyRobotHats.Push(1089);
    g_hBuyRobotHats.Push(50); g_hBuyRobotHats.Push(101); g_hBuyRobotHats.Push(104); g_hBuyRobotHats.Push(144);
    g_hBuyRobotHats.Push(177); g_hBuyRobotHats.Push(184); g_hBuyRobotHats.Push(303); g_hBuyRobotHats.Push(315);
    g_hBuyRobotHats.Push(323); g_hBuyRobotHats.Push(363); g_hBuyRobotHats.Push(378); g_hBuyRobotHats.Push(381);
    g_hBuyRobotHats.Push(383); g_hBuyRobotHats.Push(388); g_hBuyRobotHats.Push(398); g_hBuyRobotHats.Push(467);
    g_hBuyRobotHats.Push(616); g_hBuyRobotHats.Push(620); g_hBuyRobotHats.Push(621); g_hBuyRobotHats.Push(639);
    g_hBuyRobotHats.Push(657); g_hBuyRobotHats.Push(754); g_hBuyRobotHats.Push(769); g_hBuyRobotHats.Push(770);
    g_hBuyRobotHats.Push(778); g_hBuyRobotHats.Push(828); g_hBuyRobotHats.Push(843); g_hBuyRobotHats.Push(867);
    g_hBuyRobotHats.Push(878); g_hBuyRobotHats.Push(978); g_hBuyRobotHats.Push(982); g_hBuyRobotHats.Push(986);
    g_hBuyRobotHats.Push(1012); g_hBuyRobotHats.Push(1039);
    g_hBuyRobotHats.Push(53); g_hBuyRobotHats.Push(109); g_hBuyRobotHats.Push(110); g_hBuyRobotHats.Push(117);
    g_hBuyRobotHats.Push(158); g_hBuyRobotHats.Push(181); g_hBuyRobotHats.Push(229); g_hBuyRobotHats.Push(314);
    g_hBuyRobotHats.Push(344); g_hBuyRobotHats.Push(393); g_hBuyRobotHats.Push(400); g_hBuyRobotHats.Push(518);
    g_hBuyRobotHats.Push(534); g_hBuyRobotHats.Push(600); g_hBuyRobotHats.Push(618); g_hBuyRobotHats.Push(626);
    g_hBuyRobotHats.Push(645); g_hBuyRobotHats.Push(646); g_hBuyRobotHats.Push(720); g_hBuyRobotHats.Push(759);
    g_hBuyRobotHats.Push(762); g_hBuyRobotHats.Push(779); g_hBuyRobotHats.Push(819); g_hBuyRobotHats.Push(847);
    g_hBuyRobotHats.Push(877); g_hBuyRobotHats.Push(917); g_hBuyRobotHats.Push(948); g_hBuyRobotHats.Push(981);
    g_hBuyRobotHats.Push(986); g_hBuyRobotHats.Push(1022); g_hBuyRobotHats.Push(1023); g_hBuyRobotHats.Push(1029);
    g_hBuyRobotHats.Push(1076); g_hBuyRobotHats.Push(1077); g_hBuyRobotHats.Push(1094); g_hBuyRobotHats.Push(1095);
    g_hBuyRobotHats.Push(55); g_hBuyRobotHats.Push(103); g_hBuyRobotHats.Push(108); g_hBuyRobotHats.Push(147);
    g_hBuyRobotHats.Push(180); g_hBuyRobotHats.Push(223); g_hBuyRobotHats.Push(319); g_hBuyRobotHats.Push(337);
    g_hBuyRobotHats.Push(361); g_hBuyRobotHats.Push(388); g_hBuyRobotHats.Push(397); g_hBuyRobotHats.Push(437);
    g_hBuyRobotHats.Push(459); g_hBuyRobotHats.Push(462); g_hBuyRobotHats.Push(483); g_hBuyRobotHats.Push(521);
    g_hBuyRobotHats.Push(602); g_hBuyRobotHats.Push(622); g_hBuyRobotHats.Push(629); g_hBuyRobotHats.Push(637);
    g_hBuyRobotHats.Push(639); g_hBuyRobotHats.Push(763); g_hBuyRobotHats.Push(782); g_hBuyRobotHats.Push(789);
    g_hBuyRobotHats.Push(841); g_hBuyRobotHats.Push(872); g_hBuyRobotHats.Push(879); g_hBuyRobotHats.Push(919);
    g_hBuyRobotHats.Push(936); g_hBuyRobotHats.Push(977); g_hBuyRobotHats.Push(1029); g_hBuyRobotHats.Push(1030);
}

void BuyRobot_RemoveWearables(int client)
{
    if (!IsValidClientIndex(client))
        return;
    
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
        {
            int idx = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
            if (idx >= 5617 && idx <= 5625)
                continue;
                
            AcceptEntityInput(ent, "Kill");
        }
    }
    
    ent = -1;
    while ((ent = FindEntityByClassname(ent, "tf_wearable_vm")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
        {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

void BuyRobot_EquipHat(int client)
{
    if (!IsValidClientIndex(client))
        return;
    
    bool isPurchased = g_bBuyIsPurchasedRobot[client];
    bool isDefender = g_bIsDefenderBot[client];
    
    if (!isPurchased && !isDefender)
        return;
    
    if (isPurchased && !g_cvBuyEnableHats.BoolValue)
        return;
    
    if (isDefender && !isPurchased && !g_cvBuyEnableDefenderHats.BoolValue)
        return;

    if (g_hBuyRobotHats == null || g_hBuyRobotHats.Length == 0)
    {
        BuyRobot_PopulateHatsList();
        if (g_hBuyRobotHats.Length == 0)
            return;
    }

    if (hEquipWearable == null)
        return;

    BuyRobot_RemoveWearables(client);

    TFClassType class = TF2_GetPlayerClass(client);
    int hatIndex;
    
    if (isPurchased)
    {
        if (g_iBuyRobotHatIndex[client] > 0)
            hatIndex = g_iBuyRobotHatIndex[client];
        else
        {
            hatIndex = BuyRobot_GetRandomHatForClass(class);
            if (hatIndex != -1)
                g_iBuyRobotHatIndex[client] = hatIndex;
        }
    }
    else if (isDefender)
    {
        if (g_iDefenderBotHatIndex[client] > 0)
            hatIndex = g_iDefenderBotHatIndex[client];
        else
        {
            hatIndex = BuyRobot_GetRandomHatForClass(class);
            if (hatIndex != -1)
                g_iDefenderBotHatIndex[client] = hatIndex;
        }
    }
    
    if (hatIndex == -1)
        return;

    int hat = CreateEntityByName("tf_wearable");
    if (!IsValidEntity(hat))
        return;

    SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", hatIndex);
    SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
    SetEntProp(hat, Prop_Send, "m_iEntityLevel", GetRandomInt(1, 100));
    SetEntProp(hat, Prop_Send, "m_iEntityQuality", 6);
    SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
    
    SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);
    DispatchSpawn(hat);
    SDKCall(hEquipWearable, client, hat);
}

int BuyRobot_GetRandomHatForClass(TFClassType class)
{
    if (g_hBuyRobotHats == null || g_hBuyRobotHats.Length == 0)
        return -1;
    
    ArrayList validHats = new ArrayList();
    
    for (int i = 0; i < g_hBuyRobotHats.Length; i++)
    {
        int hatIndex = g_hBuyRobotHats.Get(i);
        
        if (IsAllClassHat(hatIndex))
        {
            validHats.Push(hatIndex);
            continue;
        }
        
        switch (class)
        {
            case TFClass_Scout:    if (IsScoutHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Soldier:  if (IsSoldierHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Pyro:     if (IsPyroHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_DemoMan:  if (IsDemomanHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Heavy:    if (IsHeavyHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Engineer: if (IsEngineerHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Medic:    if (IsMedicHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Sniper:   if (IsSniperHat(hatIndex)) validHats.Push(hatIndex);
            case TFClass_Spy:      if (IsSpyHat(hatIndex)) validHats.Push(hatIndex);
        }
    }
    
    int result = -1;
    if (validHats.Length > 0)
        result = validHats.Get(GetRandomInt(0, validHats.Length - 1));
    
    delete validHats;
    return result;
}

bool IsAllClassHat(int index)
{
    int hats[] = {
        116, 125, 126, 134, 135, 136, 137, 138, 139, 162, 189, 260, 261, 263, 279, 287, 289, 291,
        302, 332, 333, 334, 341, 345, 408, 409, 410, 420, 470, 471, 473, 492, 523, 537, 538, 576,
        578, 579, 580, 584, 598, 634, 666, 667, 668, 671, 675, 702, 711, 712, 713, 756, 785, 817,
        920, 921, 940, 941, 942, 944, 984, 993, 994, 1014, 1033, 1034, 1035, 1067, 1122, 1899,
        30001, 30003, 30006, 30008, 30058, 30065, 30066, 30140, 30177, 30307, 30313, 30329, 30362,
        30422, 30425, 30469, 30473, 30542, 30546, 30549, 30567, 30571, 30607, 30623, 30640, 30643,
        30646, 30647
    };
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsScoutHat(int index)
{
    int hats[] = {52, 106, 107, 111, 150, 174, 219, 249, 324, 346, 453, 539, 614, 617, 633, 652, 760, 765, 780, 788, 846};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsSoldierHat(int index)
{
    int hats[] = {54, 98, 99, 152, 183, 227, 240, 250, 251, 252, 339, 340, 360, 378, 391, 395, 417, 434, 439, 445, 516, 575, 611, 631, 641, 701, 719, 721, 732, 764, 766, 829, 844, 945, 980, 1021};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsPyroHat(int index)
{
    int hats[] = {51, 102, 105, 151, 175, 182, 213, 247, 248, 253, 316, 318, 321, 335, 377, 394, 435, 481, 570, 571, 596, 597, 612, 615, 627, 644, 745, 753, 761, 783, 820, 842, 854, 937, 949, 950, 976, 1020, 1031, 1038};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsDemomanHat(int index)
{
    int hats[] = {47, 100, 120, 146, 179, 216, 255, 259, 306, 342, 359, 388, 390, 403, 465, 480, 514, 605, 607, 703, 771, 776, 786, 830, 845, 874, 876, 935, 986, 1012, 1019, 1029};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsHeavyHat(int index)
{
    int hats[] = {49, 96, 97, 145, 185, 246, 254, 290, 292, 309, 313, 330, 358, 378, 380, 427, 478, 485, 515, 517, 524, 535, 585, 601, 603, 613, 635, 757, 777, 840, 866, 876, 946, 952, 985, 989, 991, 1012, 1018, 1028};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsEngineerHat(int index)
{
    int hats[] = {48, 94, 95, 118, 148, 178, 322, 338, 379, 382, 384, 386, 389, 399, 436, 484, 519, 520, 533, 590, 591, 605, 606, 628, 646, 670, 755, 784, 848, 948, 986, 988, 1008, 1009, 1010, 1012, 1017, 1065, 1089};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsMedicHat(int index)
{
    int hats[] = {50, 101, 104, 144, 177, 184, 303, 315, 323, 363, 378, 381, 383, 388, 398, 467, 616, 620, 621, 639, 657, 754, 769, 770, 778, 828, 843, 867, 878, 978, 982, 986, 1012, 1039};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsSniperHat(int index)
{
    int hats[] = {53, 109, 110, 117, 158, 181, 229, 314, 344, 393, 400, 518, 534, 600, 618, 626, 645, 646, 720, 759, 762, 779, 819, 847, 877, 917, 948, 981, 986, 1022, 1023, 1029, 1076, 1077, 1094, 1095};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

bool IsSpyHat(int index)
{
    int hats[] = {55, 103, 108, 147, 180, 223, 319, 337, 361, 388, 397, 437, 459, 462, 483, 521, 602, 622, 629, 637, 639, 763, 782, 789, 841, 872, 879, 919, 936, 977, 1029, 1030};
    for (int i = 0; i < sizeof(hats); i++) if (index == hats[i]) return true;
    return false;
}

void BuyRobot_OnMapStart()
{
    BuyRobot_Cleanup();
    
    bWaveBeginProcessed = false;
    fLastWaveBeginTime = 0.0;
    
    g_flLastSendTime = 0.0;
    g_flLastSendTime2 = 0.0;
    g_flLastAnySendTime = 0.0;
    g_iWaveBonusCounter = 0;
    g_iWaveBonusCounter2 = 0;

    g_bSaxtonVoteOnCooldown = false;
    g_bGrayVoteOnCooldown = false;
    
    if (g_hBuyQueue == null)
    {
        g_hBuyQueue = new ArrayList(ByteCountToCells(256));
    }

    if (g_hWaitingQueue != null)
    {
    	g_hWaitingQueue.Clear();
    }
    
    if (g_hSpawnPoints != null)
    {
        delete g_hSpawnPoints;
        g_hSpawnPoints = null;
    }
    g_hSpawnPoints = new ArrayList(4);
    
    if (g_hSpawnAngles != null)
    {
        delete g_hSpawnAngles;
        g_hSpawnAngles = null;
    }
    g_hSpawnAngles = new ArrayList(3);
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    BuildPath(Path_SM, g_sSpawnConfigFile, sizeof(g_sSpawnConfigFile), "configs/defenderbots/buyrobot/spawns_%s.cfg", mapName);
    
    char folderPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/buyrobot");
    if (!DirExists(folderPath))
    {
        CreateDirectory(folderPath, 511);
    }
    
    LoadSpawnPoints();
    BuyRobot_PrecacheSounds();
    BuyRobot_PrecacheWaveIcon();
    BuyRobot_PrecacheSpawnModel();
    BuyRobot_ForceDownloadMaterials();
    
    if (g_hSpawnPoints.Length > 0)
    {
        CreateTimer(0.1, Timer_ForceRefreshModels, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if (g_hValidationTimer != INVALID_HANDLE)
    {
        KillTimer(g_hValidationTimer);
        g_hValidationTimer = INVALID_HANDLE;
    }
    g_hValidationTimer = CreateTimer(VALIDATION_INTERVAL, BuyRobot_ValidationTimer, _, TIMER_REPEAT);
    
    BuyRobot_LoadAllPoints();

    CreateTimer(3.0, Timer_DelayedPointsLoad, _, TIMER_FLAG_NO_MAPCHANGE);
}