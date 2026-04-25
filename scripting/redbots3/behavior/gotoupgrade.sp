int m_iStation[MAXPLAYERS + 1];

BehaviorAction CTFBotGotoUpgrade()
{
	BehaviorAction action = ActionsManager.Create("DefenderGotoUpgrade");
	
	action.OnStart = CTFBotGotoUpgrade_OnStart;
	action.Update = CTFBotGotoUpgrade_Update;
	action.OnEnd = CTFBotGotoUpgrade_OnEnd;
	action.OnNavAreaChanged = CTFBotGotoUpgrade_OnNavAreaChanged;
	
	return action;
}

public Action CTFBotGotoUpgrade_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	m_pPath[actor].SetMinLookAheadDistance(GetDesiredPathLookAheadRange(actor));
	
	if (g_bBuyIsPurchasedRobot[actor])
	{
		ConVar buyUseUpgrades = FindConVar("sm_buyrobot_use_upgrades");
		bool canUseUpgrades = (buyUseUpgrades != null && buyUseUpgrades.BoolValue);
		
		if (!canUseUpgrades)
		{
			return action.Done("Purchased robot cannot use upgrades");
		}
		
		TF2_SetInUpgradeZone(actor, true);
		return action.ChangeTo(CTFBotUpgrade(), "Purchased robot upgrading anywhere");
	}
	
	m_iStation[actor] = FindClosestUpgradeStation(actor);

	if (m_iStation[actor] <= MaxClients)
	{
		TF2_SetInUpgradeZone(actor, true);
	}
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		float myOrigin[3]; GetClientAbsOrigin(actor, myOrigin);
		
		if (GetVectorDistance(myOrigin, WorldSpaceCenter(m_iStation[actor])) >= 1000.0)
			TF2_SetInUpgradeZone(actor, true);
	}
	
	return action.Continue();
}

public Action CTFBotGotoUpgrade_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (g_bBuyIsPurchasedRobot[actor])
	{
		ConVar buyUseUpgrades = FindConVar("sm_buyrobot_use_upgrades");
		bool canUseUpgrades = (buyUseUpgrades != null && buyUseUpgrades.BoolValue);
		
		if (canUseUpgrades && TF2_IsInUpgradeZone(actor))
		{
			return action.ChangeTo(CTFBotUpgrade(), "Upgrading now");
		}
		
		return action.Done("Not ready for upgrade");
	}
	
	if (TF2_IsInUpgradeZone(actor)) 
		return action.ChangeTo(CTFBotUpgrade(), "Reached upgrade station; buying upgrades");
	
	int station = m_iStation[actor];
	
	float center[3];
	bool hasGoal = GetMapUpgradeStationGoal(center);
	
	if (!hasGoal)
	{
		CNavArea area = TheNavMesh.GetNearestNavArea(WorldSpaceCenter(station), true, 1000.0, false, false, TEAM_ANY);
		
		if (area == NULL_AREA)
			return action.Continue();
		
		CNavArea_GetRandomPoint(area, center);
		
		center[2] += 50.0;
		
		TR_TraceRayFilter(center, WorldSpaceCenter(station), MASK_PLAYERSOLID, RayType_EndPoint, NextBotTraceFilterIgnoreActors);
		TR_GetEndPosition(center);
	}
	
	INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
	
	if (m_flRepathTime[actor] <= GetGameTime())
	{
		m_flRepathTime[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
		m_pPath[actor].ComputeToPos(myBot, center);
	}
	
	m_pPath[actor].Update(myBot);
	
	return action.Continue();
}

public void CTFBotGotoUpgrade_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	m_iStation[actor] = -1;
}

public Action CTFBotGotoUpgrade_OnNavAreaChanged(BehaviorAction action, int actor, CTFNavArea newArea, CTFNavArea oldArea, ActionDesiredResult result)
{
	if (newArea && GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		TFNavAttributeType spawnRoomFlag = TF2_GetClientTeam(actor) == TFTeam_Red ? RED_SPAWN_ROOM : BLUE_SPAWN_ROOM;
		
		if (!newArea.HasAttributeTF(spawnRoomFlag))
			return action.TryDone(RESULT_IMPORTANT, "I am not in a spawn room");
	}
	
	return action.TryContinue();
}

int FindClosestUpgradeStation(int actor)
{
    int stations[MAXPLAYERS + 1];
    int stationcount;
    float myOrigin[3];
    GetClientAbsOrigin(actor, myOrigin);
    
    int i = -1;
    while ((i = FindEntityByClassname(i, "func_upgradestation")) != -1)
    {
        if (!IsUpgradeStationEnabled(i))
            continue;
        
        CNavArea area = TheNavMesh.GetNearestNavArea(WorldSpaceCenter(i), true, 8000.0, false, false, TEAM_ANY);
        
        if (area == NULL_AREA)
            continue;
        
        float center[3]; area.GetCenter(center);
        
        center[2] += 50.0;
        
        TR_TraceRay(center, WorldSpaceCenter(i), MASK_PLAYERSOLID, RayType_EndPoint);
        TR_GetEndPosition(center);
        
        if (!IsPathToVectorPossible(actor, center))
            continue;
        
        stations[stationcount] = i;
        stationcount++;
    }
    
    if (stationcount == 0)
        return -1;
    
    int bestStation = stations[0];
    float bestDistance = GetVectorDistance(myOrigin, WorldSpaceCenter(bestStation));
    
    for (int j = 1; j < stationcount; j++)
    {
        float distance = GetVectorDistance(myOrigin, WorldSpaceCenter(stations[j]));
        if (distance < bestDistance)
        {
            bestDistance = distance;
            bestStation = stations[j];
        }
    }
    
    return bestStation;
}

bool GetMapUpgradeStationGoal(float buffer[3])
{
	char map[PLATFORM_MAX_PATH]; GetCurrentMap(map, PLATFORM_MAX_PATH);
	
	if (StrContains(map, "mvm_mannworks") != -1)
	{
		buffer = {-643.9, -2635.2, 384.0};
		return true;
	}
	else if (StrContains(map, "mvm_teien") != -1)
	{
		buffer = {4613.1, -6561.9, 260.0};
		return true;
	}
	else if (StrContains(map, "mvm_sequoia") != -1)
	{
		buffer = {-5117.0, -377.3, 4.5};
		return true;
	}
	else if (StrContains(map, "mvm_highground") != -1)
	{
		buffer = {-2013.0, 4561.0, 448.0};
		return true;
	}
	else if (StrContains(map, "mvm_newnormandy") != -1)
	{
		buffer = {-345.0, 4178.0, 205.0};
		return true;
	}
	else if (StrContains(map, "mvm_snowfall") != -1)
	{
		buffer = {-26.0, 792.0, -159.0};
		return true;
	}
	
	return false;
}