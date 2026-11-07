--[[
	Do you want help us translating to your language?
	Send me your translation in: https://www.curseforge.com/wow/addons/titan-panel-professions-multi
	Author: Canettieri
  Spanish translator: aniceto
  Last update: 07/04/2017
--]]

local _, L = ...;
if GetLocale() == "esES" then
--- Profissions
L["alchemy"] = "Alquimia"
L["archaeology"] = "Arqueología"
L["blacksmithing"] = "Herrería"
L["cooking"] = "Cocina"
L["enchanting"] = "Encantamiento"
L["engineering"] = "Ingeniería"
L["firstAid"] = "Primeros auxilios"
L["fishing"] = "Pesca"
L["herbalism"] = "Herboristería"
L["herbalismskills"] = "Habilidades en herboristería"
L["inscription"] = "Inscripción"
L["jewelcrafting"] = "Joyería"
L["leatherworking"] = "Peletería"
L["mining"] = "Minería"
L["miningskills"] = "Habilidades mineras"
L["skinning"] = "Desuello"
L["skinningskills"] = "Habilidad en desuello"
L["tailoring"] = "Sastrería"
-- Master
L["masterPlayer"] = "|cFFFFFFFFMostrando todas las profesiones de ${player}|r|cFFFFFFFF.|r"
L["masterTutorialBar"] = "|cFF69FF69¡Mueva su cursor aquí! :)|r"
L["masterTutorialIntro"] = "[INTRODUCCIÓN]"
L["masterTutorialIntroText"] = "Este plugin tiene la función de resumir todas sus profesiones en un solo lugar.\rA diferencia de los plugins separados, éste mostrará TODO en esta información\rsobre herramientas."
L["masterTutorialHowTo"] = "[CÓMO USAR]"
L["masterTutorialHowToText"] = "Para comenzar, haga clic derecho en este complemento y seleccione la opción\r |cFFFFFFFF'Ocultar tutorial'|r.\r\r¡Se puede visualizar en el lado derecho del Panel de Titán y así ser visualmente\rmás agradable!"
L["hideTutorial"] = "Ocultar Tutorial"
L["masterHint"] = "|cFFB4EEB4Sugerencia:|r |cFFFFFFFFClic izquierdo abre la ventana\rde la profesión #1 y clic botón central abre\rla ventana de la profesión #2.|r\r\r"
L["primprof"] = "Muestra profesiones primarias"

------ Reagents pack
--- Achaeology
L["ready"] = "|cFF69FF69¡Preparado!  "
L["archfragments"] = "Fragmentos de Arqueología"
L["fragments"] = "Fragmentos"
L["fragtooltip"] = "|cFFB4EEB4Sugerencia:|r |cFFFFFFFFClic derecho en el plugin y\rseleccione el fragmento que será\rmostrado en la barra.|r\r"
L["hidehint"] = "Ocultar Sugerencia"
L["displaynofrag"] = "Mostrar Razas Sin Fragmentos"
L["inprog"] = "\rEn progreso:"
L["nofragments"] = "Sin fragmentos"
L["noarchaeology"] = "|cFFFF2e2eTodavía no aprendiste arqueología o no tiene fragmentos.|r\r\rVisite al instructor más cercano para aprenderlo o diríjase\ra una zona de excavación."
------ Shared with one or more
--- Shared
L["hint"] = "|cFFB4EEB4Sugerencia:|r |cFFFFFFFFClic Izquierdo abre\n|cFFFFFFFFla ventana de su profesión."
L["maximum"] = "Max"
L["noprof"] = "!?"
L["bonus"] = "(Bonificación)"
L["hidemax"] = "Ocultar Valores Máximos"
L["session"] = "|rAprendido en esta sesión: "
L["noskill"] = "|cFFFF2e2eNo aprendiste esta profesión.|r\r\rVaya al entrenador más cercano para aprenderlo.\rSi lo necesita, puede olvidar cualquier profesión primaria."
L["nosecskill"] = "|cFFFF2e2eNo aprendiste esta profesión.|r\r\rVaya al instructor más cercano para aprenderlo."
L["showbb"] = "Mostrar Balance de Sesión en la Barra"
L["simpleb"] = "Bonificación Simplificada"
L["craftsmanship"] = "Habilidad: "
L["goodwith"] = "|cFFFFFFFF[Combinar con]|r"
L["info"] = "|cFFFFFFFF[Informaciones]|r"
L["maxskill"] = "|r¡Has alcanzado tu máximo potencial!"
L["warning"] = "\r\r|cFFFF2e2e[¡Atención!]|r\r¡Ha alcanzado la máxima maestría\ry no está aprendiendo más! Visite\run instructor o aprenda la maestría\rlocal." -- Not tested
L["maxtext"] = "Máximo actual: "
L["bonustext"] = "Bonificación activa:"
L["totalbag"] = "Total en la Bolsa: "
L["totalbank"] = "Total en el Banco: "
L["totalbyquality"] = "Por calidad (bolsas + banco)"
L["qualityfallback"] = "%s (Calidad %d)"
L["reagents"] = "Componentes"
L["rLegion"] = "Componentes - Legion"
L["rBfA"] = "Componentes - BfA"
L["rShadowlands"] = "Componentes - Shadowlands"
L["rSL"] = "Componentes - SL"
L["rMidnight"] = "Componentes - Midnight"
L["rMID"] = "Componentes - Midnight"
L["rClassic"] = "Componentes - Classic"
L["rForever"] = "Componentes - Forever"
L["rMists"] = "Componentes - Mists of Pandaria"
L["rTBC"] = "Componentes - The Burning Crusade"
L["reagentCategory"] = "Profesión [Componentes]"
L["noreagent"] = "No tiene ninguno de\restos componentes."
L["hide"] = "Ocultar"
L["totalSkill"] = "Habilidad total:"
L["hideCombination"] = "Ocultar combinación"
L["buttonText"] = "Texto de la barra"
L["tooltip"] = "Descripción emergente"
L["barPosition"] = "Posición en la barra"
L["moveRight"] = "Mover a la derecha"
L["moveLeft"] = "Mover a la izquierda"
end
