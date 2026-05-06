static int m_iWaveFailCounterTick;
static float flLastAddTime = 0.0;

void InitGameEventHooks()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("mvm_wave_failed", Event_MvmWaveFailed);
	HookEvent("mvm_wave_complete", Event_MvmWaveComplete);
	HookEvent("revive_player_notify", Event_RevivePlayerNotify);
	HookEvent("mvm_begin_wave", Event_MvmWaveBegin);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("mvm_mission_update", Event_MvmMissionUpdate, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
}

static void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsClientInGame(client) || !IsFakeClient(client))
        return;
    
    if (TF2_GetClientTeam(client) == TFTeam_Blue && !g_bBuyIsPurchasedRobot[client])
        return;
    
    if (!g_bBuyIsPurchasedRobot[client])
    {
        CreateTimer(0.2, Timer_PlayerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    if (g_bIsDefenderBot[client] && !g_bBuyIsPurchasedRobot[client])
    {
        CreateTimer(0.3, Timer_ReapplyHat, client, TIMER_FLAG_NO_MAPCHANGE);

        g_bIsBeingRevived[client] = false;
        g_iBuyUpgradesNumber[client] = CanBuyUpgradesNow(client) ? GetRandomInt(1, 100) : 0;
        
        if (redbots_manager_debug.BoolValue)
            PrintToChatAll("[Event_PlayerSpawn] g_iBuyUpgradesNumber[%d] = %d", client, g_iBuyUpgradesNumber[client]);
    }
}

public Action Timer_ReapplyHat(Handle timer, int client)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        BuyRobot_EquipHat(client);
    }
    return Plugin_Stop;
}

static void Event_MvmWaveFailed(Event event, const char[] name, bool dontBroadcast)
{
	m_iWaveFailCounterTick++;
	
	if (redbots_manager_kick_bots.BoolValue)
	{
		RemoveAllDefenderBots("BotManager3: Wave failed!");
		ManageDefenderBots(false);
		CreateTimer(0.1, Timer_UpdateChosenBotTeamComposition, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToChatAll("%s Use command !viewbotlineup to view the next bot team composition", PLUGIN_PREFIX);
	}
	
	if (redbots_manager_mode.IntValue == MANAGER_MODE_READY_BOTS)
	{
		//Global cooldown before players can ready up again
		g_flNextReadyTime = GetGameTime() + redbots_manager_ready_cooldown.FloatValue;
		
		if (m_iWaveFailCounterTick > 3)
		{
			//Mission restarted or changed, don't have a cooldown here
			g_flNextReadyTime = 0.0;
		}
	}
	
	if (redbots_manager_bot_lineup_mode.IntValue == BOT_LINEUP_MODE_CHOOSE)
	{
		//In case the mission changed, let players pick the bot team
		FreeChosenBotTeam();
	}
	
	CreateTimer(0.1, Timer_WaveFailure, _, TIMER_FLAG_NO_MAPCHANGE);
}

static void Event_MvmWaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	if (redbots_manager_kick_bots.BoolValue)
	{
		RemoveAllDefenderBots("BotManager3: Wave complete!", IsFinalWave());
		ManageDefenderBots(false);
		CreateTimer(0.1, Timer_UpdateChosenBotTeamComposition, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToChatAll("%s Use command !viewbotlineup to view the next bot team composition", PLUGIN_PREFIX);
	}

#if defined MOD_REQUEST_CREDITS
	bool bRequestCredits = redbots_manager_bot_request_credits.BoolValue;
#endif
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i])
		{
			//Wave complete, rethink what we should do
			ResetIntentionInterface(i);
			
#if defined MOD_REQUEST_CREDITS
			if (bRequestCredits)
				FakeClientCommand(i, "sm_requestcredits");
#endif
		}
	}
}

static void Event_RevivePlayerNotify(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("entindex");
	
	//This event indicates someone attempted a revive on the client
	g_bIsBeingRevived[client] = true;
}

static void Event_MvmWaveBegin(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i] && IsPlayerAlive(i))
		{
			if (!ShouldResetBehavior(i))
				continue;
			
			//Rethink what we're supposed to do
			ResetIntentionInterface(i);
		}
	}
	
	if (redbots_manager_mode.IntValue == MANAGER_MODE_AUTO_BOTS)
		ManageDefenderBots(true);
	
	//At this point the bots should already be here, so clear up the lineup that was used
	FreeChosenBotTeam();
}

static void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	TFTeam oldTeam = view_as<TFTeam>(event.GetInt("oldteam"));
	bool isDisconnect = event.GetBool("disconnect");
	
	if (!IsFakeClient(client))
	{
		/* When changing teams, update bot team composition for
		- red player disconnected
		- player joined red
		- player left red */
		if ((isDisconnect && oldTeam == TFTeam_Red) || (!isDisconnect && (team == TFTeam_Red || oldTeam == TFTeam_Red)))
		{
			CreateTimer(0.1, Timer_UpdateChosenBotTeamComposition, _, TIMER_FLAG_NO_MAPCHANGE);
			
			if (oldTeam == TFTeam_Red)
			{
				HandleTeamPlayerCountChanged(TFTeam_Red, client);
			}
		}
		
#if defined CHANGETEAM_RESTRICTIONS
		if (!isDisconnect && team == TFTeam_Red && oldTeam == TFTeam_Blue && !CheckCommandAccess(client, NULL_STRING, ADMFLAG_GENERIC, true))
		{
			//Switching from BLUE to RED will temporarily ban the player from starting the bots
			if (g_flEnableBotsCooldown[client] <= GetGameTime())
				g_flEnableBotsCooldown[client] = GetGameTime() + 30.0;
			else
				g_flEnableBotsCooldown[client] += 10.0;
		}
#endif
	}
}

static Action Event_MvmMissionUpdate(Event event, const char[] name, bool dontBroadcast)
{
	//TFBot spies fire this event on death, so block it when a defender bot dies
	if (g_bSpyKilled)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Was the map reset?
	if (event.GetBool("full_reset"))
	{
		SetupSniperSpotHints();
	}
}

static Action Timer_PlayerSpawn(Handle timer, int data)
{
    if (!IsClientInGame(data) || !IsTFBotPlayer(data))
        return Plugin_Stop;
    
    if (TF2_GetClientTeam(data) == TFTeam_Blue && !g_bBuyIsPurchasedRobot[data])
        return Plugin_Stop;
    
    bool isPurchased = g_bBuyIsPurchasedRobot[data];
    
    if (g_bIsDefenderBot[data] && !isPurchased)
    {
        BuyRobot_EquipHat(data);

#if defined MOD_REQUEST_CREDITS
        if (redbots_manager_bot_request_credits.BoolValue && GameRules_GetRoundState() == RoundState_BetweenRounds)
            FakeClientCommand(data, "sm_requestcredits");
#endif
        
        if (redbots_manager_debug.BoolValue)
            PrintToChatAll("[Timer_PlayerSpawn] %N's currency: %d", data, TF2_GetCurrency(data));
        
        return Plugin_Stop;
    }
    
    char clientName[MAX_NAME_LENGTH]; GetClientName(data, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (StrContains(clientName, TFBOT_IDENTITY_NAME) != -1 || isPurchased)
    {
        g_bIsDefenderBot[data] = true;
        g_bHasBoughtUpgrades[data] = false;
        
        ConVar buyLoadoutCvar = FindConVar("sm_buyrobot_use_custom_loadouts");
        bool useCustomLoadouts = (buyLoadoutCvar != null && buyLoadoutCvar.BoolValue);
        
        if (isGiant || isBoss)
        {
            if (TF2_GetPlayerClass(data) == TFClass_Sniper)
                SetMission(data, CTFBot_MISSION_SNIPER);
        }
        else
        {
            if (redbots_manager_use_custom_loadouts.BoolValue && (!isPurchased || useCustomLoadouts))
            {
                TF2_RespawnPlayer(data);
            }
            else
            {
                if (TF2_GetPlayerClass(data) == TFClass_Sniper)
                    SetMission(data, CTFBot_MISSION_SNIPER);
            }
        }
        
        if (isPurchased && TF2_GetPlayerClass(data) == TFClass_Sniper)
        {
            int primary = GetPlayerWeaponSlot(data, TFWeaponSlot_Primary);
            bool hasBow = false;
            
            if (primary != -1)
            {
                int weaponID = TF2Util_GetWeaponID(primary);
                if (weaponID == TF_WEAPON_COMPOUND_BOW)
                {
                    hasBow = true;
                }
            }
            
            if (!hasBow)
            {
                SetMission(data, CTFBot_MISSION_SNIPER);
            }
        }
        
        VS_AddBotAttribute(data, CTFBot_PROJECTILE_SHIELD);
        BaseEntity_MarkNeedsNamePurge(data);
        TF2_SetCurrency(data, GetStartingCurrency(g_iPopulationManager) + GetAcquiredCreditsOfAllWaves());
        SetFakeClientConVar(data, "fov_desired", "90");
        SDKHook(data, SDKHook_TouchPost, DefenderBot_TouchPost);
        DHooks_DefenderBot(data);
        
#if defined IDLEBOT_AIMING
        VS_AddBotAttribute(data, CTFBot_IGNORE_ENEMIES);
#endif
        
#if defined MOD_REQUEST_CREDITS
        if (redbots_manager_bot_request_credits.BoolValue)
            FakeClientCommand(data, "sm_requestcredits");
#endif
        
#if defined MOD_CUSTOM_ATTRIBUTES
        if (TF2Attrib_IsValidAttributeName("cannot be sapped"))
            TF2Attrib_SetByName(data, "cannot be sapped", 1.0);
#endif
        
        if (!isPurchased)
        {
            SetRandomNameOnBot(data);
        }
    }
    
    return Plugin_Stop;
}

static Action Timer_WaveFailure(Handle timer)
{
	m_iWaveFailCounterTick = 0;
	
	if (GameRules_GetRoundState() != RoundState_BetweenRounds)
		return Plugin_Stop;
	
	//Don't refund if we wanna keep them
	//TODO: how we gonna do this for custom loadouts?
	if (redbots_manager_keep_bot_upgrades.BoolValue)
		return Plugin_Stop;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_bIsDefenderBot[i] && !g_bBuyIsPurchasedRobot[i])
		{
			/* NOTE: this isn't actually necessary, but the reason why I'm doing this is so we
			or the population manager forgets about the bots' upgrades so they can 
			just go and buy upgrades again in their upgrade behavior, though this is really 
			just for the bots that failed a wave but were not kicked */
			if (g_bHasUpgraded[i])
			{
				g_bHasBoughtUpgrades[i] = false;
				VS_GrantOrRemoveAllUpgrades(i, true, true);
				g_bHasUpgraded[i] = false;
			}
		}
	}
	
	return Plugin_Stop;
}

static Action Timer_UpdateChosenBotTeamComposition(Handle timer)
{
	//These modes use their own way of composing a bot team
	if (redbots_manager_bot_lineup_mode.IntValue == BOT_LINEUP_MODE_CHOOSE)
		return Plugin_Stop;
	
	UpdateChosenBotTeamComposition();
	
	return Plugin_Stop;
}

static bool ShouldResetBehavior(int client)
{
	//Looking for sniping spots, don't disturb
	if (ActionsManager.LookupEntityActionByName(client, "SniperLurk") != INVALID_ACTION)
		return false;
	
	//I'm healing people
	if (ActionsManager.LookupEntityActionByName(client, "Heal") != INVALID_ACTION)
		return false;
	
	//I am building shit
	if (ActionsManager.LookupEntityActionByName(client, "DefenderEngineerIdle") != INVALID_ACTION)
		return false;
	
	return true;
}