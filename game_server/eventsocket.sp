#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <socket>
#include <smlib>

/******************************************************************************
* Event types:
* C - connected
* A - attacked
* F - weapon fired
* R - reload (pre)
* S - weapon switch (buggy)
*
* Need to implement:
* P - reload (post)
* H - health update
******************************************************************************/

new Handle:listener;
new bool:inUse = false;
new listenClient;
new bool:clientConnected = false;

public Plugin:myinfo = {
    name = "L4D2 socket events",
    author = "wchill",
    description = "Provides a server that broadcasts events over a socket",
    version = "1.0.0",
    url = "http://vps2.intense.io/"
};
 
public OnPluginStart() {
    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("weapon_reload", Event_WeaponReload);
//  HookEvent("heal_success", Event_HealSuccess);
//  HookEvent("pills_used", Event_MedsUsed);
//  HookEvent("adrenaline_used", Event_MedsUsed);
    // enable socket debugging (only for testing purposes!)
    SocketSetOption(INVALID_HANDLE, DebugMode, 1);


    // create a new tcp socket
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
    // bind the socket to all interfaces, port 50000
    SocketBind(socket, "0.0.0.0", 50000);
    // let the socket listen for incoming connections
    SocketListen(socket, OnSocketIncoming);
}

/*
public OnEntityCreated(entity, const String:classname[]) {
    if(StrContains(classname, "weapon_") != -1) {
        SDKHook(entity, SDKHook_SpawnPost, OnWeaponSpawned);
    }
}

public OnWeaponSpawned(entity) {
    decl String:classname[MAX_NAME_LENGTH];
    GetEdictClassname(entity, classname, sizeof(classname));
    PrintToServer("Weapon spawned: %s", classname);
    PrintToChatAll("Weapon spawned: %s", classname);
    SDKHook(entity, SDKHook_ReloadPost, OnWeaponReload);
}

public OnWeaponReload(weapon, bool:bSuccessful) {
    if(bSuccessful) {
        PrintToChatAll("Reload complete");
    }
}
*/

// Prints out the following:
// C - Connect event
// Client name
// name of current weapon
// number of bullets in current clip
// perm health
// temp health
stock GetConnectString(client, String:clientInfo[], size) {
    decl String:weapon[64]
    Client_GetActiveWeaponName(client, weapon, sizeof(weapon));
    strcopy(weapon, sizeof(weapon), weapon[7]);
    new weapon_id = Client_GetActiveWeapon(client);
    new clip_ammo = Weapon_GetPrimaryClip(weapon_id);
    new perm_health = GetClientHealth(client);
    new temp_health = GetClientTempHealth(client);
    Format(clientInfo, size, "C\t%N\t%s\t%d\t%d\t%d\n",
        client, weapon, clip_ammo, perm_health, temp_health);
}

public OnClientPostAdminCheck(client) {
    new String:name[MAX_NAME_LENGTH];
    decl String:auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    if(StrEqual(auth, "STEAM_1:1:44525921")) {
        PrintToServer("Hooked %s", auth);
        listenClient = client;
        clientConnected = true;
        if(inUse) {
            decl String:clientInfo[128];
            GetConnectString(client, clientInfo, sizeof(clientInfo));
            SocketSend(listener, clientInfo);
        }
//      SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    }
    if(IsClientInGame(client) && !IsFakeClient(client)) {
        PrintToChat(client, "\x04[SM][ADMIN] Please note that this server is for development purposes and as such, unusual things may happen from time to time. I apologize for the inconvenience");
        PrintToChatAll("\x03Client %N (%s) connected", client, auth);
    }
}

public OnWeaponSwitchPost(client, weapon) {
    if(inUse) {
        decl String:sendString[MAX_NAME_LENGTH + 16];
        decl String:weaponName[MAX_NAME_LENGTH];
        Client_GetActiveWeaponName(client, weaponName, sizeof(weaponName));
        strcopy(weaponName, sizeof(weaponName), weaponName[7]);
        new weaponAmmo = Weapon_GetPrimaryClip(weapon);
        Format(sendString, sizeof(sendString), "S\t%s\t%d\n", weaponName, weaponAmmo);
        SocketSend(listener, sendString);
    }
}

public Action:OnTakeDamagePost(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
    if(inUse) {
        if(IsClientInGame(victim)) {
            decl String:victimName[MAX_NAME_LENGTH];
            Format(victimName, sizeof(victimName), "%N", victim);
            new permHp = GetClientHealth(victim);
            new tempHp = GetClientTempHealth(victim);
            new String:fmtString[64];
            Format(fmtString, sizeof(fmtString), "A\t%d\t%d\n", permHp, tempHp);
            SocketSend(listener, fmtString);
        }
    }
    return Plugin_Continue;
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast) {
    decl String:weapon[64]
    new attackerId = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:attackerName[MAX_NAME_LENGTH];
    Format(attackerName, sizeof(attackerName), "%N", attackerId);
    if(!StrEqual(attackerName, "xXSwaggernautsXx")) {
        return;
    }
//  GetEventString(event, "weapon", weapon, sizeof(weapon));
    Client_GetActiveWeaponName(attackerId, weapon, sizeof(weapon));
    strcopy(weapon, sizeof(weapon), weapon[7]);
    new iWeapon = Client_GetActiveWeapon(attackerId);
//  new iWeapon = GetPlayerWeaponSlot(attackerId, 0); 
//  new iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
    new iAmmo = Weapon_GetPrimaryClip(iWeapon);
    decl String:fmtString[255];
    if(iAmmo < 0) {
        Format(fmtString, sizeof(fmtString), "F\t%s\t%d\n", weapon, 0);
    } else {
        Format(fmtString, sizeof(fmtString), "F\t%s\t%d\n", weapon, iAmmo-1);
    }
    PrintToServer(fmtString);
    if(inUse) {
        SocketSend(listener, fmtString); 
    }

// pulled from Perkmod2 for testing

new iCid = attackerId;
new iAmmoO=FindDataMapOffs(iCid,"m_iAmmo");
decl iAmmoO_offset;
decl iAmmoCount;

//checks each weapon type ammo in player's inventory
//if non-zero, then assume player has that weapon
//and adjust only that weapon's ammo

//----DEBUG----
//new iI = 0;
//PrintToChatAll("\x05PR\x03 being feedback loop");
//while (iI <= 64)
//{
    //iAmmoCount = GetEntData(iCid, iAmmoO + iI);
    //PrintToChatAll("\x05PR\x03 iI = \x01%i\x03, value = \x01%i",iI, iAmmoCount);
    //iI++;
//}

//rifle - offset +12
iAmmoO_offset = 12;
iAmmoCount = GetEntData(iCid, iAmmoO + iAmmoO_offset);
if (iAmmoCount > 0)
{
    PrintToChat(iCid, "Rifle reserve ammo %d", iAmmoCount);
}
//smg - offset +20
iAmmoO_offset = 20;
iAmmoCount = GetEntData(iCid, iAmmoO + iAmmoO_offset);
if (iAmmoCount > 0)
{
    PrintToChat(iCid, "SMG reserve ammo %d", iAmmoCount);
}
}

public Event_WeaponReload(Handle:event, const String:name[], bool:dontBroadcast) {
    decl String:weapon[64]
    new attackerId = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:attackerName[MAX_NAME_LENGTH];
    Format(attackerName, sizeof(attackerName), "%N", attackerId);
    if(!StrEqual(attackerName, "xXSwaggernautsXx")) {
        return;
    }
    Client_GetActiveWeaponName(attackerId, weapon, sizeof(weapon))
    strcopy(weapon, sizeof(weapon), weapon[7]);
    new iWeapon = Client_GetActiveWeapon(attackerId);
    new iAmmo;
    new pAmmo;
//  if(Client_GetWeaponPlayerAmmo(attackerId, weapon, pAmmo, iAmmo)){
//      PrintToServer("failed...");
//  }
    iAmmo = Weapon_GetPrimaryAmmoCount(iWeapon);
//  new iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
    new String:fmtString[255];
    Format(fmtString, sizeof(fmtString), "R\t%s\t%d\n", weapon, iAmmo);
    PrintToServer(fmtString);
    if(inUse) {
        SocketSend(listener, fmtString); 
    }
new iCid = attackerId;
new iAmmoO=FindDataMapOffs(iCid,"m_iAmmo");
decl iAmmoO_offset;
decl iAmmoCount;

//checks each weapon type ammo in player's inventory
//if non-zero, then assume player has that weapon
//and adjust only that weapon's ammo

//----DEBUG----
//new iI = 0;
//PrintToChatAll("\x05PR\x03 being feedback loop");
//while (iI <= 64)
//{
    //iAmmoCount = GetEntData(iCid, iAmmoO + iI);
    //PrintToChatAll("\x05PR\x03 iI = \x01%i\x03, value = \x01%i",iI, iAmmoCount);
    //iI++;
//}

//rifle - offset +12
iAmmoO_offset = 12;
iAmmoCount = GetEntData(iCid, iAmmoO + iAmmoO_offset);
if (iAmmoCount > 0)
{
    PrintToChat(iCid, "Rifle reserve ammo %d", iAmmoCount);
}
//smg - offset +20
iAmmoO_offset = 20;
iAmmoCount = GetEntData(iCid, iAmmoO + iAmmoO_offset);
if (iAmmoCount > 0)
{
    PrintToChat(iCid, "SMG reserve ammo %d", iAmmoCount);
}
new g_iNextPAttO  = FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
new Float:flGameTime = GetGameTime();
new Float:flNextTime_ret = GetEntDataFloat(iWeapon,g_iNextPAttO);
PrintToChat(iCid, "Reloading in %f seconds", flNextTime_ret-flGameTime);
}

public OnSocketIncoming(Handle:socket, Handle:newSocket, String:remoteIP[], remotePort, any:arg) {
    PrintToServer("%s:%d connected", remoteIP, remotePort);
    PrintToChatAll("\x04[SM][DEBUG] Socket listener %s:%d connected", remoteIP, remotePort);
    listener = newSocket;
    inUse = true;
    SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
    SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
    SocketSetErrorCallback(newSocket, OnChildSocketError);
    if(clientConnected) {
        decl String:clientInfo[128];
        GetConnectString(listenClient, clientInfo, sizeof(clientInfo));
        SocketSend(listener, clientInfo);
    }
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
    // a socket error occured

    LogError("socket error %d (errno %d)", errorType, errorNum);
    if(socket == listener) inUse = false;
    CloseHandle(socket);
    PrintToChatAll("\x04[SM][DEBUG] Socket listener disconnected");
}

public OnChildSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
    // send (echo) the received data back
    SocketSend(socket, receiveData);
    // close the connection/socket/handle if it matches quit
    if (strncmp(receiveData, "quit", 4) == 0) {
        inUse = false;
        CloseHandle(socket);
    }
}

public OnChildSocketDisconnected(Handle:socket, any:hFile) {
    // remote side disconnected
    if(socket == listener) inUse = false;
    CloseHandle(socket);
    PrintToChatAll("[SM][DEBUG] Socket listener disconnected");
}

public OnChildSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
    // a socket error occured

    LogError("child socket error %d (errno %d)", errorType, errorNum);
    if(socket == listener) inUse = false;
    CloseHandle(socket);
    PrintToChatAll("[SM][DEBUG] Socket listener disconnected");
}

stock GetClientTempHealth(client) {
    //First filter -> Must be a valid client, successfully in-game and not an spectator (The dont have health).
    if(!client
    || !IsValidEntity(client)
    || !IsClientInGame(client)
    || !IsPlayerAlive(client)
    || IsClientObserver(client)
    || GetClientTeam(client) != 2)
    {
        return -1;
    }
    
    //First, we get the amount of temporal health the client has
    new Float:buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    
    //We declare the permanent and temporal health variables
    new Float:TempHealth;
    
    //In case the buffer is 0 or less, we set the temporal health as 0, because the client has not used any pills or adrenaline yet
    if(buffer <= 0.0)
    {
        TempHealth = 0.0;
    }
    
    //In case it is higher than 0, we proceed to calculate the temporl health
    else
    {
        //This is the difference between the time we used the temporal item, and the current time
        new Float:difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
        
        //We get the decay rate from this convar (Note: Adrenaline uses this value)
        new Float:decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
        
        //This is a constant we create to determine the amount of health. This is the amount of time it has to pass
        //before 1 Temporal HP is consumed.
        new Float:constant = 1.0/decay;
        
        //Then we do the calcs
        TempHealth = buffer - (difference / constant);
    }
    
    //If the temporal health resulted less than 0, then it is just 0.
    if(TempHealth < 0.0)
    {
        TempHealth = 0.0;
    }
    
    //Return the value
    return RoundToFloor(TempHealth);
}
