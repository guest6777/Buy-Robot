static DynamicHook m_hMyTouch;
static DynamicHook m_hIsBot;
static DynamicHook m_hEventKilled;
static DynamicHook m_hIsVisibleEntityNoticed;
static DynamicHook m_hIsIgnored;

bool g_bSpyKilled;

static bool m_bTouchCredits;
static bool m_bPlayerKilled;
static bool m_bEngineerKilled;

bool g_bWasEngineer[MAXPLAYERS + 1];
float g_flEngineerDeathTime[MAXPLAYERS + 1];

bool InitDHooks(GameData hGamedata)
{
	int iFailCount = 0;
	
#if defined METHOD_MVM_UPGRADES
	if (!g_pMannVsMachineUpgrades)
		if (!RegisterDetour(hGamedata, "CMannVsMachineUpgradeManager::LoadUpgradesFile", _, DHookCallback_LoadUpgradesFile_Post))
			iFailCount++;
#endif
	
	if (!RegisterDetour(hGamedata, "CTFPlayer::ManageRegularWeapons", DHookCallback_ManageRegularWeapons_Pre, DHookCallback_ManageRegularWeapons_Post))
		iFailCount++;
	
	if (!RegisterDetour(hGamedata, "CTFPlayer::ManageBuilderWeapons", DHookCallback_ManageBuilderWeapons_Pre))
		iFailCount++;
	
	if (!RegisterHook(hGamedata, m_hMyTouch, "CItem::MyTouch"))
		iFailCount++;
	
	if (!RegisterHook(hGamedata, m_hIsBot, "CBasePlayer::IsBot"))
		iFailCount++;
	
	if (!RegisterHook(hGamedata, m_hEventKilled, "CBaseEntity::Event_Killed"))
		iFailCount++;
	
	if (!RegisterHook(hGamedata, m_hIsVisibleEntityNoticed, "IVision::IsVisibleEntityNoticed"))
		iFailCount++;
	
	if (!RegisterHook(hGamedata, m_hIsIgnored, "IVision::IsIgnored"))
		iFailCount++;
	
	if (iFailCount > 0)
	{
		LogError("InitDHooks: found %d problems with gamedata!", iFailCount);
		return false;
	}
	
	return true;
}

public void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "item_currencypack_") != -1)
	{
		m_hMyTouch.HookEntity(Hook_Pre, entity, DHookCallback_MyTouch_Pre);
		m_hMyTouch.HookEntity(Hook_Post, entity, DHookCallback_MyTouch_Post);
	}
}

void DHooks_DefenderBot(int client)
{
	m_hIsBot.HookEntity(Hook_Pre, client, DHookCallback_IsBot_Pre);
	m_hEventKilled.HookEntity(Hook_Pre, client, DHookCallback_EventKilled_Pre);
	m_hEventKilled.HookEntity(Hook_Post, client, DHookCallback_EventKilled_Post);
	
	INextBot bot = CBaseNPC_GetNextBotOfEntity(client);
	Address vision = view_as<Address>(bot.GetVisionInterface());
	
	if (vision != Address_Null)
	{
		m_hIsVisibleEntityNoticed.HookRaw(Hook_Pre, vision, DHookCallback_IsVisibleEntityNoticed_Pre);
		m_hIsVisibleEntityNoticed.HookRaw(Hook_Post, vision, DHookCallback_IsVisibleEntityNoticed_Post);
		m_hIsIgnored.HookRaw(Hook_Pre, vision, DHookCallback_IsIgnored_Pre);
	}
	else
	{
		LogError("DHooks_DefenderBot: IVision is NULL! Bot vision will not be hooked.");
	}
}

static MRESReturn DHookCallback_LoadUpgradesFile_Post(Address pThis)
{
	if (!g_pMannVsMachineUpgrades)
	{
		g_pMannVsMachineUpgrades = pThis;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ManageRegularWeapons_Pre(int pThis)
{
    if (g_bBuyIsPurchasedRobot[pThis])
    {
        ConVar buyLoadoutCvar = FindConVar("sm_buyrobot_use_custom_loadouts");
        if (buyLoadoutCvar != null && buyLoadoutCvar.BoolValue)
        {
            return MRES_Ignored;
        }
        return MRES_Supercede;
    }
    
    if (g_bIsDefenderBot[pThis] && !g_bBuyIsPurchasedRobot[pThis] && TF2_GetClientTeam(pThis) == TFTeam_Red && redbots_manager_use_custom_loadouts.BoolValue && IsPlayerAlive(pThis) && TF2_IsInUpgradeZone(pThis))
        return MRES_Supercede;
    
    return MRES_Ignored;
}

static MRESReturn DHookCallback_ManageRegularWeapons_Post(int pThis)
{
    if (g_bBuyIsPurchasedRobot[pThis])
    {
        ConVar buyLoadoutCvar = FindConVar("sm_buyrobot_use_custom_loadouts");
        if (buyLoadoutCvar != null && buyLoadoutCvar.BoolValue)
        {
            if (IsPlayerAlive(pThis) && !TF2_IsInUpgradeZone(pThis))
            {
                if (g_bHasCustomLoadout[pThis])
                {
                    CreateTimer(0.1, Timer_GiveCustomLoadout, pThis, TIMER_FLAG_NO_MAPCHANGE);
                }
                else
                {
                    PrepareCustomLoadout(pThis);
                    CreateTimer(0.1, Timer_GiveCustomLoadout, pThis, TIMER_FLAG_NO_MAPCHANGE);
                }
            }
        }
        return MRES_Ignored;
    }
    
    if (g_bIsDefenderBot[pThis] && !g_bBuyIsPurchasedRobot[pThis] && TF2_GetClientTeam(pThis) == TFTeam_Red && redbots_manager_use_custom_loadouts.BoolValue)
    {
        if (IsPlayerAlive(pThis) && !TF2_IsInUpgradeZone(pThis))
        {
            if (g_bHasCustomLoadout[pThis])
            {
                CreateTimer(0.1, Timer_GiveCustomLoadout, pThis, TIMER_FLAG_NO_MAPCHANGE);
            }
            else
            {
                PrepareCustomLoadout(pThis);
                CreateTimer(0.1, Timer_GiveCustomLoadout, pThis, TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
    
    return MRES_Ignored;
}

static MRESReturn DHookCallback_ManageBuilderWeapons_Pre(int pThis)
{
    char clientName[MAX_NAME_LENGTH];
    GetClientName(pThis, clientName, sizeof(clientName));
    
    if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
        return MRES_Ignored;
    
    if (g_bBuyIsPurchasedRobot[pThis])
    {
        ConVar buyLoadoutCvar = FindConVar("sm_buyrobot_use_custom_loadouts");
        if (buyLoadoutCvar != null && buyLoadoutCvar.BoolValue)
        {
            if (TF2_GetPlayerClass(pThis) == TFClass_Spy && IsPlayerAlive(pThis))
            {
                if (TF2_IsInUpgradeZone(pThis))
                    return MRES_Supercede;
            }
        }
        return MRES_Ignored;
    }
    
    if (g_bIsDefenderBot[pThis] && !g_bBuyIsPurchasedRobot[pThis] && TF2_GetClientTeam(pThis) == TFTeam_Red && redbots_manager_use_custom_loadouts.BoolValue)
    {
        if (TF2_GetPlayerClass(pThis) == TFClass_Spy && IsPlayerAlive(pThis))
        {
            if (TF2_IsInUpgradeZone(pThis))
                return MRES_Supercede;
        }
    }
    
    return MRES_Ignored;
}

static MRESReturn DHookCallback_MyTouch_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	int player = hParams.Get(1);
	
	if (g_bIsDefenderBot[player] || g_bBuyIsPurchasedRobot[player])
		m_bTouchCredits = true;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_MyTouch_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	int player = hParams.Get(1);
	
	if (g_bIsDefenderBot[player] || g_bBuyIsPurchasedRobot[player])
		m_bTouchCredits = false;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsBot_Pre(int pThis, DHookReturn hReturn)
{
	if (IsClientInGame(pThis) && (g_bIsDefenderBot[pThis] || g_bBuyIsPurchasedRobot[pThis]))
	{
		if (TF2_GetClientTeam(pThis) != TFTeam_Red && !g_bBuyIsPurchasedRobot[pThis])
			return MRES_Ignored;
		
		if (m_bTouchCredits || m_bPlayerKilled)
		{
			hReturn.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_EventKilled_Pre(int pThis, DHookParam hParams)
{
    if (IsSentryBusterRobot(pThis))
        return MRES_Ignored;
    
    if (g_bIsDefenderBot[pThis])
    {
        m_bPlayerKilled = true;
        
        g_bWasEngineer[pThis] = (TF2_GetPlayerClass(pThis) == TFClass_Engineer);
        
        if (TF2_GetPlayerClass(pThis) == TFClass_Engineer)
        {
            TF2_SetPlayerClass(pThis, TFClass_Soldier, _, false);
            m_bEngineerKilled = true;
            
            g_flEngineerDeathTime[pThis] = GetGameTime();
            
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(pThis));
            pack.WriteCell(g_bWasEngineer[pThis]);
            CreateTimer(20.0, Timer_ForceEngineerRestore, pack, TIMER_FLAG_NO_MAPCHANGE);
        }
        else if (TF2_GetPlayerClass(pThis) == TFClass_Spy)
        {
            g_bSpyKilled = true;
        }
    }
    
    return MRES_Ignored;
}

public Action Timer_ForceEngineerRestore(Handle timer, DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    bool wasEngineer = pack.ReadCell();
    delete pack;
    
    int client = GetClientOfUserId(userid);
    
    if (!client || !IsClientInGame(client))
        return Plugin_Stop;
    
    if (wasEngineer && TF2_GetPlayerClass(client) != TFClass_Engineer)
    {
        TF2_SetPlayerClass(client, TFClass_Engineer, _, false);
    }
    
    return Plugin_Stop;
}

static MRESReturn DHookCallback_EventKilled_Post(int pThis, DHookParam hParams)
{
	if (g_bIsDefenderBot[pThis])
	{
		m_bPlayerKilled = false;
		
		if (g_bWasEngineer[pThis] && TF2_GetPlayerClass(pThis) != TFClass_Engineer)
		{
			TF2_SetPlayerClass(pThis, TFClass_Engineer, _, false);
		}
		
		if (m_bEngineerKilled)
		{
			TF2_SetPlayerClass(pThis, TFClass_Engineer, _, false);
			m_bEngineerKilled = false;
		}
		
		g_bWasEngineer[pThis] = false;
		g_flEngineerDeathTime[pThis] = 0.0;
		
		if (g_bSpyKilled)
			g_bSpyKilled = false;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsVisibleEntityNoticed_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsVisibleEntityNoticed_Post(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsIgnored_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
    int subject = hParams.Get(1);
    int myself = view_as<IVision>(pThis).GetBot().GetEntity();
    int myTeam = GetClientTeam(myself);
    
    if (BaseEntity_IsPlayer(subject) && GetClientTeam(subject) != myTeam)
    {
        if (TF2_IsInvulnerable(subject))
        {
            if (TF2_IsPlayerInCondition(subject, TFCond_ImmuneToPushback))
            {
                hReturn.Value = true;
                return MRES_Supercede;
            }
            
            int myWeapon = BaseCombatCharacter_GetActiveWeapon(myself);
            
            if (myWeapon != -1)
            {
                switch (TF2Util_GetWeaponID(myWeapon))
                {
                    case TF_WEAPON_ROCKETLAUNCHER, TF_WEAPON_GRENADELAUNCHER, TF_WEAPON_PIPEBOMBLAUNCHER, TF_WEAPON_DIRECTHIT, TF_WEAPON_PARTICLE_CANNON, TF_WEAPON_FLAME_BALL:
                    {
                    }
                    case TF_WEAPON_FLAMETHROWER:
                    {
                        if (!CanWeaponAirblast(myWeapon))
                        {
                            hReturn.Value = true;
                            return MRES_Supercede;
                        }
                    }
                    default:
                    {
                        hReturn.Value = true;
                        return MRES_Supercede;
                    }
                }
            }
        }
    }
    else if (BaseEntity_IsBaseObject(subject) && BaseEntity_GetTeamNumber(subject) != myTeam)
    {
        if (TF2_HasSapper(subject))
        {
            hReturn.Value = true;
            return MRES_Supercede;
        }
    }
    
    return MRES_Ignored;
}

static bool RegisterDetour(GameData gd, const char[] fnName, DHookCallback pre = INVALID_FUNCTION, DHookCallback post = INVALID_FUNCTION)
{
	DynamicDetour hDetour;
	hDetour = DynamicDetour.FromConf(gd, fnName);
	
	if (hDetour)
	{
		if (pre != INVALID_FUNCTION)
			hDetour.Enable(Hook_Pre, pre);
		
		if (post != INVALID_FUNCTION)
			hDetour.Enable(Hook_Post, post);
	}
	else
	{
		delete hDetour;
		LogError("Failed to detour \"%s\"!", fnName);
		
		return false;
	}
	
	delete hDetour;
	
	return true;
}

static bool RegisterHook(GameData gd, DynamicHook &hook, const char[] fnName)
{
	hook = DynamicHook.FromConf(gd, fnName);
	
	if (hook == null)
	{
		LogError("Failed to setup DynamicHook for \"%s\"!", fnName);
		return false;
	}
	
	return true;
}