#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>

#define  PLUGIN_VERSION        "1.2"
#define CVAR_FLAGS FCVAR_NOTIFY

public Plugin myinfo =
{
        name = "L4D(2) Admin Reserved Slots",
        author = "fenghf & HarryPotter",
        description = "As the name says, you dumb fuck!",
        version = PLUGIN_VERSION,
        url = "https://steamcommunity.com/id/HarryPotter_TW/"
};

static char MSG_KICK_REASON[] = "剩餘通道只能管理員加入.. Sorry, Reserverd Slots for Admin..";

int g_iCvarReservedSlots, g_iMaxplayers;
ConVar L4dtoolzExtension, sv_visiblemaxplayers, g_hCvarReservedSlots, g_hAdmAccess, g_hHideSlots;
char g_sAdminAcclvl[16];
bool g_bHideSlots;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
        EngineVersion test = GetEngineVersion();

        if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
        {
                strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
                return APLRes_SilentFailure;
        }

        return APLRes_Success; 
}

public void OnPluginStart()
{
        L4dtoolzExtension = FindConVar("sv_maxplayers");
        if(L4dtoolzExtension == null)
                SetFailState("Could not find ConVar \"sv_maxplayers\".");

        sv_visiblemaxplayers = FindConVar("sv_visiblemaxplayers");
        if(sv_visiblemaxplayers == null)
                SetFailState("Could not find ConVar \"sv_visiblemaxplayers\".");

        g_hCvarReservedSlots = CreateConVar("l4d_reservedslots_adm", "1", "Reserved how many slots for Admin. 預留多少位置給管理員加入. (0=關閉)", CVAR_FLAGS, true, 0.0);
        g_hAdmAccess = CreateConVar("l4d_reservedslots_adm_flag", "z", "Players with these flags have access to use admin reserved slots. (Empty = Everyone, -1: Nobody)", CVAR_FLAGS);
        g_hHideSlots = CreateConVar("l4d_reservedslots_hide", "1", "If set to 1, reserved slots will hidden (subtracted 'l4d_reservedslots_adm' from the max slot 'sv_maxplayers')", CVAR_FLAGS, true, 0.0, true, 1.0);

        GetCvars();
        L4dtoolzExtension.AddChangeHook(ConVarChanged_Cvars);
        sv_visiblemaxplayers.AddChangeHook(ConVarChanged_Cvars);
        g_hCvarReservedSlots.AddChangeHook(ConVarChanged_Cvars);
        g_hAdmAccess.AddChangeHook(ConVarChanged_Cvars);
        g_hHideSlots.AddChangeHook(ConVarChanged_Cvars);

        AutoExecConfig(true, "l4d_reservedslots");
}

public void OnPluginEnd()
{
	/* 	If the plugin has been unloaded, reset visiblemaxplayers. In the case of the server shutting down this effect will not be visible */
	ResetVisibleMax();
}

public void OnMapStart()
{
        CheckHiddenSlots();
}

public void OnConfigsExecuted()
{ 
        CheckHiddenSlots();	
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
        GetCvars();
}

void GetCvars()
{
        g_iMaxplayers = L4dtoolzExtension.IntValue;
        g_iCvarReservedSlots = g_hCvarReservedSlots.IntValue;
        g_hAdmAccess.GetString(g_sAdminAcclvl, sizeof(g_sAdminAcclvl));
        g_bHideSlots = g_hHideSlots.BoolValue;

        CheckHiddenSlots();
}

public void OnClientDisconnect_Post(int client)
{
	CheckHiddenSlots();
}

public void OnClientPostAdminCheck(int client)
{
        if (IsFakeClient(client) || g_iCvarReservedSlots == 0)
                return;
        
        if (IsServerFull(client))
        {
                if(HasAccess(client, g_sAdminAcclvl) == false) CreateTimer(0.1, OnTimedKick, client);
        }
}

public Action OnTimedKick(Handle timer, any client)
{	
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	KickClient(client, MSG_KICK_REASON);
	
	CheckHiddenSlots();
	
	return Plugin_Handled;
}

public bool IsServerFull(int client)
{
        int current = 0;

        for (int i=1; i<=MaxClients; i++)
        {
                if (i==client) continue;
                if (!IsClientConnected(i)) continue;
                if (!IsClientInGame(i)) continue;
                if (IsFakeClient(i)) continue;
                
                current++;
        }
        //PrintToChatAll("%d - %d - %d", current, g_iCvarReservedSlots, g_iMaxplayers);
        if (current + g_iCvarReservedSlots >= g_iMaxplayers) return true;

        return false;
}

public bool HasAccess(int client, const char[] g_sAcclvl)
{
        // no permissions set
        if (strlen(g_sAcclvl) == 0)
                return true;

        else if (StrEqual(g_sAcclvl, "-1"))
                return false;
                
        int iFlag = GetUserFlagBits(client);
        //PrintToChatAll("HasAccess %d - %d", iFlag, ReadFlagString(g_sAcclvl));
        // check permissions
        if ( iFlag & ReadFlagString(g_sAcclvl) || ( iFlag & ADMFLAG_ROOT) )
        {
                return true;
        }

        return false;
}

void CheckHiddenSlots()
{
        if (g_bHideSlots)
        {
                if(g_iMaxplayers > 0 && g_iCvarReservedSlots > 0) sv_visiblemaxplayers.IntValue = g_iMaxplayers - g_iCvarReservedSlots;
        }
        else
        {
                ResetVisibleMax();
        }
}

void ResetVisibleMax()
{
	sv_visiblemaxplayers.IntValue = -1;
}