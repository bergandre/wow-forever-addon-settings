-- The content of this file is AUTO-GENERATED
-- You can update it at https://www.curseforge.com/wow/addons/autolooter/localization

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("AutoLooter", "enUS", true, true)
if L then
	L["(Legacy Types)"] = true
L["Add item to alert list"] = true
L["Add item to ignore list"] = true
L["Add item to white list"] = true
L["Added"] = true
L["Alert List"] = true
L["All"] = true
L["All items received between this delay will be grouped"] = true
L["Already in the list"] = true
L["Auto confirm loot roll"] = true
L["Blacklist"] = true
L["Close"] = true
L["Close after loot"] = true
L["Coin"] = true
L["Disabled"] = true
L["Don't loot anything while Fishing"] = true
L["Enable AutoLooter"] = true
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
L["Enabled"] = true
L["Fast loot"] = true
L["Fishing"] = true
L["General"] = true
L["Hold and drag to move"] = true
L["Ignore BoP"] = true
L["Ignore Fishing"] = true
L["Ignore greys when looting by type"] = true
L["Ignored"] = true
L["Integration"] = true
L["Invalid item"] = true
L["Items list"] = true
L["Left-click"] = true
L["Listed"] = true
L["Load Profile"] = true
L["Load profile '${profile}' and reload UI?"] = true
L["Locked"] = true
L["Loot by Price"] = true
L["Loot by Rarity"] = true
L["Loot everything"] = true
L["Loot everything while Fishing"] = true
L["Loot everything with a price greater or equal to this value"] = true
L["Loot quest items"] = true
L["Not listed"] = true
L["Off"] = true
L["On"] = true
L["Price"] = true
L["Price (in coppers)"] = true
L["Print items others receive"] = true
L["Print items you receive"] = true
L["Printout chat frames"] = true
L["Printout commands at login"] = true
L["Printout items icon only"] = true
L["Printout items ignored"] = true
L["Printout items looted"] = true
L["Printout items type"] = true
L["Printout reason of loot"] = true
L["Quest"] = true
L["Rarity"] = true
L["Received Items"] = true
L["Received items group Delay (ms)"] = true
L["Remove all"] = true
L["Remove item from alert list"] = true
L["Remove item from ignore list"] = true
L["Remove item from white list"] = true
L["Remove old entries"] = true
L["Removed"] = true
L["Right-click"] = true
L["Right-click to show profile menu"] = true
L["Select all"] = true
L["Set alert sound"] = true
L["Show/Hide minimap button"] = true
L["Show/Hide UI"] = true
L["This can be useful to let addons like Fishing Buddy do its work"] = true
L["This will cleanup and recreate the type database"] = true
L["This will remove old types/subtypes entries from the database"] = true
L["to Enable/Disable loot all"] = true
L["to Show/Hide UI"] = true
L["Token"] = true
L["Try to show loot animation"] = true
L["Type"] = true
L["Whitelist"] = true
L["You"] = true
L["You can drag & drop items here!"] = true


	if GetLocale() == "enUS" or GetLocale() == "enGB" then
		return
	end
end

L = AceLocale:NewLocale("AutoLooter", "ptBR")
if L then
	L["(Legacy Types)"] = "(Tipos Legados)"
L["Add item to alert list"] = "Adiciona um item na lista de alertas"
L["Add item to ignore list"] = "Adiciona um item na lista de ignorados"
L["Add item to white list"] = "Adiciona um item na lista branca"
L["Added"] = "Adicionado"
L["Alert List"] = "Lista de Alertas"
L["All"] = "Tudo"
L["All items received between this delay will be grouped"] = "Todos os itens recebidos dentro deste intervalo serão agrupados"
L["Already in the list"] = "Já está na lista"
L["Auto confirm loot roll"] = "Auto confirmar loot"
L["Blacklist"] = "Lista Negra"
L["Close"] = "Fechar"
L["Close after loot"] = "Fechar após pegar"
L["Coin"] = "Moeda"
L["Disabled"] = "Desligado"
L["Don't loot anything while Fishing"] = "Não pegar itens enquanto pescando"
L["Enable AutoLooter"] = "Ativar AutoLooter"
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter não irá pegar nenhum item quando o Saque automático do WoW estiver funcionando!

Isso possibilita utilizar a tecla de saque para ativar/desativar o AutoLooter por alvo.

Você pode configurar essas opções em 'Menu > Interface > Controles'.]=]
L["Enabled"] = "Ligado"
L["Fast loot"] = "Loot rápido"
L["Fishing"] = "Pescaria"
L["General"] = "Geral"
L["Hold and drag to move"] = "Segure e arraste para mover"
L["Ignore BoP"] = "Ignorar BoP"
L["Ignore Fishing"] = "Ignorar pescaria"
L["Ignore greys when looting by type"] = "Ignorar cinzas ao pegar por tipo"
L["Ignored"] = "Ignorado"
L["Integration"] = "Integração"
L["Invalid item"] = "Item inválido"
L["Items list"] = "Lista de itens"
L["Left-click"] = "Clique-esquerdo"
L["Listed"] = "Lista"
L["Load Profile"] = "Carrega Perfil"
L["Load profile '${profile}' and reload UI?"] = "Carrega Perfil '${profile}' e recarregar UI?"
L["Locked"] = "Bloqueado"
L["Loot by Price"] = "Loot por preço"
L["Loot by Rarity"] = "Loot por raridade"
L["Loot everything"] = "Pegar tudo"
L["Loot everything while Fishing"] = "Pegar tudo enquanto pescando"
L["Loot everything with a price greater or equal to this value"] = "Pega todos os itens com preço maior ou igual a esse valor"
L["Loot quest items"] = "Pegar itens de missão"
L["Not listed"] = "Não listado"
L["Off"] = "Desligado"
L["On"] = "Ligado"
L["Price"] = "Preço"
L["Price (in coppers)"] = "Preço (em bronze)"
L["Print items others receive"] = "Escrever items que os outros recebem"
L["Print items you receive"] = "Escrever items que você recebe"
L["Printout chat frames"] = "Escrever nos seguintes chats"
L["Printout commands at login"] = "Exibir comandos durante o login"
L["Printout items icon only"] = "Exibir apenas o icone dos itens no chat"
L["Printout items ignored"] = "Escrever ignorados"
L["Printout items looted"] = "Escrever loot"
L["Printout items type"] = "Escrever o tipo"
L["Printout reason of loot"] = "Escrever a razão do loot"
L["Quest"] = "Missão"
L["Rarity"] = "Raridade"
L["Received Items"] = "Itens recebidos"
L["Received items group Delay (ms)"] = "Intervalo de agrupamento dos itens recebidos (ms)"
L["Remove all"] = "Remover todos"
L["Remove item from alert list"] = "Remove um item da lista de alertas"
L["Remove item from ignore list"] = "Remove um item da lista de ignorados"
L["Remove item from white list"] = "Remove um item da lista branca"
L["Remove old entries"] = "Remover registros antigos"
L["Removed"] = "Removido"
L["Right-click"] = "Clique-direito"
L["Right-click to show profile menu"] = "Clique-direito para exibir o menu de perfil"
L["Select all"] = "Selecionar todos"
L["Set alert sound"] = "Altera o som de alerta"
L["Show/Hide minimap button"] = "Mostra/Esconde botão do minimapa"
L["Show/Hide UI"] = "Mostra/Esconde a UI"
L["This can be useful to let addons like Fishing Buddy do its work"] = "Isso pode ser util para permitir que addons como Fishing Buddy cuidem da pesca"
L["This will cleanup and recreate the type database"] = "Isso irá limpar e recriar o banco de dados de tipo"
L["This will remove old types/subtypes entries from the database"] = "Isso irá remover todos os tipos/subtipos antigos do banco de dados"
L["to Enable/Disable loot all"] = "para Liga/Desligar 'pegar tudo'"
L["to Show/Hide UI"] = "para Mostrar/Esconder a UI"
L["Token"] = "Moeda"
L["Try to show loot animation"] = "Tentar exibir animação de saque"
L["Type"] = "Tipo"
L["Whitelist"] = "Lista Branca"
L["You"] = "Você"
L["You can drag & drop items here!"] = "Você pode arrastar e soltar itens aqui!"

	--[==[@debug@
	L["Select all"] = "Selecionar todos"
	L["Remove all"] = "Remover todos"
	L["Enable AutoLooter"] = "Ativar AutoLooter"
	L["Printout items looted"] = "Escrever loot"
	L["Printout items ignored"] = "Escrever ignorados"
	L["Printout items type"] = "Escrever o tipo"
	L["Loot everything"] = "Pegar tudo"
	L["Loot quest items"] = "Pegar itens de missão"
	L["Close after loot"] = "Fechar após pegar"
	L["Ignore greys when looting by type"] = "Ignorar cinzas ao pegar por tipo"
	L["Auto confirm loot roll"] = "Auto confirmar loot"
	L["Close"] = "Fechar"
	L["Price (in coppers)"] = "Preço (em bronze)"
	L["Rarity"] = "Raridade"
	L["Locked"] = "Bloqueado"
	L["Coin"] = "Moeda"
	L["Listed"] = "Lista"
	L["Rarity"] = "Raridade"
	L["Price"] = "Preço"
	L["All"] = "Tudo"
	L["Quest"] = "Missão"
	L["Ignored"] = "Ignorado"
	L["Type"] = "Tipo"
	L["Token"] = "Moeda"
	L["(Legacy Types)"] = "(Tipos Legados)"
	L["Enabled"] = "Ligado"
	L["Disabled"] = "Desligado"
	L["On"] = "Ligado"
	L["Off"] = "Desligado"
	L["Loot by Price"] = "Loot por preço"
	L["Loot by Rarity"] = "Loot por raridade"
	L["Add item to white list"] = "Adiciona um item na lista branca"
	L["Add item to ignore list"] = "Adiciona um item na lista de ignorados"
	L["Add item to alert list"] = "Adiciona um item na lista de alertas"
	L["Remove item from white list"] = "Remove um item da lista branca"
	L["Remove item from ignore list"] = "Remove um item da lista de ignorados"
	L["Remove item from alert list"] = "Remove um item da lista de alertas"
	L["Set alert sound"] = "Altera o som de alerta"
	L["Invalid item"] = "Item inválido"
	L["Already in the list"] = "Já está na lista"
	L["Added"] = "Adicionado"
	L["Removed"] = "Removido"
	L["Not listed"] = "Não listado"
	L["Left-click"] = "Clique-esquerdo"
	L["Right-click"] = "Clique-direito"
	L["to Show/Hide UI"] = "para Mostrar/Esconder a UI"
	L["Show/Hide UI"] = "Mostra/Esconde a UI"
	L["Show/Hide minimap button"] = "Mostra/Esconde botão do minimapa"
	L["to Enable/Disable loot all"] = "para Liga/Desligar 'pegar tudo'"
	L["Hold and drag to move"] = "Segure e arraste para mover"
	L["Ignore BoP"] = "Ignorar BoP"
	L["General"] = "Geral"
	L["Alert List"] = "Lista de Alertas"
	L["Blacklist"] = "Lista Negra"
	L["Whitelist"] = "Lista Branca"
	L["Items list"] = "Lista de itens"
	L["You can drag & drop items here!"] = "Você pode arrastar e soltar itens aqui!"
	L["Printout items icon only"] = "Exibir apenas o icone dos itens no chat"
	L["Printout reason of loot"] = "Escrever a razão do loot"
	L["Printout chat frames"] = "Escrever nos seguintes chats"
	L["Fishing"] = "Pescaria"
	L["Loot everything while Fishing"] = "Pegar tudo enquanto pescando"
	L["Remove old entries"] = "Remover registros antigos"
	L["This will cleanup and recreate the type database"] = "Isso irá limpar e recriar o banco de dados de tipo"
	L["This will remove old types/subtypes entries from the database"] = "Isso irá remover todos os tipos/subtipos antigos do banco de dados"
	L["Ignore Fishing"] = "Ignorar pescaria"
	L["Integration"] = "Integração"
	L["Don't loot anything while Fishing"] = "Não pegar itens enquanto pescando"
	L["This can be useful to let addons like Fishing Buddy do its work"] = "Isso pode ser util para permitir que addons como Fishing Buddy cuidem da pesca"
	L["ENABLE_AUTO_LOOTER_DESC"] = "AutoLooter não irá pegar nenhum item quando o Saque automático do WoW estiver funcionando.\n\n" ..
			"Isso possibilita utilizar a tecla de saque para ativar/desativar o AutoLooter por alvo.\n\n" ..
			"Você pode configurar essas opções em 'Menu > Interface > Controles'."
	L["Loot everything with a price greater or equal to this value"] = "Pega todos os itens com preço maior ou igual a esse valor"
	L["Fast loot"] = "Loot rápido"
	L["Try to show loot animation"] = "Tentar exibir animação de saque"
	L["Printout commands at login"] = "Exibir comandos durante o login"
	L["Received Items"] = "Itens recebidos"
	L["Print items you receive"] = "Escrever items que você recebe"
	L["Print items others receive"] = "Escrever items que os outros recebem"
	L["Received items group Delay (ms)"] = "Intervalo de agrupamento dos itens recebidos (ms)"
	L["All items received between this delay will be grouped"] = "Todos os itens recebidos dentro deste intervalo serão agrupados"
	L["You"] = "Você"
	--@end-debug@]==]

	return
end

L = AceLocale:NewLocale("AutoLooter", "frFR")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
L["Add item to alert list"] = "Ajouter un objet dans la liste d'alerte"
L["Add item to ignore list"] = "Ajouter un objet dans la liste noire"
L["Add item to white list"] = "Ajoute un objet dans la liste blanche"
L["Added"] = "Ajouté"
L["Alert List"] = "Liste d'alerte"
L["All"] = "Tout"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
L["Already in the list"] = "Déjà dans la liste"
L["Auto confirm loot roll"] = "Confirmer automatiquement les lancers de dés"
L["Blacklist"] = "Liste noire"
L["Close"] = "Fermer"
L["Close after loot"] = "Fermer après avoir ramassé le butin"
L["Coin"] = "Pièce"
L["Disabled"] = "Désactivé"
L["Don't loot anything while Fishing"] = "Ne rien rien ramasser en péchant"
L["Enable AutoLooter"] = "Activer AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "deDE")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
--[[Translation missing --]]
L["Add item to alert list"] = "Add item to alert list"
--[[Translation missing --]]
L["Add item to ignore list"] = "Add item to ignore list"
--[[Translation missing --]]
L["Add item to white list"] = "Add item to white list"
--[[Translation missing --]]
L["Added"] = "Added"
--[[Translation missing --]]
L["Alert List"] = "Alert List"
--[[Translation missing --]]
L["All"] = "All"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
--[[Translation missing --]]
L["Already in the list"] = "Already in the list"
--[[Translation missing --]]
L["Auto confirm loot roll"] = "Auto confirm loot roll"
--[[Translation missing --]]
L["Blacklist"] = "Blacklist"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close after loot"] = "Close after loot"
--[[Translation missing --]]
L["Coin"] = "Coin"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
--[[Translation missing --]]
L["Enable AutoLooter"] = "Enable AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "itIT")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
--[[Translation missing --]]
L["Add item to alert list"] = "Add item to alert list"
--[[Translation missing --]]
L["Add item to ignore list"] = "Add item to ignore list"
--[[Translation missing --]]
L["Add item to white list"] = "Add item to white list"
--[[Translation missing --]]
L["Added"] = "Added"
--[[Translation missing --]]
L["Alert List"] = "Alert List"
--[[Translation missing --]]
L["All"] = "All"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
--[[Translation missing --]]
L["Already in the list"] = "Already in the list"
--[[Translation missing --]]
L["Auto confirm loot roll"] = "Auto confirm loot roll"
--[[Translation missing --]]
L["Blacklist"] = "Blacklist"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close after loot"] = "Close after loot"
--[[Translation missing --]]
L["Coin"] = "Coin"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
--[[Translation missing --]]
L["Enable AutoLooter"] = "Enable AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "esES")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
--[[Translation missing --]]
L["Add item to alert list"] = "Add item to alert list"
--[[Translation missing --]]
L["Add item to ignore list"] = "Add item to ignore list"
--[[Translation missing --]]
L["Add item to white list"] = "Add item to white list"
L["Added"] = "Agregar"
--[[Translation missing --]]
L["Alert List"] = "Alert List"
L["All"] = "Todo"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
--[[Translation missing --]]
L["Already in the list"] = "Already in the list"
--[[Translation missing --]]
L["Auto confirm loot roll"] = "Auto confirm loot roll"
--[[Translation missing --]]
L["Blacklist"] = "Blacklist"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close after loot"] = "Close after loot"
--[[Translation missing --]]
L["Coin"] = "Coin"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
--[[Translation missing --]]
L["Enable AutoLooter"] = "Enable AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "esMX")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
L["Add item to alert list"] = "Agregar objeto a la lista de alertas"
L["Add item to ignore list"] = "Agregar objeto a la lista de ignorados"
L["Add item to white list"] = "Agregar objeto a la lista blanca"
L["Added"] = "Agregar"
L["Alert List"] = "Lista de alertas"
L["All"] = "Todo"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
L["Already in the list"] = "Ya se encuentra en la lista"
L["Auto confirm loot roll"] = "Confirmar automáticamente el botín"
L["Blacklist"] = "Lista Negra"
L["Close"] = "Cerrar"
L["Close after loot"] = "Cerrar después del botín"
--[[Translation missing --]]
L["Coin"] = "Coin"
L["Disabled"] = "Deshabilitado"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
L["Enable AutoLooter"] = "Habilitar AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
L["Enabled"] = "Habilitado"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
L["General"] = "General"
L["Hold and drag to move"] = "Sostenga y arrastre para mover"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
L["Ignored"] = "Ignorar"
--[[Translation missing --]]
L["Integration"] = "Integration"
L["Invalid item"] = "Objeto Invalido"
L["Items list"] = "Lista de objetos"
L["Left-click"] = "Click izquierdo"
L["Listed"] = "Listado"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
L["Locked"] = "Cerrado"
L["Loot by Price"] = "Recolectar por precio"
L["Loot by Rarity"] = "Recolectar por rareza"
L["Loot everything"] = "Recolectar todo"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
L["Loot quest items"] = "Recolectar objetos de misión"
L["Not listed"] = "No enlistado"
L["Off"] = "Apagar"
L["On"] = "Encender"
L["Price"] = "Precio"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "ruRU")
if L then
	L["(Legacy Types)"] = "(Устаревшие типы)"
L["Add item to alert list"] = "Добавить предмет в список уведомлений"
L["Add item to ignore list"] = "Добавить предмет в черный список"
L["Add item to white list"] = "Добавить предмет в белый список"
L["Added"] = "Добавлено"
L["Alert List"] = "Список уведомлений"
L["All"] = "Всё"
L["All items received between this delay will be grouped"] = "Все полученные за указанный период предметы будут сгруппированы"
L["Already in the list"] = "Уже в списке"
L["Auto confirm loot roll"] = "Автоподтверждение ролла"
L["Blacklist"] = "Черный список"
L["Close"] = "Закрыть"
L["Close after loot"] = "Закрыть после сбора"
L["Coin"] = "Деньги"
L["Disabled"] = "Отключено"
L["Don't loot anything while Fishing"] = "Не собирать во время рыбалки"
L["Enable AutoLooter"] = "Включить AutoLooter"
L["ENABLE_AUTO_LOOTER_DESC"] = "AutoLooter не будет ничего собирать, если WoW собирает своей встроенной функцией! Это позволяет использовать клавишу автосбора как способ включения/выключения AutoLooter от цели к цели. Эти настройки можно изменить в \"Меню\" -> \"Интерфейс\" -> \"Управление\"."
L["Enabled"] = "Включено"
L["Fast loot"] = "Быстрый сбор"
L["Fishing"] = "Рыбалка"
L["General"] = "Общие настройки"
L["Hold and drag to move"] = "Удерживай и тащи, чтобы перемещать"
L["Ignore BoP"] = "Игнорировать BoP"
L["Ignore Fishing"] = "Игнорировать рыбалку"
L["Ignore greys when looting by type"] = "Игнорировать мусор при сборе по типу"
L["Ignored"] = "Игнорируется"
L["Integration"] = "Интеграция"
L["Invalid item"] = "Неверный предмет"
L["Items list"] = "Список предметов"
L["Left-click"] = "Левый щелчок"
L["Listed"] = "Внесено в список"
L["Load Profile"] = "Загрузить профиль"
L["Load profile '${profile}' and reload UI?"] = "Загрузить профиль '${profile}' и перезагрузить интерфейс?"
L["Locked"] = "Заблокировано"
L["Loot by Price"] = "Сбор по цене"
L["Loot by Rarity"] = "Сбор по редкости"
L["Loot everything"] = "Собирать всё"
L["Loot everything while Fishing"] = "Собирать всё во время рыбалки"
L["Loot everything with a price greater or equal to this value"] = "Собирать всё, что дороже указанной стоимости"
L["Loot quest items"] = "Собирать квестовые предметы"
L["Not listed"] = "Не внесено в список"
L["Off"] = "Выключено"
L["On"] = "Включено"
L["Price"] = "Цена"
L["Price (in coppers)"] = "Цена (в медных монетах)"
L["Print items others receive"] = "Выводить предметы, которые собирают другие"
L["Print items you receive"] = "Выводить предметы, которые собираете вы."
L["Printout chat frames"] = "Окна чата для отображения"
L["Printout commands at login"] = "Выводить команды при входе"
L["Printout items icon only"] = "Показывать только иконку предмета"
L["Printout items ignored"] = "Показывать проигнорированные предметы"
L["Printout items looted"] = "Показывать собранные предметы"
L["Printout items type"] = "Показывать тип предметов"
L["Printout reason of loot"] = "Показывать причину сбора"
L["Quest"] = "Квестовые"
L["Rarity"] = "Редкость"
L["Received Items"] = "Полученные предметы"
L["Received items group Delay (ms)"] = "Задержка для предметов, полученных группой (мс)"
L["Remove all"] = "Удалить всё"
L["Remove item from alert list"] = "Удалить предмет из списка уведомлений"
L["Remove item from ignore list"] = "Удалить предмет из черного списка"
L["Remove item from white list"] = "Удалить предмет из белого списка"
L["Remove old entries"] = "Удалить старые данные"
L["Removed"] = "Удалено"
L["Right-click"] = "Правый щелчок"
L["Right-click to show profile menu"] = "ПКМ чтобы показать меню профиля"
L["Select all"] = "Выбрать всё"
L["Set alert sound"] = "Выбрать звук уведомления"
L["Show/Hide minimap button"] = "Показать/скрыть иконку у миникарты"
L["Show/Hide UI"] = "Показать/скрыть интерфейс"
L["This can be useful to let addons like Fishing Buddy do its work"] = "Может быть полезно для Fishing Buddy и подобных дополнений."
L["This will cleanup and recreate the type database"] = "Это очистит и пересоздаст базу данных."
L["This will remove old types/subtypes entries from the database"] = "Это удалит старые типы/подтипы из базы данных."
L["to Enable/Disable loot all"] = ": включить/выключить сбор всего"
L["to Show/Hide UI"] = ": скрыть/показать интерфейс"
L["Token"] = "Токен"
L["Try to show loot animation"] = "Показывать анимацию сбора"
L["Type"] = "Тип"
L["Whitelist"] = "Белый список"
L["You"] = "Вы"
L["You can drag & drop items here!"] = "Сюда можно перетаскивать предметы!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "koKR")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
--[[Translation missing --]]
L["Add item to alert list"] = "Add item to alert list"
--[[Translation missing --]]
L["Add item to ignore list"] = "Add item to ignore list"
--[[Translation missing --]]
L["Add item to white list"] = "Add item to white list"
--[[Translation missing --]]
L["Added"] = "Added"
--[[Translation missing --]]
L["Alert List"] = "Alert List"
--[[Translation missing --]]
L["All"] = "All"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
--[[Translation missing --]]
L["Already in the list"] = "Already in the list"
--[[Translation missing --]]
L["Auto confirm loot roll"] = "Auto confirm loot roll"
--[[Translation missing --]]
L["Blacklist"] = "Blacklist"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close after loot"] = "Close after loot"
--[[Translation missing --]]
L["Coin"] = "Coin"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
--[[Translation missing --]]
L["Enable AutoLooter"] = "Enable AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
--[[Translation missing --]]
L["Token"] = "Token"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "zhCN")
if L then
	L["(Legacy Types)"] = "(战利品类型)"
L["Add item to alert list"] = "添加物品到警告列表"
L["Add item to ignore list"] = "添加物品到忽略列表"
L["Add item to white list"] = "添加物品到白名单"
L["Added"] = "已添加"
L["Alert List"] = "警告列表"
L["All"] = "所有"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
L["Already in the list"] = "已经在列表中"
L["Auto confirm loot roll"] = "自动确认拾取骰点"
L["Blacklist"] = "黑名单"
L["Close"] = "关闭窗口"
L["Close after loot"] = "拾取后关闭窗口"
L["Coin"] = "钱币"
L["Disabled"] = "已禁用"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
L["Enable AutoLooter"] = "启用AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
L["Enabled"] = "已启用"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
L["General"] = "通用"
L["Hold and drag to move"] = "按住并拖动移动"
L["Ignore BoP"] = "忽略装备后绑定"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
L["Ignore greys when looting by type"] = "当按类型拾取时忽略灰色物品"
L["Ignored"] = "忽略的"
--[[Translation missing --]]
L["Integration"] = "Integration"
L["Invalid item"] = "无效的物品"
L["Items list"] = "物品列表"
L["Left-click"] = "点击鼠标左键"
L["Listed"] = "列出的"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
L["Locked"] = "锁定的"
L["Loot by Price"] = "按价格拾取"
L["Loot by Rarity"] = "按稀有度拾取"
L["Loot everything"] = "拾取所有物品"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
L["Loot quest items"] = "拾取任务物品"
L["Not listed"] = "未列出的"
L["Off"] = "关"
L["On"] = "开"
L["Price"] = "价格"
L["Price (in coppers)"] = "价格 (铜币)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
L["Printout items icon only"] = "聊天栏只显示物品图标"
L["Printout items ignored"] = "聊天栏显示忽略的物品"
L["Printout items looted"] = "聊天栏显示已拾取物品"
L["Printout items type"] = "聊天栏显示物品类型"
L["Printout reason of loot"] = "聊天栏显示拾取原因"
L["Quest"] = "任务"
L["Rarity"] = "稀有度"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
L["Remove all"] = "删除所有"
L["Remove item from alert list"] = "从警告列表中删除物品"
L["Remove item from ignore list"] = "从忽略列表中删除物品"
L["Remove item from white list"] = "从白名单中删除物品"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
L["Removed"] = "已删除"
L["Right-click"] = "点击鼠标右键"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
L["Select all"] = "全选"
L["Set alert sound"] = "设置警告声音"
L["Show/Hide minimap button"] = "显示或隐藏小地图按钮"
L["Show/Hide UI"] = "显示或隐藏界面"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
L["to Enable/Disable loot all"] = "启用或禁用拾取所有物品"
L["to Show/Hide UI"] = "显示或隐藏界面"
L["Token"] = "货币"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
L["Type"] = "类型"
L["Whitelist"] = "白名单"
--[[Translation missing --]]
L["You"] = "You"
L["You can drag & drop items here!"] = "你可以在这里拖放物品!"

	return
end

L = AceLocale:NewLocale("AutoLooter", "zhTW")
if L then
	--[[Translation missing --]]
L["(Legacy Types)"] = "(Legacy Types)"
--[[Translation missing --]]
L["Add item to alert list"] = "Add item to alert list"
--[[Translation missing --]]
L["Add item to ignore list"] = "Add item to ignore list"
--[[Translation missing --]]
L["Add item to white list"] = "Add item to white list"
--[[Translation missing --]]
L["Added"] = "Added"
--[[Translation missing --]]
L["Alert List"] = "Alert List"
--[[Translation missing --]]
L["All"] = "All"
--[[Translation missing --]]
L["All items received between this delay will be grouped"] = "All items received between this delay will be grouped"
--[[Translation missing --]]
L["Already in the list"] = "Already in the list"
--[[Translation missing --]]
L["Auto confirm loot roll"] = "Auto confirm loot roll"
--[[Translation missing --]]
L["Blacklist"] = "Blacklist"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close after loot"] = "Close after loot"
--[[Translation missing --]]
L["Coin"] = "Coin"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Don't loot anything while Fishing"] = "Don't loot anything while Fishing"
--[[Translation missing --]]
L["Enable AutoLooter"] = "Enable AutoLooter"
--[[Translation missing --]]
L["ENABLE_AUTO_LOOTER_DESC"] = [=[AutoLooter will not loot anything when WoWs AutoLoot option is looting!

This allows you to use the WoWs AutoLoot key as way to enable/disable AutoLooter by target.

You can configure this options in 'Menu > Interface > Controls'.]=]
--[[Translation missing --]]
L["Enabled"] = "Enabled"
--[[Translation missing --]]
L["Fast loot"] = "Fast loot"
--[[Translation missing --]]
L["Fishing"] = "Fishing"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["Hold and drag to move"] = "Hold and drag to move"
--[[Translation missing --]]
L["Ignore BoP"] = "Ignore BoP"
--[[Translation missing --]]
L["Ignore Fishing"] = "Ignore Fishing"
--[[Translation missing --]]
L["Ignore greys when looting by type"] = "Ignore greys when looting by type"
--[[Translation missing --]]
L["Ignored"] = "Ignored"
--[[Translation missing --]]
L["Integration"] = "Integration"
--[[Translation missing --]]
L["Invalid item"] = "Invalid item"
--[[Translation missing --]]
L["Items list"] = "Items list"
--[[Translation missing --]]
L["Left-click"] = "Left-click"
--[[Translation missing --]]
L["Listed"] = "Listed"
--[[Translation missing --]]
L["Load Profile"] = "Load Profile"
--[[Translation missing --]]
L["Load profile '${profile}' and reload UI?"] = "Load profile '${profile}' and reload UI?"
--[[Translation missing --]]
L["Locked"] = "Locked"
--[[Translation missing --]]
L["Loot by Price"] = "Loot by Price"
--[[Translation missing --]]
L["Loot by Rarity"] = "Loot by Rarity"
--[[Translation missing --]]
L["Loot everything"] = "Loot everything"
--[[Translation missing --]]
L["Loot everything while Fishing"] = "Loot everything while Fishing"
--[[Translation missing --]]
L["Loot everything with a price greater or equal to this value"] = "Loot everything with a price greater or equal to this value"
--[[Translation missing --]]
L["Loot quest items"] = "Loot quest items"
--[[Translation missing --]]
L["Not listed"] = "Not listed"
--[[Translation missing --]]
L["Off"] = "Off"
--[[Translation missing --]]
L["On"] = "On"
--[[Translation missing --]]
L["Price"] = "Price"
--[[Translation missing --]]
L["Price (in coppers)"] = "Price (in coppers)"
--[[Translation missing --]]
L["Print items others receive"] = "Print items others receive"
--[[Translation missing --]]
L["Print items you receive"] = "Print items you receive"
--[[Translation missing --]]
L["Printout chat frames"] = "Printout chat frames"
--[[Translation missing --]]
L["Printout commands at login"] = "Printout commands at login"
--[[Translation missing --]]
L["Printout items icon only"] = "Printout items icon only"
--[[Translation missing --]]
L["Printout items ignored"] = "Printout items ignored"
--[[Translation missing --]]
L["Printout items looted"] = "Printout items looted"
--[[Translation missing --]]
L["Printout items type"] = "Printout items type"
--[[Translation missing --]]
L["Printout reason of loot"] = "Printout reason of loot"
--[[Translation missing --]]
L["Quest"] = "Quest"
--[[Translation missing --]]
L["Rarity"] = "Rarity"
--[[Translation missing --]]
L["Received Items"] = "Received Items"
--[[Translation missing --]]
L["Received items group Delay (ms)"] = "Received items group Delay (ms)"
--[[Translation missing --]]
L["Remove all"] = "Remove all"
--[[Translation missing --]]
L["Remove item from alert list"] = "Remove item from alert list"
--[[Translation missing --]]
L["Remove item from ignore list"] = "Remove item from ignore list"
--[[Translation missing --]]
L["Remove item from white list"] = "Remove item from white list"
--[[Translation missing --]]
L["Remove old entries"] = "Remove old entries"
--[[Translation missing --]]
L["Removed"] = "Removed"
--[[Translation missing --]]
L["Right-click"] = "Right-click"
--[[Translation missing --]]
L["Right-click to show profile menu"] = "Right-click to show profile menu"
--[[Translation missing --]]
L["Select all"] = "Select all"
--[[Translation missing --]]
L["Set alert sound"] = "Set alert sound"
--[[Translation missing --]]
L["Show/Hide minimap button"] = "Show/Hide minimap button"
--[[Translation missing --]]
L["Show/Hide UI"] = "Show/Hide UI"
--[[Translation missing --]]
L["This can be useful to let addons like Fishing Buddy do its work"] = "This can be useful to let addons like Fishing Buddy do its work"
--[[Translation missing --]]
L["This will cleanup and recreate the type database"] = "This will cleanup and recreate the type database"
--[[Translation missing --]]
L["This will remove old types/subtypes entries from the database"] = "This will remove old types/subtypes entries from the database"
--[[Translation missing --]]
L["to Enable/Disable loot all"] = "to Enable/Disable loot all"
--[[Translation missing --]]
L["to Show/Hide UI"] = "to Show/Hide UI"
L["Token"] = "代幣"
--[[Translation missing --]]
L["Try to show loot animation"] = "Try to show loot animation"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Whitelist"] = "Whitelist"
--[[Translation missing --]]
L["You"] = "You"
--[[Translation missing --]]
L["You can drag & drop items here!"] = "You can drag & drop items here!"

	return
end
