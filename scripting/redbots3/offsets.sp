static StringMap m_adtOffsets;

void InitOffsets(GameData hGamedata)
{
	m_adtOffsets = new StringMap();
	
	SetOffset(hGamedata, "CTFPlayer", "m_LastDamageType");
	SetOffset(hGamedata, "CObjectSentrygun", "m_bPlacementOK");
	SetOffset(hGamedata, "CObjectSentrygun", "m_vecCurAngles");
	SetOffset(hGamedata, "CTFBot", "m_isLookingAroundForEnemies");
	SetOffset(hGamedata, "CTFBot", "m_mission");
	SetOffset(hGamedata, "CTFBot", "m_opportunisticTimer");
	SetOffset(hGamedata, "CPopulationManager", "m_nStartingCurrency");
	SetOffset(hGamedata, "CTFBuffItem", "m_bPlayingHorn");
	SetOffset(hGamedata, "CTFRevolver", "m_flLastAccuracyCheck");
	SetOffset(hGamedata, "CTFNavArea", "m_distanceToBombTarget");
}

static void SetOffset(GameData hGamedata, const char[] cls, const char[] prop)
{
	char key[64], base_key[64], base_prop[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
	
	if (hGamedata.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
	{
		int base_offset = FindSendPropInfo(cls, base_prop);
		
		if (StrEqual(cls, "CTFBot"))
			base_offset = FindSendPropInfo("CTFPlayer", base_prop);
		
		if (base_offset == -1)
		{
			base_offset = FindSendPropInfo("CBaseEntity", base_prop);
			
			if (base_offset == -1)
			{
				ThrowError("Base offset '%s::%s' could not be found", cls, base_prop);
			}
		}
		
		int offset = base_offset + hGamedata.GetOffset(key);
		m_adtOffsets.SetValue(key, offset);
	}
	else
	{
		int offset = hGamedata.GetOffset(key);
		
		if (offset == -1)
		{
			ThrowError("Offset '%s' could not be found", key);
		}
		
		m_adtOffsets.SetValue(key, offset);
	}
}

static any GetOffset(const char[] cls, const char[] prop)
{
	char key[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	
	int offset;
	if (!m_adtOffsets.GetValue(key, offset))
	{
		ThrowError("Offset '%s' not present in map", key);
	}
	
	return offset;
}

int GetLastDamageType(int client)
{
	return GetEntData(client, GetOffset("CTFPlayer", "m_LastDamageType"));
}

bool IsPlacementOK(int iObject)
{
	return view_as<bool>(GetEntData(iObject, GetOffset("CObjectSentrygun", "m_bPlacementOK"), 1));
}

void GetTurretAngles(int sentry, float buffer[3])
{
	GetEntDataVector(sentry, GetOffset("CObjectSentrygun", "m_vecCurAngles"), buffer);
}

void SetLookingAroundForEnemies(int client, bool shouldLook)
{
	SetEntData(client, GetOffset("CTFBot", "m_isLookingAroundForEnemies"), shouldLook, 1);
}

int GetTFBotMission(int client)
{
	return GetEntData(client, GetOffset("CTFBot", "m_mission"));
}

Address GetOpportunisticTimer(int client)
{
	return GetEntityAddress(client) + GetOffset("CTFBot", "m_opportunisticTimer");
}

int GetStartingCurrency(int populator)
{
	return GetEntData(populator, GetOffset("CPopulationManager", "m_nStartingCurrency"));
}

bool IsPlayingHorn(int weapon)
{
	return view_as<bool>(GetEntData(weapon, GetOffset("CTFBuffItem", "m_bPlayingHorn"), 1));
}

float GetLastAccuracyCheck(int weapon)
{
	return GetEntDataFloat(weapon, GetOffset("CTFRevolver", "m_flLastAccuracyCheck"));
}

float GetTravelDistanceToBombTarget(CTFNavArea area)
{
	return LoadFromAddress(view_as<Address>(area) + GetOffset("CTFNavArea", "m_distanceToBombTarget"), NumberType_Int32);
}