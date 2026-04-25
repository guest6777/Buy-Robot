#define SENTRY_WATCH_BOMB_RANGE	400.0

float m_ctSentrySafe[MAXPLAYERS + 1];
float m_ctSentryCooldown[MAXPLAYERS + 1];

float m_ctDispenserSafe[MAXPLAYERS + 1]; 
float m_ctDispenserCooldown[MAXPLAYERS + 1];

float m_ctTeleporterEntranceSafe[MAXPLAYERS + 1];
float m_ctTeleporterEntranceCooldown[MAXPLAYERS + 1];
float m_ctTeleporterExitSafe[MAXPLAYERS + 1];
float m_ctTeleporterExitCooldown[MAXPLAYERS + 1];

float m_ctFindNestHint[MAXPLAYERS + 1]; 
float m_ctAdvanceNestSpot[MAXPLAYERS + 1]; 

float m_ctRecomputePathMvMEngiIdle[MAXPLAYERS + 1];

CNavArea m_aNestArea[MAXPLAYERS + 1] = {NULL_AREA, ...};

bool g_bGoingToGrabBuilding[MAXPLAYERS + 1];
int m_hBuildingToGrab[MAXPLAYERS + 1];
bool g_bIsHelpingTeammate[MAXPLAYERS + 1];
float m_flNextHelpCheck[MAXPLAYERS + 1];
bool g_bEvadingBuster[MAXPLAYERS + 1];

float GetScaledDistance(int client, float distance)
{
    float scale = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
    if (scale <= 0.0) scale = 1.0;
    return distance * scale;
}

BehaviorAction CTFBotMvMEngineerIdle()
{
	BehaviorAction action = ActionsManager.Create("DefenderEngineerIdle");
	
	action.OnStart = CTFBotMvMEngineerIdle_OnStart;
	action.Update = CTFBotMvMEngineerIdle_Update;
	action.OnEnd = CTFBotMvMEngineerIdle_OnEnd;
	action.OnMoveToSuccess = CTFBotMvMEngineerIdle_OnMoveToSuccess;
	
	return action;
}

static Action CTFBotMvMEngineerIdle_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	m_pPath[actor].SetMinLookAheadDistance(GetDesiredPathLookAheadRange(actor));
	
	CTFBotMvMEngineerIdle_ResetProperties(actor);
	
	return action.Continue();
}

static Action CTFBotMvMEngineerIdle_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
    int sentry = GetObjectOfType(actor, TFObject_Sentry);
    int dispenser = GetObjectOfType(actor, TFObject_Dispenser);

    INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
    IBody myBody = myBot.GetBodyInterface();
    ILocomotion myLoco = myBot.GetLocomotionInterface();

    if ((TF2_GetClientTeam(actor) == TFTeam_Red) && ShouldEngineerBuildTeleporter(actor) && GameRules_GetRoundState() == RoundState_BetweenRounds)
    {
        int teleporterEntrance = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
        int teleporterExit = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
        
        float targetPos[3];
        
        if (teleporterEntrance == -1 || !IsValidEntity(teleporterEntrance))
        {
            if (g_iBotEntranceSpot[actor] == -1)
                g_iBotEntranceSpot[actor] = GetRandomInt(0, g_hTeleporterEntranceSpots.Length - 1);
            
            g_hTeleporterEntranceSpots.GetArray(g_iBotEntranceSpot[actor], targetPos);
            
            if (!IsWeapon(actor, TF_WEAPON_BUILDER))
                FakeClientCommandThrottled(actor, "build 1");
            
            if (myBot.IsRangeLessThanEx(targetPos, 325.0))
            {
                AimHeadTowards(myBody, targetPos, MANDATORY, 0.1, Address_Null, "Building teleporter entrance");
                VS_PressFireButton(actor);
            }
            else
            {
                g_arrPluginBot[actor].SetPathGoalVector(targetPos);
                g_arrPluginBot[actor].bPathing = true;
            }
            return action.Continue();
        }
        
        if (teleporterExit == -1 || !IsValidEntity(teleporterExit))
        {
            if (m_aNestArea[actor] != NULL_AREA)
            {
                m_aNestArea[actor].GetCenter(targetPos);
                targetPos[0] += GetRandomFloat(-50.0, 50.0);
                targetPos[1] += GetRandomFloat(-50.0, 50.0);
                targetPos[2] += 20.0;
            }
            
            if (!IsWeapon(actor, TF_WEAPON_BUILDER))
                FakeClientCommandThrottled(actor, "build 3");
            
            if (myBot.IsRangeLessThanEx(targetPos, 100.0))
            {
                AimHeadTowards(myBody, targetPos, MANDATORY, 0.1, Address_Null, "Building teleporter exit at nest");
                VS_PressFireButton(actor);
            }
            else
            {
                g_arrPluginBot[actor].SetPathGoalVector(targetPos);
                g_arrPluginBot[actor].bPathing = true;
            }
            return action.Continue();
        }
    }
    
    bool bShouldAdvance = CTFBotMvMEngineerIdle_ShouldAdvanceNestSpot(actor);
    
    if (bShouldAdvance && !g_bGoingToGrabBuilding[actor])
    {
        if (redbots_manager_debug_actions.BoolValue)
            PrintToServer("CTFBotMvMEngineerIdle_Update: ADVANCE");
        
        CTFBotMvMEngineerIdle_ResetProperties(actor);
        
        m_aNestArea[actor] = PickBuildArea(actor);
        
        if (sentry != INVALID_ENT_REFERENCE && m_aNestArea[actor] != NULL_AREA)
        {
            g_bGoingToGrabBuilding[actor] = true;
            m_hBuildingToGrab[actor] = EntIndexToEntRef(sentry);
            g_arrPluginBot[actor].SetPathGoalEntity(sentry);
        }
    }
    
    if (g_bGoingToGrabBuilding[actor])
    {
        int building = EntRefToEntIndex(m_hBuildingToGrab[actor]);
        
        if (building == INVALID_ENT_REFERENCE)
        {
            g_bGoingToGrabBuilding[actor] = false;
            m_hBuildingToGrab[actor] = INVALID_ENT_REFERENCE;
            DetonateObjectOfType(actor, TFObject_Sentry);
            DetonateObjectOfType(actor, TFObject_Dispenser);
            g_arrPluginBot[actor].bPathing = false;
            return action.Continue();
        }
        
        UpdateLookAroundForEnemies(actor, false);
        
        if (!TF2_IsCarryingObject(actor))
        {
            float flDistanceToBuilding = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(building));
            float requiredDist = GetScaledDistance(actor, 90.0);
            
            if (flDistanceToBuilding < requiredDist)
            {
                EquipWeaponSlot(actor, TFWeaponSlot_Melee);
                AimHeadTowards(myBody, WorldSpaceCenter(building), CRITICAL, 1.0, _, "Grab building");
                VS_PressAltFireButton(actor);
            }
        }
        else
        {
            if (m_aNestArea[actor] != NULL_AREA)
            {
                float center[3];
                m_aNestArea[actor].GetCenter(center);
                g_arrPluginBot[actor].SetPathGoalVector(center);
                
                float flDistanceToGoal = GetVectorDistance(GetAbsOrigin(actor), center);
                float requiredDist = GetScaledDistance(actor, 200.0);
                
                if (flDistanceToGoal < requiredDist)
                {
                    if (!myLoco.IsStuck())
                        g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
                    
                    if (flDistanceToGoal < 70.0)
                    {
                        int objBeingBuilt = TF2_GetCarriedObject(actor);
                        
                        if (objBeingBuilt == -1)
                            return action.Continue();
                        
                        bool m_bPlacementOK = IsPlacementOK(objBeingBuilt);
                        
                        VS_PressFireButton(actor);
                        
                        if (!m_bPlacementOK && myBody.IsHeadAimingOnTarget() && myBody.GetHeadSteadyDuration() > 0.6)
                        {
                            m_aNestArea[actor] = PickBuildArea(actor);
                        }
                        else
                        {
                            g_bGoingToGrabBuilding[actor] = false;
                            m_hBuildingToGrab[actor] = INVALID_ENT_REFERENCE;
                            g_arrPluginBot[actor].bPathing = false;
                        }
                    }
                }
            }
        }
        
        g_arrPluginBot[actor].bPathing = true;
        return action.Continue();
    }
    
    // SÓ chama PickBuildArea se realmente precisa de um novo spot
    if ((m_aNestArea[actor] == NULL_AREA || bShouldAdvance) || sentry == INVALID_ENT_REFERENCE)
    {
        if (m_ctFindNestHint[actor] > 0.0 && m_ctFindNestHint[actor] > GetGameTime())
            return action.Continue();
        
        m_ctFindNestHint[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
        
        if (m_aNestArea[actor] == NULL_AREA || bShouldAdvance)
        {
            m_aNestArea[actor] = PickBuildArea(actor);
        }
    }
    
    if (bShouldAdvance)
        return action.Continue();

// ============================================================
// PRIORIDADE 0: FUGIR DE SENTRY BUSTER
// ============================================================
if (TF2_GetClientTeam(actor) == TFTeam_Red)
{
    int buster = FindNearestSentryBuster(actor);
    if (buster != -1 && sentry != INVALID_ENT_REFERENCE)
    {
        float busterPos[3], sentryPos[3];
        GetClientAbsOrigin(buster, busterPos);
        GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPos);
        
        float distToBuster = GetVectorDistance(sentryPos, busterPos);
        
        if (distToBuster < 600.0)
        {
            if (!TF2_IsCarryingObject(actor))
            {
                float distToSentry = GetVectorDistance(GetAbsOrigin(actor), sentryPos);
                
                if (distToSentry < 120.0)
                {
                    EquipWeaponSlot(actor, TFWeaponSlot_Melee);
                    AimHeadTowards(myBody, WorldSpaceCenter(sentry), CRITICAL, 0.5, _, "Grab sentry - Buster!");
                    VS_PressAltFireButton(actor);
                    
                    if (TF2_IsCarryingObject(actor))
                    {
                        float fleeDir[3];
                        SubtractVectors(sentryPos, busterPos, fleeDir);
                        NormalizeVector(fleeDir, fleeDir);
                        
                        float fleePos[3];
                        fleePos[0] = sentryPos[0] + (fleeDir[0] * 400.0);
                        fleePos[1] = sentryPos[1] + (fleeDir[1] * 400.0);
                        fleePos[2] = sentryPos[2];
                        
                        g_arrPluginBot[actor].SetPathGoalVector(fleePos);
                        g_arrPluginBot[actor].bPathing = true;
                    }
                }
                else
                {
                    g_arrPluginBot[actor].SetPathGoalEntity(sentry);
                    g_arrPluginBot[actor].bPathing = true;
                }
            }
            else
            {
                float fleeDir[3];
                SubtractVectors(sentryPos, busterPos, fleeDir);
                NormalizeVector(fleeDir, fleeDir);
                
                float fleePos[3];
                fleePos[0] = GetAbsOrigin(actor)[0] + (fleeDir[0] * 400.0);
                fleePos[1] = GetAbsOrigin(actor)[1] + (fleeDir[1] * 400.0);
                fleePos[2] = GetAbsOrigin(actor)[2];
                
                g_arrPluginBot[actor].SetPathGoalVector(fleePos);
                g_arrPluginBot[actor].bPathing = true;
            }
            
            return action.Continue();
        }
        else if (TF2_IsCarryingObject(actor))
        {
            VS_PressFireButton(actor);
        }
    }
}
    
    // ============================================================
    // PRIORIDADE 1: REPARAR CONSTRUÇÕES DANIFICADAS
    // ============================================================
    
    if (sentry != INVALID_ENT_REFERENCE) 
    {
        bool isMini = TF2_IsMiniBuilding(sentry);
        bool needsWork = false;
        int ammoCount = GetEntProp(sentry, Prop_Send, "m_iAmmoShells");
        bool lowAmmo = (ammoCount < 50);
        
        if (isMini)
            needsWork = (BaseEntity_GetHealth(sentry) < TF2Util_GetEntityMaxHealth(sentry));
        else
            needsWork = (TF2_GetUpgradeLevel(sentry) < 3 || BaseEntity_GetHealth(sentry) < TF2Util_GetEntityMaxHealth(sentry));
        
        if (needsWork || lowAmmo)
        {
            float dist = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(sentry));
            float requiredDist = GetScaledDistance(actor, 90.0);
            
            if (m_ctRecomputePathMvMEngiIdle[actor] < GetGameTime()) 
            {
                m_ctRecomputePathMvMEngiIdle[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
                
                float vTurretAngles[3];
                GetTurretAngles(sentry, vTurretAngles);
                float dir[3];
                GetAngleVectors(vTurretAngles, dir, NULL_VECTOR, NULL_VECTOR);
                
                float goal[3];
                goal = GetAbsOrigin(sentry);
                goal[0] -= (50.0 * dir[0]);
                goal[1] -= (50.0 * dir[1]);
                goal[2] -= (50.0 * dir[2]);
                
                if (IsPathToVectorPossible(actor, goal))
                    g_arrPluginBot[actor].SetPathGoalVector(goal);
                else
                    g_arrPluginBot[actor].SetPathGoalEntity(sentry);
                
                g_arrPluginBot[actor].bPathing = true;
            }
            
            if (dist < requiredDist) 
            {
                if (!myLoco.IsStuck())
                    g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
                
                EquipWeaponSlot(actor, TFWeaponSlot_Melee);
                UpdateLookAroundForEnemies(actor, false);
                
                if (lowAmmo && !needsWork)
                    AimHeadTowards(myBody, WorldSpaceCenter(sentry), CRITICAL, 1.0, _, "Reload my Sentry");
                else
                    AimHeadTowards(myBody, WorldSpaceCenter(sentry), CRITICAL, 1.0, _, "Work on my Sentry");
                
                VS_PressFireButton(actor);
            }
            
            return action.Continue();
        }
    }
    
    if (dispenser != INVALID_ENT_REFERENCE)
    {
        if (TF2_GetUpgradeLevel(dispenser) < 3 || BaseEntity_GetHealth(dispenser) < TF2Util_GetEntityMaxHealth(dispenser))
        {
            float dist = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(dispenser));
            float requiredDist = GetScaledDistance(actor, 90.0);
            
            if (m_ctRecomputePathMvMEngiIdle[actor] < GetGameTime()) 
            {
                m_ctRecomputePathMvMEngiIdle[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
                
                float dir[3];
                SubtractVectors(GetAbsAngles(dispenser), GetAbsOrigin(actor), dir);
                NormalizeVector(dir, dir);
                
                float goal[3];
                goal = GetAbsOrigin(dispenser);
                goal[0] -= (50.0 * dir[0]);
                goal[1] -= (50.0 * dir[1]);
                goal[2] -= (50.0 * dir[2]);
                
                if (IsPathToVectorPossible(actor, goal))
                    g_arrPluginBot[actor].SetPathGoalVector(goal);
                else
                    g_arrPluginBot[actor].SetPathGoalEntity(sentry);
                
                g_arrPluginBot[actor].bPathing = true;
            }
            
            if (dist < requiredDist) 
            {
                if (!myLoco.IsStuck())
                    g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
                
                EquipWeaponSlot(actor, TFWeaponSlot_Melee);
                UpdateLookAroundForEnemies(actor, false);
                AimHeadTowards(myBody, WorldSpaceCenter(dispenser), CRITICAL, 1.0, _, "Work on my Dispenser");
                VS_PressFireButton(actor);
            }
            
            return action.Continue();
        }
    }
    
    if (TF2_GetClientTeam(actor) == TFTeam_Red)
    {
        int teleporterExit = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
        if (teleporterExit != INVALID_ENT_REFERENCE)
        {
            if (TF2_GetUpgradeLevel(teleporterExit) < 3 || BaseEntity_GetHealth(teleporterExit) < TF2Util_GetEntityMaxHealth(teleporterExit))
            {
                float dist = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(teleporterExit));
                float requiredDist = GetScaledDistance(actor, 90.0);
                
                if (m_ctRecomputePathMvMEngiIdle[actor] < GetGameTime()) 
                {
                    m_ctRecomputePathMvMEngiIdle[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
                    
                    float dir[3];
                    SubtractVectors(GetAbsAngles(teleporterExit), GetAbsOrigin(actor), dir);
                    NormalizeVector(dir, dir);
                    
                    float goal[3];
                    goal = GetAbsOrigin(teleporterExit);
                    goal[0] -= (50.0 * dir[0]);
                    goal[1] -= (50.0 * dir[1]);
                    goal[2] -= (50.0 * dir[2]);
                    
                    if (IsPathToVectorPossible(actor, goal))
                        g_arrPluginBot[actor].SetPathGoalVector(goal);
                    else
                        g_arrPluginBot[actor].SetPathGoalEntity(teleporterExit);
                    
                    g_arrPluginBot[actor].bPathing = true;
                }
                
                if (dist < requiredDist) 
                {
                    if (!myLoco.IsStuck())
                        g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
                    
                    EquipWeaponSlot(actor, TFWeaponSlot_Melee);
                    UpdateLookAroundForEnemies(actor, false);
                    AimHeadTowards(myBody, WorldSpaceCenter(teleporterExit), CRITICAL, 1.0, _, "Work on Teleporter Exit");
                    VS_PressFireButton(actor);
                }
                
                return action.Continue();
            }
        }
    }
    
    // ============================================================
    // PRIORIDADE 2: CONSTRUIR O QUE FALTA
    // ============================================================

    if (sentry == INVALID_ENT_REFERENCE)
    {
        if (m_ctSentryCooldown[actor] < GetGameTime()) 
        {
            m_ctSentryCooldown[actor] = GetGameTime() + 3.0;
            return action.SuspendFor(CTFBotMvMEngineerBuildSentrygun(), "No sentry - building a new one");
        }
    }
    
    if (sentry != INVALID_ENT_REFERENCE && dispenser == INVALID_ENT_REFERENCE)
    {
        if (m_ctDispenserCooldown[actor] < GetGameTime())
        {
            m_ctDispenserCooldown[actor] = GetGameTime() + 3.0;
            return action.SuspendFor(CTFBotMvMEngineerBuildDispenser(), "No dispenser - building one");
        }
    }

    if (TF2_GetClientTeam(actor) == TFTeam_Red)
    {    
        if (sentry != INVALID_ENT_REFERENCE && dispenser != INVALID_ENT_REFERENCE)
        {
            int teleporterEntrance = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
            
            if (teleporterEntrance == INVALID_ENT_REFERENCE)
            {
                if (m_ctTeleporterEntranceCooldown[actor] < GetGameTime())
                {
                    m_ctTeleporterEntranceCooldown[actor] = GetGameTime() + 3.0;
                    return action.SuspendFor(CTFBotMvMEngineerBuildTeleporterEntrance(), "Building teleporter entrance");
                }
            }
        }
        
        if (sentry != INVALID_ENT_REFERENCE && dispenser != INVALID_ENT_REFERENCE)
        {
            int teleporterEntranceCheck = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
            
            if (teleporterEntranceCheck != INVALID_ENT_REFERENCE)
            {
                int teleporterExitCheck = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
                
                if (teleporterExitCheck == INVALID_ENT_REFERENCE && m_aNestArea[actor] != NULL_AREA)
                {
                    if (m_ctTeleporterExitCooldown[actor] < GetGameTime())
                    {
                        m_ctTeleporterExitCooldown[actor] = GetGameTime() + 3.0;
                        return action.SuspendFor(CTFBotMvMEngineerBuildTeleporterExit(), "Building teleporter exit");
                    }
                }
            }
        }
    }
    
    // ============================================================
    // PRIORIDADE 3: AJUDAR ENGENHEIROS ALIADOS
    // ============================================================
    if (!g_bIsHelpingTeammate[actor] && CTFBotMvMEngineerIdle_ShouldHelpTeammateEngineer(actor))
    {
        int teammateToHelp = CTFBotMvMEngineerIdle_FindTeammateEngineerToHelp(actor);
        
        if (teammateToHelp != -1)
        {
            g_bIsHelpingTeammate[actor] = true;
            CTFBotMvMEngineerIdle_HelpTeammateEngineer(actor, teammateToHelp);
            return action.Continue();
        }
    }
    
if (g_bIsHelpingTeammate[actor])
{
    if (g_bEngineerHelpDisabled[actor])
    {
        g_bIsHelpingTeammate[actor] = false;
    }
    else
    {
        int teammateToHelp = CTFBotMvMEngineerIdle_FindTeammateEngineerToHelp(actor);
        
        if (teammateToHelp != -1)
        {
            CTFBotMvMEngineerIdle_HelpTeammateEngineer(actor, teammateToHelp);
            return action.Continue();
        }
        else
        {
            g_bIsHelpingTeammate[actor] = false;
        }
    }
}
    
    // ============================================================
    // PRIORIDADE 4: WRANGLER
    // ============================================================
    if (sentry != -1 && dispenser != -1)
    {
        if (m_ctSentrySafe[actor] > GetGameTime() && !g_bGoingToGrabBuilding[actor])
        {
            int mySecondary = GetPlayerWeaponSlot(actor, TFWeaponSlot_Secondary);
            
            if (mySecondary != -1 && TF2Util_GetWeaponID(mySecondary) == TF_WEAPON_LASER_POINTER && myBot.IsRangeLessThan(sentry, 180.0))
            {
                CKnownEntity threat = myBot.GetVisionInterface().GetPrimaryKnownThreat(false);
                
                if (threat)
                {
                    int iThreat = threat.GetEntity();
                    
                    if (GetVectorDistance(GetAbsOrigin(sentry), GetAbsOrigin(iThreat)) > SENTRY_MAX_RANGE && IsLineOfFireClearEntity(actor, GetEyePosition(actor), iThreat))
                    {
                        AimHeadTowards(myBody, WorldSpaceCenter(iThreat), MANDATORY, 0.1, _, "Aiming!");
                        TF2Util_SetPlayerActiveWeapon(actor, mySecondary);
                        
                        if (myBody.IsHeadAimingOnTarget() && GetEntProp(sentry, Prop_Send, "m_bPlayerControlled"))
                            OSLib_RunScriptCode(actor, _, _, "self.PressFireButton(0.1);self.PressAltFireButton(0.1)");
                        
                        g_arrPluginBot[actor].bPathing = false;
                        return action.Continue();
                    }
                }
            }
        }
    }
    
    // ============================================================
    // PRIORIDADE 5: ATUALIZAR SENTRY SAFE
    // ============================================================
    if (m_aNestArea[actor] != NULL_AREA && sentry != INVALID_ENT_REFERENCE)
    {
        bool isMini = TF2_IsMiniBuilding(sentry);
        
        if (isMini)
        {
            if (BaseEntity_GetHealth(sentry) >= TF2Util_GetEntityMaxHealth(sentry) && !TF2_IsBuilding(sentry) && GetEntProp(sentry, Prop_Send, "m_iAmmoShells") > 50)
            {
                m_ctSentrySafe[actor] = GetGameTime() + 3.0;
            }
        }
        else
        {
            if (BaseEntity_GetHealth(sentry) >= TF2Util_GetEntityMaxHealth(sentry) && !TF2_IsBuilding(sentry) && TF2_GetUpgradeLevel(sentry) >= 3 && GetEntProp(sentry, Prop_Send, "m_iAmmoShells") > 50)
            {
                m_ctSentrySafe[actor] = GetGameTime() + 3.0;
            }
        }
        
        m_ctSentryCooldown[actor] = GetGameTime() + 3.0;
    }
    
// ============================================================
// PRIORIDADE 6: FICAR NA SENTRY
// ============================================================
if (sentry != INVALID_ENT_REFERENCE) 
{
    float dist = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(sentry));
    float requiredDist = GetScaledDistance(actor, 90.0);
    
    if (dist > requiredDist)
    {
        if (m_ctRecomputePathMvMEngiIdle[actor] < GetGameTime()) 
        {
            m_ctRecomputePathMvMEngiIdle[actor] = GetGameTime() + GetRandomFloat(1.0, 2.0);
            
            float vTurretAngles[3];
            GetTurretAngles(sentry, vTurretAngles);
            float dir[3];
            GetAngleVectors(vTurretAngles, dir, NULL_VECTOR, NULL_VECTOR);
            
            float goal[3];
            goal = GetAbsOrigin(sentry);
            goal[0] -= (50.0 * dir[0]);
            goal[1] -= (50.0 * dir[1]);
            goal[2] -= (50.0 * dir[2]);
            
            if (IsPathToVectorPossible(actor, goal))
                g_arrPluginBot[actor].SetPathGoalVector(goal);
            else
                g_arrPluginBot[actor].SetPathGoalEntity(sentry);
            
            g_arrPluginBot[actor].bPathing = true;
        }
        
        g_arrPluginBot[actor].bPathing = true;
        return action.Continue();
    }
    
    g_arrPluginBot[actor].bPathing = false;
    
    if (dist < requiredDist) 
    {
        if (!myLoco.IsStuck())
            g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
        
        EquipWeaponSlot(actor, TFWeaponSlot_Melee);
        UpdateLookAroundForEnemies(actor, false);
        AimHeadTowards(myBody, WorldSpaceCenter(sentry), CRITICAL, 1.0, _, "Work on my Sentry");
        VS_PressFireButton(actor);
    }
}

// FALLBACK: Se tudo está pronto e ele está longe da sentry, force pathing
if (sentry != INVALID_ENT_REFERENCE && dispenser != INVALID_ENT_REFERENCE)
{
    float dist = GetVectorDistance(GetAbsOrigin(actor), GetAbsOrigin(sentry));
    if (dist > 200.0 && !g_arrPluginBot[actor].bPathing)
    {
        g_arrPluginBot[actor].SetPathGoalEntity(sentry);
        g_arrPluginBot[actor].bPathing = true;
    }
}

return action.Continue();
}

static void CTFBotMvMEngineerIdle_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	g_arrPluginBot[actor].bPathing = false;
}

static Action CTFBotMvMEngineerIdle_OnMoveToSuccess(BehaviorAction action, int actor, any path, ActionDesiredResult result)
{
	CBaseNPC_GetNextBotOfEntity(actor).GetLocomotionInterface().ClearStuckStatus("Arrived at goal");
	
	return action.TryContinue();
}

static void CTFBotMvMEngineerIdle_ResetProperties(int actor)
{
	m_hBuildingToGrab[actor] = INVALID_ENT_REFERENCE;
	g_bGoingToGrabBuilding[actor] = false;
	g_bIsHelpingTeammate[actor] = false;
	m_flNextHelpCheck[actor] = 0.0;
	
	m_ctRecomputePathMvMEngiIdle[actor] = -1.0;
	
	m_ctSentrySafe[actor] = -1.0;
	m_ctSentryCooldown[actor] = -1.0;
	
	m_ctDispenserSafe[actor] = -1.0;
	m_ctDispenserCooldown[actor] = -1.0;

	m_ctTeleporterEntranceSafe[actor] = -1.0;
	m_ctTeleporterEntranceCooldown[actor] = -1.0;
	m_ctTeleporterExitSafe[actor] = -1.0;
	m_ctTeleporterExitCooldown[actor] = -1.0;

	m_ctFindNestHint[actor] = -1.0;
	m_ctAdvanceNestSpot[actor] = -1.0;
	
	g_arrPluginBot[actor].bPathing = true;
}

bool CTFBotMvMEngineerIdle_ShouldAdvanceNestSpot(int actor)
{
	if (m_aNestArea[actor] == NULL_AREA)
		return false;
	
	if (TF2_GetClientTeam(actor) == TFTeam_Blue)
		return false;
	
	if (m_ctAdvanceNestSpot[actor] <= 0.0)
	{
		m_ctAdvanceNestSpot[actor] = GetGameTime() + 5.0;
		return false;
	}
	
	int obj = GetObjectOfType(actor, TFObject_Sentry);
	
	if (obj != INVALID_ENT_REFERENCE && BaseEntity_GetHealth(obj) < TF2Util_GetEntityMaxHealth(obj))
	{
		m_ctAdvanceNestSpot[actor] = GetGameTime() + 5.0;
		return false;
	}
	
	if (GetGameTime() > m_ctAdvanceNestSpot[actor])
	{
		m_ctAdvanceNestSpot[actor] = -1.0;
	}
	
	BombInfo_t bombinfo;
	
	if (!GetBombInfo(bombinfo)) 
	{
		return false;
	}
	
	float m_flBombTargetDistance = GetTravelDistanceToBombTarget(m_aNestArea[actor]);
	
	if (m_flBombTargetDistance <= 1000.0)
	{
		return false;
	}
	
	bool bigger = (m_flBombTargetDistance > bombinfo.flMaxBattleFront);
	
	return bigger;
}

static bool CTFBotMvMEngineerIdle_ShouldHelpTeammateEngineer(int actor)
{
    if (g_bEngineerHelpDisabled[actor])
        return false;

    if (m_flNextHelpCheck[actor] > GetGameTime())
        return false;
    
    m_flNextHelpCheck[actor] = GetGameTime() + 2.0;
    
    if (TF2_GetPlayerClass(actor) != TFClass_Engineer)
        return false;
    
    int sentry = GetObjectOfType(actor, TFObject_Sentry);
    int dispenser = GetObjectOfType(actor, TFObject_Dispenser);
    
    if (sentry == -1 || dispenser == -1)
        return false;
    
    if (TF2_GetClientTeam(actor) == TFTeam_Red)
    {
        int teleporterEntrance = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Entrance);
        int teleporterExit = GetObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
        
        if (teleporterEntrance == -1 || teleporterExit == -1)
            return false;
        
        if (TF2_GetUpgradeLevel(teleporterExit) < 3 || BaseEntity_GetHealth(teleporterExit) < TF2Util_GetEntityMaxHealth(teleporterExit))
            return false;
    }
    
    if (TF2_GetUpgradeLevel(sentry) < 3 || BaseEntity_GetHealth(sentry) < TF2Util_GetEntityMaxHealth(sentry))
        return false;
    
    if (TF2_GetUpgradeLevel(dispenser) < 3 || BaseEntity_GetHealth(dispenser) < TF2Util_GetEntityMaxHealth(dispenser))
        return false;
    
    return true;
}

static int CTFBotMvMEngineerIdle_FindTeammateEngineerToHelp(int actor)
{
    int bestEngineer = -1;
    float bestDistance = 999999.0;
    float myOrigin[3];
    GetClientAbsOrigin(actor, myOrigin);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || i == actor)
            continue;
        
        if (TF2_GetPlayerClass(i) != TFClass_Engineer)
            continue;
        
        if (GetClientTeam(i) != GetClientTeam(actor))
            continue;
        
        bool needsHelp = false;
        
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
        {
            if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == i)
            {
                if (!TF2_IsMiniBuilding(ent))
                {
                    if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                    {
                        needsHelp = true;
                        break;
                    }
                }
            }
        }
        
        if (!needsHelp)
        {
            ent = -1;
            while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
            {
                if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == i)
                {
                    if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                    {
                        needsHelp = true;
                        break;
                    }
                }
            }
        }
        
        if (TF2_GetClientTeam(actor) == TFTeam_Red)
        {
            if (!needsHelp)
            {
                ent = -1;
                while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
                {
                    if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == i && TF2_GetObjectMode(ent) == TFObjectMode_Exit)
                    {
                        if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                        {
                            needsHelp = true;
                            break;
                        }
                    }
                }
            }
        }
        
        if (!needsHelp)
            continue;
        
        float theirOrigin[3];
        GetClientAbsOrigin(i, theirOrigin);
        float dist = GetVectorDistance(myOrigin, theirOrigin);
        
        if (dist < bestDistance)
        {
            bestDistance = dist;
            bestEngineer = i;
        }
    }
    
    return bestEngineer;
}

static int FindNearestSentryBuster(int client)
{
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    float bestDist = 999999.0;
    int bestBuster = -1;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        
        if (GetClientTeam(i) == GetClientTeam(client))
            continue;
        
        if (!IsSentryBusterRobot(i))
            continue;
        
        float busterPos[3];
        GetClientAbsOrigin(i, busterPos);
        float dist = GetVectorDistance(myPos, busterPos);
        
        if (dist < bestDist)
        {
            bestDist = dist;
            bestBuster = i;
        }
    }
    
    return bestBuster;
}

static void CTFBotMvMEngineerIdle_HelpTeammateEngineer(int actor, int targetEngineer)
{
    if (targetEngineer <= 0 || targetEngineer > MaxClients || !IsClientInGame(targetEngineer))
        return;
    
    int buildingToHelp = -1;
    float buildingOrigin[3];
    
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
    {
        if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == targetEngineer)
        {
            if (!TF2_IsMiniBuilding(ent))
            {
                if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                {
                    buildingToHelp = ent;
                    break;
                }
            }
        }
    }
    
    if (buildingToHelp == -1)
    {
        ent = -1;
        while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
        {
            if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == targetEngineer)
            {
                if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                {
                    buildingToHelp = ent;
                    break;
                }
            }
        }
    }
    
    if (TF2_GetClientTeam(actor) == TFTeam_Red)
    {
        if (buildingToHelp == -1)
        {
            ent = -1;
            while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
            {
                if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == targetEngineer && TF2_GetObjectMode(ent) == TFObjectMode_Exit)
                {
                    if (TF2_GetUpgradeLevel(ent) < 3 || BaseEntity_GetHealth(ent) < TF2Util_GetEntityMaxHealth(ent))
                    {
                        buildingToHelp = ent;
                        break;
                    }
                }
            }
        }
    }
    
    if (buildingToHelp == -1)
        return;
    
    INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
    IBody myBody = myBot.GetBodyInterface();
    ILocomotion myLoco = myBot.GetLocomotionInterface();
    
    GetEntPropVector(buildingToHelp, Prop_Send, "m_vecOrigin", buildingOrigin);
    float dist = GetVectorDistance(GetAbsOrigin(actor), buildingOrigin);
    float requiredDist = GetScaledDistance(actor, 70.0);
    
    EquipWeaponSlot(actor, TFWeaponSlot_Melee);
    
    if (dist > requiredDist)
    {
        if (m_ctRecomputePathMvMEngiIdle[actor] < GetGameTime())
        {
            m_ctRecomputePathMvMEngiIdle[actor] = GetGameTime() + GetRandomFloat(0.5, 1.0);
            g_arrPluginBot[actor].SetPathGoalVector(buildingOrigin);
            g_arrPluginBot[actor].bPathing = true;
        }
        
        g_arrPluginBot[actor].bPathing = true;
        return;
    }
    
    g_arrPluginBot[actor].bPathing = false;
    
    if (!myLoco.IsStuck())
        g_arrExtraButtons[actor].PressButtons(IN_DUCK, 0.1);
    
    UpdateLookAroundForEnemies(actor, false);
    
    float aimPos[3];
    GetEntPropVector(buildingToHelp, Prop_Send, "m_vecOrigin", aimPos);
    aimPos[2] += 30.0;
    
    AimHeadTowards(myBody, aimPos, CRITICAL, 0.5, _, "Helping teammate engineer");
    
    VS_PressFireButton(actor);
}