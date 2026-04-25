#define BUY_UPGRADES_MAX_TIME	30.0
#define BUY_UPGRADES_FAST_MAX_TIME	3.0

static int MAX_INT = 99999999;
static int MIN_INT = -99999999;

JSONArray CTFPlayerUpgrades[MAXPLAYERS + 1];
float m_flNextUpgrade[MAXPLAYERS + 1];
int m_nPurchasedUpgrades[MAXPLAYERS + 1];
float m_flUpgradingTime[MAXPLAYERS + 1];

BehaviorAction CTFBotUpgrade()
{
	BehaviorAction action = ActionsManager.Create("DefenderUpgrade");
	
	action.OnStart = CTFBotUpgrade_OnStart;
	action.Update = CTFBotUpgrade_Update;
	action.OnEnd = CTFBotUpgrade_OnEnd;
	
	return action;
}

public Action CTFBotUpgrade_OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
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
	}
	else if (!TF2_IsInUpgradeZone(actor)) 
	{
		return action.ChangeTo(CTFBotGotoUpgrade(), "Not standing at an upgrade station!");
	}
	
	CollectUpgrades(actor);
	
	KV_MvM_UpgradesBegin(actor);
	
	m_flNextUpgrade[actor] = GetGameTime() + GetUpgradeInterval();
	
	bool isRoundActive = GameRules_GetRoundState() == RoundState_RoundRunning;
	
	if (g_bHasUpgraded[actor] == false && isRoundActive)
	{
		m_flUpgradingTime[actor] = GetGameTime() + 15.0;
	}
	else
	{
		m_flUpgradingTime[actor] = GetGameTime() + (isRoundActive ? BUY_UPGRADES_FAST_MAX_TIME : BUY_UPGRADES_MAX_TIME);
	}
	
	return action.Continue();
}

public Action CTFBotUpgrade_Update(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (!g_bBuyIsPurchasedRobot[actor] && !TF2_IsInUpgradeZone(actor)) 
		return action.ChangeTo(CTFBotGotoUpgrade(), "Not standing at an upgrade station!");
	
	if (m_flUpgradingTime[actor] <= GetGameTime())
	{
		if (TF2_GetPlayerClass(actor) != TFClass_Engineer)
		{
			SetPlayerReady(actor, true);
		}
		
		if (redbots_manager_debug_actions.BoolValue)
			PrintToChatAll("%N upgrade for long with %d credits left!", actor, TF2_GetCurrency(actor));
		
		return GetUpgradePostAction(actor, action);
	}
	
	float flNextTime = m_flNextUpgrade[actor] - GetGameTime();
	
	if (flNextTime <= 0.0)
	{
		m_flNextUpgrade[actor] = GetGameTime() + GetUpgradeInterval();
		
		JSONObject info = CTFBotPurchaseUpgrades_ChooseUpgrade(actor);
		
		if (info != null) 
		{
			CTFBotPurchaseUpgrades_PurchaseUpgrade(actor, info);
			
			if (redbots_manager_debug_actions.BoolValue)
				PrintToChatAll("Currenct left for %N: %d", actor, TF2_GetCurrency(actor));
		}
		else 
		{
			if (TF2_GetPlayerClass(actor) != TFClass_Engineer)
			{
				SetPlayerReady(actor, true);
			}
			
			delete info;
			
			return GetUpgradePostAction(actor, action);
		}
		
		delete info;
	}
	
	if (TF2_GetPlayerClass(actor) == TFClass_Medic)
	{
		int secondary = GetPlayerWeaponSlot(actor, TFWeaponSlot_Secondary);
		
		if (secondary != -1 && TF2Util_GetWeaponID(secondary) == TF_WEAPON_MEDIGUN)
		{
			int teammate = GerNearestTeammate(actor, WEAPON_MEDIGUN_RANGE);
			
			if (teammate != -1)
			{
				TF2Util_SetPlayerActiveWeapon(actor, secondary);
				SnapViewToPosition(actor, WorldSpaceCenter(teammate));
				VS_PressFireButton(actor);
			}
		}
	}
	
	return action.Continue();
}

public void CTFBotUpgrade_OnEnd(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	PurchaseAffordableCanteens(actor);
	
	KV_MvM_UpgradesDone(actor);
	
	if (TF2_GetPlayerClass(actor) == TFClass_Engineer && GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		DetonateObjectOfType(actor, TFObject_Sentry);
		DetonateObjectOfType(actor, TFObject_Dispenser);
		DetonateObjectOfType(actor, TFObject_Teleporter, TFObjectMode_Exit);
	}
	
	if (IsPlayerAlive(actor))
	{
		Command_BoughtUpgrades(actor, 0);
		
		if (GameRules_GetRoundState() == RoundState_RoundRunning && g_bHasUpgraded[actor] == false)
			UpgradeMidRoundPostActivity(actor);
		
		g_bHasUpgraded[actor] = true;
		g_iBuyUpgradesNumber[actor] = 0;
		
		TF2_SetInUpgradeZone(actor, false);
		
		if (g_bBuyIsPurchasedRobot[actor] && GameRules_GetRoundState() == RoundState_BetweenRounds)
		{
			SetPlayerReady(actor, true);
		}
	}

	if (IsHalloweenActive() && g_bBuyIsPurchasedRobot[actor])
	{
		CreateTimer(0.5, Timer_ReapplyZombieAfterUpgrade, GetClientUserId(actor), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ReapplyZombieAfterUpgrade(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && g_bBuyIsPurchasedRobot[client] && IsPlayerAlive(client) && IsHalloweenActive())
	{
		BuyRobot_EquipZombieCosmetic(client);
	}
	return Plugin_Stop;
}

void CollectUpgrades(int client)
{
	if (CTFPlayerUpgrades[client] != null)
		delete CTFPlayerUpgrades[client];
		
	CTFPlayerUpgrades[client] = new JSONArray();
	
	ArrayList iArraySlots = new ArrayList();
	
	iArraySlots.Push(-1);
	
	bool bDemoKnight = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) == -1;
	bool bEngineer = TF2_GetPlayerClass(client) == TFClass_Engineer;
	
	if (bEngineer)
	{
		iArraySlots.Push(TF_LOADOUT_SLOT_MELEE);
		iArraySlots.Push(TF_LOADOUT_SLOT_BUILDING);
		iArraySlots.Push(TF_LOADOUT_SLOT_PDA);
	}
	else
	{
		if (TF2_GetPlayerClass(client) == TFClass_Sniper)
		{
			iArraySlots.Push(TF_LOADOUT_SLOT_PRIMARY);
			iArraySlots.Push(TF_LOADOUT_SLOT_MELEE);
		}
		else if (TF2_GetPlayerClass(client) == TFClass_Medic)
		{
			iArraySlots.Push(TF_LOADOUT_SLOT_SECONDARY);
		}
		else if (TF2_GetPlayerClass(client) == TFClass_Spy)
		{
			iArraySlots.Push(TF_LOADOUT_SLOT_BUILDING);
			iArraySlots.Push(TF_LOADOUT_SLOT_MELEE);
		}

		iArraySlots.Push(bDemoKnight ? TF_LOADOUT_SLOT_MELEE : TF_LOADOUT_SLOT_PRIMARY);
		
		if (TF2_IsShieldEquipped(client))
		{
			iArraySlots.Push(TF_LOADOUT_SLOT_SECONDARY);
		}
		else
		{
			int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			int weaponID = secondary != -1 ? TF2Util_GetWeaponID(secondary) : -1;
			
			switch (weaponID)
			{
				case TF_WEAPON_JAR, TF_WEAPON_JAR_MILK, TF_WEAPON_BUFF_ITEM, TF_WEAPON_JAR_GAS:
				{
					iArraySlots.Push(TF_LOADOUT_SLOT_SECONDARY);
				}
				case TF_WEAPON_PIPEBOMBLAUNCHER:
				{
					if (bDemoKnight)
						iArraySlots.Push(TF_LOADOUT_SLOT_SECONDARY);
				}
			}
		}
	}

	for (int i = 0; i < iArraySlots.Length; i++)
	{
		int slot = iArraySlots.Get(i);
	
		for (int index = 0; index < MAX_UPGRADES; index++)
		{
			CMannVsMachineUpgrades upgrades = CMannVsMachineUpgradeManager().GetUpgradeByIndex(index);
			
			if (upgrades.m_iUIGroup() == UIGROUP_UPGRADE_ATTACHED_TO_PLAYER && slot != -1) 
				continue;
			
			CEconItemAttributeDefinition attr = CEIAD_GetAttributeDefinitionByName(upgrades.m_szAttribute());
			if (attr.Address == Address_Null)
				continue;
			
			if (!CanUpgradeWithAttrib(client, slot, attr.GetIndex(), upgrades.Address))
				continue;
			
			JSONObject UpgradeInfo = new JSONObject();
			UpgradeInfo.SetInt("pclass", view_as<int>(TF2_GetPlayerClass(client)));
			UpgradeInfo.SetInt("slot", slot);
			UpgradeInfo.SetInt("index", index);
			UpgradeInfo.SetInt("random", GetRandomInt(MIN_INT, MAX_INT));
			UpgradeInfo.SetInt("priority", GetUpgradePriority(UpgradeInfo));
			
			CTFPlayerUpgrades[client].Push(UpgradeInfo);
			
			delete UpgradeInfo;
		}
	}
	
	delete iArraySlots;
	
	JSONArray new_json = new JSONArray();
	
	while (CTFPlayerUpgrades[client].Length > 0)
	{	
		JSONObject mObj = view_as<JSONObject>(CTFPlayerUpgrades[client].Get(0));
		int minimum = mObj.GetInt("priority");
		
		JSONObject tempObj = new JSONObject();
		tempObj.SetInt("pclass",   mObj.GetInt("pclass"));
		tempObj.SetInt("slot",     mObj.GetInt("slot"));
		tempObj.SetInt("index",    mObj.GetInt("index"));
		tempObj.SetInt("random",   mObj.GetInt("random"));
		tempObj.SetInt("priority", mObj.GetInt("priority"));
		
		delete mObj;
		
		for (int x = 0; x < CTFPlayerUpgrades[client].Length; x++)
		{
			JSONObject xObj = view_as<JSONObject>(CTFPlayerUpgrades[client].Get(x));
			
			if (xObj.GetInt("priority") > minimum)
			{
				minimum = xObj.GetInt("priority");
				
				tempObj.SetInt("pclass",   xObj.GetInt("pclass"));
				tempObj.SetInt("slot",     xObj.GetInt("slot"));
				tempObj.SetInt("index",    xObj.GetInt("index"));
				tempObj.SetInt("random",   xObj.GetInt("random"));
				tempObj.SetInt("priority", xObj.GetInt("priority"));
			}

			delete xObj;
		}
		
		new_json.Push(tempObj);
		delete tempObj;
		
		int index = FindPriorityIndex(CTFPlayerUpgrades[client], "priority", minimum);
		CTFPlayerUpgrades[client].Remove(index);
	}
    
	if (redbots_manager_debug_actions.BoolValue)
	{
		PrintToServer("\nPreferred upgrades for #%d \"%N\"\n", client, client);
		PrintToServer("%3s %4s %4s %5s %-64s\n", "#", "SLOT", "COST", "INDEX", "ATTRIBUTE");
	}
	
	for (int i = 0; i < new_json.Length; i++) 
	{
		JSONObject info = view_as<JSONObject>(new_json.Get(i));
		CTFPlayerUpgrades[client].Push(info);
		
		if (redbots_manager_debug_actions.BoolValue)
		{
			CMannVsMachineUpgradeManager manager = CMannVsMachineUpgradeManager();
			int cost = GetCostForUpgrade(manager.GetUpgradeByIndex(info.GetInt("index")).Address, info.GetInt("slot"), info.GetInt("pclass"), client);
			PrintToServer("%3d %4d %4d %5d %-64s", i, info.GetInt("slot"), cost, info.GetInt("index"), manager.GetUpgradeByIndex(info.GetInt("index")).m_szAttribute());
		}
		
		delete info;
	}
	
	delete new_json;
}

int GetUpgradePriority(JSONObject info)
{
	CMannVsMachineUpgrades upgrade = CMannVsMachineUpgradeManager().GetUpgradeByIndex(info.GetInt("index"));
	
	if (info.GetInt("pclass") == view_as<int>(TFClass_Spy)) 
	{
		if (info.GetInt("slot") == TF_LOADOUT_SLOT_MELEE) 
		{
			if (StrEqual(upgrade.m_szAttribute(), "armor piercing"))
				return 100;
				
			if (StrEqual(upgrade.m_szAttribute(), "melee attack rate bonus"))
				return 90;
				
			if (StrEqual(upgrade.m_szAttribute(), "robo sapper"))
				return 80;
		}
	}
	
	if (info.GetInt("slot") == TF_LOADOUT_SLOT_ACTION) 
		return -10;
	
	return GetRandomInt(50, 100);
}

int FindPriorityIndex(JSONArray array, const char[] key, int value)
{
	int index = -1;
	
	for (int i = 0; i < array.Length; i++)
	{
		JSONObject iObj = view_as<JSONObject>(array.Get(i));
		if (value == iObj.GetInt(key))
		{
			index = i;
			
			delete iObj;
			break;
		}
		
		delete iObj;
	}
	
	return index;
}

void KV_MvM_UpgradesBegin(int client)
{
	m_nPurchasedUpgrades[client] = 0;

	KeyValues kv = new KeyValues("MvM_UpgradesBegin");
	FakeClientCommandKeyValues(client, kv);
	delete kv;
}

float GetUpgradeInterval()
{
	float customInterval = redbots_manager_bot_upgrade_interval.FloatValue;
	
	if (customInterval >= 0.0)
		return customInterval;
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
		return GetRandomFloat(0.1, 0.75);
	
	const float interval = 1.25;
	const float variance = 0.3;
	
	return GetRandomFloat(interval - variance, interval + variance);
}

JSONObject CTFBotPurchaseUpgrades_ChooseUpgrade(int actor)
{
	int currency = TF2_GetCurrency(actor);
	
	CollectUpgrades(actor);
	
	for (int i = 0; i < CTFPlayerUpgrades[actor].Length; i++) 
	{
		JSONObject info = view_as<JSONObject>(CTFPlayerUpgrades[actor].Get(i));
		
		CMannVsMachineUpgrades upgrades = CMannVsMachineUpgradeManager().GetUpgradeByIndex(info.GetInt("index"));
		if (upgrades.Address == Address_Null)
		{
			delete info;
			return null;
		}
		
		char attrib[MAX_ATTRIBUTE_DESCRIPTION_LENGTH]; attrib = upgrades.m_szAttribute();
		CEconItemAttributeDefinition attr = CEIAD_GetAttributeDefinitionByName(attrib);
		if (attr.Address == Address_Null)
			continue;
		
		int iAttribIndex = attr.GetIndex();
		if (!CanUpgradeWithAttrib(actor, info.GetInt("slot"), iAttribIndex, upgrades.Address))
		{
			delete info;
			continue;
		}
		
		int iCost = GetCostForUpgrade(upgrades.Address, info.GetInt("slot"), info.GetInt("pclass"), actor);
		if (iCost > currency)
		{
			delete info;
			continue;
		}
	
		int tier = GetUpgradeTier(info.GetInt("index"));
		if (tier != 0) 
		{
			if (!IsUpgradeTierEnabled(actor, info.GetInt("slot"), tier))
			{
				delete info;
				continue;
			}
		}
		
		return info;
	}
	
	return null;
}

void CTFBotPurchaseUpgrades_PurchaseUpgrade(int actor, JSONObject info)
{
	KV_MVM_Upgrade(actor, 1, info.GetInt("slot"), info.GetInt("index"));
	++m_nPurchasedUpgrades[actor];
}

void KV_MVM_Upgrade(int client, int count, int slot, int index)
{
	KeyValues kv = new KeyValues("MVM_Upgrade");
	kv.JumpToKey("upgrade", true);
	kv.SetNum("itemslot", slot);
	kv.SetNum("upgrade", index);
	kv.SetNum("count", count);
	FakeClientCommandKeyValues(client, kv);
	delete kv;
}

void KV_MvM_UpgradesDone(int client)
{
	KeyValues kv = new KeyValues("MvM_UpgradesDone");
	kv.SetNum("num_upgrades", m_nPurchasedUpgrades[client]);
	FakeClientCommandKeyValues(client, kv);
	delete kv;
}

void UpgradeMidRoundPostActivity(int client)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Medic:
		{
			int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			
			if (secondary != -1)
				SetEntPropFloat(secondary, Prop_Send, "m_flChargeLevel", 1.0);
			
			SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
		}
	}
}