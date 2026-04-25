BehaviorAction CTFBotMvMEngineerBuildTeleporterEntrance()
{
    BehaviorAction action = ActionsManager.Create("DefenderBuildTeleporterEntrance");
    
    action.OnStart = CTFBotMvMEngineerBuildTeleporterEntrance_OnStart;
    action.Update = CTFBotMvMEngineerBuildTeleporterEntrance_Update;
    action.OnEnd = CTFBotMvMEngineerBuildTeleporterEntrance_OnEnd;
    
    return action;
}

public Action CTFBotMvMEngineerBuildTeleporterEntrance_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    UpdateLookAroundForEnemies(actor, true);
    
    return action.Continue();
}

public Action CTFBotMvMEngineerBuildTeleporterEntrance_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
    if (g_hTeleporterEntranceSpots == null || g_hTeleporterEntranceSpots.Length == 0)
    {
        return action.Done("No teleporter spots");
    }
    
    int existingEntrance = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
    if (existingEntrance != INVALID_ENT_REFERENCE)
    {
        if (m_aNestArea[actor] != NULL_AREA)
        {
            float nestPos[3];
            m_aNestArea[actor].GetCenter(nestPos);
            g_arrPluginBot[actor].SetPathGoalVector(nestPos);
            g_arrPluginBot[actor].bPathing = true;
            return action.Done("Teleporter entrance already exists, returning to nest");
        }
        return action.Done("Teleporter entrance already exists");
    }
    
    INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
    IBody myBody = myBot.GetBodyInterface();
    
    float targetPos[3];
    
    int startIndex = g_iBotEntranceSpot[actor];
    if (startIndex == -1)
        startIndex = GetRandomInt(0, g_hTeleporterEntranceSpots.Length - 1);
    
    int attempts = 0;
    int maxAttempts = g_hTeleporterEntranceSpots.Length;
    int selectedIndex = -1;
    
    for (int i = 0; i < maxAttempts; i++)
    {
        int checkIndex = (startIndex + i) % maxAttempts;
        g_hTeleporterEntranceSpots.GetArray(checkIndex, targetPos);
        
        int existing = -1;
        while ((existing = FindEntityByClassname(existing, "obj_teleporter")) != -1)
        {
            if (TF2_GetObjectMode(existing) != TFObjectMode_Entrance)
                continue;
            
            float existingPos[3];
            GetEntPropVector(existing, Prop_Send, "m_vecOrigin", existingPos);
            
            if (GetVectorDistance(targetPos, existingPos) < 100.0)
            {
                existing = -2;
                break;
            }
        }
        
        if (existing != -2)
        {
            selectedIndex = checkIndex;
            break;
        }
    }
    
    if (selectedIndex == -1)
    {
        if (m_aNestArea[actor] != NULL_AREA)
        {
            float nestPos[3];
            m_aNestArea[actor].GetCenter(nestPos);
            g_arrPluginBot[actor].SetPathGoalVector(nestPos);
            g_arrPluginBot[actor].bPathing = true;
        }
        return action.Done("All teleporter spots occupied");
    }
    
    g_iBotEntranceSpot[actor] = selectedIndex;
    g_hTeleporterEntranceSpots.GetArray(selectedIndex, targetPos);
    
    float range_to_hint = GetVectorDistance(GetAbsOrigin(actor), targetPos);
    
    if (range_to_hint < 250.0) 
    {
        if (!IsWeapon(actor, TF_WEAPON_BUILDER))
            FakeClientCommandThrottled(actor, "build 1");
        
        AimHeadTowards(myBody, targetPos, MANDATORY, 0.1, Address_Null, "Building teleporter entrance");
        VS_PressFireButton(actor);
    }
    
    if (range_to_hint > 70.0)
    {
        g_arrPluginBot[actor].SetPathGoalVector(targetPos);
        g_arrPluginBot[actor].bPathing = true;
        
        return action.Continue();
    }
    
    g_arrPluginBot[actor].bPathing = false;
    
    int teleporter = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
    
    if (teleporter == INVALID_ENT_REFERENCE)
        return action.Continue();

    if (!TF2_IsBuilding(teleporter) && TF2_GetUpgradeLevel(teleporter) >= 1)
    {
        if (m_aNestArea[actor] != NULL_AREA)
        {
            float nestPos[3];
            m_aNestArea[actor].GetCenter(nestPos);
            
            g_arrPluginBot[actor].SetPathGoalVector(nestPos);
            g_arrPluginBot[actor].bPathing = true;
            
            return action.Done("Built teleporter entrance, returning to nest");
        }
    }
    
    return action.Continue();
}

public void CTFBotMvMEngineerBuildTeleporterEntrance_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    UpdateLookAroundForEnemies(actor, true);
}

BehaviorAction CTFBotMvMEngineerBuildTeleporterExit()
{
    BehaviorAction action = ActionsManager.Create("DefenderBuildTeleporterExit");
    
    action.OnStart = CTFBotMvMEngineerBuildTeleporterExit_OnStart;
    action.Update = CTFBotMvMEngineerBuildTeleporterExit_Update;
    action.OnEnd = CTFBotMvMEngineerBuildTeleporterExit_OnEnd;
    
    return action;
}

public Action CTFBotMvMEngineerBuildTeleporterExit_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    UpdateLookAroundForEnemies(actor, true);
    
    return action.Continue();
}

public Action CTFBotMvMEngineerBuildTeleporterExit_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
    if (m_aNestArea[actor] == NULL_AREA)
    {
        return action.Done("No nest area");
    }

    if (GetObjectOfType(actor, TFObject_Sentry) == INVALID_ENT_REFERENCE)
    {
        return action.Done("No sentry");
    }
    
    INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
    IBody myBody = myBot.GetBodyInterface();
    
    int teleporterEntrance = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
    
    if (teleporterEntrance == INVALID_ENT_REFERENCE)
    {
        return action.Done("No entrance");
    }
    
    float targetPos[3];
    m_aNestArea[actor].GetCenter(targetPos);
    targetPos[0] += GetRandomFloat(-50.0, 50.0);
    targetPos[1] += GetRandomFloat(-50.0, 50.0);
    targetPos[2] += 20.0;
    
    float range_to_hint = GetVectorDistance(GetAbsOrigin(actor), targetPos);
    
    if (range_to_hint < 100.0) 
    {
        if (!IsWeapon(actor, TF_WEAPON_BUILDER))
            FakeClientCommandThrottled(actor, "build 3");
        
        AimHeadTowards(myBody, targetPos, MANDATORY, 0.1, Address_Null, "Building teleporter exit");
        VS_PressFireButton(actor);
    }
    
    if (range_to_hint > 70.0)
    {
        g_arrPluginBot[actor].SetPathGoalVector(targetPos);
        g_arrPluginBot[actor].bPathing = true;
        
        return action.Continue();
    }
    
    g_arrPluginBot[actor].bPathing = false;
    
    int teleporter = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
    
    if (teleporter == INVALID_ENT_REFERENCE)
        return action.Continue();
    
    return action.Done("Built teleporter exit");
}

public void CTFBotMvMEngineerBuildTeleporterExit_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    UpdateLookAroundForEnemies(actor, true);
}