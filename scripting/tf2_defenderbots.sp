/* --------------------------------------------------
MvM Defender TFBots
April 08 2024
Author: ★ Officer Spy ★
-------------------------------------------------- */
#include <sourcemod>
#include <tf2_stocks>
#include <dhooks>
#include <tf2attributes>
#include <tf_econ_data>
#include <tf2utils>
#include <cbasenpc>
#include <cbasenpc/tf/nav>
#include <ripext>

#define _disable_actions_query_result_type
#define _disable_actions_event_result_priority_type
#include <actions>

#pragma semicolon 1
#pragma newdecls required

// #define TESTING_ONLY

#define MOD_REQUEST_CREDITS
#define MOD_CUSTOM_ATTRIBUTES
#define MOD_ROLL_THE_DICE_REVAMPED

#define METHOD_MVM_UPGRADES

#define CHANGETEAM_RESTRICTIONS

// #define TFBOT_CUSTOM_SPY_CONTACT

#define EXTRA_PLUGINBOT

// #define VALIDATE_ENTITY_TANKBOSS

// #define IDLEBOT_AIMING

#define PLUGIN_PREFIX	"[BotManager]"
#define TFBOT_IDENTITY_NAME	"TFBOT_SEX_HAVER"

enum
{
	MANAGER_MODE_MANUAL_BOTS = 0,
	MANAGER_MODE_READY_BOTS,
	MANAGER_MODE_AUTO_BOTS
}

enum
{
	BOT_LINEUP_MODE_RANDOM,
	BOT_LINEUP_MODE_PREFERENCE,
	BOT_LINEUP_MODE_CHOOSE,
	BOT_LINEUP_MODE_PREFERENCE_CHOOSE
}

enum struct esMapConfiguration
{
	ArrayList adtSniperSpot;
	ArrayList adtEngineerNestLocation;
	ArrayList adtTeleporterEntranceLocation;
	ArrayList adtTeleporterExitLocation;
	
	void Initialize()
	{
		this.adtSniperSpot = new ArrayList(3);
	}
	void Reset()
	{
		this.adtSniperSpot.Clear();
	}
}

enum struct esButtonInput
{
	int iPress;
	float flPressTime;
	int iRelease;
	float flReleaseTime;
	float flKeySpeed;
	
	void Reset()
	{
		this.iPress = 0;
		this.flPressTime = 0.0;
		this.iRelease = 0;
		this.flReleaseTime = 0.0;
		this.flKeySpeed = 0.0;
	}
	
	void PressButtons(int buttons, float duration = -1.0)
	{
		this.iPress = buttons;
		this.flPressTime = duration > 0.0 ? GetGameTime() + duration : 0.0;
	}
	
	void ReleaseButtons(int buttons, float duration = -1.0)
	{
		this.iRelease = buttons;
		this.flReleaseTime = duration > 0.0 ? GetGameTime() + duration : 0.0;
	}
}

//Globals
bool g_bLateLoad;
bool g_bBotsEnabled;
float g_flAddingBotTime;
float g_flNextReadyTime;
int g_iDetonatingPlayer = -1;
ArrayList g_adtChosenBotClasses;
bool g_bBotClassesLocked;
int g_iUIDBotSummoner = 0;
bool g_bAllowBotTeamRedo;
bool g_bSpotsGlobalVisible = false;
Handle g_hGlobalSpotTimer = INVALID_HANDLE;
ArrayList g_hTeleporterEntranceSpots = null;
char g_sTeleporterConfigFile[PLATFORM_MAX_PATH];
int g_iBotEntranceSpot[MAXPLAYERS + 1];
int g_iObjectiveResource = -1;

//For defender bots
bool g_bIsDefenderBot[MAXPLAYERS + 1];
bool g_bIsBeingRevived[MAXPLAYERS + 1];
bool g_bHasUpgraded[MAXPLAYERS + 1];
bool g_bBuyIsPurchasedRobot[MAXPLAYERS + 1];
bool g_bBuyIsAIRobot[MAXPLAYERS + 1];
esButtonInput g_arrExtraButtons[MAXPLAYERS + 1];
static float m_flDeadRethinkTime[MAXPLAYERS + 1];
int g_iBuybackNumber[MAXPLAYERS + 1];
int g_iBuyUpgradesNumber[MAXPLAYERS + 1];
bool g_bEngineerHelpDisabled[MAXPLAYERS + 1];

bool g_bHeavyWindDown[MAXPLAYERS+1];
bool g_bHeavyLocked1[MAXPLAYERS+1];
bool g_bHeavyLocked2[MAXPLAYERS+1];
bool g_bHeavyLocked3[MAXPLAYERS+1];
bool g_bPyroLocked1[MAXPLAYERS+1];
bool g_bPyroLocked2[MAXPLAYERS+1];

int g_iDefenderBotHatIndex[MAXPLAYERS + 1];

static float g_flLastNestMoveTime[MAXPLAYERS + 1];
#define NEST_MOVE_COOLDOWN 10.0

#if !defined IDLEBOT_AIMING
static float m_flNextSnipeFireTime[MAXPLAYERS + 1];
#endif

#if defined MOD_ROLL_THE_DICE_REVAMPED
static float m_flNextRollTime[MAXPLAYERS + 1];
#endif

//For other players
bool g_bChoosingBotClasses[MAXPLAYERS + 1];

#if defined CHANGETEAM_RESTRICTIONS
float g_flEnableBotsCooldown[MAXPLAYERS + 1];
#endif

static float m_flLastCommandTime[MAXPLAYERS + 1];
static float m_flLastReadyInputTime[MAXPLAYERS + 1];

//Config
esMapConfiguration g_arrMapConfig;
static ArrayList m_adtBotNames;

//Global entities
int g_iPopulationManager = -1;

ConVar redbots_manager_debug;
ConVar redbots_manager_debug_actions;
ConVar redbots_manager_mode;
ConVar redbots_manager_bot_lineup_mode;
ConVar redbots_manager_use_custom_loadouts;
ConVar redbots_manager_kick_bots;
ConVar redbots_manager_min_players;
ConVar redbots_manager_defender_team_size;
ConVar redbots_manager_ready_cooldown;
ConVar redbots_manager_keep_bot_upgrades;
ConVar redbots_manager_bot_upgrade_interval;
ConVar redbots_manager_bot_use_upgrades;
ConVar redbots_manager_bot_buyback_chance;
ConVar redbots_manager_bot_buy_upgrades_chance;
ConVar redbots_manager_bot_max_tank_attackers;
ConVar redbots_manager_bot_aim_skill;
ConVar redbots_manager_bot_reflect_skill;
ConVar redbots_manager_bot_reflect_chance;
ConVar redbots_manager_bot_backstab_skill;
ConVar redbots_manager_bot_hear_spy_range;
ConVar redbots_manager_bot_notice_spy_time;
ConVar redbots_manager_extra_bots;

#if defined MOD_REQUEST_CREDITS
ConVar redbots_manager_bot_request_credits;
#endif

#if defined MOD_ROLL_THE_DICE_REVAMPED
ConVar redbots_manager_bot_rtd_variance;
#endif

ConVar nb_blind;
ConVar tf_bot_path_lookahead_range;
ConVar tf_bot_health_critical_ratio;
ConVar tf_bot_health_ok_ratio;
ConVar tf_bot_ammo_search_range;
ConVar tf_bot_health_search_far_range;
ConVar tf_bot_health_search_near_range;
ConVar tf_bot_suicide_bomb_range;

#if defined METHOD_MVM_UPGRADES
Address g_pMannVsMachineUpgrades;
#endif

#include "redbots3/buyrobot.sp"
#include "redbots3/util.sp"
#include "redbots3/offsets.sp"
#include "redbots3/sdkcalls.sp"
#include "redbots3/loadouts.sp"
#include "redbots3/dhooks.sp"
#include "redbots3/events.sp"
#include "redbots3/player_pref.sp"
#include "redbots3/menu.sp"
#include "redbots3/tf_upgrades.sp"
#include "redbots3/nextbot_behavior.sp"
#include "redbots3/botaim.sp"

public Plugin myinfo =
{
	name = "Defender TFBots",
	author = "Officer Spy",
	description = "TFBots that play Mann vs. Machine",
	version = "1.5.5",
	url = "https://github.com/OfficerSpy/TF2-MvM-Defender-TFBots"
};

public void OnPluginStart()
{
#if defined TESTING_ONLY
	BuildPath(Path_SM, g_sPlayerPrefPath, PLATFORM_MAX_PATH, "data/testing/db_botpref.txt");
	PrintToServer("[BOTS MANAGER] DEBUG BUILD: FOR DEV USE ONLY");
#else
	BuildPath(Path_SM, g_sPlayerPrefPath, PLATFORM_MAX_PATH, "data/db_botpref.txt");
#endif

    HookEvent("mvm_begin_wave", BuyRobot_WaveBegin);
    HookEvent("mvm_wave_complete", BuyRobot_WaveEnd);
    HookEvent("mvm_wave_failed", BuyRobot_WaveEnd);
	
	redbots_manager_debug = CreateConVar("sm_redbots_manager_debug", "0", _, FCVAR_NONE);
	redbots_manager_debug_actions = CreateConVar("sm_redbots_manager_debug_actions", "0", _, FCVAR_NONE);
	redbots_manager_mode = CreateConVar("sm_redbots_manager_mode", "0", "What mode of the mod the use.", FCVAR_NOTIFY);
	redbots_manager_bot_lineup_mode = CreateConVar("sm_redbots_manager_bot_lineup_mode", "0", "How bot team composition is decided.", FCVAR_NOTIFY);
	redbots_manager_use_custom_loadouts = CreateConVar("sm_redbots_manager_use_custom_loadouts", "0", "Let's bots use different weapons.", FCVAR_NOTIFY);
	redbots_manager_kick_bots = CreateConVar("sm_redbots_manager_kick_bots", "1", "Kick bots on wave failure/completion.", FCVAR_NOTIFY);
	redbots_manager_min_players = CreateConVar("sm_redbots_manager_min_players", "3", "Minimum players for normal missions. Other difficulties are adjusted based on this value. Set to -1 to disable entirely.", FCVAR_NOTIFY, true, -1.0, true, float(MAXPLAYERS));
	redbots_manager_defender_team_size = CreateConVar("sm_redbots_manager_defender_team_size", "6", _, FCVAR_NOTIFY);
	redbots_manager_ready_cooldown = CreateConVar("sm_redbots_manager_ready_cooldown", "30.0", _, FCVAR_NOTIFY, true, 0.0);
	redbots_manager_keep_bot_upgrades = CreateConVar("sm_redbots_manager_keep_bot_upgrades", "0", _, FCVAR_NOTIFY);
	redbots_manager_bot_upgrade_interval = CreateConVar("sm_redbots_manager_bot_upgrade_interval", "0.1", _, FCVAR_NOTIFY);
	redbots_manager_bot_use_upgrades = CreateConVar("sm_redbots_manager_bot_use_upgrades", "1", "Enable bots to buy upgrades.", FCVAR_NOTIFY);
	redbots_manager_bot_buyback_chance = CreateConVar("sm_redbots_manager_bot_buyback_chance", "5", "Chance for bots to buyback into the game.", FCVAR_NOTIFY);
	redbots_manager_bot_buy_upgrades_chance = CreateConVar("sm_redbots_manager_bot_buy_upgrades_chance", "50", "Chance for bots to buy upgrades in the middle of a game.", FCVAR_NOTIFY);
	redbots_manager_bot_max_tank_attackers = CreateConVar("sm_redbots_manager_bot_max_tank_attackers", "3", _, FCVAR_NOTIFY);
	redbots_manager_bot_aim_skill = CreateConVar("sm_redbots_manager_bot_aim_skill", "0", _, FCVAR_NOTIFY);
	redbots_manager_bot_reflect_skill = CreateConVar("sm_redbots_manager_bot_reflect_skill", "1", _, FCVAR_NOTIFY);
	redbots_manager_bot_reflect_chance = CreateConVar("sm_redbots_manager_bot_reflect_chance", "100.0", _, FCVAR_NOTIFY);
	redbots_manager_bot_backstab_skill = CreateConVar("sm_redbots_manager_bot_backstab_skill", "0", _, FCVAR_NOTIFY);
	redbots_manager_bot_hear_spy_range = CreateConVar("sm_redbots_manager_bot_hear_spy_range", "3000.0", _, FCVAR_NOTIFY);
	redbots_manager_bot_notice_spy_time = CreateConVar("sm_redbots_manager_bot_notice_spy_time", "0.0", _, FCVAR_NOTIFY);
	redbots_manager_extra_bots = CreateConVar("sm_redbots_manager_extra_bots", "1", "How many more bots we are allowed to request beyond the team size", FCVAR_NOTIFY);
	
#if defined MOD_REQUEST_CREDITS
	redbots_manager_bot_request_credits = CreateConVar("sm_redbots_manager_bot_request_credits", "1", _, FCVAR_NOTIFY);
#endif
	
#if defined MOD_ROLL_THE_DICE_REVAMPED
	redbots_manager_bot_rtd_variance = CreateConVar("sm_redbots_manager_bot_rtd_variance", "15.0", _, FCVAR_NOTIFY);
#endif
	
	HookConVarChange(redbots_manager_mode, ConVarChanged_ManagerMode);
	HookConVarChange(redbots_manager_bot_lineup_mode, ConVarChanged_BotLineupMode);
	
	RegConsoleCmd("sm_votebots", Command_Votebots);
	RegConsoleCmd("sm_vb", Command_Votebots);
	RegConsoleCmd("sm_botpref", Command_BotPreferences);
	RegConsoleCmd("sm_botpreferences", Command_BotPreferences);
	RegConsoleCmd("sm_viewbotchances", Command_ShowBotChances);
	RegConsoleCmd("sm_botchances", Command_ShowBotChances);
	RegConsoleCmd("sm_viewbotlineup", Command_ShowNewBotTeamComposition);
	RegConsoleCmd("sm_botlineup", Command_ShowNewBotTeamComposition);
	RegConsoleCmd("sm_rerollbotclasses", Command_RerollNewBotTeamComposition);
	RegConsoleCmd("sm_rerollbots", Command_RerollNewBotTeamComposition);
	RegConsoleCmd("sm_rollbots", Command_RerollNewBotTeamComposition);
	RegConsoleCmd("sm_playwithbots", Command_JoinBluePlayWithBots);
	RegConsoleCmd("sm_requestbot", Command_RequestExtraBot);
	RegConsoleCmd("sm_choosebotteam", Command_ChooseBotClasses);
	RegConsoleCmd("sm_cbt", Command_ChooseBotClasses);
	RegConsoleCmd("sm_redobots", Command_RedoBotTeamLineup);
	
#if defined TESTING_ONLY
	RegConsoleCmd("sm_bots_start_now", Command_BotsReadyNow);
#endif
	
	RegAdminCmd("sm_addbots", Command_AddBots, ADMFLAG_GENERIC);
	RegAdminCmd("sm_purgebots", Command_RemoveAllBots, ADMFLAG_GENERIC);
	RegAdminCmd("sm_botmanager_stop", Command_StopManagingBots, ADMFLAG_GENERIC);
	RegAdminCmd("sm_view_bot_upgrades", Command_ViewBotUpgrades, ADMFLAG_GENERIC);
	RegAdminCmd("sm_addsniperhit", Command_AddSniperHit, ADMFLAG_GENERIC, "Adds sniper spot at current position");
	RegAdminCmd("sm_addnest", Command_AddNestSpot, ADMFLAG_GENERIC, "Add engineer nest spot at current position");
	RegAdminCmd("sm_listnests", Command_ListNestSpots, ADMFLAG_GENERIC, "List all engineer nest spots");
	RegAdminCmd("sm_spots", Command_SpotsToggle, ADMFLAG_GENERIC, "Enable/Disable spot visualization");
	RegAdminCmd("sm_spotinfo", Command_SpotInfo, ADMFLAG_GENERIC, "Shows info of spot you're looking at");
	RegAdminCmd("sm_addteleporter", Command_AddTeleporterEntrance, ADMFLAG_GENERIC, "Add teleporter entrance at current position");
	RegAdminCmd("sm_listteleporter", Command_ListTeleporterSpots, ADMFLAG_GENERIC, "List teleporter spots");
	RegAdminCmd("sm_removeteleporter", Command_RemoveTeleporterSpot, ADMFLAG_GENERIC, "Remove teleporter spot by ID");
	RegAdminCmd("sm_clearteleporter", Command_ClearTeleporterSpots, ADMFLAG_GENERIC, "Clear all teleporter spots");
	
	AddCommandListener(Listener_TournamentPlayerReadystate, "tournament_player_readystate");
	
	AddNormalSoundHook(SoundHook_General);
	
	InitGameEventHooks();
	
	GameData hGamedata = new GameData("tf2.defenderbots");
	
	if (hGamedata)
	{
		InitOffsets(hGamedata);
		
		bool bFailed = false;
		
#if defined METHOD_MVM_UPGRADES
		InitMvMUpgrades(hGamedata);
		
		g_pMannVsMachineUpgrades = GameConfGetAddress(hGamedata, "MannVsMachineUpgrades");
		
		if (!g_pMannVsMachineUpgrades)
			LogError("OnPluginStart: Failed to find Address to g_MannVsMachineUpgrades!");
#if defined TESTING_ONLY
		else
			LogMessage("OnPluginStart: Found \"g_MannVsMachineUpgrades\" @ 0x%X", g_pMannVsMachineUpgrades);
#endif
#endif
		
		if (!InitSDKCalls(hGamedata))
			bFailed = true;
		
		if (!InitDHooks(hGamedata))
			bFailed = true;
		
		delete hGamedata;
		
		if (bFailed)
			SetFailState("Gamedata failed!");
	}
	else
	{
		SetFailState("Failed to load gamedata file tf2.defenderbots.txt");
	}
	
	if (g_bLateLoad)
	{
		g_iPopulationManager = FindEntityByClassname(MaxClients + 1, "info_populator");
	}
	
	LoadLoadoutFunctions();
	LoadPreferencesData();
	
	g_adtChosenBotClasses = new ArrayList(TF2_CLASS_MAX_NAME_LENGTH);
	m_adtBotNames = new ArrayList(MAX_NAME_LENGTH);
	g_arrMapConfig.Initialize();
	
	InitNextBotPathing();
	BuyRobot_Init();
	
#if defined IDLEBOT_AIMING
	InitTFBotAim();
#endif
	
	CreateTimer(0.1, Timer_FixWaveBar, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	FindGameConsoleVariables();
	AutoExecConfig(true, "defenderbots");
}

public void OnPluginEnd()
{
	RemoveAllDefenderBots("BM3 OnPluginEnd");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnMapStart()
{
	g_bBotsEnabled = false;
	g_flAddingBotTime = 0.0;
	g_flNextReadyTime = 0.0;
	g_bBotClassesLocked = false;
	g_bAllowBotTeamRedo = false;

	Config_LoadMap();
	Config_LoadBotNames();
	CreateBotPreferenceMenu();
	BuyRobot_OnMapStart();
	InitializeEngineerSpotSystem();
	InitializeTeleporterSystem();
}

/* public void OnMapEnd()
{
	RemoveAllDefenderBots("BM3 OnMapEnd");
} */

public void OnClientDisconnect(int client)
{
    if (client == g_iPlayerForcedPref)
        g_iPlayerForcedPref = -1;

    BuyRobot_CleanupBot(client);
    CleanupDefenderBotData(client);
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client))
    {
        CreateTimer(5.0, Timer_WelcomeMessage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    CleanupDefenderBotData(client);

#if defined MOD_ROLL_THE_DICE_REVAMPED
    m_flNextRollTime[client] = 0.0;
#endif
    
#if defined CHANGETEAM_RESTRICTIONS
    g_flEnableBotsCooldown[client] = 0.0;
#endif
    
    m_flLastCommandTime[client] = GetGameTime();
    m_flLastReadyInputTime[client] = 0.0;
    
#if defined IDLEBOT_AIMING
    BotAim(client).Reset();
#endif
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "info_populator"))
		g_iPopulationManager = entity;
	
	if (StrEqual(classname, "tf_objective_resource"))
		g_iObjectiveResource = entity;
	
	DHooks_OnEntityCreated(entity, classname);

    if (StrEqual(classname, "tf_ammo_pack") || 
        StrContains(classname, "item_ammopack") != -1 ||
        StrContains(classname, "item_healthkit") != -1)
    {
        CreateTimer(0.01, Timer_RemoveDropIfFromPurchasedRobot, EntIndexToEntRef(entity));
    }
}

void AddRobotToWaveBar(int client)
{
    if (g_iObjectiveResource == -1 || !IsValidEntity(g_iObjectiveResource))
        return;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    int iFlags = MVM_CLASS_FLAG_NORMAL;
    if (isBoss)
        iFlags |= MVM_CLASS_FLAG_MINIBOSS | MVM_CLASS_FLAG_ALWAYSCRIT;
    else if (isGiant)
        iFlags |= MVM_CLASS_FLAG_MINIBOSS;
    
    OSLib_IncrementWaveIconSpawnCount(g_iObjectiveResource, "blu2_lite", iFlags, 1, false);
}

void RemoveRobotFromWaveBar(int client)
{
    if (g_iObjectiveResource == -1 || !IsValidEntity(g_iObjectiveResource))
        return;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    int iFlags = MVM_CLASS_FLAG_NORMAL;
    if (isBoss)
        iFlags |= MVM_CLASS_FLAG_MINIBOSS | MVM_CLASS_FLAG_ALWAYSCRIT;
    else if (isGiant)
        iFlags |= MVM_CLASS_FLAG_MINIBOSS;
    
    OSLib_DecrementWaveIconSpawnCount(g_iObjectiveResource, "blu2_lite", iFlags, 1, false);
}

public Action Timer_FixWaveBar(Handle timer)
{
    if (GameRules_GetRoundState() != RoundState_RoundRunning)
        return Plugin_Continue;
    
    if (g_iObjectiveResource == -1 || !IsValidEntity(g_iObjectiveResource))
        return Plugin_Continue;
    
    int blueBots = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
            blueBots++;
    }
    
    int currentWaveCount = GetEntProp(g_iObjectiveResource, Prop_Send, "m_nMannVsMachineWaveEnemyCount");
    int originalWaveCount = currentWaveCount - blueBots;
    if (originalWaveCount < 0) originalWaveCount = 0;
    
    SetEntProp(g_iObjectiveResource, Prop_Send, "m_nMannVsMachineWaveEnemyCount", originalWaveCount + blueBots);
    
    return Plugin_Continue;
}

public Action Timer_RemoveDropIfFromPurchasedRobot(Handle timer, any entref)
{
    int entity = EntRefToEntIndex(entref);
    
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
        return Plugin_Stop;
    
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if (owner > 0 && owner <= MaxClients && IsClientInGame(owner))
    {
        if (g_bBuyIsPurchasedRobot[owner])
        {
            AcceptEntityInput(entity, "Kill");
            return Plugin_Stop;
        }
    }
    
    float entPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bBuyIsPurchasedRobot[i] && !IsPlayerAlive(i))
        {
            float botPos[3];
            GetClientAbsOrigin(i, botPos);
            
            if (GetVectorDistance(botPos, entPos) < 200.0)
            {
                AcceptEntityInput(entity, "Kill");
                break;
            }
        }
    }
    
    return Plugin_Stop;
}

/* NOTE: This forward is not consistent with nextbot functionalities such as Action::Update
Nextbot behavior updates are based on the value of convar nb_update_frequency
This forward is only called every time CBasePlayer::PlayerRunCommand is called, which updates on its own interval
So what gets done in here will never always be consistent with the nextbot behavior actions */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_bIsDefenderBot[client])
        return Plugin_Continue;
	
	if (IsPlayerAlive(client))
	{
		if (g_arrExtraButtons[client].iPress != 0)
		{
			if (g_arrExtraButtons[client].iPress & IN_BACK)
				vel[0] -= PLAYER_SIDESPEED;
			
			if (g_arrExtraButtons[client].iPress & IN_FORWARD)
				vel[0] += PLAYER_SIDESPEED;
			
			if (g_arrExtraButtons[client].iPress & IN_MOVELEFT)
				vel[1] -= PLAYER_SIDESPEED;
			
			if (g_arrExtraButtons[client].iPress & IN_MOVERIGHT)
				vel[1] += PLAYER_SIDESPEED;
			
			if (g_arrExtraButtons[client].iPress & IN_LEFT)
				angles[1] -= g_arrExtraButtons[client].flKeySpeed;
			
			if (g_arrExtraButtons[client].iPress & IN_RIGHT)
				angles[1] += g_arrExtraButtons[client].flKeySpeed;
			
			buttons |= g_arrExtraButtons[client].iPress;
			
			//We are told to hold these inputs down for a specific time, don't clear until it expires
			if (g_arrExtraButtons[client].flPressTime <= GetGameTime())
				g_arrExtraButtons[client].iPress = 0;
		}
		
		if (g_arrExtraButtons[client].iRelease != 0)
		{
			buttons &= ~g_arrExtraButtons[client].iRelease;
			
			if (g_arrExtraButtons[client].flReleaseTime <= GetGameTime())
				g_arrExtraButtons[client].iRelease = 0;
		}
		
#if defined EXTRA_PLUGINBOT
		PluginBot_SimulateFrame(client);
#endif
		
#if defined IDLEBOT_AIMING
		if (m_ctReload[client] > GetGameTime())
		{
			buttons |= IN_RELOAD;
		}
		
		if (m_ctFire[client] > GetGameTime())
		{
			buttons |= IN_ATTACK;
		}
		
		if (m_ctAltFire[client] > GetGameTime())
		{
			buttons |= IN_ATTACK2;
		}
#endif
		
		if (GameRules_GetRoundState() != RoundState_BetweenRounds)
		{
			int myWeapon = BaseCombatCharacter_GetActiveWeapon(client);
			int weaponID = myWeapon != -1 ? TF2Util_GetWeaponID(myWeapon) : -1;
			
			if (buttons & IN_ATTACK)
			{
				switch (weaponID)
				{
#if !defined IDLEBOT_AIMING
					case TF_WEAPON_MINIGUN:
					{
						//Don't keep spinning the minigun if it ran out of ammo
						if (!HasAmmo(myWeapon))
							buttons &= ~IN_ATTACK;
					}
#endif
					case TF_WEAPON_SNIPERRIFLE_CLASSIC:
					{
						//For the classic, let go on a full charge
						if (GetEntPropFloat(myWeapon, Prop_Send, "m_flChargedDamage") >= 150.0)
							buttons &= ~IN_ATTACK;
					}
					case TF_WEAPON_BUFF_ITEM:
					{
						//Once we blow the horn, stop pressing the fire button
						if (IsPlayingHorn(myWeapon))
							buttons &= ~IN_ATTACK;
					}
					case TF_WEAPON_REVOLVER:
					{
						if (CanRevolverHeadshot(myWeapon))
						{
							//Don;t fire if our shot won't be very accurate
							if (!(GetGameTime() - GetLastAccuracyCheck(myWeapon) > 1.0))
								buttons &= ~IN_ATTACK;
						}
					}
				}
			}
			
			INextBot myBot = CBaseNPC_GetNextBotOfEntity(client);
			IVision myVision = myBot.GetVisionInterface();
			
			MonitorKnownEntities(client, myVision);
			
			CKnownEntity threat = myVision.GetPrimaryKnownThreat(false);
			
			OpportunisticallyUseWeaponAbilities(client, myWeapon, myBot, threat);
			OpportunisticallyUsePowerupBottle(client, myWeapon, myBot, threat);
			
			if ((weaponID == TF_WEAPON_FLAMETHROWER || weaponID == TF_WEAPON_FLAME_BALL) && CanWeaponAirblast(myWeapon))
				UtilizeCompressionBlast(client, myBot, threat, 1);
			
#if defined IDLEBOT_AIMING
			if (threat)
			{
				//TODO: disable on engineers for now until we make a proper better behavior
				if (TF2_GetPlayerClass(client) != TFClass_Engineer)
					BotAim(client).AimHeadTowardsEntity(threat.GetEntity(), CRITICAL, 0.1);
			}
#else
			if (WeaponID_IsSniperRifle(weaponID))
			{
				if (TF2_IsPlayerInCondition(client, TFCond_Zoomed))
				{
					if (redbots_manager_bot_aim_skill.IntValue >= 1)
					{
						//TODO: this needs to be more precise with actually getting our current m_lookAtSubject in PlayerBody as this can cause jittery aim
						if (threat && IsLineOfFireClearEntity(client, GetEyePosition(client), threat.GetEntity()))
						{
							//Help aim towards the desired target point
							float aimPos[3]; myBot.GetIntentionInterface().SelectTargetPoint(threat.GetEntity(), aimPos);
							SnapViewToPosition(client, aimPos);
							
							if (m_flNextSnipeFireTime[client] <= GetGameTime())
								VS_PressFireButton(client);
						}
						else
						{
							//Delay to give a reaction time the next time we can see a threat
							m_flNextSnipeFireTime[client] = GetGameTime() + SNIPER_REACTION_TIME;
						}
					}
					else
					{
						if (threat && threat.IsVisibleInFOVNow() && myBot.GetBodyInterface().IsHeadAimingOnTarget())
						{
							if (m_flNextSnipeFireTime[client] <= GetGameTime())
								VS_PressFireButton(client);
						}
						else
						{
							m_flNextSnipeFireTime[client] = GetGameTime() + SNIPER_REACTION_TIME;
						}
					}
				}
				else
				{
					//Set a reaction time when we're not scoped in
					m_flNextSnipeFireTime[client] = GetGameTime() + SNIPER_REACTION_TIME;
				}
			}
			else
			{
				if (threat)
				{
					//Exclude certain things for scenarios where aim shouldn't be altered
					//TODO: replace this with a variable to control this
					if (IsCombatWeapon(client, myWeapon) && weaponID != TF_WEAPON_KNIFE && TF2_GetPlayerClass(client) != TFClass_Engineer && weaponID != TF_WEAPON_BONESAW)
					{
						int iThreat = threat.GetEntity();
						
						if (redbots_manager_bot_aim_skill.IntValue >= 2)
						{
							/* NOTE: this used to be handled in CTFBotMainAction_SelectTargetPoint, but it seems that function doesn't always get called when the bot is up close to it
							The bot will look up, but then start looking towards the center again and stop firing before going to look up and fire again
							It then just repeats this process over and over unless it gets away from the tank */
							if (weaponID == TF_WEAPON_FLAMETHROWER && IsBaseBoss(iThreat) && myBot.IsRangeLessThan(iThreat, FLAMETHROWER_REACH_RANGE))
							{
								float aimPos[3]; GetFlameThrowerAimForTank(iThreat, aimPos);
								SnapViewToPosition(client, aimPos);
								buttons |= IN_ATTACK;
							}
							else if (!threat.IsVisibleInFOVNow() && IsLineOfFireClearEntity(client, GetEyePosition(client), iThreat))
							{
								//We're not currently facing our threat, so let's quickly turn towards them
								float aimPos[3]; myBot.GetIntentionInterface().SelectTargetPoint(iThreat, aimPos);
								SnapViewToPosition(client, aimPos);
							}
						}
						else if (redbots_manager_bot_aim_skill.IntValue == 1)
						{
							if (weaponID == TF_WEAPON_FLAMETHROWER && IsBaseBoss(iThreat) && myBot.IsRangeLessThan(iThreat, FLAMETHROWER_REACH_RANGE))
							{
								float aimPos[3]; GetFlameThrowerAimForTank(iThreat, aimPos);
								SnapViewToPosition(client, aimPos);
								buttons |= IN_ATTACK;
							}
							else if (!threat.IsVisibleRecently() && IsLineOfFireClearEntity(client, GetEyePosition(client), iThreat))
							{
								float aimPos[3]; myBot.GetIntentionInterface().SelectTargetPoint(iThreat, aimPos);
								SnapViewToPosition(client, aimPos);
							}
						}
						else
						{
							if (weaponID == TF_WEAPON_FLAMETHROWER && IsBaseBoss(iThreat) && myBot.IsRangeLessThan(iThreat, FLAMETHROWER_REACH_RANGE))
							{
								float aimPos[3];
								GetFlameThrowerAimForTank(iThreat, aimPos);
								SnapViewToPosition(client, aimPos); //TODO: replace with AimHeadTowards
								buttons |= IN_ATTACK;
							}
						}
					}
				}
			}
#endif
			
#if defined MOD_ROLL_THE_DICE_REVAMPED
			if (redbots_manager_bot_rtd_variance.FloatValue >= COMMAND_MAX_RATE)
			{
				if (threat && threat.IsVisibleInFOVNow() && m_flNextRollTime[client] <= GetGameTime())
				{
					m_flNextRollTime[client] = GetGameTime() + GetRandomFloat(COMMAND_MAX_RATE, redbots_manager_bot_rtd_variance.FloatValue);
					FakeClientCommand(client, "sm_rtd");
				}
			}
#endif
			
#if defined TESTING_ONLY
			if (GetEntityFlags(client) & FL_ONGROUND == 0 && !TF2_IsJumping(client))
			{
				//TFBots have no air control in mvm, keep us moving
				PathFollower myPath = myBot.GetCurrentPath();
				
				if (myPath)
				{
					Segment pGoal = myPath.GetCurrentGoal();
					
					if (pGoal)
					{
						float vGoal[3]; pGoal.GetPosition(vGoal);
						MovePlayerTowardsGoal(client, vGoal, vel);
					}
				}
			}
#endif
		}
		
		//TODO: is this too expensive? use global per-player variable otherwise
		if (TF2_IsInUpgradeZone(client) && ActionsManager.LookupEntityActionByName(client, "DefenderUpgrade") != INVALID_ACTION)
		{
			//Because of CTFBot::AvoidPlayers, do not let ourselves move away from other players while upgrading
			vel = NULL_VECTOR;
		}
		
#if defined IDLEBOT_AIMING
		BotAim(client).Upkeep();
		BotAim(client).FireWeaponAtEnemy();
#endif
	}
	else
	{
		if (m_flDeadRethinkTime[client] <= GetGameTime())
		{
			//Think every second while we're dead
			m_flDeadRethinkTime[client] = GetGameTime() + 1.0;
			
			int iObsMode = BasePlayer_GetObserverMode(client);
			
			if (iObsMode == OBS_MODE_FREEZECAM || iObsMode == OBS_MODE_DEATHCAM)
			{
				//We can't buyback right now, so don't even think about it
				g_iBuybackNumber[client] = 0;
			}
			else
			{
				//Randomly think about buying back
				g_iBuybackNumber[client] = GetRandomInt(1, 100);
			}
			
			if (ShouldBuybackIntoGame(client))
				PlayerBuyback(client);
			
			if (redbots_manager_debug.BoolValue)
				PrintToChatAll("[OnPlayerRunCmd] g_iBuybackNumber[%d] = %d", client, g_iBuybackNumber[client]);
		}
		
		
	}

    if (g_bBuyIsPurchasedRobot[client] && IsPlayerAlive(client))
    {
        char clientName[64];
        GetClientName(client, clientName, sizeof(clientName));
        bool isGiant = (StrContains(clientName, "Giant") != -1);
        bool isBoss = (StrContains(clientName, "Boss") != -1);
        
        if (isGiant || isBoss)
        {
            TFClassType class = TF2_GetPlayerClass(client);
            
            if (class == TFClass_Heavy)
            {
                int heavyWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
                if (IsValidEntity(heavyWeapon))
                {
                    int state = GetEntProp(heavyWeapon, Prop_Send, "m_iWeaponState");
                    
                    if (state == 1 && !g_bHeavyLocked1[client])
                    {
                        EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunwindup.wav", client, SNDCHAN_WEAPON);
                        g_bHeavyLocked1[client] = true;
                        g_bHeavyLocked2[client] = false;
                        g_bHeavyLocked3[client] = false;
                        g_bHeavyWindDown[client] = true;
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
                    }
                    else if (state == 2 && !g_bHeavyLocked2[client])
                    {
                        EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunfire.wav", client, SNDCHAN_WEAPON);
                        g_bHeavyLocked2[client] = true;
                        g_bHeavyLocked1[client] = true;
                        g_bHeavyLocked3[client] = false;
                        g_bHeavyWindDown[client] = true;
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunwindup.wav");
                    }
                    else if (state == 3 && !g_bHeavyLocked3[client])
                    {
                        EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunspin.wav", client, SNDCHAN_WEAPON);
                        g_bHeavyLocked3[client] = true;
                        g_bHeavyLocked1[client] = true;
                        g_bHeavyLocked2[client] = false;
                        g_bHeavyWindDown[client] = true;
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunwindup.wav");
                    }
                    else if (state == 0)
                    {
                        if (g_bHeavyWindDown[client])
                        {
                            EmitSoundToAll(")mvm/giant_heavy/giant_heavy_gunwinddown.wav", client, SNDCHAN_WEAPON);
                            g_bHeavyWindDown[client] = false;
                        }
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunspin.wav");
                        StopSound(client, SNDCHAN_WEAPON, ")mvm/giant_heavy/giant_heavy_gunfire.wav");
                        g_bHeavyLocked1[client] = false;
                        g_bHeavyLocked2[client] = false;
                        g_bHeavyLocked3[client] = false;
                    }
                }
            }
            else if (class == TFClass_Pyro)
            {
                int pyroWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
                if (IsValidEntity(pyroWeapon))
                {
                    int state = GetEntProp(pyroWeapon, Prop_Send, "m_iWeaponState");
                    
                    if (state == 1 && !g_bPyroLocked1[client])
                    {
                        EmitSoundToAll("^mvm/giant_pyro/giant_pyro_flamethrower_start.wav", client, SNDCHAN_WEAPON);
                        g_bPyroLocked1[client] = true;
                        g_bPyroLocked2[client] = false;
                        StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_loop.wav");
                    }
                    else if (state == 2 && !g_bPyroLocked2[client])
                    {
                        EmitSoundToAll("^mvm/giant_pyro/giant_pyro_flamethrower_loop.wav", client, SNDCHAN_WEAPON);
                        g_bPyroLocked2[client] = true;
                        g_bPyroLocked1[client] = true;
                        StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_start.wav");
                    }
                    else if (state == 0)
                    {
                        g_bPyroLocked1[client] = false;
                        g_bPyroLocked2[client] = false;
                        StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_loop.wav");
                        StopSound(client, SNDCHAN_WEAPON, "^mvm/giant_pyro/giant_pyro_flamethrower_start.wav");
                    }
                }
            }
        }
    }
	
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
    if (condition == TFCond_Taunting && TF2_GetClientTeam(client) == TFTeam_Blue && IsSentryBusterRobot(client))
    {
        g_iDetonatingPlayer = client;
        CreateTimer(2.0, Timer_ForgetDetonatingPlayer, client);
    }
}

public Action Command_Votebots(int client, int args)
{
    if (g_bBotsEnabled)
    {
        ReplyToCommand(client, "%s Bots are already enabled for this round.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (redbots_manager_mode.IntValue != MANAGER_MODE_MANUAL_BOTS)
    {
        ReplyToCommand(client, "%s This is only allowed in MANAGER_MODE_MANUAL_BOTS.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (g_flNextReadyTime > GetGameTime())
    {
        ReplyToCommand(client, "%s You're going too fast!", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (IsServerFull())
    {
        ReplyToCommand(client, "%s Server is at max capacity.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        ReplyToCommand(client, "%s A vote is already in progress.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (redbots_manager_bot_lineup_mode.IntValue == BOT_LINEUP_MODE_CHOOSE)
    {
        if (!HavePlayersChosenBotTeam())
        {
            if (g_bChoosingBotClasses[client])
            {
                ReplyToCommand(client, "%s You are already choosing the next team lineup.", PLUGIN_PREFIX);
                return Plugin_Handled;
            }
            
            if (GetCountOfPlayersChoosingBotClasses() > 0)
            {
                ReplyToCommand(client, "%s Someone is currently choosing the next team lineup.", PLUGIN_PREFIX);
                return Plugin_Handled;
            }
            
            ReplyToCommand(client, "%s Choose your bot team lineup first! Use command !choosebotteam or !cbt", PLUGIN_PREFIX);
            return Plugin_BadLoad;
        }
    }
    
    switch (TF2_GetClientTeam(client))
    {
        case TFTeam_Red:
        {
#if defined CHANGETEAM_RESTRICTIONS
            float botBanTime = g_flEnableBotsCooldown[client] - GetGameTime();
            
            if (botBanTime > 0.0)
            {
                ReplyToCommand(client, "%s You cannot start the bots at this time.", PLUGIN_PREFIX);
                LogAction(client, -1, "MANAGER_MODE_MANUAL_BOTS: %L tried to start the bots on cooldown. (%f seconds)", client, botBanTime);
                
                return Plugin_Handled;
            }
#endif
            
            if (GetHumanAndDefenderBotCount(TFTeam_Red) < redbots_manager_defender_team_size.IntValue)
            {
                StartBotVote(client);
                return Plugin_Handled;
            }
            else
            {
                ReplyToCommand(client, "%s RED team is full.", PLUGIN_PREFIX);
                return Plugin_Handled;
            }
        }
        default:
        {
            ReplyToCommand(client, "%s You cannot use this command on this team.", PLUGIN_PREFIX);
            return Plugin_Handled;
        }
    }
}

public Action Command_BotPreferences(int client, int args)
{
	DisplayMenu(g_hBotPreferenceMenu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_ShowBotChances(int client, int args)
{
	ShowCurrentBotClassChances(client);
	return Plugin_Handled;
}

public Action Command_ShowNewBotTeamComposition(int client, int args)
{
	if (!CreateDisplayPanelBotTeamComposition(client))
	{
		ReplyToCommand(client, "%s There is no bot lineup currently active.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "Use command !rerollbotclasses to reshuffle the bot class lineup.");
	
	return Plugin_Handled;
}

public Action Command_RerollNewBotTeamComposition(int client, int args)
{
    // Ignorar robôs comprados
    if (g_bBuyIsPurchasedRobot[client])
        return Plugin_Handled;
    
#if !defined TESTING_ONLY
    if (TF2_GetClientTeam(client) != TFTeam_Red)
    {
        ReplyToCommand(client, "%s Your team is not allowed to use this.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
#endif
    
    switch (redbots_manager_bot_lineup_mode.IntValue)
    {
        case BOT_LINEUP_MODE_CHOOSE:
        {
            ReplyToCommand(client, "%s This cannot be used with the current lineup mode.", PLUGIN_PREFIX);
            return Plugin_Handled;
        }
    }
    
    UpdateChosenBotTeamComposition(client);
    CreateDisplayPanelBotTeamComposition(client);
    
    return Plugin_Handled;
}

public Action Command_JoinBluePlayWithBots(int client, int args)
{
	if (redbots_manager_mode.IntValue < MANAGER_MODE_MANUAL_BOTS)
	{
		ReplyToCommand(client, "%s Currently not allowed.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	if (g_bBotsEnabled)
	{
		ReplyToCommand(client, "%s Bots are already enabled for this round.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	if (TF2_GetClientTeam(client) != TFTeam_Blue && TF2_GetClientTeam(client) != TFTeam_Spectator)
	{
    		ReplyToCommand(client, "%s Your team is not allowed to use this.", PLUGIN_PREFIX);
	        return Plugin_Handled;
	}
	
	if (GetHumanAndDefenderBotCount(TFTeam_Red) > 0)
	{
		ReplyToCommand(client, "%s You cannot use this with players on RED team.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	AddRandomDefenderBots(redbots_manager_defender_team_size.IntValue); //TODO: replace me with a smarter team comp
	g_bBotsEnabled = true;
	PrintToChatAll("%s You will play a game with bots.", PLUGIN_PREFIX);
	
	return Plugin_Handled;
}

public Action Command_RequestExtraBot(int client, int args)
{
	if (!g_bBotsEnabled)
	{
		ReplyToCommand(client, "%s Bots aren't enabled.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	if (g_flAddingBotTime > GetGameTime())
	{
		return Plugin_Handled;
	}
	
	if (TF2_GetClientTeam(client) != TFTeam_Red)
	{
		ReplyToCommand(client, "%s Your team is not allowed to use this.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	if (IsServerFull())
	{
		ReplyToCommand(client, "%s It is currently not possible to add any more.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	int defenderLimit = redbots_manager_defender_team_size.IntValue + redbots_manager_extra_bots.IntValue;
	
	if (GetHumanAndDefenderBotCount(TFTeam_Red) >= defenderLimit)
	{
		ReplyToCommand(client, "%s You already have an additional bot.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	g_flAddingBotTime = GetGameTime() + 0.1;
	
	if (args > 0)
	{
		char arg1[TF2_CLASS_MAX_NAME_LENGTH]; GetCmdArg(1, arg1, sizeof(arg1));
		
		if (strcmp(arg1, "random", false) == 0)
		{
			AddRandomDefenderBots(1);
			return Plugin_Handled;
		}
		
		TFClassType class = TF2_GetClassIndexFromString(arg1);
		
		if (class == TFClass_Unknown)
		{
			ReplyToCommand(client, "%s Invalid class specified: %s.", PLUGIN_PREFIX, arg1);
			return Plugin_Handled;
		}
		
		AddDefenderTFBot(1, arg1);
		PrintToChatAll("%s %N requested an additional \"%s\" bot.", PLUGIN_PREFIX, client, arg1);
		
		return Plugin_Handled;
	}
	
	AddBotsBasedOnLineupMode(1);
	PrintToChatAll("%s %N requested an additional bot.", PLUGIN_PREFIX, client);
	
	return Plugin_Handled;
}

public Action Command_ChooseBotClasses(int client, int args)
{
    // Ignorar robôs comprados
    if (g_bBuyIsPurchasedRobot[client])
        return Plugin_Handled;
    
    if (g_bBotsEnabled)
    {
        ReplyToCommand(client, "%s Bots are already enabled.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (redbots_manager_bot_lineup_mode.IntValue != BOT_LINEUP_MODE_CHOOSE)
    {
        ReplyToCommand(client, "%s Not allowed in the current manager lineup mode.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (TF2_GetClientTeam(client) != TFTeam_Red)
    {
        ReplyToCommand(client, "%s Your team is not allowed to use this.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (g_bBotClassesLocked)
    {
        ReplyToCommand(client, "%s Someone has already chosen the lineup for the next game.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (g_bChoosingBotClasses[client])
    {
        ReplyToCommand(client, "%s You are already choosing the next team lineup.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (GetCountOfPlayersChoosingBotClasses() > 0)
    {
        ReplyToCommand(client, "%s Someone is currently choosing the next team lineup.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (GameRules_GetRoundState() != RoundState_BetweenRounds)
    {
        ReplyToCommand(client, "%s This can only be used between waves.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    int redTeamCount = GetHumanAndDefenderBotCount(TFTeam_Red);
    int defenderTeamSize = redbots_manager_defender_team_size.IntValue;
    
    if (redTeamCount >= defenderTeamSize)
    {
        ReplyToCommand(client, "%s You are not solo.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    //Should only be able to call this while solo, so current team count should always be 1
    ShowDefenderBotTeamSetupMenu(client, _, true, defenderTeamSize - redTeamCount);
    PrintToChatAll("%N is choosing the current bot team lineup.", client);
    
    return Plugin_Handled;
}

public Action Command_RedoBotTeamLineup(int client, int args)
{
    // Ignorar robôs comprados
    if (g_bBuyIsPurchasedRobot[client])
        return Plugin_Handled;

    if (!g_bBotsEnabled)
    {
        ReplyToCommand(client, "%s The bots aren't here, dummy.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (!g_bAllowBotTeamRedo)
    {
        ReplyToCommand(client, "%s This is currently not allowed.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (TF2_GetClientTeam(client) != TFTeam_Red)
    {
        ReplyToCommand(client, "%s Your team is not allowed to use this.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (g_bChoosingBotClasses[client])
    {
        ReplyToCommand(client, "%s You are already choosing the next team lineup.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    if (GetCountOfPlayersChoosingBotClasses() > 0)
    {
        ReplyToCommand(client, "%s Someone is currently choosing the next team lineup.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }
    
    switch (redbots_manager_bot_lineup_mode.IntValue)
    {
        case BOT_LINEUP_MODE_RANDOM:
        {
            g_bBotsEnabled = false;
            RemoveAllDefenderBots("DB redo bots");
            g_bBotClassesLocked = false;
            UpdateChosenBotTeamComposition();
        }
        case BOT_LINEUP_MODE_PREFERENCE:
        {
            g_bBotsEnabled = false;
            RemoveAllDefenderBots("DB redo bots");
            g_bBotClassesLocked = false;
            UpdateChosenBotTeamComposition();
        }
        case BOT_LINEUP_MODE_CHOOSE:
        {
            g_bBotsEnabled = false;
            RemoveAllDefenderBots("DB redo bots");
            FreeChosenBotTeam(false);
            Command_ChooseBotClasses(client, 0); //Lazy
        }
        case BOT_LINEUP_MODE_PREFERENCE_CHOOSE:
        {
            g_bBotsEnabled = false;
            RemoveAllDefenderBots("DB redo bots");
            g_bBotClassesLocked = false;
            UpdateChosenBotTeamComposition();
        }
    }
    
    //Solo players are always allowed to repick their bot lineup
    g_bAllowBotTeamRedo = GetTeamHumanClientCount(TFTeam_Red) == 1;
    
    PrintToChatAll("%s %N has decided to repick the bot team lineup.", PLUGIN_PREFIX, client);
    LogAction(client, -1, "%L triggered defender bot redo", client);
    
    return Plugin_Handled;
}

#if defined TESTING_ONLY
public Action Command_BotsReadyNow(int client, int args)
{
	/* for (int i = 1; i <= MaxClients; i++)
		if (g_bIsDefenderBot[i] && !IsPlayerReady(i))
			FakeClientCommand(i, "tournament_player_readystate 1"); */
	
	int target = GetClientAimTarget(client);
	SpawnSapper(client, target);
	
	return Plugin_Handled;
}
#endif

public Action Command_AddBots(int client, int args)
{
	if (args > 0)
	{
		char arg1[3]; GetCmdArg(1, arg1, sizeof(arg1));
		int amount = StringToInt(arg1);
		AddBotsBasedOnLineupMode(amount, false);
		
		return Plugin_Handled;
	}
	
	CreateDisplayMenuAddDefenderBots(client);
	return Plugin_Handled;
}

public Action Command_RemoveAllBots(int client, int args)
{
    if (args > 0)
    {
        char arg1[3]; GetCmdArg(1, arg1, sizeof(arg1));
        if (StringToInt(arg1) == 1)
            ManageDefenderBots(false);
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i])
        {
            CleanupDefenderBotData(i);
            KickClient(i, "Admin request");
        }
    }
    
    ShowActivity2(client, "[SM] ", "Purged all bots.");
    return Plugin_Handled;
}

public Action Command_StopManagingBots(int client, int args)
{
	ManageDefenderBots(false);
	ReplyToCommand(client, "Stopped manaing bots.");
	
	return Plugin_Handled;
}

public Action Command_ViewBotUpgrades(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_view_bot_upgrades <#userid|name> <slot>");
		return Plugin_Handled;
	}
	
	char arg[65]; GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int slot = -1;
	
	if (args >= 2)
	{
		char arg2[3]; GetCmdArg(2, arg2, sizeof(arg2));
		
		slot = StringToInt(arg2);
	}
	
	for (int i = 0; i < target_count; i++)
		ShowPlayerUpgrades(client, target_list[i], slot);
	
	return Plugin_Handled;
}

public Action Command_ForcePlayerPreference(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_db_use_pref_of_player <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[4]; GetCmdArg(1, arg, sizeof(arg));
	
	//TODO: this is a terrible mockup, please change this
	//We only want one target at a time here
	if (!strcmp(arg, "@me"))
	{
		g_iPlayerForcedPref = client;
		return Plugin_Handled;
	}
	
	//TODO: for admin to force use someone else's instead
	
	return Plugin_Handled;
}

public void ConVarChanged_ManagerMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int mode = StringToInt(newValue);
	
	//TODO: really only here for legacy reasons
	//Catch all cases of everything!
}

public void ConVarChanged_BotLineupMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int mode = StringToInt(newValue);
	
	switch (mode)
	{
		case BOT_LINEUP_MODE_RANDOM:
		{
			UpdateChosenBotTeamComposition();
		}
		case BOT_LINEUP_MODE_PREFERENCE:
		{
			UpdateChosenBotTeamComposition();
		}
		case BOT_LINEUP_MODE_CHOOSE:
		{
			FreeChosenBotTeam(true);
		}
		case BOT_LINEUP_MODE_PREFERENCE_CHOOSE:
		{
			FreeChosenBotTeam(true);
			UpdateChosenBotTeamComposition();
		}
	}
}

public Action Listener_TournamentPlayerReadystate(int client, const char[] command, int argc)
{
    if (g_bIsDefenderBot[client])
        return Plugin_Continue;
    
    if (g_bBuyIsPurchasedRobot[client])
        return Plugin_Handled;
    
    switch (redbots_manager_mode.IntValue)
    {
        case MANAGER_MODE_MANUAL_BOTS:
        {
            if (TF2_GetClientTeam(client) != TFTeam_Red)
                return Plugin_Continue;
            
            if (GetDefenderBotCount(TFTeam_Red) > 0)
                return Plugin_Continue;
            
            char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));
            int value = StringToInt(arg1);
            
            if (value < 1)
                return Plugin_Continue;
            
            if (IsPlayerReady(client))
                return Plugin_Continue;
            
            if (redbots_manager_min_players.IntValue != -1)
            {
                eMissionDifficulty difficulty = GetMissionDifficulty();
                int defenderTeamSize = redbots_manager_defender_team_size.IntValue;
                int minPlayers = redbots_manager_min_players.IntValue;
                int trueMinPlayers;
                
                switch (difficulty)
                {
                    case MISSION_NORMAL:
                    {
                        trueMinPlayers = minPlayers > defenderTeamSize ? defenderTeamSize : minPlayers;
                        
                        if (GetHumanAndDefenderBotCount(TFTeam_Red) < trueMinPlayers)
                        {
                            PrintToChat(client, "%s More players are required.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                    }
                    case MISSION_INTERMEDIATE:
                    {
                        trueMinPlayers = minPlayers + 1 > defenderTeamSize ? defenderTeamSize : minPlayers + 1;
                        
                        if (GetHumanAndDefenderBotCount(TFTeam_Red) < trueMinPlayers)
                        {
                            PrintToChat(client, "%s More players are required.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                    }
                    case MISSION_ADVANCED:
                    {
                        trueMinPlayers = minPlayers + 2 > defenderTeamSize ? defenderTeamSize : minPlayers + 2;
                        
                        if (GetHumanAndDefenderBotCount(TFTeam_Red) < trueMinPlayers)
                        {
                            PrintToChat(client, "%s More players are required.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                    }
                    case MISSION_EXPERT:
                    {
                        trueMinPlayers = minPlayers + 3 > defenderTeamSize ? defenderTeamSize : minPlayers + 3;
                        
                        if (GetHumanAndDefenderBotCount(TFTeam_Red) < trueMinPlayers)
                        {
                            PrintToChat(client, "%s More players are required.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                    }
                    case MISSION_NIGHTMARE:
                    {
                        trueMinPlayers = minPlayers + 4 > defenderTeamSize ? defenderTeamSize : minPlayers + 4;
                        
                        if (GetHumanAndDefenderBotCount(TFTeam_Red) < trueMinPlayers)
                        {
                            PrintToChat(client, "%s More players are required.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                    }
                    default:	LogError("Listener_Readystate: Unknown difficulty returned!");
                }
            }
        }
        case MANAGER_MODE_READY_BOTS:
        {
            if (TF2_GetClientTeam(client) != TFTeam_Red)
                return Plugin_Continue;
            
            if (GetDefenderBotCount(TFTeam_Red) > 0)
                return Plugin_Continue;
            
            if (!ShouldProcessCommand(client))
                return Plugin_Handled;
            
            if (g_bBotsEnabled)
            {
                return Plugin_Continue;
            }
            else
            {
                if (g_flNextReadyTime > GetGameTime())
                {
                    PrintToChat(client, "%s You're going too fast!", PLUGIN_PREFIX);
                    
                    return Plugin_Handled;
                }
                
#if defined CHANGETEAM_RESTRICTIONS
                float botBanTime = g_flEnableBotsCooldown[client] - GetGameTime();
                
                if (botBanTime > 0.0)
                {
                    ReplyToCommand(client, "%s You cannot start the bots at this time.", PLUGIN_PREFIX);
                    LogAction(client, -1, "MANAGER_MODE_READY_BOTS: %L tried to start the bots on cooldown. (%f seconds)", client, botBanTime);
                    
                    return Plugin_Handled;
                }
#endif
                
                if (redbots_manager_bot_lineup_mode.IntValue == BOT_LINEUP_MODE_CHOOSE)
                {
                    if (!HavePlayersChosenBotTeam())
                    {
                        if (GetCountOfPlayersChoosingBotClasses() > 0)
                        {
                            PrintToChat(client, "%s Someone is currently choosing the next team lineup.", PLUGIN_PREFIX);
                            return Plugin_Handled;
                        }
                        
                        PrintToChat(client, "%s Choose your bot team lineup first! Use command !choosebotteam/!cbt", PLUGIN_PREFIX);
                        return Plugin_BadLoad;
                    }
                }
                
                if (m_flLastReadyInputTime[client] <= GetGameTime())
                {
                    m_flLastReadyInputTime[client] = GetGameTime() + 3.0;
                    PrintToChat(client, "%s Press ready again to start the bots.", PLUGIN_PREFIX);
                    
                    return Plugin_Handled;
                }
                else
                {
                    ManageDefenderBots(true);
                    g_iUIDBotSummoner = GetClientUserId(client);
                    
                    return Plugin_Handled;
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action SoundHook_General(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (channel == SNDCHAN_VOICE && volume > 0.0 && BaseEntity_IsPlayer(entity))
	{
		if (StrContains(sample, "spy_mvm_LaughShort", false) != -1)
		{
			if (TF2_IsPlayerInCondition(entity, TFCond_Disguised) && !TF2_IsStealthed(entity))
			{
				/* Robots have robotic voices even when disguised so any
				defender bot that can see him right now will call him out */
				for (int i = 1; i <= MaxClients; i++)
				{
					if (i == entity)
						continue;
					
					if (!IsClientInGame(i))
						continue;
					
					if (g_bIsDefenderBot[i] == false)
						continue;
					
					if (GetClientTeam(entity) == GetClientTeam(i))
						continue;
					
					if (GetVectorDistance(GetAbsOrigin(i), WorldSpaceCenter(entity)) > redbots_manager_bot_hear_spy_range.FloatValue)
						continue;
					
					if (IsLineOfFireClearEntity(i, GetEyePosition(i), entity))
					{
						DataPack pack;
						CreateDataTimer(redbots_manager_bot_notice_spy_time.FloatValue, Timer_RealizeSpy, pack, TIMER_FLAG_NO_MAPCHANGE);
						pack.WriteCell(GetClientUserId(i));
						pack.WriteCell(GetClientUserId(entity));
						pack.Reset();
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_CheckBotImbalance(Handle timer)
{
    if (!g_bBotsEnabled)
        return Plugin_Stop;

    switch (redbots_manager_mode.IntValue)
    {
        case MANAGER_MODE_MANUAL_BOTS, MANAGER_MODE_READY_BOTS:
        {
            if (GameRules_GetRoundState() != RoundState_BetweenRounds && GameRules_GetRoundState() != RoundState_RoundRunning)
                return Plugin_Stop;
            
            int defenderCount = GetHumanAndDefenderBotCount(TFTeam_Red);
            
            if (defenderCount < redbots_manager_defender_team_size.IntValue)
            {
                int amount = redbots_manager_defender_team_size.IntValue - defenderCount;
                AddBotsBasedOnLineupMode(amount);
            }
        }
        case MANAGER_MODE_AUTO_BOTS:
        {
            if (GameRules_GetRoundState() != RoundState_RoundRunning)
                return Plugin_Stop;
            
            int defenderCount = GetHumanAndDefenderBotCount(TFTeam_Red);
            
            if (defenderCount < redbots_manager_defender_team_size.IntValue)
            {
                int amount = redbots_manager_defender_team_size.IntValue - defenderCount;
                AddBotsBasedOnLineupMode(amount);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_ForgetDetonatingPlayer(Handle timer, any data)
{
	//They should have detonated by now
	
	//Another player might have started detonating
	//Don't forget the newest one so soon
	if (g_iDetonatingPlayer == data)
		g_iDetonatingPlayer = -1;
	
	return Plugin_Stop;
}

public void Timer_ReadyPlayer(Handle timer, int data)
{
	if (!IsClientInGame(data))
		return;
	
	SetPlayerReady(data, true);
}

public void Timer_RealizeSpy(Handle timer, DataPack pack)
{
	int client = GetClientOfUserId(pack.ReadCell());
	
	if (client == 0)
		return;
	
	int threat = GetClientOfUserId(pack.ReadCell());
	
	if (threat == 0)
		return;
	
	TFBot_NoticeThreat(client, threat);
}

public void DefenderBot_TouchPost(int entity, int other)
{
	//Call out enemy spies upon contact
	if (BaseEntity_IsPlayer(other) && GetClientTeam(other) != GetClientTeam(entity) && TF2_IsPlayerInCondition(other, TFCond_Disguised))
	{
#if defined TFBOT_CUSTOM_SPY_CONTACT
		DataPack pack;
		CreateDataTimer(redbots_manager_bot_notice_spy_time.FloatValue, Timer_RealizeSpy, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(GetClientUserId(entity));
		pack.WriteCell(GetClientUserId(other));
		pack.Reset();
#else
		TFBot_NoticeThreat(entity, other);
#endif
	}
}

void FindGameConsoleVariables()
{
	nb_blind = FindConVar("nb_blind");
	tf_bot_path_lookahead_range = FindConVar("tf_bot_path_lookahead_range");
	tf_bot_health_critical_ratio = FindConVar("tf_bot_health_critical_ratio");
	tf_bot_health_ok_ratio = FindConVar("tf_bot_health_ok_ratio");
	tf_bot_ammo_search_range = FindConVar("tf_bot_ammo_search_range");
	tf_bot_health_search_far_range = FindConVar("tf_bot_health_search_far_range");
	tf_bot_health_search_near_range = FindConVar("tf_bot_health_search_near_range");
	tf_bot_suicide_bomb_range = FindConVar("tf_bot_suicide_bomb_range");
}

bool FakeClientCommandThrottled(int client, const char[] command)
{
	if (m_flLastCommandTime[client] > GetGameTime())
		return false;
	
	FakeClientCommand(client, command);
	
	m_flLastCommandTime[client] = GetGameTime() + 0.4;
	
	return true;
}

void CleanupDefenderBotData(int client)
{
    BuyRobot_RemoveWearables(client);
    g_bIsDefenderBot[client] = false;
    g_bIsBeingRevived[client] = false;
    g_bHasUpgraded[client] = false;
    g_bHasBoughtUpgrades[client] = false;
    g_iDefenderBotHatIndex[client] = 0;
    g_iBuybackNumber[client] = 0;
    g_iBuyUpgradesNumber[client] = 0;
    g_iBotEntranceSpot[client] = -1;
    g_bChoosingBotClasses[client] = false;
    g_arrExtraButtons[client].Reset();
    m_flDeadRethinkTime[client] = 0.0;
    ResetLoadouts(client);
    ResetNextBot(client);
}

void MakePlayerDance(int client)
{
	if (IsPlayerAlive(client))
	{
		//TODO: tauntem
	}
}

void ShowPlayerUpgrades(int client, int target, int slot)
{
	Address pAttr;
	float value;
	int attribIndexes[MAX_RUNTIME_ATTRIBUTES];
	
	switch (slot)
	{
		case -1: //Player
		{
			PrintToChat(client, "UPGRADES FOR %N", target);
			
			int count = TF2Attrib_ListDefIndices(target, attribIndexes, sizeof(attribIndexes));
			
			for (int i = 0; i < count; i++)
			{
				pAttr = TF2Attrib_GetByDefIndex(target, attribIndexes[i]);
				value = TF2Attrib_GetValue(pAttr);
				
				PrintToChat(client, "INDEX %d, VALUE %f", attribIndexes[i], value);
			}
		}
		case 0: //Primary
		{
			int weapon = GetPlayerWeaponSlot(target, TFWeaponSlot_Primary);
			
			if (weapon == -1)
			{
				PrintToChat(client, "%N doesn't have a primary weapon.", target);
				return;
			}
			
			PrintToChat(client, "UPGRADES FOR %N's primary", target);
			
			int count = TF2Attrib_ListDefIndices(weapon, attribIndexes, sizeof(attribIndexes));
			
			for (int i = 0; i < count; i++)
			{
				pAttr = TF2Attrib_GetByDefIndex(weapon, attribIndexes[i]);
				value = TF2Attrib_GetValue(pAttr);
				
				PrintToChat(client, "INDEX %d, VALUE %f", attribIndexes[i], value);
			}
		}
		case 1: //Secondary
		{
			int weapon = GetPlayerWeaponSlot(target, TFWeaponSlot_Secondary);
			
			if (weapon == -1)
			{
				PrintToChat(client, "%N doesn't have a secondary weapon.", target);
				return;
			}
			
			PrintToChat(client, "UPGRADES FOR %N's secondary", target);
			
			int count = TF2Attrib_ListDefIndices(weapon, attribIndexes, sizeof(attribIndexes));
			
			for (int i = 0; i < count; i++)
			{
				pAttr = TF2Attrib_GetByDefIndex(weapon, attribIndexes[i]);
				value = TF2Attrib_GetValue(pAttr);
				
				PrintToChat(client, "INDEX %d, VALUE %f", attribIndexes[i], value);
			}
		}
		case 2: //Melee
		{
			int weapon = GetPlayerWeaponSlot(target, TFWeaponSlot_Melee);
			
			if (weapon == -1)
			{
				PrintToChat(client, "%N doesn't have a melee weapon.", target);
				return;
			}
			
			PrintToChat(client, "UPGRADES FOR %N's melee", target);
			
			int count = TF2Attrib_ListDefIndices(weapon, attribIndexes, MAX_RUNTIME_ATTRIBUTES);
			
			for (int i = 0; i < count; i++)
			{
				pAttr = TF2Attrib_GetByDefIndex(weapon, attribIndexes[i]);
				value = TF2Attrib_GetValue(pAttr);
				
				PrintToChat(client, "INDEX %d, VALUE %f", attribIndexes[i], value);
			}
		}
	}
	
	PrintToChat(client, "%N currently has %d credits.", target, TF2_GetCurrency(target));
}

int GetHumanAndDefenderBotCount(TFTeam team)
{
    int count = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (TF2_GetClientTeam(i) == team)
        {
            if (g_bIsDefenderBot[i] || !IsFakeClient(i))
                count++;
        }
    }
    
    return count;
}

int GetDefenderBotCount(TFTeam team)
{
    int count = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (g_bIsDefenderBot[i] && TF2_GetClientTeam(i) == team)
            count++;
    }
    
    return count;
}

int GetCountOfPlayersChoosingBotClasses()
{
    int count = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !g_bBuyIsPurchasedRobot[i] && g_bChoosingBotClasses[i])
            count++;
    }
    
    return count;
}

/* Used to check players last command input
Usually for preventing palyers from sending a command multiple times in a single frame */
bool ShouldProcessCommand(int client)
{
	if (m_flLastCommandTime[client] > GetGameTime())
		return false;
	
	m_flLastCommandTime[client] = GetGameTime() + COMMAND_MAX_RATE;
	return true;
}

void RemoveAllDefenderBots(char[] reason = "", bool bDanceInstead = false)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i])
        {
            CleanupDefenderBotData(i);
            
            if (bDanceInstead)
            {
                MakePlayerDance(i);
                continue;
            }
            
            KickClient(i, reason);
        }
    }
}

static int m_iFindNameTries[MAXPLAYERS + 1];
void SetRandomNameOnBot(int client)
{
	char newName[MAX_NAME_LENGTH]; GetRandomDefenderBotName(newName, sizeof(newName));
	const int maxTries = 10;
	
	if (m_adtBotNames.Length > 0 && DoesAnyPlayerUseThisName(newName) && m_iFindNameTries[client] < maxTries)
	{
		m_iFindNameTries[client]++;
		
		//Someone's already using my name, mock them for it and try again
		PrintToChatAll("%s : %s", newName, g_sPlayerUseMyNameResponse[GetRandomInt(0, sizeof(g_sPlayerUseMyNameResponse) - 1)]);
		SetRandomNameOnBot(client);
		
		return;
	}
	
	m_iFindNameTries[client] = 0;
	SetClientName(client, newName);
}

void GetRandomDefenderBotName(char[] buffer, int maxlen)
{
	if (m_adtBotNames.Length == 0)
	{
		// LogError("GetRandomDefenderBotName: No bot names were ever parsed!");
		strcopy(buffer, maxlen, "You forgot to give me a name!");
		return;
	}
	
	char botName[MAX_NAME_LENGTH]; m_adtBotNames.GetString(GetRandomInt(0, m_adtBotNames.Length - 1), botName, sizeof(botName));
	
	strcopy(buffer, maxlen, botName);
}

void ManageDefenderBots(bool bManage, bool bAddBots = true)
{
	if (bManage)
	{
		if (bAddBots)
			AddBotsFromChosenTeamComposition();
		
		CreateTimer(1.0, Timer_CheckBotImbalance, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		g_bBotsEnabled = true;
		
		PrintToChatAll("%s Bots have been enabled.", PLUGIN_PREFIX);
	}
	else
	{
		g_bBotsEnabled = false;
	}
}

void AddBotsBasedOnLineupMode(int count, bool bAdjustTime = true)
{
    int currentBots = GetDefenderBotCount(TFTeam_Red);
    int maxBots = redbots_manager_defender_team_size.IntValue;
    int availableSlots = maxBots - currentBots;
    
    int actualCount = count;
    if (actualCount > availableSlots)
        actualCount = availableSlots;
    
    if (actualCount <= 0)
        return;
    
    switch (redbots_manager_bot_lineup_mode.IntValue)
    {
        case BOT_LINEUP_MODE_RANDOM:
        {
            AddRandomDefenderBots(actualCount);
        }
        case BOT_LINEUP_MODE_PREFERENCE, BOT_LINEUP_MODE_CHOOSE, BOT_LINEUP_MODE_PREFERENCE_CHOOSE:
        {
            AddBotsBasedOnPreferences(actualCount);
        }
        default:
        {
            ThrowError("Unhandled lineup mode %d", redbots_manager_bot_lineup_mode.IntValue);
        }
    }
    
    if (bAdjustTime)
    {
        float restartRoundTime = GameRules_GetPropFloat("m_flRestartRoundTime");
        
        if (restartRoundTime > 0)
        {
            if (restartRoundTime - GetGameTime() <= BUY_UPGRADES_MAX_TIME)
            {
                GameRules_SetPropFloat("m_flRestartRoundTime", restartRoundTime + BUY_UPGRADES_MAX_TIME);
            }
        }
    }
}

/* Decide what to do when a player decides to change their team
This is to prevent abuse of the system by leaving RED players with unfavorable teams */
void HandleTeamPlayerCountChanged(TFTeam team, int iWhoChanging = -1)
{
    // Ignorar se quem está mudando for um robô comprado
    if (iWhoChanging > 0 && iWhoChanging <= MaxClients && g_bBuyIsPurchasedRobot[iWhoChanging])
        return;
    
    if (GameRules_GetRoundState() != RoundState_BetweenRounds)
        return;
    
    if (redbots_manager_mode.IntValue == MANAGER_MODE_MANUAL_BOTS)
    {
        if (iWhoChanging > 0 && iWhoChanging == GetClientOfUserId(g_iUIDBotSummoner) && IsVoteInProgress())
        {
            //He started the bot vote then changed teams, cancel it
            CancelVote();
        }
    }
    switch (redbots_manager_bot_lineup_mode.IntValue)
    {
        case BOT_LINEUP_MODE_CHOOSE, BOT_LINEUP_MODE_PREFERENCE_CHOOSE:
        {
            //Allow the classes to be picked again, but don't clear current list
            g_bBotClassesLocked = false;
            PrintToChatTeam(team, "%s You can repick your bot team lineup.", PLUGIN_PREFIX);
        }
    }
    
    if (!g_bBotsEnabled)
        return;
    
    if (iWhoChanging > 0 && GetClientOfUserId(g_iUIDBotSummoner) == iWhoChanging)
    {
        //The summoner changed teams, allow RED team to repick their bots
        g_bAllowBotTeamRedo = true;
        PrintToChatTeam(team, "%s Use command !redobots to repick your bot team lineup.", PLUGIN_PREFIX);
    }
    
    int iWhoToUnready = -1;
    int iReadyCount = 0;
    int iMemberCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        //Whoever is changing teams won't count to the team count
        if (i == iWhoChanging)
            continue;
        
        if (!IsClientInGame(i))
            continue;
        
        // Ignorar robôs comprados na contagem
        if (g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (TF2_GetClientTeam(i) != team)
            continue;
        
        if (IsPlayerReady(i))
        {
            if (iWhoToUnready != -1)
            {
                if (g_bIsDefenderBot[iWhoToUnready])
                {
                    //Always prefer to unready human players first
                    if (!g_bIsDefenderBot[i])
                        iWhoToUnready = i;
                }
            }
            else
            {
                iWhoToUnready = i;
            }
            
            iReadyCount++;
        }
        
        iMemberCount++;
    }
    
    //Are all remaining members of the team ready?
    if (iReadyCount == iMemberCount)
    {
        //Unready one member to prevent starting the game and allow another bot to enter
        SetPlayerReady(iWhoToUnready, false);
        
        if (g_bIsDefenderBot[iWhoToUnready] && !g_bBuyIsPurchasedRobot[iWhoToUnready])
        {
            //Ready up the bot again after some time
            CreateTimer(0.2, Timer_ReadyPlayer, iWhoToUnready, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

void AddDefenderTFBot(int count, char[] class, char[] team = "red", char[] difficulty = "expert", bool quotaManaged = false)
{
	//Send command as many times as needed because custom names aren't supported when adding multiple
	for (int i = 0; i < count; i++)
		ServerCommand("tf_bot_add %d %s %s %s %s %s", 1, class, team, difficulty, quotaManaged ? "" : "noquota", TFBOT_IDENTITY_NAME);
}

void AddRandomDefenderBots(int amount)
{
	PrintToChatAll("%s Adding %d bot(s)...", PLUGIN_PREFIX, amount);
	
	for (int i = 1; i <= amount; i++)
		AddDefenderTFBot(1, g_sRawPlayerClassNames[GetRandomInt(1, 9)], "red", "expert");
}

void AddBotsWithPresetTeamComp(int count = 6, int teamType = 0)
{
	int total = 0;
	
	for (int i = 0; i < count; i++)
	{
		//We're done here
		if (total >= count)
			break;
		
		//We asked for more than the array size, cycle back from the beginning
		if (i >= sizeof(g_sBotTeamCompositions[]))
			i = 0;
		
		AddDefenderTFBot(1, g_sBotTeamCompositions[teamType][i], "red", "expert");
		total++;
	}
}

void SetupSniperSpotHints()
{
	if (g_arrMapConfig.adtSniperSpot.Length > 0)
	{
		for (int i = 0; i < g_arrMapConfig.adtSniperSpot.Length; i++)
		{
			float vec[3]; g_arrMapConfig.adtSniperSpot.GetArray(i, vec);
			int ent = CreateEntityByName("func_tfbot_hint");
			
			if (ent != -1)
			{
				DispatchKeyValueVector(ent, "origin", vec);
				// DispatchKeyValue(ent, "targetname", "db_sniper");
				DispatchKeyValue(ent, "team", "2");
				DispatchKeyValue(ent, "hint", "0");
				DispatchSpawn(ent);
			}
		}
	}
	else
	{
		//No custom hints specified, so we'll just override any existing ones
		int ent = -1;
		
		while ((ent = FindEntityByClassname(ent, "func_tfbot_hint")) != -1)
			DispatchKeyValue(ent, "team", "0");
		
		LogError("SetupSniperSpotHints: No hints specified by configuration, overriding other hint entities!");
	}
}

bool HavePlayersChosenBotTeam()
{
    if (GetCountOfPlayersChoosingBotClasses() > 0)
        return false;
    
    int humanCount = 0;
    int defenderBotCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (TF2_GetClientTeam(i) == TFTeam_Red)
        {
            if (IsFakeClient(i) && g_bIsDefenderBot[i])
                defenderBotCount++;
            else if (!IsFakeClient(i))
                humanCount++;
        }
    }
    
    int currentTotal = humanCount + defenderBotCount;
    
    if (currentTotal >= redbots_manager_defender_team_size.IntValue)
        return true;
    
    return g_adtChosenBotClasses.Length > 0;
}

void FreeChosenBotTeam(bool bAnnounce = false)
{
	g_adtChosenBotClasses.Clear();
	g_bBotClassesLocked = false;
	
	if (bAnnounce)
		PrintToChatAll("%s Bot team lineup can now be changed.", PLUGIN_PREFIX);
}

void UpdateChosenBotTeamComposition(int caller = -1)
{
    if (caller > 0 && caller <= MaxClients && g_bBuyIsPurchasedRobot[caller])
        return;
    
    if (g_bBotClassesLocked)
    {
        if (caller != -1)
            PrintToChat(caller, "%s Bot team lineup is locked for the next game.");
        
        return;
    }
    
    if (GetCountOfPlayersChoosingBotClasses() > 0)
    {
        if (caller != -1)
            PrintToChat(caller, "%s Someone is currently choosing the bot team lineup.");
        
        return;
    }
    
    g_adtChosenBotClasses.Clear();
    
    int humanCount = 0;
    int defenderBotCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || g_bBuyIsPurchasedRobot[i])
            continue;
        
        if (TF2_GetClientTeam(i) == TFTeam_Red)
        {
            if (IsFakeClient(i) && g_bIsDefenderBot[i])
                defenderBotCount++;
            else if (!IsFakeClient(i))
                humanCount++;
        }
    }
    
    int currentTotal = humanCount + defenderBotCount;
    int newBotsToAdd = redbots_manager_defender_team_size.IntValue - currentTotal;
    
    if (newBotsToAdd < 1)
        return;
    
    switch (redbots_manager_bot_lineup_mode.IntValue)
    {
        case BOT_LINEUP_MODE_RANDOM:
        {
            for (int i = 1; i <= newBotsToAdd; i++)
                g_adtChosenBotClasses.PushString(g_sRawPlayerClassNames[GetRandomInt(TFClass_Scout, TFClass_Engineer)]);
        }
        case BOT_LINEUP_MODE_PREFERENCE, BOT_LINEUP_MODE_PREFERENCE_CHOOSE:
        {
            ArrayList adtClassPref = new ArrayList(TF2_CLASS_MAX_NAME_LENGTH);
            
            CollectPlayerBotClassPreferences(adtClassPref);
            
            if (adtClassPref.Length > 0)
            {
                for (int i = 1; i <= newBotsToAdd; i++)
                {
                    char class[TF2_CLASS_MAX_NAME_LENGTH]; adtClassPref.GetString(GetRandomInt(0, adtClassPref.Length - 1), class, sizeof(class));
                    
                    g_adtChosenBotClasses.PushString(class);
                }
            }
            else
            {
                for (int i = 1; i <= newBotsToAdd; i++)
                    g_adtChosenBotClasses.PushString(g_sRawPlayerClassNames[GetRandomInt(TFClass_Scout, TFClass_Engineer)]);
            }
            
            delete adtClassPref;
        }
        default:
        {
            ThrowError("Unknown lineup mode %d", redbots_manager_bot_lineup_mode.IntValue);
        }
    }
    
    if (caller != -1 && !g_bBuyIsPurchasedRobot[caller])
        PrintToChatAll("%s %N changed the bot team lineup", PLUGIN_PREFIX, caller);
    else
        PrintToChatAll("%s Bot lineup changed", PLUGIN_PREFIX);
}

void AddBotsFromChosenTeamComposition()
{
    char class[TF2_CLASS_MAX_NAME_LENGTH];
    int currentBots = GetDefenderBotCount(TFTeam_Red);
    int maxBots = redbots_manager_defender_team_size.IntValue;
    int availableSlots = maxBots - currentBots;
    int botsToAdd = g_adtChosenBotClasses.Length;
    
    if (botsToAdd > availableSlots)
        botsToAdd = availableSlots;
    
    for (int i = 0; i < botsToAdd; i++)
    {
        g_adtChosenBotClasses.GetString(i, class, sizeof(class));
        AddDefenderTFBot(1, class, "red", "expert");
    }
    
    g_bBotClassesLocked = false;
    
    PrintToChatAll("%s Added %d bot(s).", PLUGIN_PREFIX, botsToAdd);
}

eMissionDifficulty GetMissionDifficulty()
{
	int rsrc = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
	
	if (rsrc == -1)
	{
		LogError("GetMissionDifficulty: Could not find entity tf_objective_resource!");
		return MISSION_UNKNOWN;
	}
	
	char missionName[PLATFORM_MAX_PATH]; TF2_GetMvMPopfileName(rsrc, missionName, sizeof(missionName));
	
	//Remove unnecessary
	ReplaceString(missionName, sizeof(missionName), "scripts/population/", "");
	ReplaceString(missionName, sizeof(missionName), ".pop", "");
	
	eMissionDifficulty type = Config_GetMissionDifficultyFromName(missionName);
	
	//No config file specified a difficulty, search for one ourselves
	if (type == MISSION_UNKNOWN)
	{
		char mapName[PLATFORM_MAX_PATH]; GetCurrentMap(mapName, sizeof(mapName));
		
		//Searching by prefix or suffix
		if (StrEqual(missionName, mapName) || StrContains(missionName, "_norm_", false) != -1)
		{
			//If the mission name is the same as the map's name, it's typically a normal mission
			type = MISSION_NORMAL;
		}
		else if (StrContains(missionName, "_intermediate", false) != -1 || StrContains(missionName, "_int_", false) != -1)
		{
			type = MISSION_INTERMEDIATE;
		}
		else if (StrContains(missionName, "_advanced", false) != -1 || StrContains(missionName, "_adv_", false) != -1)
		{
			type = MISSION_ADVANCED;
		}
		else if (StrContains(missionName, "_expert", false) != -1 || StrContains(missionName, "_exp_", false) != -1)
		{
			type = MISSION_EXPERT;
		}
		else if (StrContains(missionName, "_night_", false) != -1)
		{
			//NOTE: No official mission actually uses this
			type = MISSION_NIGHTMARE;
		}
	}
	
	if (redbots_manager_debug.BoolValue)
		PrintToChatAll("GetMissionDifficulty: Current difficulty is %d", type);
	
	return type;
}

void Config_LoadMap()
{
	g_arrMapConfig.Reset();
	
	char mapName[PLATFORM_MAX_PATH]; GetCurrentMap(mapName, sizeof(mapName));
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "configs/defenderbots/map/%s.cfg", mapName);
	
	KeyValues kv = new KeyValues("MapConfig");
	
	if (!kv.ImportFromFile(filePath))
	{
		CloseHandle(kv);
		LogError("Config_LoadMap: File not found (%s)", filePath);
		return;
	}
	
	if (kv.JumpToKey("SniperSpot"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				float vec[3]; kv.GetVector("origin", vec);
				g_arrMapConfig.adtSniperSpot.PushArray(vec);
			} while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}
	
	CloseHandle(kv);
	
#if defined TESTING_ONLY
	LogMessage("Config_LoadMap: Found %d locations for SniperSpot", g_arrMapConfig.adtSniperSpot.Length);
#endif
}

void Config_LoadBotNames()
{
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "configs/defenderbots/bot_names.txt");
	File hConfigFile = OpenFile(filePath, "r");
	char currentLine[MAX_NAME_LENGTH + 1];
	
	if (hConfigFile == null)
	{
		LogError("Config_LoadBotNames: Could not locate file %s!", filePath);
		return;
	}
	
	m_adtBotNames.Clear();
	
	while (ReadFileLine(hConfigFile, currentLine, sizeof(currentLine)))
	{
		TrimString(currentLine);
		
		if (strlen(currentLine) > 0)
			m_adtBotNames.PushString(currentLine);
	}
	
	delete hConfigFile;
}

eMissionDifficulty Config_GetMissionDifficultyFromName(char[] missionName)
{
	char filePath[PLATFORM_MAX_PATH];
	
	for (eMissionDifficulty i = MISSION_NORMAL; i < MISSION_MAX_COUNT; i++)
	{
		BuildPath(Path_SM, filePath, sizeof(filePath), g_sMissionDifficultyFilePaths[i]);
		
		File hOpenedFile = OpenFile(filePath, "r");
		
		if (hOpenedFile == null)
		{
			if (redbots_manager_debug.BoolValue)
				LogMessage("Config_GetMissionDifficultyFromName: Could not locate file %s. Skipping...", filePath);
			
			continue;
		}
		
		char currentLine[PLATFORM_MAX_PATH];
		
		while (ReadFileLine(hOpenedFile, currentLine, sizeof(currentLine)))
		{
			TrimString(currentLine);
			
			if (StrEqual(currentLine, missionName))
			{
				//Current line matches with the mission name in the file, this is it
				delete hOpenedFile;
				return i;
			}
		}
		
		delete hOpenedFile;
	}
	
	return MISSION_UNKNOWN;
}


public Action Command_AddSniperHit(int client, int args)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Handled;
    
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "configs/defenderbots/map/%s.cfg", mapName);
    
    char folderPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/map");
    if (!DirExists(folderPath))
    {
        CreateDirectory(folderPath, 511);
    }
    
    KeyValues kv = new KeyValues("MapConfig");
    
    if (FileExists(filePath))
    {
        kv.ImportFromFile(filePath);
    }
    
    if (!kv.JumpToKey("SniperSpot", true))
    {
        delete kv;
        PrintToChat(client, "\x07FF4500[Error]\x01 Could not create SniperSpot section");
        return Plugin_Handled;
    }
    
    char key[8];
    int nextId = 1;
    
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            nextId++;
        } while (kv.GotoNextKey(false));
        
        kv.GoBack();
    }
    
    kv.GoBack();
    kv.JumpToKey("SniperSpot", true);
    IntToString(nextId, key, sizeof(key));
    kv.JumpToKey(key, true);
    kv.SetVector("origin", pos);
    
    kv.Rewind();
    kv.ExportToFile(filePath);
    
    delete kv;
    
    PrintToChat(client, "\x0732CD32[Sniper Spot]\x01 Point #%d added at (%.1f %.1f %.1f)", 
                nextId, pos[0], pos[1], pos[2]);
    
    return Plugin_Handled;
}

public Action Command_AddNestSpot(int client, int args)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    InitializeEngineerSpotSystem();
    AddEngineerSpot(pos);
    
    int count = GetEngineerSpotCount();
    PrintToChat(client, "\x0732CD32[Engineer Nest]\x01 Spot #%d added at (%.1f %.1f %.1f)", 
                count - 1, pos[0], pos[1], pos[2]);
    
    return Plugin_Handled;
}

public Action Command_ListNestSpots(int client, int args)
{
    InitializeEngineerSpotSystem();
    
    int count = GetEngineerSpotCount();
    if (count == 0)
    {
        PrintToChat(client, "\x07FF4500[Engineer Nest]\x01 No spots defined for this map");
        return Plugin_Handled;
    }
    
    PrintToChat(client, "\x0732CD32[Engineer Nest]\x01 Spots (%d):", count);
    
    float pos[3];
    for (int i = 0; i < count; i++)
    {
        GetEngineerSpotPosition(i, pos);
        PrintToChat(client, " #%d: %.1f %.1f %.1f", i, pos[0], pos[1], pos[2]);
    }
    
    return Plugin_Handled;
}

void ShowAllSpots()
{
    int sniperCount = g_arrMapConfig.adtSniperSpot.Length;
    int engCount = GetEngineerSpotCount();
    int teleCount = g_hTeleporterEntranceSpots.Length;
    
    float pos[3];
    
    // Sniper Spots - Vermelho
    for (int i = 0; i < sniperCount; i++)
    {
        g_arrMapConfig.adtSniperSpot.GetArray(i, pos);
        pos[2] += 20.0;
        
        int red[4] = {255, 0, 0, 255};
        
        TE_SetupBeamRingPoint(pos, 30.0, 50.0, PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              0, 15, 0.5, 10.0, 0.0, red, 10, 0);
        TE_SendToAll();
        
        TE_SetupGlowSprite(pos, PrecacheModel("sprites/glow01.vmt"), 0.5, 1.0, 255);
        TE_SendToAll();
    }
    
    // Engineer Nest Spots - Amarelo
    for (int i = 0; i < engCount; i++)
    {
        GetEngineerSpotPosition(i, pos);
        pos[2] += 20.0;
        
        int yellow[4] = {255, 255, 0, 255};
        
        TE_SetupBeamRingPoint(pos, 30.0, 50.0, PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              0, 15, 0.5, 10.0, 0.0, yellow, 10, 0);
        TE_SendToAll();
        
        TE_SetupGlowSprite(pos, PrecacheModel("sprites/glow01.vmt"), 0.5, 1.0, 255);
        TE_SendToAll();
    }
    
    // Teleporter Entrance Spots - VERDE
    for (int i = 0; i < teleCount; i++)
    {
        g_hTeleporterEntranceSpots.GetArray(i, pos);
        pos[2] += 20.0;
        
        int green[4] = {0, 255, 0, 255};
        
        TE_SetupBeamRingPoint(pos, 30.0, 50.0, PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              PrecacheModel("materials/sprites/laserbeam.vmt"), 
                              0, 15, 0.5, 10.0, 0.0, green, 10, 0);
        TE_SendToAll();
        
        TE_SetupGlowSprite(pos, PrecacheModel("sprites/glow01.vmt"), 0.5, 1.0, 255);
        TE_SendToAll();
    }
}

public Action Command_SpotsToggle(int client, int args)
{
    if (!CheckCommandAccess(client, "sm_spots", ADMFLAG_GENERIC))
    {
        ReplyToCommand(client, "You don't have access to this command");
        return Plugin_Handled;
    }
    
    if (g_bSpotsGlobalVisible)
    {
        g_bSpotsGlobalVisible = false;
        
        if (g_hGlobalSpotTimer != INVALID_HANDLE)
        {
            KillTimer(g_hGlobalSpotTimer);
            g_hGlobalSpotTimer = INVALID_HANDLE;
        }
        
        ReplyToCommand(client, "\x0732CD32[Spots]\x01 Visualization DISABLED");
    }
    else
    {
        g_bSpotsGlobalVisible = true;
        
        if (g_hGlobalSpotTimer != INVALID_HANDLE)
            KillTimer(g_hGlobalSpotTimer);
        
        g_hGlobalSpotTimer = CreateTimer(0.5, Timer_GlobalUpdateSpots_, _, TIMER_REPEAT);
        
        ReplyToCommand(client, "\x0732CD32[Spots]\x01 Visualization ENABLED");
        ReplyToCommand(client, "\x0732CD32[Spots]\x01 \x07FF0000Red = Sniper\x01 | \x07FFFF00Yellow = Engineer\x01 | \x0700FF00Green = Teleporter");
    }
    
    return Plugin_Handled;
}

public Action Timer_GlobalUpdateSpots_(Handle timer)
{
    if (!g_bSpotsGlobalVisible)
        return Plugin_Stop;
    
    ShowAllSpots();
    return Plugin_Continue;
}

public Action Command_SpotInfo(int client, int args)
{
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    float endPos[3];
    Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SHOT, RayType_Infinite, TraceFilterNoPlayers, client);
    
    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(endPos, trace);
    }
    delete trace;
    
    int sniperCount = g_arrMapConfig.adtSniperSpot.Length;
    int engCount = GetEngineerSpotCount();
    int teleCount = g_hTeleporterEntranceSpots.Length;
    
    float spotPos[3];
    float bestDist = 100.0;
    int bestIndex = -1;
    int spotType = 0; // 0 = none, 1 = sniper, 2 = engineer, 3 = teleporter
    
    for (int i = 0; i < sniperCount; i++)
    {
        g_arrMapConfig.adtSniperSpot.GetArray(i, spotPos);
        float dist = GetVectorDistance(endPos, spotPos);
        if (dist < bestDist)
        {
            bestDist = dist;
            bestIndex = i;
            spotType = 1;
        }
    }
    
    for (int i = 0; i < engCount; i++)
    {
        GetEngineerSpotPosition(i, spotPos);
        float dist = GetVectorDistance(endPos, spotPos);
        if (dist < bestDist)
        {
            bestDist = dist;
            bestIndex = i;
            spotType = 2;
        }
    }
    
    for (int i = 0; i < teleCount; i++)
    {
        g_hTeleporterEntranceSpots.GetArray(i, spotPos);
        float dist = GetVectorDistance(endPos, spotPos);
        if (dist < bestDist)
        {
            bestDist = dist;
            bestIndex = i;
            spotType = 3;
        }
    }
    
    if (bestIndex != -1)
    {
        switch (spotType)
        {
            case 1:
            {
                g_arrMapConfig.adtSniperSpot.GetArray(bestIndex, spotPos);
                PrintToChat(client, "\x0732CD32[SniperSpot]\x01 #%d", bestIndex);
                PrintToChat(client, "Position: %.1f %.1f %.1f", spotPos[0], spotPos[1], spotPos[2]);
            }
            case 2:
            {
                GetEngineerSpotPosition(bestIndex, spotPos);
                PrintToChat(client, "\x0732CD32[EngineerSpot]\x01 #%d", bestIndex);
                PrintToChat(client, "Position: %.1f %.1f %.1f", spotPos[0], spotPos[1], spotPos[2]);
            }
            case 3:
            {
                g_hTeleporterEntranceSpots.GetArray(bestIndex, spotPos);
                PrintToChat(client, "\x0732CD32[TeleporterSpot]\x01 #%d", bestIndex);
                PrintToChat(client, "Position: %.1f %.1f %.1f", spotPos[0], spotPos[1], spotPos[2]);
            }
        }
    }
    else
    {
        PrintToChat(client, "\x07FF4500[Spot Info]\x01 No spot found nearby");
    }
    
    return Plugin_Handled;
}

public bool TraceFilterNoPlayers(int entity, int contentsMask, any data)
{
    return entity != data;
}

void InitializeTeleporterSystem()
{
    if (g_hTeleporterEntranceSpots == null)
    {
        g_hTeleporterEntranceSpots = new ArrayList(3);
    }
    
    LoadTeleporterSpots();
}

void LoadTeleporterSpots()
{
    if (g_hTeleporterEntranceSpots == null)
        g_hTeleporterEntranceSpots = new ArrayList(3);
    
    g_hTeleporterEntranceSpots.Clear();
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    BuildPath(Path_SM, g_sTeleporterConfigFile, sizeof(g_sTeleporterConfigFile), 
              "configs/defenderbots/teleporter/%s.cfg", mapName);
    
    if (!FileExists(g_sTeleporterConfigFile))
    {
        char folderPath[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/teleporter");
        if (!DirExists(folderPath))
            CreateDirectory(folderPath, 511);
        return;
    }
    
    File hFile = OpenFile(g_sTeleporterConfigFile, "r");
    if (hFile == null)
        return;
    
    char line[256];
    float pos[3];
    
    while (!IsEndOfFile(hFile) && ReadFileLine(hFile, line, sizeof(line)))
    {
        TrimString(line);
        
        if (strlen(line) == 0 || line[0] == '#' || line[0] == '/')
            continue;
        
        char parts[3][32];
        int numParts = ExplodeString(line, " ", parts, 3, 32);
        
        if (numParts == 3)
        {
            pos[0] = StringToFloat(parts[0]);
            pos[1] = StringToFloat(parts[1]);
            pos[2] = StringToFloat(parts[2]);
            
            if (pos[0] == 0.0 && pos[1] == 0.0 && pos[2] == 0.0)
                continue;
            
            g_hTeleporterEntranceSpots.PushArray(pos);
        }
    }
    
    delete hFile;
}

void SaveTeleporterSpots()
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ReplaceString(mapName, sizeof(mapName), "maps/", "");
    ReplaceString(mapName, sizeof(mapName), ".bsp", "");
    
    BuildPath(Path_SM, g_sTeleporterConfigFile, sizeof(g_sTeleporterConfigFile), 
              "configs/defenderbots/teleporter/%s.cfg", mapName);
    
    char folderPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, folderPath, sizeof(folderPath), "configs/defenderbots/teleporter");
    if (!DirExists(folderPath))
        CreateDirectory(folderPath, 511);
    
    File hFile = OpenFile(g_sTeleporterConfigFile, "w");
    if (hFile == null)
        return;
    
    hFile.WriteLine("// Teleporter Spots for %s", mapName);
    hFile.WriteLine("// Format: X Y Z");
    hFile.WriteLine("");
    
    float pos[3];
    
    for (int i = 0; i < g_hTeleporterEntranceSpots.Length; i++)
    {
        g_hTeleporterEntranceSpots.GetArray(i, pos);
        if (pos[0] != 0.0 || pos[1] != 0.0 || pos[2] != 0.0)
            hFile.WriteLine("%.2f %.2f %.2f", pos[0], pos[1], pos[2]);
    }
    
    delete hFile;
}

bool ShouldEngineerBuildTeleporter(int client)
{
    if (TF2_GetPlayerClass(client) != TFClass_Engineer)
        return false;
    
    if (g_hTeleporterEntranceSpots == null || g_hTeleporterEntranceSpots.Length == 0)
        return false;
    
    int teleporterEntrance = -1;
    int teleporterExit = -1;
    int ent = -1;
    
    while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") != client)
            continue;
        
        if (TF2_GetObjectMode(ent) == TFObjectMode_Entrance)
            teleporterEntrance = ent;
        else if (TF2_GetObjectMode(ent) == TFObjectMode_Exit)
            teleporterExit = ent;
    }
    
    if (teleporterEntrance == -1)
        return true;
    
    if (teleporterEntrance != -1 && teleporterExit == -1)
        return true;
    
    return false;
}

void GetRandomTeleporterEntranceSpot(float pos[3])
{
    pos[0] = 0.0; pos[1] = 0.0; pos[2] = 0.0;
    
    if (g_hTeleporterEntranceSpots == null || g_hTeleporterEntranceSpots.Length == 0)
        return;
    
    int randomIndex = GetRandomInt(0, g_hTeleporterEntranceSpots.Length - 1);
    g_hTeleporterEntranceSpots.GetArray(randomIndex, pos);
}

public Action Command_AddTeleporterEntrance(int client, int args)
{
    if (!CheckCommandAccess(client, "sm_addteleporter", ADMFLAG_GENERIC))
    {
        ReplyToCommand(client, "You don't have access to this command.");
        return Plugin_Handled;
    }
    
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    if (pos[0] == 0.0 && pos[1] == 0.0 && pos[2] == 0.0)
    {
        ReplyToCommand(client, "\x07FF4500[Teleporter]\x01 Cannot add at 0,0,0. Move to a valid position.");
        return Plugin_Handled;
    }
    
    InitializeTeleporterSystem();
    g_hTeleporterEntranceSpots.PushArray(pos);
    SaveTeleporterSpots();
    
    ReplyToCommand(client, "\x0732CD32[Teleporter]\x01 Entrance #%d added at (%.1f %.1f %.1f)", 
                   g_hTeleporterEntranceSpots.Length - 1, pos[0], pos[1], pos[2]);
    
    return Plugin_Handled;
}

public Action Command_ListTeleporterSpots(int client, int args)
{
    InitializeTeleporterSystem();
    
    int count = g_hTeleporterEntranceSpots.Length;
    
    if (count == 0)
    {
        ReplyToCommand(client, "\x07FF4500[Teleporter]\x01 No teleporter spots defined for this map.");
        return Plugin_Handled;
    }
    
    ReplyToCommand(client, "\x0732CD32[Teleporter]\x01 Teleporter Spots (%d):", count);
    
    float pos[3];
    for (int i = 0; i < count; i++)
    {
        g_hTeleporterEntranceSpots.GetArray(i, pos);
        ReplyToCommand(client, "  #%d: %.1f %.1f %.1f", i, pos[0], pos[1], pos[2]);
    }
    
    return Plugin_Handled;
}

public Action Command_RemoveTeleporterSpot(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "\x07FF4500[Teleporter]\x01 Usage: sm_removeteleporter <id>");
        return Plugin_Handled;
    }
    
    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));
    int id = StringToInt(arg);
    
    if (id < 0 || id >= g_hTeleporterEntranceSpots.Length)
    {
        ReplyToCommand(client, "\x07FF4500[Teleporter]\x01 Invalid ID.");
        return Plugin_Handled;
    }
    
    g_hTeleporterEntranceSpots.Erase(id);
    SaveTeleporterSpots();
    
    ReplyToCommand(client, "\x0732CD32[Teleporter]\x01 Spot #%d removed.", id);
    
    return Plugin_Handled;
}

public Action Command_ClearTeleporterSpots(int client, int args)
{
    InitializeTeleporterSystem();
    g_hTeleporterEntranceSpots.Clear();
    SaveTeleporterSpots();
    
    ReplyToCommand(client, "\x0732CD32[Teleporter]\x01 All teleporter spots cleared.");
    
    return Plugin_Handled;
}

void CommandEngineerMoveNest(int client, int target, bool isAdminMenu = false)
{
    if (!IsPlayerAlive(target))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Your Engineer robot is dead!");
        return;
    }
    
    if (TF2_GetPlayerClass(target) != TFClass_Engineer)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This robot is not an Engineer!");
        return;
    }
    
    float currentTime = GetGameTime();
    if (!isAdminMenu && (currentTime - g_flLastNestMoveTime[client] < NEST_MOVE_COOLDOWN))
    {
        int remaining = RoundToCeil(NEST_MOVE_COOLDOWN - (currentTime - g_flLastNestMoveTime[client]));
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Cooldown! \x07FFD700%d\x01 seconds remaining.", remaining);
        return;
    }
    
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    float sentryPos[3], planeNormal[3];
    Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilterNoPlayers, client);
    
    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(sentryPos, trace);
        TR_GetPlaneNormal(trace, planeNormal);
        
        float distance = GetVectorDistance(eyePos, sentryPos);
        if (distance > 500.0)
        {
            delete trace;
            PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Too far! Max distance is 500 units.");
            return;
        }
    }
    else
    {
        delete trace;
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 No valid build location found!");
        return;
    }
    delete trace;
    
    if (planeNormal[2] < 0.1)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Surface is too steep! Cannot build on walls.");
        return;
    }
    
    CNavArea area = TheNavMesh.GetNearestNavArea(sentryPos, true, 300.0, true, true, view_as<int>(TFTeam_Red));
    
    if (area == NULL_AREA)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Invalid location! Point at the ground.");
        return;
    }
    
    CTFNavArea tfArea = view_as<CTFNavArea>(area);
    
    if (tfArea.HasAttributeTF(BLUE_SPAWN_ROOM) || tfArea.HasAttributeTF(RED_SPAWN_ROOM))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Cannot build inside spawn room!");
        return;
    }
    
    if (tfArea.HasAttributeTF(BLOCKED) || tfArea.HasAttributeTF(BLOCKED_AFTER_POINT_CAPTURE))
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 This area is blocked for building!");
        return;
    }
    
    float fwd[3];
    GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);
    
    float buildAngle[3];
    buildAngle[0] = 0.0;
    buildAngle[1] = eyeAng[1];
    buildAngle[2] = 0.0;
    
    float backDir[3];
    backDir[0] = -fwd[0];
    backDir[1] = -fwd[1];
    backDir[2] = 0.0;
    
    float engPos[3];
    engPos[0] = sentryPos[0] + (backDir[0] * 100.0);
    engPos[1] = sentryPos[1] + (backDir[1] * 100.0);
    engPos[2] = sentryPos[2];
    
    float engUp[3], engDown[3];
    engUp[0] = engPos[0];
    engUp[1] = engPos[1];
    engUp[2] = engPos[2] + 500.0;
    engDown[0] = engPos[0];
    engDown[1] = engPos[1];
    engDown[2] = engPos[2] - 500.0;
    
    Handle engGround = TR_TraceRayFilterEx(engUp, engDown, MASK_SOLID, RayType_EndPoint, TraceFilterNoPlayers, client);
    if (TR_DidHit(engGround))
    {
        TR_GetEndPosition(engPos, engGround);
        engPos[2] += 5.0;
    }
    delete engGround;
    
    CNavArea engAreaCheck = TheNavMesh.GetNearestNavArea(engPos, true, 300.0, true, true, view_as<int>(TFTeam_Red));
    if (engAreaCheck == NULL_AREA)
    {
        PrintToChat(client, "\x0732CD32[Buy Robot]\x01 Engineer position is outside the nav mesh!");
        return;
    }
    
    g_flLastNestMoveTime[client] = currentTime;
    
    CNavArea newArea = TheNavMesh.GetNearestNavArea(engPos, true, 500.0, true, true, view_as<int>(TFTeam_Red));
    if (newArea != NULL_AREA)
        m_aNestArea[target] = newArea;
    
    m_ctFindNestHint[target] = -1.0;
    m_ctAdvanceNestSpot[target] = -1.0;
    m_ctSentrySafe[target] = -1.0;
    
    int sentry = GetObjectOfType(target, TFObject_Sentry);
    if (sentry != -1)
        DetonateObjectOfType(target, TFObject_Sentry);
    
    int dispenser = GetObjectOfType(target, TFObject_Dispenser);
    if (dispenser != -1)
        DetonateObjectOfType(target, TFObject_Dispenser);
    
    int teleExit = GetObjectOfType(target, TFObject_Teleporter, TFObjectMode_Exit);
    if (teleExit != -1)
        DetonateObjectOfType(target, TFObject_Teleporter, TFObjectMode_Exit);
    
    TeleportEntity(target, engPos, NULL_VECTOR, NULL_VECTOR);
    
    char robotName[64];
    GetClientName(target, robotName, sizeof(robotName));
    
    char nameColor[8] = "FFD700";
    if (StrContains(robotName, "Giant") != -1)
        nameColor = "8B008B";
    else if (StrContains(robotName, "Boss") != -1)
        nameColor = "FF1493";
    
    PrintToChat(client, "\x0732CD32[Buy Robot]\x01 \x07%s%s\x01 nest deployed at your crosshair!", nameColor, robotName);
}

void CleanupEngineerNest(int client)
{
    m_aNestArea[client] = NULL_AREA;
    m_ctFindNestHint[client] = -1.0;
    m_ctAdvanceNestSpot[client] = -1.0;
    m_ctSentrySafe[client] = -1.0;
}

public Action Timer_WelcomeMessage(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && !IsFakeClient(client))
    {
        PrintToChat(client, "\x0732CD32[Defender Bots & Buy Robot]\x01 Type \x07FFD700!helpmenu\x01 or \x07FFD700!bothelp\x01 to see all available commands!");
    }
    return Plugin_Stop;
}
