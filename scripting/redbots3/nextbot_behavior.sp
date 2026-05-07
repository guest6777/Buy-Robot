#define ACTION_HEAL_PATIENT_OFFSET	0x4850

#define FLAMETHROWER_REACH_RANGE	350.0
#define FLAMEBALL_REACH_RANGE	526.0

PathFollower m_pPath[MAXPLAYERS + 1];
ChasePath m_pChasePath[MAXPLAYERS + 1];
float m_flRepathTime[MAXPLAYERS + 1];

static int m_nCurrentPowerupBottle[MAXPLAYERS + 1];
static float m_flNextBottleUseTime[MAXPLAYERS + 1];

#if defined EXTRA_PLUGINBOT
enum struct esPluginBot
{
	bool bPathing;
	float vecPathGoal[3];
	int iPathGoalEntity;
	
	void Reset()
	{
		this.bPathing = false;
		this.vecPathGoal = NULL_VECTOR;
		this.iPathGoalEntity = -1;
	}
	
	bool HasPathGoalVector()
	{
		return !Vector_IsZero(this.vecPathGoal);
	}
	
	bool HasPathGoalEntity()
	{
		return this.iPathGoalEntity != -1;
	}
	
	void SetPathGoalVector(const float vec[3])
	{
		this.iPathGoalEntity = -1;
		this.vecPathGoal = vec;
	}
	
	void SetPathGoalEntity(int entity)
	{
		this.vecPathGoal = NULL_VECTOR;
		this.iPathGoalEntity = entity;
	}
}

esPluginBot g_arrPluginBot[MAXPLAYERS + 1];
#endif

bool IsValidBot(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    if (TF2_GetClientTeam(client) == TFTeam_Blue)
        return g_bBuyIsPurchasedRobot[client];
    
    return (g_bIsDefenderBot[client] || g_bBuyIsPurchasedRobot[client]);
}

#include "behavior/attack.sp"
#include "behavior/markgiant.sp"
#include "behavior/collectmoney.sp"
#include "behavior/gotoupgrade.sp"
#include "behavior/upgrade.sp"
#include "behavior/getammo.sp"
#include "behavior/movetofront.sp"
#include "behavior/gethealth.sp"
#include "behavior/engineeridle.sp"
#include "behavior/engineerbuildsentrygun.sp"
#include "behavior/engineerbuilddispenser.sp"
#include "behavior/engineerbuildteleporter.sp"
#include "behavior/spylurk.sp"
#include "behavior/spysap.sp"
#include "behavior/spysapplayer.sp"
#include "behavior/medicrevive.sp"
#include "behavior/attackforuber.sp"
#include "behavior/evadebuster.sp"
#include "behavior/campbomb.sp"
#include "behavior/attacktank.sp"
#include "behavior/destroyteleporter.sp"
#include "behavior/guardpoint.sp"
#include "behavior/collectnearmoney.sp"

void InitNextBotPathing()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		m_pPath[i] = PathFollower(_, Path_FilterIgnoreActors, Path_FilterOnlyActors);
		m_pChasePath[i] = ChasePath(LEAD_SUBJECT, _, Path_FilterIgnoreActors, Path_FilterOnlyActors);
	}
}

void ResetNextBot(int client)
{
	m_flRepathTime[client] = 0.0;
	
	m_nCurrentPowerupBottle[client] = POWERUP_BOTTLE_NONE;
	m_flNextBottleUseTime[client] = 0.0;
	
	m_iAttackTarget[client] = -1;
	m_iTarget[client] = -1;
	m_flNextMarkTime[client] = 0.0;
	m_iCurrencyPack[client] = -1;
	m_iStation[client] = -1;
	m_flNextUpgrade[client] = 0.0;
	m_nPurchasedUpgrades[client] = 0;
	m_flUpgradingTime[client] = 0.0;
	m_iAmmoPack[client] = -1;
	m_vecGoalArea[client] = NULL_VECTOR;
	m_ctMoveTimeout[client] = 0.0;
	m_iHealthPack[client] = -1;
	m_iSapTarget[client] = -1;
	m_iPlayerSapTarget[client] = -1;
	m_vecStartArea[client] = NULL_VECTOR;
	m_iTankTarget[client] = -1;
	m_iTeleporterTarget[client] = -1;
	m_vecPointDefendArea[client] = NULL_VECTOR;
	
#if defined EXTRA_PLUGINBOT
	g_arrPluginBot[client].Reset();
#endif
}

#if defined EXTRA_PLUGINBOT
void PluginBot_SimulateFrame(int client)
{
	if (g_arrPluginBot[client].bPathing)
	{
		if (TF2_GetPlayerClass(client) == TFClass_Engineer)
		{
			if (ActionsManager.LookupEntityActionByName(client, "DefenderGetAmmo") != INVALID_ACTION || ActionsManager.LookupEntityActionByName(client, "DefenderGetHealth") != INVALID_ACTION)
				return;
		}
		
		bool shouldPathToVec = g_arrPluginBot[client].HasPathGoalVector();
		bool shouldPathToEntity = g_arrPluginBot[client].HasPathGoalEntity();
		
		if (shouldPathToVec || shouldPathToEntity)
		{
			INextBot myBot = CBaseNPC_GetNextBotOfEntity(client);
			
			if (m_flRepathTime[client] <= GetGameTime())
			{
				CBaseCombatCharacter(client).UpdateLastKnownArea();
				
				if (shouldPathToVec)
					m_pPath[client].ComputeToPos(myBot, g_arrPluginBot[client].vecPathGoal);
				else if (shouldPathToEntity)
					m_pPath[client].ComputeToTarget(myBot, g_arrPluginBot[client].iPathGoalEntity);
				
				m_flRepathTime[client] = GetGameTime() + 0.2;
			}
			
			m_pPath[client].Update(myBot);
		}
	}
}
#endif

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (actor <= MaxClients)
	{
		if (StrEqual(name, "MainAction"))
		{
			action.SelectTargetPoint = CTFBotMainAction_SelectTargetPoint;
			action.ShouldAttack = CTFBotMainAction_ShouldAttack;
		}
		else if (StrEqual(name, "TacticalMonitor"))
		{
			action.Update = CTFBotTacticalMonitor_Update;
			action.SelectMoreDangerousThreat = CTFBotMainAction_SelectMoreDangerousThreat;
		}
		else if (StrEqual(name, "ScenarioMonitor"))
		{
			action.Update = CTFBotScenarioMonitor_Update;
		}
		else if (StrEqual(name, "Heal"))
		{
			action.UpdatePost = CTFBotMedicHeal_UpdatePost;
		}
		else if (StrEqual(name, "FetchFlag"))
		{
			action.OnStart = CTFBotFetchFlag_OnStart;
		}
		else if (StrEqual(name, "MvMEngineerIdle"))
		{
			action.OnStart = CTFBotMvMEngineerIdle_OnStart;
		}
		else if (StrEqual(name, "SniperLurk"))
		{
			action.Update = CTFBotSniperLurk_Update;
			action.SelectMoreDangerousThreat = CTFBotSniperLurk_SelectMoreDangerousThreat;
		}
		else if (StrEqual(name, "SpyLeaveSpawnRoom"))
		{
			action.OnStart = CTFBotSpyLeaveSpawnRoom_OnStart;
		}
	}
}

public Action CTFBotMainAction_SelectMoreDangerousThreat(BehaviorAction action, INextBot nextbot, int entity, CKnownEntity threat1, CKnownEntity threat2, CKnownEntity& knownEntity)
{
    int me = action.Actor;
    
    if (!IsValidBot(me))
        return Plugin_Continue;
    
    int iThreat1 = threat1.GetEntity();
    int iThreat2 = threat2.GetEntity();
    
    int myWeapon = BaseCombatCharacter_GetActiveWeapon(me);
    
    if (myWeapon != -1 && (TF2Util_GetWeaponID(myWeapon) == TF_WEAPON_FLAMETHROWER || IsMeleeWeapon(myWeapon)))
    {
        knownEntity = SelectCloserThreat(nextbot, threat1, threat2);
        return Plugin_Changed;
    }
    
    int oneVisible = FindOnlyOneVisibleEntity(me, iThreat1, iThreat2);
    
    if (oneVisible == iThreat1)
    {
        knownEntity = threat1;
        return Plugin_Changed;
    }
    
    if (oneVisible == iThreat2)
    {
        knownEntity = threat2;
        return Plugin_Changed;
    }
    
    if (myWeapon != -1 && TF2Util_GetWeaponID(myWeapon) == TF_WEAPON_MINIGUN)
    {
        if (TF2_IsRageDraining(me))
        {
            if (BaseEntity_IsPlayer(iThreat1) && (TF2_HasTheFlag(iThreat1) || TF2_IsMiniBoss(iThreat1)))
            {
                knownEntity = threat1;
                return Plugin_Changed;
            }
            
            if (BaseEntity_IsPlayer(iThreat2) && (TF2_HasTheFlag(iThreat2) || TF2_IsMiniBoss(iThreat2)))
            {
                knownEntity = threat2;
                return Plugin_Changed;
            }
        }
        
        if (IsBaseBoss(iThreat1) && !IsBaseBoss(iThreat2))
        {
            knownEntity = threat2;
            return Plugin_Changed;
        }
        
        if (!IsBaseBoss(iThreat1) && IsBaseBoss(iThreat2))
        {
            knownEntity = threat1;
            return Plugin_Changed;
        }
    }
    
    float rangeSq1 = nextbot.GetRangeSquaredTo(iThreat1);
    float rangeSq2 = nextbot.GetRangeSquaredTo(iThreat2);
    
    if (rangeSq1 < rangeSq2)
    {
        knownEntity = threat1;
    }
    else
    {
        knownEntity = threat2;
    }
    
    if (BaseEntity_IsPlayer(knownEntity.GetEntity()))
    {
        knownEntity = GetHealerOfThreat(nextbot, knownEntity);
    }
    
    return Plugin_Changed;
}

public Action CTFBotMainAction_SelectTargetPoint(BehaviorAction action, INextBot nextbot, int entity, float vec[3])
{
	int me = action.Actor;
	
	if (!IsValidBot(me))
		return Plugin_Continue;
	
	int myWeapon = BaseCombatCharacter_GetActiveWeapon(me);
	
	if (myWeapon != -1)
	{
		switch (TF2Util_GetWeaponID(myWeapon))
		{
			case TF_WEAPON_GRENADELAUNCHER, TF_WEAPON_PIPEBOMBLAUNCHER:
			{
				float target_point[3];
				
				target_point = WorldSpaceCenter(entity);
				float vecTarget[3], vecActor[3];
				vecTarget = GetAbsOrigin(entity);
				GetClientAbsOrigin(me, vecActor);
				
				float distance = GetVectorDistance(vecTarget, vecActor);
				
				if (distance > 150.0)
				{
					distance = distance / GetProjectileSpeed(myWeapon);
					
					float absVelocity[3]; CBaseEntity(entity).GetAbsVelocity(absVelocity);
					
					target_point[0] = vecTarget[0] + absVelocity[0] * distance;
					target_point[1] = vecTarget[1] + absVelocity[1] * distance;
					target_point[2] = vecTarget[2] + absVelocity[2] * distance;
				}
				else
				{
					target_point = WorldSpaceCenter(entity);
				}
				
				float vecToTarget[3]; SubtractVectors(target_point, vecActor, vecToTarget);
				
				float a5 = NormalizeVector(vecToTarget, vecToTarget);
				
				float ballisticElevation = 0.0125 * a5;
				
				if (ballisticElevation > 45.0)
					ballisticElevation = 45.0;
				
				float elevation = ballisticElevation * (FLOAT_PI / 180.0);
				float sineValue = Sine(elevation);
				float cosineValue = Cosine(elevation);
				
				if (cosineValue != 0.0)
					target_point[2] += (sineValue * a5) / cosineValue;
				
				vec = target_point;
				
				return Plugin_Changed;
			}
			case TF_WEAPON_PARTICLE_CANNON:
			{
				float target_point[3];
				
				float vecTarget[3], vecActor[3];
				vecTarget = GetAbsOrigin(entity);
				vecActor = GetAbsOrigin(me);
				
				float distance = GetVectorDistance(vecTarget, vecActor);
				
				if (distance > 150.0)
				{
					distance = distance * 0.00090909092;
					
					float absVelocity[3]; CBaseEntity(entity).GetAbsVelocity(absVelocity);
					
					target_point[0] = vecTarget[0] + absVelocity[0] * distance;
					target_point[1] = vecTarget[1] + absVelocity[1] * distance;
					target_point[2] = vecTarget[2] + absVelocity[2] * distance;
					
					if (!IsLineOfFireClearPosition(me, GetEyePosition(me), target_point))
					{
						vecTarget = WorldSpaceCenter(entity);
						
						target_point[0] = vecTarget[0] + absVelocity[0] * distance;
						target_point[1] = vecTarget[1] + absVelocity[1] * distance;
						target_point[2] = vecTarget[2] + absVelocity[2] * distance;
					}
				}
				else
				{
					target_point = WorldSpaceCenter(entity);
				}
				
				vec = target_point;
				
				return Plugin_Changed;
			}
			case TF_WEAPON_SNIPERRIFLE, TF_WEAPON_SNIPERRIFLE_DECAP, TF_WEAPON_SNIPERRIFLE_CLASSIC:
			{
				int bone = LookupBone(entity, "bip_head");
				
				if (bone != -1)
				{
					float vEmpty[3];
					GetBonePosition(entity, bone, vec, vEmpty);
					vec[2] += 3.0;
					
					return Plugin_Changed;
				}
			}
			case TF_WEAPON_REVOLVER:
			{
				if (CanRevolverHeadshot(myWeapon))
				{
					int bone = LookupBone(entity, "bip_head");
					
					if (bone != -1)
					{
						float vEmpty[3];
						GetBonePosition(entity, bone, vec, vEmpty);
						vec[2] += 3.0;
						
						return Plugin_Changed;
					}
					
					vec = GetEyePosition(entity);
					
					return Plugin_Changed;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

static Action CTFBotMainAction_ShouldAttack(BehaviorAction action, INextBot nextbot, CKnownEntity knownEntity, QueryResultType& result)
{
	int me = action.Actor;
	
	if (!IsValidBot(me))
		return Plugin_Continue;
	
	result = ANSWER_YES;
	return Plugin_Changed;
}

public Action CTFBotTacticalMonitor_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (!IsValidBot(actor))
		return Plugin_Continue;
	
	if (TF2_IsInUpgradeZone(actor) && ActionsManager.LookupEntityActionByName(actor, "DefenderUpgrade") != INVALID_ACTION)
	{
		TFClassType iClass = TF2_GetPlayerClass(actor);
		
		if (iClass == TFClass_DemoMan || iClass == TFClass_Scout)
		{
			CountdownTimer pOpportunisticTimer = CountdownTimer(GetOpportunisticTimer(actor));
			
			if (pOpportunisticTimer.Address)
			{
				pOpportunisticTimer.Start(interval);
			}
		}
		
		return Plugin_Continue;
	}
	
	if (!ShouldUseTeleporter(actor))
	{
		CountdownTimer pFindTeleporterTimer = CountdownTimer(view_as<Address>(view_as<int>(action) + 0x70));
		
		if (pFindTeleporterTimer.Address)
		{
			pFindTeleporterTimer.Start(interval);
		}
	}
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		bool low_health = false;
		
		float health_ratio = float(GetClientHealth(actor)) / float(TEMP_GetPlayerMaxHealth(actor));
		
		if ((GetTimeSinceWeaponFired(actor) > 2.0 || TF2_GetPlayerClass(actor) == TFClass_Sniper) && health_ratio < tf_bot_health_critical_ratio.FloatValue)
			low_health = true;
		else if (health_ratio < tf_bot_health_ok_ratio.FloatValue)
			low_health = true;
		
		if (low_health && CTFBotGetHealth_IsPossible(actor))
			return action.SuspendFor(CTFBotGetHealth(), "Getting health");
		else
		{
			int primary = GetPlayerWeaponSlot(actor, TFWeaponSlot_Primary);
			
			if (primary != -1 && TF2Util_GetWeaponID(primary) == TF_WEAPON_FLAMETHROWER && (TF2_IsCritBoosted(actor) || TF2_IsPlayerInCondition(actor, TFCond_CritMmmph)))
			{
				if (!HasAmmo(primary) && CTFBotGetAmmo_IsPossible(actor))
					return action.SuspendFor(CTFBotGetAmmo(), "Get ammo for crit");
			}
			else if (IsAmmoLow(actor) && CTFBotGetAmmo_IsPossible(actor))
			{
				return action.SuspendFor(CTFBotGetAmmo(), "Getting ammo");
			}
		}
	}
	
	return Plugin_Continue;
}

public Action CTFBotScenarioMonitor_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
    if (actor <= 0 || actor > MaxClients || !IsClientInGame(actor))
    {
        return Plugin_Continue;
    }
    
    if (TF2_GetClientTeam(actor) == TFTeam_Blue && !g_bBuyIsPurchasedRobot[actor])
        return Plugin_Continue;
    
    if (!IsValidBot(actor))
        return Plugin_Continue;
    
    return GetDesiredBotAction(actor, action);
}

public Action CTFBotMedicHeal_UpdatePost(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (!IsValidBot(actor))
		return Plugin_Continue;
	
	if (result.type == CHANGE_TO)
	{
		BehaviorAction resultingAction = result.action;
		char name[ACTION_NAME_LENGTH]; resultingAction.GetName(name);
		
		if (StrEqual(name, "FetchFlag"))
			return action.SuspendFor(CTFBotDefenderAttack(), "Stop the bomb");
	}
	
	int secondary = GetPlayerWeaponSlot(actor, TFWeaponSlot_Secondary);
	
	if (secondary == -1)
		return action.SuspendFor(CTFBotDefenderAttack(), "No medigun");
	
	if (CTFBotAttackUber_IsPossible(actor, secondary))
		return action.SuspendFor(CTFBotAttackUber(), "Seek uber");
	
	if (CTFBotMedicRevive_IsPossible(actor))
		return action.SuspendFor(CTFBotMedicRevive(), "Revive teammate");
	
	int myWeapon = BaseCombatCharacter_GetActiveWeapon(actor);
	
	if (myWeapon != -1 && TF2Util_GetWeaponID(myWeapon) == TF_WEAPON_MEDIGUN && GetMedigunType(myWeapon) == MEDIGUN_RESIST)
	{
		int myPatient = action.GetHandleEntity(ACTION_HEAL_PATIENT_OFFSET);
		
		if (myPatient > 0)
		{
			int iResistType = GetResistType(myWeapon);
			int iLastDmgType = GetLastDamageType(myPatient);
			
			if (iLastDmgType & DMG_BULLET && iResistType != MEDIGUN_BULLET_RESIST)
				g_arrExtraButtons[actor].PressButtons(IN_RELOAD);
			else if (iLastDmgType & DMG_BLAST && iResistType != MEDIGUN_BLAST_RESIST)
				g_arrExtraButtons[actor].PressButtons(IN_RELOAD);
			else if (iLastDmgType & DMG_BURN && iResistType != MEDIGUN_FIRE_RESIST)
				g_arrExtraButtons[actor].PressButtons(IN_RELOAD);
		}
	}
	
	return Plugin_Continue;
}

public Action CTFBotFetchFlag_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    if (!IsValidBot(actor))
    {
        return Plugin_Continue;
    }
    
    if (g_bBuyIsPurchasedRobot[actor] && TF2_GetClientTeam(actor) == TFTeam_Blue)
    {
        return action.Done();
    }
    
    return Plugin_Continue;
}

public Action CTFBotMvMEngineerIdle_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	if (!IsValidBot(actor))
		return Plugin_Continue;
	
	return action.Done();
}

public Action CTFBotSniperLurk_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (!IsValidBot(actor))
		return Plugin_Continue;
	
	if (!CanUsePrimayWeapon(actor))
	{
		return action.SuspendFor(CTFBotDefenderAttack(), "Lost my rifle");
	}
	
	return Plugin_Continue;
}

public Action CTFBotSniperLurk_SelectMoreDangerousThreat(BehaviorAction action, INextBot nextbot, int entity, CKnownEntity threat1, CKnownEntity threat2, CKnownEntity& knownEntity)
{
	int me = action.Actor;
	
	if (!IsValidBot(me))
		return Plugin_Continue;
	
	knownEntity = NULL_KNOWN_ENTITY;
	
	int iThreat1 = threat1.GetEntity();
	
	if (BaseEntity_IsPlayer(iThreat1) && IsLineOfFireClearEntity(me, GetEyePosition(me), iThreat1))
	{
		int enemyWeapon = BaseCombatCharacter_GetActiveWeapon(iThreat1);
		
		if (enemyWeapon != -1)
		{
			int enemyWepID = TF2Util_GetWeaponID(enemyWeapon);
			
			if (WeaponID_IsSniperRifle(enemyWepID))
			{
				knownEntity = threat1;
				return Plugin_Changed;
			}
			else if (enemyWepID == TF_WEAPON_MEDIGUN)
			{
				if (GetEntPropEnt(enemyWeapon, Prop_Send, "m_hHealingTarget") != -1 || GetEntPropFloat(enemyWeapon, Prop_Send, "m_flChargeLevel") >= 1.0)
				{
					knownEntity = threat1;
					return Plugin_Changed;
				}
			}
		}
	}
	
	int iThreat2 = threat2.GetEntity();
	
	if (BaseEntity_IsPlayer(iThreat2) && IsLineOfFireClearEntity(me, GetEyePosition(me), iThreat2))
	{
		int enemyWeapon = BaseCombatCharacter_GetActiveWeapon(iThreat2);
		
		if (enemyWeapon != -1)
		{
			int enemyWepID = TF2Util_GetWeaponID(enemyWeapon);
			
			if (WeaponID_IsSniperRifle(enemyWepID))
			{
				knownEntity = threat2;
				return Plugin_Changed;
			}
			else if (enemyWepID == TF_WEAPON_MEDIGUN)
			{
				if (GetEntPropEnt(enemyWeapon, Prop_Send, "m_hHealingTarget") != -1 || GetEntPropFloat(enemyWeapon, Prop_Send, "m_flChargeLevel") >= 1.0)
				{
					knownEntity = threat2;
					return Plugin_Changed;
				}
			}
		}
	}
	
	return Plugin_Changed;
}

public Action CTFBotSpyLeaveSpawnRoom_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	if (!IsValidBot(actor))
		return Plugin_Continue;
	
	return action.Done();
}

Action GetDesiredBotAction(int client, BehaviorAction action)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return Plugin_Continue;
    }
    
    if (TF2_GetClientTeam(client) == TFTeam_Blue && !g_bBuyIsPurchasedRobot[client])
        return Plugin_Continue;
    
    if (!IsValidBot(client))
        return Plugin_Continue;
    
    RoundState state = GameRules_GetRoundState();
    TFTeam team = TF2_GetClientTeam(client);
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (team == TFTeam_Blue)
    {
        if (state == RoundState_BetweenRounds)
        {
            if (isGiant || isBoss)
            {
                if (TF2_GetPlayerClass(client) == TFClass_Engineer)
                {
                    SetPlayerReady(client, true);
                    return action.SuspendFor(CTFBotMvMEngineerIdle(), "Engineer building (giant)");
                }
                
                if (TF2_GetPlayerClass(client) == TFClass_Medic)
                {
                    SetPlayerReady(client, true);
                    return Plugin_Continue;
                }
                
                if (HasSniperRifle(client))
                {
                    SetPlayerReady(client, true);
                    return Plugin_Continue;
                }
                
                if (TF2_GetPlayerClass(client) == TFClass_Spy)
                {
                    SetPlayerReady(client, true);
                    return action.SuspendFor(CTFBotSpyLurkMvM(), "Spy lurking (giant)");
                }
                
                SetPlayerReady(client, true);
                return action.SuspendFor(CTFBotMoveToFront(), "Skip upgrading (giant robot)");
            }
            
            SetPlayerReady(client, true);
            return action.SuspendFor(CTFBotMoveToFront(), "BLUE team - no upgrades");
        }
        else if (state == RoundState_RoundRunning)
        {
            switch (TF2_GetPlayerClass(client))
            {
                case TFClass_Medic:
                {
                    return Plugin_Continue;
                }
                case TFClass_Scout:
                {
                    if (CTFBotMarkGiant_IsPossible(client))
                        return action.SuspendFor(CTFBotMarkGiant(), "Marking giant");
                    else if (CTFBotAttackTank_SelectTarget(client))
                        return action.SuspendFor(CTFBotAttackTank(), "Scout: Attacking tank");
                    else if (CTFBotDefenderAttack_SelectTarget(client))
                        return action.SuspendFor(CTFBotDefenderAttack(), "Scout: Attacking robots");
                }
                case TFClass_Sniper:
                {
                    if (HasSniperRifle(client))
                    {
                        return Plugin_Continue;
                    }
                    else
                    {
                        return action.SuspendFor(CTFBotDefenderAttack(), "Sniper Attacking robots");
                    }
                }
                case TFClass_Engineer:
                {
                    return action.SuspendFor(CTFBotMvMEngineerIdle(), "Engineer Start building");
                }
                case TFClass_Spy:
                {
                    return action.SuspendFor(CTFBotSpyLurkMvM(), "Spy do be lurking");
                }
                case TFClass_Heavy:
                {
                    if (CTFBotDefenderAttack_SelectTarget(client))
                        return action.SuspendFor(CTFBotDefenderAttack(), "CTFBotAttack_IsPossible");
                    else if (CTFBotAttackTank_SelectTarget(client))
                        return action.SuspendFor(CTFBotAttackTank(), "Attacking tank");
                }
                case TFClass_Pyro, TFClass_Soldier, TFClass_DemoMan:
                {
                    if (CTFBotAttackTank_SelectTarget(client))
                        return action.SuspendFor(CTFBotAttackTank(), "Attacking tank");
                    else if (CTFBotDefenderAttack_SelectTarget(client))
                        return action.SuspendFor(CTFBotDefenderAttack(), "CTFBotAttack_IsPossible");
                }
            }
        }
        
        return Plugin_Continue;
    }
    
    if (state == RoundState_BetweenRounds)
    {
        if (CTFBotCollectMoney_IsPossible(client))
        {
            return action.SuspendFor(CTFBotCollectMoney(), "Is possible");
        }
        else if (!TF2_IsInUpgradeZone(client) && !IsPlayerReady(client) && ActionsManager.LookupEntityActionByName(client, "DefenderMoveToFront") == INVALID_ACTION)
        {
            if (isGiant || isBoss)
            {
                if (TF2_GetPlayerClass(client) == TFClass_Engineer)
                {
                    SetPlayerReady(client, true);
                    return action.SuspendFor(CTFBotMvMEngineerIdle(), "Engineer building (giant)");
                }
                
                if (TF2_GetPlayerClass(client) == TFClass_Medic)
                {
                    SetPlayerReady(client, true);
                    return Plugin_Continue;
                }
                
                if (HasSniperRifle(client))
                {
                    SetPlayerReady(client, true);
                    return Plugin_Continue;
                }
                
                if (TF2_GetPlayerClass(client) == TFClass_Spy)
                {
                    SetPlayerReady(client, true);
                    return action.SuspendFor(CTFBotSpyLurkMvM(), "Spy lurking (giant)");
                }
                
                SetPlayerReady(client, true);
                return action.SuspendFor(CTFBotMoveToFront(), "Skip upgrading (giant robot)");
            }
            
            if (g_bBuyIsPurchasedRobot[client])
            {
                ConVar buyUseUpgrades = FindConVar("sm_buyrobot_use_upgrades");
                bool canUseUpgrades = (buyUseUpgrades != null && buyUseUpgrades.BoolValue);
                
                if (canUseUpgrades)
                {
                    return action.SuspendFor(CTFBotGotoUpgrade(), "Buying upgrades (purchased robot)");
                }
                else
                {
                    if (TF2_GetPlayerClass(client) == TFClass_Engineer)
                    {
                        SetPlayerReady(client, true);
                        return action.SuspendFor(CTFBotMvMEngineerIdle(), "Engineer building (purchased)");
                    }
                    
                    if (TF2_GetPlayerClass(client) == TFClass_Medic)
                    {
                        SetPlayerReady(client, true);
                        return Plugin_Continue;
                    }
                    
                    if (HasSniperRifle(client))
                    {
                        SetPlayerReady(client, true);
                        return Plugin_Continue;
                    }
                    
                    if (TF2_GetPlayerClass(client) == TFClass_Spy)
                    {
                        SetPlayerReady(client, true);
                        return action.SuspendFor(CTFBotSpyLurkMvM(), "Spy lurking (purchased)");
                    }
                    
                    SetPlayerReady(client, true);
                    return action.SuspendFor(CTFBotMoveToFront(), "Skip upgrading (purchased robot)");
                }
            }
            
            if (redbots_manager_bot_use_upgrades.BoolValue)
            {
                return action.SuspendFor(CTFBotGotoUpgrade(), "!IsInUpgradeZone && RoundState_BetweenRounds");
            }
            else
            {
                SetPlayerReady(client, true);
                return action.SuspendFor(CTFBotMoveToFront(), "Skip upgrading");
            }
        }
    }
    else if (state == RoundState_RoundRunning)
    {
        bool shouldUpgrade = false;
        
        if (redbots_manager_bot_use_upgrades.BoolValue && (g_bHasUpgraded[client] == false || ShouldUpgradeMidRound(client)) && !TF2_IsInUpgradeZone(client))
        {
            shouldUpgrade = true;
        }
        
        if (isGiant || isBoss)
        {
        }
        else if (g_bBuyIsPurchasedRobot[client])
        {
            ConVar buyUseUpgrades = FindConVar("sm_buyrobot_use_upgrades");
            bool canUseUpgrades = (buyUseUpgrades != null && buyUseUpgrades.BoolValue);
            
            if (canUseUpgrades && (g_bHasUpgraded[client] == false || ShouldUpgradeMidRound(client)) && !TF2_IsInUpgradeZone(client))
            {
                g_iBuyUpgradesNumber[client] = 0;
                return action.SuspendFor(CTFBotGotoUpgrade(), "Buy upgrades now (purchased robot)");
            }
        }
        else if (shouldUpgrade)
        {
            g_iBuyUpgradesNumber[client] = 0;
            return action.SuspendFor(CTFBotGotoUpgrade(), "Buy upgrades now");
        }
        
        switch (TF2_GetPlayerClass(client))
        {
            case TFClass_Medic:
            {
                return Plugin_Continue;
            }
            case TFClass_Scout:
            {
                if (CTFBotCollectMoney_IsPossible(client))
                    return action.SuspendFor(CTFBotCollectMoney(), "Collecting money");
                else if (CTFBotMarkGiant_IsPossible(client))
                    return action.SuspendFor(CTFBotMarkGiant(), "Marking giant");
                else if (CTFBotAttackTank_SelectTarget(client))
                    return action.SuspendFor(CTFBotAttackTank(), "Scout: Attacking tank");
                else if (CTFBotDefenderAttack_SelectTarget(client))
                    return action.SuspendFor(CTFBotDefenderAttack(), "Scout: Attacking robots");
            }
            case TFClass_Sniper:
            {
                if (HasSniperRifle(client))
                {
                    return Plugin_Continue;
                }
                else
                {
                    return action.SuspendFor(CTFBotDefenderAttack(), "Sniper Attacking robots");
                }
            }
            case TFClass_Engineer:
            {
                return action.SuspendFor(CTFBotMvMEngineerIdle(), "Engineer Start building");
            }
            case TFClass_Spy:
            {
                return action.SuspendFor(CTFBotSpyLurkMvM(), "Spy do be lurking");
            }
            case TFClass_Heavy:
            {
                if (CTFBotDefenderAttack_SelectTarget(client))
                    return action.SuspendFor(CTFBotDefenderAttack(), "CTFBotAttack_IsPossible");
                else if (CTFBotAttackTank_SelectTarget(client))
                    return action.SuspendFor(CTFBotAttackTank(), "Attacking tank");
                else if (CTFBotCollectNearMoney_SelectTarget(client))
                    return action.SuspendFor(CTFBotCollectNearMoney(), "Nearby money");
            }
            case TFClass_Pyro, TFClass_Soldier, TFClass_DemoMan:
            {
                if (CTFBotAttackTank_SelectTarget(client))
                    return action.SuspendFor(CTFBotAttackTank(), "Attacking tank");
                else if (CTFBotDefenderAttack_SelectTarget(client))
                    return action.SuspendFor(CTFBotDefenderAttack(), "CTFBotAttack_IsPossible");
                else if (CTFBotCollectNearMoney_SelectTarget(client))
                    return action.SuspendFor(CTFBotCollectNearMoney(), "Nearby money");
            }
        }
    }
    
    return Plugin_Continue;
}

Action GetUpgradePostAction(int client, BehaviorAction action)
{
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    bool isGiant = (StrContains(clientName, "Giant") != -1);
    bool isBoss = (StrContains(clientName, "Boss") != -1);
    
    if (isGiant || isBoss)
    {
        if (GameRules_GetRoundState() == RoundState_BetweenRounds)
        {
            if (TF2_GetPlayerClass(client) == TFClass_Engineer)
            {
                SetPlayerReady(client, true);
                return action.ChangeTo(CTFBotMvMEngineerIdle(), "Start building");
            }
            else if (TF2_GetPlayerClass(client) == TFClass_Medic)
                return action.Done("Start heal mission");
            else if (TF2_GetPlayerClass(client) == TFClass_Spy)
                return action.ChangeTo(CTFBotSpyLurkMvM(), "Start spy lurking");
            else if (HasSniperRifle(client))
                return action.Done("Start lurking");
            else
                return action.ChangeTo(CTFBotMoveToFront(), "Skip upgrades; Move to front");
        }
        return action.Done("Skipped upgrades (giant robot)");
    }
    
    if (g_bBuyIsPurchasedRobot[client])
    {
        ConVar buyUseUpgrades = FindConVar("sm_buyrobot_use_upgrades");
        bool canUseUpgrades = (buyUseUpgrades != null && buyUseUpgrades.BoolValue);
        
        if (!canUseUpgrades)
        {
            if (GameRules_GetRoundState() == RoundState_BetweenRounds)
            {
                if (TF2_GetPlayerClass(client) == TFClass_Engineer)
                    return action.ChangeTo(CTFBotMvMEngineerIdle(), "Start building");
                else if (TF2_GetPlayerClass(client) == TFClass_Medic)
                    return action.Done("Start heal mission");
                else if (TF2_GetPlayerClass(client) == TFClass_Spy)
                    return action.ChangeTo(CTFBotSpyLurkMvM(), "Start spy lurking");
                else if (HasSniperRifle(client))
                    return action.Done("Start lurking");
                else
                    return action.ChangeTo(CTFBotMoveToFront(), "Skip upgrades; Move to front");
            }
            return action.Done("Skipped upgrades (purchased robot)");
        }
        
        if (GameRules_GetRoundState() == RoundState_BetweenRounds)
        {
            if (TF2_GetPlayerClass(client) == TFClass_Engineer)
                return action.ChangeTo(CTFBotMvMEngineerIdle(), "Start building");
            else if (TF2_GetPlayerClass(client) == TFClass_Medic)
                return action.Done("Start heal mission");
            else if (TF2_GetPlayerClass(client) == TFClass_Spy)
                return action.ChangeTo(CTFBotSpyLurkMvM(), "Start spy lurking");
            else if (HasSniperRifle(client))
                return action.Done("Start lurking");
            else
                return action.ChangeTo(CTFBotMoveToFront(), "Finished upgrading; Move to front and press F4");
        }
        
        return action.Done("I finished upgrading");
    }
    
    if (GameRules_GetRoundState() == RoundState_BetweenRounds)
    {
        if (TF2_GetPlayerClass(client) == TFClass_Engineer)
            return action.ChangeTo(CTFBotMvMEngineerIdle(), "Start building");
        else if (TF2_GetPlayerClass(client) == TFClass_Medic)
            return action.Done("Start heal mission");
        else if (TF2_GetPlayerClass(client) == TFClass_Spy)
            return action.ChangeTo(CTFBotSpyLurkMvM(), "Start spy lurking");
        else if (HasSniperRifle(client))
            return action.Done("Start lurking");
        else
            return action.ChangeTo(CTFBotMoveToFront(), "Finished upgrading; Move to front and press F4");
    }
    
    return action.Done("I finished upgrading");
}

public bool NextBotTraceFilterIgnoreActors(int entity, int contentsMask, any iExclude)
{
	char class[64]; GetEntityClassname(entity, class, sizeof(class));
	
	if (StrEqual(class, "entity_medigun_shield"))
		return false;
	else if (StrEqual(class, "func_respawnroomvisualizer"))
		return false;
	else if (StrContains(class, "tf_projectile_", false) != -1)
		return false;
	else if (StrContains(class, "obj_", false) != -1)
		return false;
	else if (StrEqual(class, "entity_revive_marker"))
		return false;
	else if (StrEqual(class, "tank_boss"))
		return false;
	else if (StrEqual(class, "func_forcefield"))
		return false;
	
	return !CBaseEntity(entity).IsCombatCharacter();
}

float GetDesiredPathLookAheadRange(int client)
{
	return tf_bot_path_lookahead_range.FloatValue * BaseAnimating_GetModelScale(client);
}

bool IsPathToVectorPossible(int bot_entidx, const float vec[3], float &length = -1.0)
{
	CBaseCombatCharacter(bot_entidx).UpdateLastKnownArea();
	
	PathFollower temp_path = PathFollower(_, Path_FilterIgnoreActors, Path_FilterOnlyActors);
	
	bool success = temp_path.ComputeToPos(CBaseNPC_GetNextBotOfEntity(bot_entidx), vec);
	
	length = temp_path.GetLength();
	
	temp_path.Destroy();
	
	return success;
}

bool IsAmmoLow(int client)
{
	int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

	if (IsValidEntity(primary) && !HasAmmo(primary))
		return true;
	
	int myWeapon = BaseCombatCharacter_GetActiveWeapon(client);
	
	if (myWeapon != -1 && TF2Util_GetWeaponID(myWeapon) != TF_WEAPON_WRENCH)
	{
		if (!IsMeleeWeapon(myWeapon))
		{
			float flAmmoRation = float(BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_PRIMARY)) / float(TF2Util_GetPlayerMaxAmmo(client, TF_AMMO_PRIMARY));
			return flAmmoRation < 0.2;
		}
		
		return false;
	}
	
	return BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_METAL) <= 0;
}

bool IsAmmoFull(int client)
{
	bool isPrimaryFull = BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_PRIMARY) >= TF2Util_GetPlayerMaxAmmo(client, TF_AMMO_PRIMARY);
	bool isSecondaryFull = BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_SECONDARY) >= TF2Util_GetPlayerMaxAmmo(client, TF_AMMO_SECONDARY);
	
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		return BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_METAL) >= 200 && isPrimaryFull && isSecondaryFull;
	}
	
	return isPrimaryFull && isSecondaryFull;
}

void ResetIntentionInterface(int bot_entidx)
{
	CBaseNPC_GetNextBotOfEntity(bot_entidx).GetIntentionInterface().Reset();
}

void UpdateLookAroundForEnemies(int client, bool bVal)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsValidEntity(client))
    {
        return;
    }
    
    SetLookingAroundForEnemies(client, bVal);
}

bool IsCombatWeapon(int client, int weapon)
{
	if (!IsValidEntity(weapon))
		weapon = BaseCombatCharacter_GetActiveWeapon(client);
	
	if (IsValidEntity(weapon))
	{
		switch (TF2Util_GetWeaponID(weapon))
		{
			case TF_WEAPON_MEDIGUN, TF_WEAPON_PDA, TF_WEAPON_PDA_ENGINEER_BUILD, TF_WEAPON_PDA_ENGINEER_DESTROY, TF_WEAPON_PDA_SPY, TF_WEAPON_BUILDER, TF_WEAPON_DISPENSER, TF_WEAPON_INVIS, TF_WEAPON_LUNCHBOX, TF_WEAPON_BUFF_ITEM, TF_WEAPON_PUMPKIN_BOMB:
			{
				return false;
			}
		}
    }
	
	return true;
}

float GetDesiredAttackRange(int client)
{
	int weapon = BaseCombatCharacter_GetActiveWeapon(client);
	
	if (weapon < 1)
		return 0.0;
	
	int weaponID = TF2Util_GetWeaponID(weapon);
	
	if (weaponID == TF_WEAPON_KNIFE)
		return 70.0;
	
	if (IsMeleeWeapon(weapon) || weaponID == TF_WEAPON_FLAMETHROWER)
		return 100.0;
	
	if (WeaponID_IsSniperRifle(weaponID))
		return FLT_MAX;
	
	if (weaponID == TF_WEAPON_ROCKETLAUNCHER)
		return 1250.0;
	
	return 500.0;
}

bool OpportunisticallyUseWeaponAbilities(int client, int activeWeapon, INextBot bot, const CKnownEntity threat)
{
	if (threat == NULL_KNOWN_ENTITY)
		return false;
	
	if (activeWeapon == -1)
		return false;
	
	int weaponID = TF2Util_GetWeaponID(activeWeapon);
	
	if (weaponID == TF_WEAPON_SNIPERRIFLE && TF2_IsPlayerInCondition(client, TFCond_Slowed) && threat.IsVisibleRecently())
	{
		if (TF2_GetRageMeter(client) >= 0.0 && !TF2_IsRageDraining(client))
		{
			g_arrExtraButtons[client].PressButtons(IN_RELOAD);
			return true;
		}
	}
	
	int iThreat = threat.GetEntity();
	
	if (weaponID == TF_WEAPON_FLAMETHROWER && bot.IsRangeLessThan(iThreat, FLAMETHROWER_REACH_RANGE) && !TF2_IsCritBoosted(client))
	{
		if (TF2_GetRageMeter(client) >= 100.0 && !TF2_IsRageDraining(client))
		{
			VS_PressAltFireButton(client);
			return true;
		}
	}
	
	if (weaponID == TF_WEAPON_MINIGUN && BaseEntity_IsPlayer(iThreat) && TF2_GetRageMeter(client) >= 100.0)
	{
		if (TF2_HasTheFlag(iThreat))
		{
			float vThreatOrigin[3]; GetClientAbsOrigin(iThreat, vThreatOrigin);
			
			if (GetVectorDistance(vThreatOrigin, GetBombHatchPosition()) <= 100.0)
			{
				VS_PressSpecialFireButton(client);
				return true;
			}
		}
	}
	
	return false;
}

bool OpportunisticallyUsePowerupBottle(int client, int activeWeapon, INextBot bot, const CKnownEntity threat)
{
	if (m_flNextBottleUseTime[client] > GetGameTime())
		return false;
	
	int bottle = GetPowerupBottle(client);
	
	if (bottle == -1)
		return false;
	
	if (PowerupBottle_GetNumCharges(bottle) < 1)
		return false;
	
	switch (m_nCurrentPowerupBottle[client])
	{
		case POWERUP_BOTTLE_CRITBOOST:
		{
			if (activeWeapon == -1)
				return false;
			
			if (threat == NULL_KNOWN_ENTITY)
				return false;
			
			if (TF2_GetPlayerClass(client) == TFClass_Medic)
				return false;
			
			if (TF2_IsCritBoosted(client) || TF2_IsPlayerInCondition(client, TFCond_CritMmmph))
				return false;
			
			int iThreat = threat.GetEntity();
			
			if (!IsLineOfFireClearEntity(client, GetEyePosition(client), iThreat))
				return false;
			
			int weaponID = TF2Util_GetWeaponID(activeWeapon);
			
			if (weaponID == TF_WEAPON_FLAMETHROWER && bot.IsRangeGreaterThan(iThreat, FLAMETHROWER_REACH_RANGE))
				return false;
			
			if (weaponID == TF_WEAPON_FLAME_BALL && bot.IsRangeGreaterThan(iThreat, FLAMEBALL_REACH_RANGE))
				return false;
			
			if (IsMeleeWeapon(activeWeapon) && bot.IsRangeGreaterThan(iThreat, 100.0))
				return false;
			
			if (BaseEntity_IsPlayer(iThreat))
			{
				if ((TF2_IsMiniBoss(iThreat) && GetClientHealth(iThreat) > 5000) || (IsFailureImminent(client) && GetClientHealth(iThreat) > 2000))
				{
					UseActionSlotItem(client);
					return true;
				}
			}
			else if (IsBaseBoss(iThreat) && BaseEntity_GetHealth(iThreat) > 1000)
			{
				UseActionSlotItem(client);
				return true;
			}
		}
		case POWERUP_BOTTLE_UBERCHARGE:
		{
			if (TF2_IsInvulnerable(client))
				return false;
			
			if (!threat || !threat.IsVisibleRecently())
				return false;
			
			float healthRatio = float(GetClientHealth(client)) / float(TEMP_GetPlayerMaxHealth(client));
			
			if (healthRatio < tf_bot_health_critical_ratio.FloatValue)
			{
				UseActionSlotItem(client);
				m_flNextBottleUseTime[client] = GetGameTime() + GetRandomFloat(10.0, 30.0);
				return true;
			}
			
			if (TF2_IsPlayerInCondition(client, TFCond_Gas))
			{
				UseActionSlotItem(client);
				m_flNextBottleUseTime[client] = GetGameTime() + GetRandomFloat(20.0, 30.0);
				return true;
			}
		}
		case POWERUP_BOTTLE_RECALL:
		{
			if (TF2_GetPlayerClass(client) == TFClass_Medic)
				return false;
			
			if (TF2_GetPlayerClass(client) == TFClass_Engineer)
				return false;
			
			if (ActionsManager.LookupEntityActionByName(client, "DefenderAttackTank") != INVALID_ACTION)
				return false;
			
			float myPosition[3]; myPosition = WorldSpaceCenter(client);
			
			if (TF2Util_IsPointInRespawnRoom(myPosition, client, true))
				return false;
			
			float hatchPosition[3]; hatchPosition = GetBombHatchPosition();
			
			if (GetVectorDistance(myPosition, hatchPosition) <= 1000.0)
				return false;
			
			int flag = FindBombNearestToHatch();
			
			if (flag == -1)
				return false;
			
			float bombPosition[3]; bombPosition = WorldSpaceCenter(flag);
			
			if (GetVectorDistance(bombPosition, hatchPosition) > BOMB_HATCH_RANGE_CRITICAL)
				return false;
			
			int closestToHatch = FindBotNearestToBombNearestToHatch(client);
			
			if (closestToHatch == -1)
				return false;
			
			float threatPosition[3]; GetClientAbsOrigin(closestToHatch, threatPosition);
			
			if (GetVectorDistance(threatPosition, bombPosition) > 800.0)
				return false;
			
			if (GetVectorDistance(myPosition, threatPosition) <= 500.0)
				return false;
			
			UseActionSlotItem(client);
			return true;
		}
		case POWERUP_BOTTLE_REFILL_AMMO:
		{
			int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			
			if (primary != -1 && !HasAmmo(primary))
			{
				UseActionSlotItem(client);
				return true;
			}
		}
		case POWERUP_BOTTLE_BUILDINGS_INSTANT_UPGRADE:
		{
		}
	}
	
	return false;
}

void EquipBestWeaponForThreat(int client, const CKnownEntity threat)
{
	int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	
	if (!IsCombatWeapon(client, primary))
		primary = -1;
	
	int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	
	if (!IsCombatWeapon(client, secondary))
		secondary = -1;
	
	int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	
	if (!IsCombatWeapon(client, melee))
		melee = -1;
	
	int gun = -1;
	
	if (primary != -1)
		gun = primary;
	else if (secondary != -1)
		gun = secondary;
	else
		gun = melee;
	
	if (threat == NULL_KNOWN_ENTITY || !threat.WasEverVisible() || threat.GetTimeSinceLastSeen() > 5.0)
	{
		if (gun != -1)
			TF2Util_SetPlayerActiveWeapon(client, gun);
		
		return;
	}
	
	if (BaseCombatCharacter_GetAmmoCount(client, TF_AMMO_PRIMARY) <= 0)
		primary = -1;
	
	if (BaseCombatCharacter_GetAmmoCount(client, TFWeaponSlot_Secondary) <= 0)
		secondary = -1;
	
	INextBot myBot = CBaseNPC_GetNextBotOfEntity(client);
	int threatEnt = threat.GetEntity();
	
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_DemoMan, TFClass_Heavy, TFClass_Spy, TFClass_Medic, TFClass_Engineer:
		{
		}
		case TFClass_Scout:
		{
			if (secondary != -1)
			{
				int weaponID = TF2Util_GetWeaponID(secondary);
				
				if ((weaponID == TF_WEAPON_JAR_MILK || weaponID == TF_WEAPON_CLEAVER) && HasAmmo(secondary) && BaseEntity_IsPlayer(threatEnt) && !TF2_IsInvulnerable(threatEnt))
				{
					gun = secondary;
				}
				else if (gun != -1 && !Clip1(gun))
				{
					gun = secondary;
				}
			}
		}
		case TFClass_Soldier:
		{
			if (gun != -1 && !Clip1(gun))
			{
				if (secondary != -1 && Clip1(secondary) && (!BaseEntity_IsPlayer(threatEnt) || !TF2_IsInvulnerable(threatEnt)))
				{
					const float closeSoldierRange = 500.0;
					
					float lastKnownPos[3]; threat.GetLastKnownPosition(lastKnownPos);
					
					if (myBot.IsRangeLessThanEx(lastKnownPos, closeSoldierRange))
						gun = secondary;
				}
			}
		}
		case TFClass_Sniper:
		{
			if (secondary != -1 && TF2Util_GetWeaponID(secondary) == TF_WEAPON_JAR && HasAmmo(secondary) && BaseEntity_IsPlayer(threatEnt) && !TF2_IsInvulnerable(threatEnt))
			{
				gun = secondary;
			}
			else if (primary != -1 && TF2Util_GetWeaponID(primary) == TF_WEAPON_COMPOUND_BOW)
			{
				gun = primary;
			}
			else
			{
				const float closeSniperRange = 750.0;
				
				float lastKnownPos[3]; threat.GetLastKnownPosition(lastKnownPos);
				
				if (secondary != -1 && myBot.IsRangeLessThanEx(lastKnownPos, closeSniperRange))
					gun = secondary;
			}
		}
		case TFClass_Pyro:
		{
			if (secondary != -1 && TF2Util_GetWeaponID(secondary) == TF_WEAPON_JAR_GAS && HasAmmo(secondary) && BaseEntity_IsPlayer(threatEnt) && !TF2_IsInvulnerable(threatEnt))
			{
				gun = secondary;
			}
			else
			{
				const float flameRange = 750.0;
				
				float lastKnownPos[3]; threat.GetLastKnownPosition(lastKnownPos);
				
				if (secondary != -1 && myBot.IsRangeGreaterThanEx(lastKnownPos, flameRange))
					gun = secondary;
				
				if (BaseEntity_IsPlayer(threatEnt))
				{
					TFClassType threatClass = TF2_GetPlayerClass(threatEnt);
					
					if (threatClass == TFClass_Soldier || threatClass == TFClass_DemoMan)
						gun = primary;
				}
			}
		}
	}
	
	if (gun != -1)
		TF2Util_SetPlayerActiveWeapon(client, gun);
}

CKnownEntity GetHealerOfThreat(INextBot bot, const CKnownEntity threat)
{
	if (!threat)
		return NULL_KNOWN_ENTITY;
	
	int playerThreat = threat.GetEntity();
	
	for (int i = 0; i < TF2_GetNumHealers(playerThreat); i++)
	{
		int playerHealer = TF2Util_GetPlayerHealer(playerThreat, i);
		
		if (playerHealer != -1 && BaseEntity_IsPlayer(playerHealer))
		{
			CKnownEntity knownHealer = bot.GetVisionInterface().GetKnown(playerHealer);
			
			if (knownHealer && knownHealer.IsVisibleInFOVNow())
				return knownHealer;
		}
	}
	
	return threat;
}

CKnownEntity SelectCloserThreat(INextBot bot, const CKnownEntity threat1, const CKnownEntity threat2)
{
	float rangeSq1 = bot.GetRangeSquaredTo(threat1.GetEntity());
	float rangeSq2 = bot.GetRangeSquaredTo(threat2.GetEntity());
	
	if (rangeSq1 < rangeSq2)
		return threat1;
	
	return threat2;
}

void MonitorKnownEntities(int client, IVision vision)
{
    if (nb_blind.BoolValue)
        return;
    
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;
    
    int myTeam = GetClientTeam(client);
    float myEyePos[3];
    GetClientEyePosition(client, myEyePos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        
        if (GetClientTeam(i) == myTeam)
            continue;
            
        if (IsLineOfFireClearEntity(client, myEyePos, i))
        {
            CKnownEntity known = vision.GetKnown(i);
            
            if (known)
            {
                known.UpdatePosition();
            }
            else
            {
                vision.AddKnownEntity(i);
            }
        }
    }
}

int GetCountOfBotsWithNamedAction(const char[] name, int ignore = -1)
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
		if (i != ignore && IsClientInGame(i) && IsValidBot(i) && ActionsManager.LookupEntityActionByName(i, name) != INVALID_ACTION)
			count++;
	
	return count;
}

void UtilizeCompressionBlast(int client, INextBot bot, const CKnownEntity threat, int enhancedStage = 0)
{
	if (threat == NULL_KNOWN_ENTITY)
		return;
	
	if (redbots_manager_bot_reflect_skill.IntValue < 1)
		return;
	
	int iThreat = threat.GetEntity();
	
	if (BaseEntity_IsPlayer(iThreat))
	{
		float threatOrigin[3]; GetClientAbsOrigin(iThreat, threatOrigin);
		
		if (bot.IsRangeLessThanEx(threatOrigin, 250.0))
		{
			if (TF2_IsInvulnerable(iThreat))
			{
				g_arrExtraButtons[client].ReleaseButtons(IN_ATTACK);
				VS_PressAltFireButton(client);
				return;
			}
			
			if (TF2_IsPlayerInCondition(iThreat, TFCond_Charging))
			{
				g_arrExtraButtons[client].ReleaseButtons(IN_ATTACK);
				VS_PressAltFireButton(client);
				return;
			}
			
			if (TF2_HasTheFlag(iThreat) && GetVectorDistance(threatOrigin, GetBombHatchPosition()) <= 100.0)
			{
				g_arrExtraButtons[client].ReleaseButtons(IN_ATTACK);
				VS_PressAltFireButton(client);
				return;
			}
		}
	}
	
	if (redbots_manager_bot_reflect_skill.IntValue < 2)
		return;
	
	if (redbots_manager_bot_reflect_chance.FloatValue < 100.0 && TransientlyConsistentRandomValue(client, 1.0) > redbots_manager_bot_reflect_chance.FloatValue / 100.0)
		return;
	
	int myTeam = GetClientTeam(client);
	float myEyePos[3]; GetClientEyePosition(client, myEyePos);
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
	{
		if (BaseEntity_GetTeamNumber(ent) == myTeam)
			continue;
		
		if (!CanBeReflected(ent))
			continue;
		
		float origin[3]; BaseEntity_GetLocalOrigin(ent, origin);
		float vec[3]; MakeVectorFromPoints(origin, myEyePos, vec);
		
		if (GetVectorLength(vec) < 150.0)
		{
			g_arrExtraButtons[client].ReleaseButtons(IN_ATTACK);
			VS_PressAltFireButton(client);
			return;
		}
	}
}

void PurchaseAffordableCanteens(int client, int count = 3)
{
	if (TF2_GetClientTeam(client) != TFTeam_Red)
	{
	        if (redbots_manager_debug.BoolValue)
	        PrintToChatAll("[PurchaseAffordableCanteens] %N não é do time RED, ignorando", client);
        	return;
   	}

	int bottle = GetPowerupBottle(client);
	
	if (bottle == -1)
	{
		LogError("PurchaseAffordableCanteens: %N (%d) tried to upgrade canteen, but he don't have a powerup bottle!", client, client);
		return;
	}
	
	int currentCharges = PowerupBottle_GetNumCharges(bottle);
	int desiredType = POWERUP_BOTTLE_NONE;
	
	if (currentCharges > 0)
	{
		count = PowerupBottle_GetMaxNumCharges(bottle) - currentCharges;
		desiredType = PowerupBottle_GetType(bottle);
		
		if (redbots_manager_debug.BoolValue)
			PrintToChatAll("[PurchaseAffordableCanteens] %N desires %d more charges of canteen type %d", client, count, desiredType);
	}
	
	int currency = TF2_GetCurrency(client);
	const int slot = TF_LOADOUT_SLOT_ACTION;
	int iClass = view_as<int>(TF2_GetPlayerClass(client));
	ArrayList adtAffordableCanteens = new ArrayList();
	
	for (int i = 0; i < MAX_UPGRADES; i++)
	{
		CMannVsMachineUpgrades upgrades = CMannVsMachineUpgradeManager().GetUpgradeByIndex(i);
		
		if (upgrades.m_iUIGroup() != UIGROUP_POWERUPBOTTLE) 
			continue;
		
		char attributeName[MAX_ATTRIBUTE_DESCRIPTION_LENGTH]; attributeName = upgrades.m_szAttribute();
		
		switch (desiredType)
		{
			case POWERUP_BOTTLE_CRITBOOST:
			{
				if (!StrEqual(attributeName, "critboost"))
					continue;
			}
			case POWERUP_BOTTLE_UBERCHARGE:
			{
				if (!StrEqual(attributeName, "ubercharge"))
					continue;
			}
			case POWERUP_BOTTLE_RECALL:
			{
				if (!StrEqual(attributeName, "recall"))
					continue;
			}
			case POWERUP_BOTTLE_REFILL_AMMO:
			{
				if (!StrEqual(attributeName, "refill_ammo"))
					continue;
			}
			case POWERUP_BOTTLE_BUILDINGS_INSTANT_UPGRADE:
			{
				if (!StrEqual(attributeName, "building instant upgrade"))
					continue;
			}
		}
		
		CEconItemAttributeDefinition attr = CEIAD_GetAttributeDefinitionByName(attributeName);
		
		if (attr.Address == Address_Null)
			continue;
		
		int attribDefinitionIndex = attr.GetIndex();
		
		if (!CanUpgradeWithAttrib(client, slot, attribDefinitionIndex, upgrades.Address))
			continue;
		
		int cost = GetCostForUpgrade(upgrades.Address, slot, iClass, client);
		
		if (cost > currency)
			continue;
		
		adtAffordableCanteens.Push(i);
	}
	
	if (adtAffordableCanteens.Length == 0)
	{
		delete adtAffordableCanteens;
		return;
	}
	
	int selectedUpgradeIndex = adtAffordableCanteens.Get(GetRandomInt(0, adtAffordableCanteens.Length - 1));
	delete adtAffordableCanteens;
	
	CMannVsMachineUpgrades selectedUpgrade = CMannVsMachineUpgradeManager().GetUpgradeByIndex(selectedUpgradeIndex);
	int selectedCost = GetCostForUpgrade(selectedUpgrade.Address, slot, iClass, client);
	int purchaseAmount = 0;
	
	for (int i = 0; i < count; i++)
	{
		if (currency < selectedCost)
			break;
		
		currency -= selectedCost;
		purchaseAmount++;
	}
	
	KV_MVM_Upgrade(client, purchaseAmount, slot, selectedUpgradeIndex);
	
	m_nCurrentPowerupBottle[client] = PowerupBottle_GetType(bottle);
	
	if (redbots_manager_debug.BoolValue)
		PrintToChatAll("[PurchaseAffordableCanteens] %N purchased %d charges (upgrade %d) and wanted %d charges", client, purchaseAmount, selectedUpgradeIndex, count);
}

bool ShouldBuybackIntoGame(int client)
{
	if (TF2_GetPlayerClass(client) == TFClass_Scout)
		return false;
	
	if (TF2_GetCurrency(client) < MVM_BUYBACK_COST_PER_SEC)
		return false;
	
	if (IsFailureImminent(client))
		return true;
	
	if (g_bIsBeingRevived[client])
		return false;
	
	return g_iBuybackNumber[client] <= redbots_manager_bot_buyback_chance.IntValue;
}

bool ShouldUpgradeMidRound(int client)
{
	if (!TF2Util_IsPointInRespawnRoom(WorldSpaceCenter(client), client))
		return false;
	
	return g_iBuyUpgradesNumber[client] > 0 && g_iBuyUpgradesNumber[client] <= redbots_manager_bot_buy_upgrades_chance.IntValue;
}

bool CanBuyUpgradesNow(int client)
{
	if (TF2_GetCurrency(client) < 25)
		return false;
	
	if (IsFailureImminent(client))
		return false;
	
	return true;
}

float TransientlyConsistentRandomValue(int client, float period = 10.0, int seedValue = 0)
{
	CNavArea area = CBaseCombatCharacter(client).GetLastKnownArea();
	
	if (!area)
		return 0.0;
	
	int timeMod = RoundToFloor(GetGameTime() / period) + 1;
	
	return FloatAbs(Cosine(float(seedValue + (client * area.GetID() * timeMod))));
}

bool IsFailureImminent(int client)
{
	int flag = FindBombNearestToHatch();
	
	if (flag == -1)
		return false;
	
	float bombPosition[3]; bombPosition = WorldSpaceCenter(flag);
	
	if (GetVectorDistance(bombPosition, GetBombHatchPosition()) > BOMB_HATCH_RANGE_CRITICAL)
		return false;
	
	int closestToHatch = FindBotNearestToBombNearestToHatch(client);
	
	if (closestToHatch == -1)
		return false;
	
	float threatOrigin[3]; GetClientAbsOrigin(closestToHatch, threatOrigin);
	
	return GetVectorDistance(threatOrigin, bombPosition) <= 800.0;
}

void GetFlameThrowerAimForTank(int tank, float aimPos[3])
{
	aimPos = WorldSpaceCenter(tank);
	aimPos[2] += 90.0;
}

static bool ShouldUseTeleporter(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
        return false;

    if (TF2_GetPlayerClass(client) == TFClass_Engineer)
        return false;
    
    if (GameRules_GetRoundState() == RoundState_RoundRunning)
        return true;
    
    if (GameRules_GetRoundState() == RoundState_BetweenRounds)
    {
        if (!redbots_manager_bot_use_upgrades.BoolValue)
            return true;
        
        if (!TF2_IsInUpgradeZone(client) && 
            !g_bHasUpgraded[client] &&
            ActionsManager.LookupEntityActionByName(client, "DefenderUpgrade") == INVALID_ACTION &&
            ActionsManager.LookupEntityActionByName(client, "DefenderGotoUpgrade") != INVALID_ACTION)
        {
            return false;
        }
        
        return true;
    }
    
    return false;
}