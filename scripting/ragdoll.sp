#include <sourcemod>
#include <sdktools>

Address g_wakeRagdollAddress;
int g_wakeRagdollPadding;
Handle g_hCreateServerRagdoll;
bool g_bShouldRecord[MAXPLAYERS+1];
ArrayList g_ragdolls[MAXPLAYERS+1];
int g_bruhModel;

public void OnPluginStart()
{
    GameData gamedata = new GameData("ragdoll.games");

    g_wakeRagdollAddress = gamedata.GetAddress("pRagdoll->InitRagdoll.bWakeRagdoll");

    if (g_wakeRagdollAddress == Address_Null)
    {
        delete gamedata;
        SetFailState("pRagdoll->InitRagdoll.bWakeRagdoll not found");
    }

    g_wakeRagdollPadding = gamedata.GetOffset("bWakeRagdollPadding");
    if (g_wakeRagdollPadding == -1)
    {
        delete gamedata;
        SetFailState("bWakeRagdollPadding not found");
    }

    StoreToAddress(g_wakeRagdollAddress + view_as<Address>(g_wakeRagdollPadding), 0x00, NumberType_Int8);

    StartPrepSDKCall(SDKCall_Static);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CreateServerRagdoll");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer); // pAnimating
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // forceBone
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef); // info
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // collisionGroup
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bUseLRURetirement
    PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hCreateServerRagdoll = EndPrepSDKCall();

    delete gamedata;

    RegConsoleCmd("sm_create_ragdoll", Command_CreateRagdoll);
    HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
    g_bruhModel = PrecacheModel("models/player/bruh.mdl");
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontbroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!g_ragdolls[client])
        g_ragdolls[client].Clear();

}

public void OnClientPutInServer(int client)
{
    delete g_ragdolls[client];
    g_ragdolls[client] = new ArrayList();
}

public void OnClientDisconnect(int client)
{
    if (g_ragdolls[client])
    {
        for (int j = 0; j < g_ragdolls[client].Length; j++)
        {
            AcceptEntityInput(g_ragdolls[client].Get(j), "kill");
        }
    }
}

public void OnPluginEnd()
{
    StoreToAddress(g_wakeRagdollAddress + view_as<Address>(g_wakeRagdollPadding), 0x01, NumberType_Int8);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_ragdolls[i])
        {
            for (int j = 0; j < g_ragdolls[i].Length; j++)
            {
                AcceptEntityInput(g_ragdolls[i].Get(j), "kill");
            }
        }
    }
}

public Action Command_CreateRagdoll(int client, int args)
{
    if (!client)
        return Plugin_Handled;

    g_bShouldRecord[client] = !g_bShouldRecord[client];

    return Plugin_Handled;
}

void CreateRagdoll(int owner)
{
    if (!owner || !IsClientInGame(owner) || IsClientSourceTV(owner))
        return;

    if (!g_ragdolls[owner])
        g_ragdolls[owner] = new ArrayList();

    if (g_ragdolls[owner].Length > 200)
    {
        int ragdoll = g_ragdolls[owner].Get(0);
        AcceptEntityInput(ragdoll, "kill");
        g_ragdolls[owner].Erase(0);
    }

    any info[0x4C];
    int entity = SDKCall(g_hCreateServerRagdoll, owner, GetEntProp(owner, Prop_Send, "m_nForceBone"), info, 3, false);
    SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
    SetEntProp(entity, Prop_Send, "m_nModelIndex", g_bruhModel);
    SetEntityRenderMode(entity, RENDER_TRANSCOLOR)

    int r = RoundFloat(Sine((GetEngineTime() / 2) * 4.0)) * 127 + 128;
    int g = RoundFloat(Sine((GetEngineTime() / 2) * 4.0 + 2.0)) * 127 + 128;
    int b = RoundFloat(Sine((GetEngineTime() / 2) * 4.0 + 4.0)) * 127 + 128;
    SetEntityRenderColor(entity, r, g, b, 64);
    g_ragdolls[owner].Push(entity);
}

public Action OnPlayerRunCmd(int client)
{
    if (!client || IsFakeClient(client) || !g_bShouldRecord[client])
        return Plugin_Continue;

    if (GetGameTickCount() % 2 == 0)
        CreateRagdoll(client);

    return Plugin_Continue;
}