static char g_strHealthAndAmmoEntities[][] = 
{
	"func_regenerate",
	"item_ammopack*",
	"item_health*",
	"obj_dispenser",
	"tf_ammo_pack"
};

int m_iAmmoPack[MAXPLAYERS + 1];

BehaviorAction CTFBotGetAmmo()
{
	BehaviorAction action = ActionsManager.Create("DefenderGetAmmo");
	
	action.OnStart = CTFBotGetAmmo_OnStart;
	action.Update = CTFBotGetAmmo_Update;
	action.OnEnd = CTFBotGetAmmo_OnEnd;
	action.ShouldHurry = CTFBotGetAmmo_ShouldHurry;
	action.ShouldAttack = CTFBotGetAmmo_ShouldAttack;
	
	return action;
}

public Action CTFBotGetAmmo_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	// VERIFICAÇÃO: Só pode ser do time RED
	if (TF2_GetClientTeam(actor) != TFTeam_Red)
	{
		return action.Done("Not eligible for ammo (must be RED team)");
	}
	
	// VERIFICAÇÃO: Deve ser um robô (Defender OU Comprado)
	if (!g_bIsDefenderBot[actor] && !g_bBuyIsPurchasedRobot[actor])
	{
		return action.Done("Not eligible for ammo (must be Defender OR Purchased robot)");
	}
	
	// ===== ROBÔS GIGANTES NÃO PODEM PEGAR MUNIÇÃO =====
	char clientName[64];
	GetClientName(actor, clientName, sizeof(clientName));
	if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
	{
		return action.Done("Giant robots cannot use ammo");
	}
	// ================================================
	
	m_pPath[actor].SetMinLookAheadDistance(GetDesiredPathLookAheadRange(actor));
	
	JSONArray ammo = new JSONArray();
	ComputeHealthAndAmmoVectors(actor, ammo, tf_bot_ammo_search_range.FloatValue);
	
	if (ammo.Length <= 0)
	{
		delete ammo;
		return action.Done("No ammo");
	}
	
	float flSmallestDistance = 99999.0;
	
	for (int i = 0; i < ammo.Length; i++)
	{
		JSONObject entity = view_as<JSONObject>(ammo.Get(i));
		
		if (!IsValidAmmo(entity.GetInt("entity_index")))
		{
			delete entity;
			continue;
		}
		
		float flDistance = entity.GetFloat("path_length");
		
		if (flDistance <= flSmallestDistance)
		{
			m_iAmmoPack[actor] = entity.GetInt("entity_index");
			flSmallestDistance = flDistance;
		}
		
		delete entity;
	}
	
	delete ammo;
	
	if (m_iAmmoPack[actor] != -1)
	{
		if (TF2_GetPlayerClass(actor) == TFClass_Engineer)
			UpdateLookAroundForEnemies(actor, true);
		
		BaseMultiplayerPlayer_SpeakConceptIfAllowed(actor, MP_CONCEPT_PLAYER_DISPENSERHERE);
		return action.Continue();
	}
	
	return action.Done("Could not find ammo");
}

public Action CTFBotGetAmmo_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
	// ===== ROBÔS GIGANTES NÃO PODEM PEGAR MUNIÇÃO =====
	char clientName[64];
	GetClientName(actor, clientName, sizeof(clientName));
	if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
	{
		return action.Done("Giant robots cannot use ammo");
	}
	// ================================================
	
	if (!IsValidAmmo(m_iAmmoPack[actor]))
		return action.Done("ammo is not valid");
	
	if (IsAmmoFull(actor))
		return action.Done("Ammo is full");
	
	INextBot myBot = CBaseNPC_GetNextBotOfEntity(actor);
	
	if (m_flRepathTime[actor] <= GetGameTime())
	{
		m_flRepathTime[actor] = GetGameTime() + GetRandomFloat(0.9, 1.0);
		m_pPath[actor].ComputeToPos(myBot, WorldSpaceCenter(m_iAmmoPack[actor]));
	}
	
	m_pPath[actor].Update(myBot);
	
	CKnownEntity threat = myBot.GetVisionInterface().GetPrimaryKnownThreat(false);
	
	if (threat)
		EquipBestWeaponForThreat(actor, threat);
	
	return action.Continue();
}

public void CTFBotGetAmmo_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
    if (actor <= 0 || actor > MaxClients || !IsClientInGame(actor) || !IsValidEntity(actor))
    {
        return;
    }
    
    m_iAmmoPack[actor] = -1;
}

public Action CTFBotGetAmmo_ShouldHurry(BehaviorAction action, INextBot nextbot, QueryResultType& result)
{
	int me = action.Actor;
	
	// ===== ROBÔS GIGANTES NÃO DEVEM USAR MUNIÇÃO =====
	char clientName[64];
	GetClientName(me, clientName, sizeof(clientName));
	if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
	{
		result = ANSWER_NO;
		return Plugin_Changed;
	}
	// ==============================================
	
	result = ANSWER_YES;
	return Plugin_Handled;
}

public Action CTFBotGetAmmo_ShouldAttack(BehaviorAction action, INextBot nextbot, CKnownEntity knownEntity, QueryResultType& result)
{
	int me = action.Actor;
	
	// ===== ROBÔS GIGANTES NÃO DEVEM ATACAR ENQUANTO BUSCAM MUNIÇÃO =====
	char clientName[64];
	GetClientName(me, clientName, sizeof(clientName));
	if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
	{
		result = ANSWER_NO;
		return Plugin_Changed;
	}
	// =================================================================
	
	if (TF2_GetPlayerClass(me) == TFClass_Spy)
	{
		int iThreat = knownEntity.GetEntity();
		
		if (BaseEntity_IsPlayer(iThreat) && GetClientHealth(iThreat) > 360 && !TF2_IsCritBoosted(me))
		{
			result = ANSWER_NO;
			return Plugin_Changed;
		}
		else if (GetNearestEnemyCount(me, 1000.0) > 1)
		{
			result = ANSWER_NO;
			return Plugin_Changed;
		}
	}
	
	result = ANSWER_UNDEFINED;
	return Plugin_Changed;
}

void ComputeHealthAndAmmoVectors(int client, JSONArray array, float max_range)
{
	for (int i = 0; i < sizeof(g_strHealthAndAmmoEntities); i++)
	{
		int ammo = -1;
		while ((ammo = FindEntityByClassname(ammo, g_strHealthAndAmmoEntities[i])) != -1)
		{
			if (BaseEntity_GetTeamNumber(ammo) == view_as<int>(GetPlayerEnemyTeam(client)))
				continue;
		
			if (GetVectorDistance(WorldSpaceCenter(client), WorldSpaceCenter(ammo)) > max_range)
				continue;
			
			if (BaseEntity_IsBaseObject(ammo))
			{
				if (TF2_IsBuilding(ammo))
					continue;
				
				if (TF2_GetObjectType(ammo) == TFObject_Dispenser)
				{
					if (GetEntProp(ammo, Prop_Send, "m_iAmmoMetal") <= 0)
						continue;
				}
			}
			
			float length;
			
			if (!IsPathToVectorPossible(client, WorldSpaceCenter(ammo), length))
				continue;
			
			if (length < max_range)
			{
				JSONObject entity = new JSONObject();
				entity.SetFloat("path_length", length);
				entity.SetInt("entity_index", ammo);
				
				array.Push(entity);
				
				delete entity;
			}
		}
	}
}

bool IsValidAmmo(int pack)
{
	if (!IsValidEntity(pack))
		return false;

	if (!HasEntProp(pack, Prop_Send, "m_fEffects"))
		return false;

	if (GetEntProp(pack, Prop_Send, "m_fEffects") != 0)
		return false;

	char class[64]; GetEntityClassname(pack, class, sizeof(class));
	
	if (StrContains(class, "tf_ammo_pack", false) == -1 
	&& StrContains(class, "item_ammo", false) == -1 
	&& StrContains(class, "obj_dispenser", false) == -1
	&& StrContains(class, "func_regen", false) == -1)
	{
		return false;
	}
	
	if (StrContains(class, "obj_dispenser", false) != -1 && TF2_HasSapper(pack))
		return false;
	
	return true;
}

bool CTFBotGetAmmo_IsPossible(int actor)
{
	// VERIFICAÇÃO: Só pode ser do time RED
	if (TF2_GetClientTeam(actor) != TFTeam_Red)
		return false;
	
	// VERIFICAÇÃO: Deve ser um robô (Defender OU Comprado)
	if (!g_bIsDefenderBot[actor] && !g_bBuyIsPurchasedRobot[actor])
		return false;
	
	// ===== ROBÔS GIGANTES NÃO PODEM PEGAR MUNIÇÃO =====
	char clientName[64];
	GetClientName(actor, clientName, sizeof(clientName));
	if (StrContains(clientName, "Giant") != -1 || StrContains(clientName, "Boss") != -1)
	{
		return false;
	}
	// ================================================
	
	if (m_iAmmoPack[actor] != -1 && IsValidAmmo(m_iAmmoPack[actor]))
		return true;

	JSONArray ammo = new JSONArray();
	ComputeHealthAndAmmoVectors(actor, ammo, tf_bot_ammo_search_range.FloatValue);
	
	if (ammo.Length <= 0)
	{
		delete ammo;
		return false;
	}

	bool bPossible = false;
	
	for (int i = 0; i < ammo.Length; i++)
	{
		JSONObject entity = view_as<JSONObject>(ammo.Get(i));
		
		if (!IsValidAmmo(entity.GetInt("entity_index")))
		{
			delete entity;
			continue;
		}
		
		bPossible = true;
		delete entity;
		break;
	}
	
	delete ammo;

	return bPossible;
}