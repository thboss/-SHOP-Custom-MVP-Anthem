
#include <clientprefs>
#include <sdktools>
#include <shop>

#define MAX_MVP_COUNT 1000

#pragma newdecls required

int MVPCount, Selected[MAXPLAYERS + 1];

char Configfile[1024],
	g_sMVPName[MAX_MVP_COUNT + 1][1024], 
	g_sMVPFile[MAX_MVP_COUNT + 1][1024],
	NameMVP[MAXPLAYERS + 1][1024];

Handle mvp_cookie;

KeyValues kv;

CategoryId mvpCategory;

public Plugin myinfo =
{
	name = "[CS:GO] Custom MVP Anthem",
	author = "Kento",
	version = "1.10",
	description = "Custom MVP Anthem",
	url = "https://github.com/rogeraabbccdd/csgo_mvp"
};

public void OnPluginStart()
{
	
	
	HookEvent("round_mvp", Event_RoundMVP);
	
	LoadTranslations("kento.mvp.phrases");
	
	mvp_cookie = RegClientCookie("mvp_name", "Player's MVP Anthem", CookieAccess_Private);
	

	for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i) && !IsFakeClient(i) && !AreClientCookiesCached(i))	OnClientCookiesCached(i);
	}
	
	if(Shop_IsStarted())Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();    
}

public void Shop_Started()
{
	mvpCategory = Shop_RegisterCategory("mvp", "MVP", "");
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/shop/mvp.cfg");
	char file[PLATFORM_MAX_PATH];
	char item[64], item_name[64];
	MVPCount = 1;
	
	if(kv != INVALID_HANDLE) delete kv;
	
	kv = CreateKeyValues("mvp");
	
	if(!FileToKeyValues(kv, Configfile)) ThrowError("\"%s\" not parsed", Configfile);
	
	kv.Rewind();
	
	if(KvGotoFirstSubKey(kv))
    {
        do{
            if (!KvGetSectionName(kv, item, sizeof(item))) continue;

            kv.GetString("file", file, sizeof(file));
			
			if(!file[0]) continue;
			
			if(Shop_StartItem(mvpCategory, item))
            {
				kv.GetString("name", item_name, sizeof(item_name), item);
                Shop_SetInfo(item_name, "", KvGetNum(kv, "price", 100),  KvGetNum(kv, "sellprice",KvGetNum(kv, "price")/2), Item_Togglable, KvGetNum(kv, "duration", 0));
                Shop_SetLuckChance(KvGetNum(kv, "luckchance", 20));
                Shop_SetCallbacks(_, OnEquipItem);
                Shop_EndItem();
            }
            
            strcopy(g_sMVPName[MVPCount], sizeof(g_sMVPName[]), item);
            strcopy(g_sMVPFile[MVPCount], sizeof(g_sMVPFile[]), file);
                
            char filepath[1024];
            Format(filepath, sizeof(filepath), "sound/%s", g_sMVPFile[MVPCount]);
            AddFileToDownloadsTable(filepath);
            
            char soundpath[1024];
            Format(soundpath, sizeof(soundpath), "*/%s", g_sMVPFile[MVPCount]);
            FakePrecacheSound(soundpath);

            MVPCount++;
        } while (KvGotoNextKey(kv));
    }

    kv.Rewind();
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	char buffer[PLATFORM_MAX_PATH];

	if (isOn || elapsed)
	{
		SetClientCookie(client, mvp_cookie, "");
        Selected[client] = 0;
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	Shop_GetItemById(item_id, buffer, sizeof(buffer));
    SetClientCookie(client, mvp_cookie, buffer);
    Selected[client] = FindMVPIDByName(buffer);
	//PrintToChatAll("%s", buffer);
	return Shop_UseOn;
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))	OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
	if(!IsValidClient(client) && IsFakeClient(client))	return;
		
	char scookie[1024];
	GetClientCookie(client, mvp_cookie, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		Selected[client] = FindMVPIDByName(scookie);
		if(Selected[client] > 0)	strcopy(NameMVP[client], sizeof(NameMVP[]), scookie);
		else 
		{
			NameMVP[client] = "";
			SetClientCookie(client, mvp_cookie, "");
		}
	}
	else if(StrEqual(scookie,""))	NameMVP[client] = "";
}

public Action Event_RoundMVP(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(StrEqual(NameMVP[client], "") || Selected[client] == 0)	return;
	
	int mvp = Selected[client];
	
	char sound[1024];
	Format(sound, sizeof(sound), "*/%s", g_sMVPFile[mvp]);
	
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				// Announce MVP
				PrintHintText(i, "%T", "MVP", client, client, g_sMVPName[mvp]);
					
				// Mute game sound
				// https://forums.alliedmods.net/showthread.php?t=227735
				ClientCommand(i, "playgamesound Music.StopAllMusic");
				
				// Play MVP Anthem
				EmitSoundToClient(i, sound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, _);
			}	
		}
	}
}	

public int FindMVPIDByName(char[] name)
{
	int id = 0;
	
	for(int i = 1; i <= MVPCount; i++)
	{
		if(StrEqual(g_sMVPName[i], name))
			id = i;
	}
	
	return id;
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

// https://wiki.alliedmods.net/Csgo_quirks
stock void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}