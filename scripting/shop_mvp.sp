#include <clientprefs>
#include <sdktools>
#include <kento_csgocolors>
#include <shop>

#define MAX_MVP_COUNT 1000

#pragma newdecls required

int MVPCount;
int Selected[MAXPLAYERS + 1];
float VolMVP[MAXPLAYERS + 1];

char Configfile[1024],
	g_sMVPName[MAX_MVP_COUNT + 1][1024], 
	g_sMVPFile[MAX_MVP_COUNT + 1][1024],
	NameMVP[MAXPLAYERS + 1][1024];

Handle mvp_cookie, mvp_cookie2;

KeyValues kv;

CategoryId mvpCategory;

public Plugin myinfo =
{
	name = "[SHOP] Custom MVP Anthem",
	author = "Kento, TheBO$$",
	version = "1.10",
	description = "Shop module for Custom MVP Anthem",
	url = ""
};

public void OnPluginStart()
{
	
	
	HookEvent("round_mvp", Event_RoundMVP);
	RegConsoleCmd("sm_mvp", Command_MVPVol, "MVP Volume");
	
	LoadTranslations("kento.mvp.phrases");
	
	mvp_cookie = RegClientCookie("mvp_name", "Player's MVP Anthem", CookieAccess_Private);
	mvp_cookie2 = RegClientCookie("mvp_vol", "Player MVP volume", CookieAccess_Private);
	

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
				Shop_SetInfo(item_name, "", KvGetNum(kv, "price", 100), KvGetNum(kv, "sellprice",KvGetNum(kv, "price")/2), Item_Togglable, KvGetNum(kv, "duration", 0));
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

	GetClientCookie(client, mvp_cookie2, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		VolMVP[client] = StringToFloat(scookie);
	}
	else if(StrEqual(scookie,""))	VolMVP[client] = 1.0;
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
				EmitSoundToClient(i, sound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, VolMVP[i]);
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

public Action Command_MVPVol(int client,int args)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		DisplayVolMenu(client);
	}
	return Plugin_Handled;
}

void DisplayVolMenu(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		Menu vol_menu = new Menu(VolMenuHandler);
		
		char vol[1024];
		if(VolMVP[client] > 0.00)	Format(vol, sizeof(vol), "%.2f", VolMVP[client]);
		else Format(vol, sizeof(vol), "%T", "Mute", client);
		
		char menutitle[1024];
		Format(menutitle, sizeof(menutitle), "%T", "Vol Menu Title 2", client, vol);
		vol_menu.SetTitle(menutitle);
		
		char mute[1024];
		Format(mute, sizeof(mute), "%T", "Mute", client);
		
		vol_menu.AddItem("0", mute);
		vol_menu.AddItem("0.2", "20%");
		vol_menu.AddItem("0.4", "40%");
		vol_menu.AddItem("0.6", "60%");
		vol_menu.AddItem("0.8", "80%");
		vol_menu.AddItem("1.0", "100%");
		vol_menu.Display(client, 0);
	}
}

public int VolMenuHandler(Menu menu, MenuAction action, int client,int param)
{
	if(action == MenuAction_Select)
	{
		char vol[1024];
		GetMenuItem(menu, param, vol, sizeof(vol));
		
		VolMVP[client] = StringToFloat(vol);
		CPrintToChat(client, "%T", "Volume 2", client, VolMVP[client]);
		
		SetClientCookie(client, mvp_cookie2, vol);
	}
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
