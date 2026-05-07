static ArrayList m_adtBotLineup;
static int m_iSuccesses;
static int m_iFailures;
static int m_iTanksSpawned;

public void DBTM_OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tank_boss"))
		m_iTanksSpawned++;
}

void DBTM_Initialize()
{
	m_adtBotLineup = new ArrayList(TF2_CLASS_MAX_NAME_LENGTH);
}

void DBTM_UpdateBotLineup()
{
	m_adtBotLineup.Clear();
	
	int redTeamCount = GetHumanAndDefenderBotCountEx(TFTeam_Red);
	int defenderTeamSize = redbots_manager_defender_team_size.IntValue;
	int botsNeeded = defenderTeamSize - redTeamCount;
	
	if (botsNeeded <= 0)
		return;
	
	if (m_iFailures == 0)
	{
		for (int i = 0; i < botsNeeded; i++)
			m_adtBotLineup.PushString(g_sRawPlayerClassNames[GetRandomInt(1, 9)]);
		
		return;
	}
	
	float ratio = float(m_iSuccesses) / float(m_iFailures);
	
	if (ratio < 1.0)
	{
		const char strClasses[][] = { "scout", "sniper", "soldier", "demoman", "medic", "heavyweapons", "pyro", "engineer" };
		
		for (int i = 0; i < botsNeeded; i++)
			m_adtBotLineup.PushString(strClasses[GetRandomInt(0, sizeof(strClasses) - 1)]);
		
		return;
	}
	
	for (int i = 0; i < botsNeeded; i++)
		m_adtBotLineup.PushString(g_sRawPlayerClassNames[GetRandomInt(1, 9)]);
}

int GetHumanAndDefenderBotCountEx(TFTeam team)
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (g_bBuyIsPurchasedRobot[i])
			continue;
		
		if (TF2_GetClientTeam(i) == team)
		{
			if (!IsFakeClient(i) || g_bIsDefenderBot[i])
				count++;
		}
	}
	
	return count;
}