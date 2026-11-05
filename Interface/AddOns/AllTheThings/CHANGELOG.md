# AllTheThings

## [5.4.7](https://github.com/ATTWoWAddon/AllTheThings/tree/5.4.7) (2026-11-05)
[Full Changelog](https://github.com/ATTWoWAddon/AllTheThings/compare/5.4.6...5.4.7) [Previous Releases](https://github.com/ATTWoWAddon/AllTheThings/releases)

- [Forever] The Engraved Ring should also appear in the tirisfal glades mini list.  
- [Forever] Ivar the Foul now requires Return to Quinn (Again).  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnjwdcL4Sgcv7Gq527s  
- [Forever] Ruins of Lordaeron prerequisites, Murloc Eye world drop, Wild Eyes cost.  
    - The New Plague requires A Recipe For Death (3/3); The Wrath of Rath'mael  
      requires Rear Guard Patrol (2/2) (both changed at launch).  
    - Add Murloc Eye (730) to world drops (Cooking reagents) with its droppers.  
    - Wild Eyes: Murloc Eye as a cost.  
    - Update the compiled DB.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnjwdcL4Sgcv7Gq527s  
- [Forever] Minor Discolored Healing Potion is now rewarded from Wild Eyes, not Wild Hearts.  
- [DB] Eyaball :eyes:  
- Correct required English across WoW flavors (#2736)  
    * [Text] Correct English spelling and grammar.  
    - Correct required English spelling and grammar in shared comments,  
      Standard/Forever descriptions, and contributor-tool documentation.  
    - Correct corroborated WoW names while preserving official spellings,  
      accepted variants, identifiers, data relationships, and line endings.  
    - Validate 49 Lua files with Lua 5.1.5 and compare identical stripped  
      bytecode for 38 comment-only files. Preserve executable Python AST  
      and C# text outside documentation and comments.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol.  
    * [Text] Retain necessary English corrections.  
    Restore non-English localization rows and optional English wording  
    changes. Retain spelling corrections, redundant-word repairs, and  
    clear singular/plural agreement fixes.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol.  
- [Forever] Sort all quest lists by name; Wild Hearts objective.  
    - Every n(QUESTS) list in the Forever DB is now alphabetical (case-insensitive,  
      natural number order). Silverpine, Moonglade, Undercity, Duskwood, Orgrimmar,  
      Ashenvale, Stonetalon and Thousand Needles were sorted by ID; other files had  
      newly added quests appended at the end. Nested quests move with their parent.  
    - Wild Hearts: Discolored Worg Heart is now an objective with its droppers  
      instead of a cost.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnjwdcL4Sgcv7Gq527s  
- [Logic] Fixed a Lua error when a Bonus Reputation Quest loads before it's parent has retrieved a valid name  
- [Logic] Fixed a bunch of world quests with reputation not properly being treated as the new World Quest type (the maxReputation field now modifies the Quest variant rather than the sub-type)  
- [Forever] Adjusted Redemption for Paladins.  
- [Build] Restore source packages via NuGet.  
    - Switch the three Lua projects to exact-version NuGet references.  
    - Remove vendored packages and legacy package manifests.  
    - Delete four obsolete Item Database Consolidator Debug outputs.  
    - Refresh six Release binaries from the successful Windows Actions run.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol.  
- [Build] Upgrade source Lua dependencies.  
    - Upgrade legacy projects and binding redirects to NLua 1.7.9 and KeraLua 1.4.11.  
    - Replace vendored package contents and refresh tool outputs at their existing paths.  
    - Verify 19 Windows builds and runtime checks; Skill parsing uses its offline helper.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol.  
- Move Quest Objectives toggle to Tooltip settings (Interface)  
- [Locale] Add zhCN for logistics & objectives. (#2735)  
    - Fill in the missing Simplified Chinese text for the Trade Logistics and  
    Waylaid Crates headers, including their descriptions, and for the  
    OBJECTIVES\_CHECKBOX and OBJECTIVES\_CHECKBOX\_TOOLTIP strings.  
    - The tw and other locales for these entries remain TODO. The generated  
    db/*/LocalizationDB.lua files are produced by the Parser workflow from  
    these sources and are intentionally not updated here.  
    Assisted-by: deepseek-v4.1-flash.  
- [Style] Merge CSVCleaner release settings.  
    Merge the duplicate `Release|x64` property groups, keeping `DebugType=none`, the `.contrib/.tools` output path, and `AppendTargetFrameworkToOutputPath=false` under the same condition.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol, gpt-6-astra.  
- [Forever] Tirisfal Glades: add Coldrasp and A Righteous Cause prerequisites.  
    - As Above, So Below and The One That Got Away require A Righteous Cause.  
    - Add the rare Coldrasp (274300).  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnjwdcL4Sgcv7Gq527s  
- [Forever] Tirisfal Glades: fill in missing quest objectives and sort quests by name.  
    - The Tarnished: objective counts, Rudolph Gelhardt as the head's dropper with coords.  
    - Making Repairs: Sturdy Lumber from Lumber Piles with coords.  
    - Rediscovering the Light: Injured Deathguard healing objective.  
    - A Lesson in Divinity: Billmuth / Falgan objectives, Scarlet Friar and Zealot as attack plan droppers.  
    - Sort the zone's quests alphabetically.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnjwdcL4Sgcv7Gq527s  
- [Tools] Move Skill Level Requirements to .NET 10.  
    Retarget Skill Level Requirements to net10.0 and replace its stored executable quartet with Windows CI artifacts from [source run](https://github.com/NORPG/AllTheThings/actions/runs/41973764169) (source commit `10679a693fa2cb76cd9febeebd78bb8c19fe2ac1`); the final build reproduced these hashes in [verification run](https://github.com/NORPG/AllTheThings/actions/runs/41975191188).  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol, gpt-6-astra.  
- [Tools] Upgrade IconID Converter to .NET 10.  
    Retarget IconID Converter to net10.0. Replace its stored executable quartet with Windows CI artifacts from [source run](https://github.com/NORPG/AllTheThings/actions/runs/41973764169) (source commit `10679a693fa2cb76cd9febeebd78bb8c19fe2ac1`); the final build reproduced these hashes in [verification run](https://github.com/NORPG/AllTheThings/actions/runs/41975191188).  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol, gpt-6-astra.  
- [Tools] Upgrade AssetDB Builder to .NET 10.  
    Retarget AssetDB Builder to net10.0. Replace its stored executable quartet with Windows CI artifacts from [source run](https://github.com/NORPG/AllTheThings/actions/runs/41973764169) (source commit `10679a693fa2cb76cd9febeebd78bb8c19fe2ac1`); the final build reproduced these hashes in [verification run](https://github.com/NORPG/AllTheThings/actions/runs/41975191188).  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol, gpt-6-astra.  
- [Tools] Upgrade CSVCleaner to .NET 10.  
    Target net10.0 and keep Release x64 output in .contrib/.tools independent of the target framework. Replace the stored executable quartet with CI artifacts from [source run](https://github.com/NORPG/AllTheThings/actions/runs/41973764169) (source commit `10679a693fa2cb76cd9febeebd78bb8c19fe2ac1`); the final build reproduced these hashes in [verification run](https://github.com/NORPG/AllTheThings/actions/runs/41975191188).  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol, gpt-6-astra.  
- [Forever] Fixed quest objective data for The Lich's Identity.  
- [Forever] The WRIGGLE quest is repeatable.  
- [Forever] Fixed Weapon Masters.  
- Fixed the new +Objectives setting.  
- [Forever] Fixed some tooltips caused by cost and objective existing at the same time.  
- Update Eremeir Contrib Tooltip  
- Added a +Objectives tracking option (Classic and Forever) so the objectives of quests you're on count as collectible, with its OBJECTIVES\_CHECKBOX and OBJECTIVES\_CHECKBOX\_TOOLTIP locale strings, and re-exported the compiled databases.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnnyK9wEXgYjgZPXeKD  
- [Forever] Fixed a missing map constant.  
- [Forever] Updated quest objective data for Tomb Weed.  
- [Forever] Pouch of Violet Dust: the Twitch drop is available again until November 12th (4 hours of watch time); the toy is ephemeral and will be removed from collections when the Launch Celebration ends.  
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>  
    Claude-Session: https://claude.ai/code/session\_01LyuRnnyK9wEXgYjgZPXeKD  
- [Forever] Added objective data for Doom Weed.  
- [Forever] Added missing quest objective for A Light in the Darkness.  
- [Forever] Added missing objective for Coming to Terms.  
- [Logic] Switched some common field accesses to rawget since they can never be dynamic from a Class  
    [Debug] Added an optional debugging check to verify if particular fields are ever defined within an Class. This allows us to know whether direct access or rawget can potentially be used in order to save on metatable misses in a Class (e.g. Class field misses cost ~93 ns vs ~60 ns for rawget (about 50% more), but a direct field hit costs only ~10-20% of a rawget call. rawget therefore only pays off for keys that no class defines dynamically and that are absent on more than ~60% of reads (e.g. sourceParent in the recursive filter walks), so it is limited to the most heavily-used paths)  
- [Forever] Added the Pouch of Violet Dust Twitch drop. It is no longer obtainable. A one-hour, luck-based window announced only shortly beforehand is exactly the kind of FOMO that disheartens collectors: it couldn't be earned by playing the game at all, and anyone who was at work, asleep, or simply in-game instead of on Twitch missed it permanently.  
- Fix more decor  
- [Fix] Wrap GetSpecializationInfo.  
    Read the existing app.WOWAPI specialization member directly for  
    item requirement inference. Keep unavailable specialization data  
    false in the wrapper, preserving the existing fallback helper.  
    Cover modern selection, native fallback and direct unavailable access.  
    Assisted-by: gpt-6.1-sol.  
- Fix some decor sorting, add Labyrinth hqt  
- [Fix] Wrap GetMerchantItemInfo.  
    Select the current merchant API and normalize native Classic tuples  
    to the table contract consumed by the debugger. Cover modern result  
    identity and Classic price, stack and extended-cost fields.  
    Assisted-by: gpt-6.1-sol.  
- [Forever] Updated Wago to 1.60.1.70790.  
- Updated build to 12.1.5.70783; Added Shifty Chest decor to D&D promo  
- [Fix] Wrap ChatEdit\_InsertLink.  
    Route modified link clicks through app.WOWAPI using direct member  
    access, with the current chat utility and a legacy fallback. Keep  
    unavailable insertion false in the wrapper and preserve click guards.  
    Cover link arguments, return behavior and unavailable direct access.  
    Assisted-by: gpt-6.1-sol.  
- [Test] Cover Battle.net transport wrappers.  
    Verify modern SendGameData selection and direct access when the transport is unavailable. Exercise the actual app.WOWAPI binding in the character-whisper fixture.  
    Assisted-by: gpt-6.1-sol.  
- [Fix] Wrap GetAddOnMetadata.  
    Select C\_AddOns.GetAddOnMetadata before the legacy metadata API.  
    Route version and window metadata lookups through app.WOWAPI and  
    cover modern selection and argument forwarding.  
    Assisted-by: gpt-6.1-sol.  
- [Logic] Simplify CollectibleAsQuest for some very tiny micro improvements  
- [Logic] Moved World Quests to a new sub-class QuestAsWorldQuest and moved out isWorldQuest conditions from standard Quest logic  
    * World Quests are now only considered 'trackable' when they are active  
- [Logic] Remove duplicate Quest variants now that they aren't contaminated from the Quest class  
- [Logic] Fixed variant generation logic to not corrupt the source variant arrays for classes  
- [Logic] Ignore some Vignettes  
    [DB] Link some Vignettes & cleanup Kyrian Anima Conductor file  
- Add another Wah'du quest  
- Add D&D promo, timeline out twitch drop, fix Mogu'Shan ach  
- [DB] M Ula'tek HQT  
- [DB] MoP instances: Achievements and misc  
- [DB] Re-fixed Amirdrassil catalysts :weary: pls Gold  
- [MOP] Bump wago files to 5.5.4.70631  
- [DB] Rebuilt all DBs to include missing locales for Git users.  
- moving catalyst to the bottom of each difficulty  
    reason1: for lfr, having the catalyst at the top displays all missing tier items, which pushes out the specific drops from each boss. even if you are only missing say 3 tier items from each tier, it fills the tooltip with say tier from vault>aberrus>amir until you finally see the specific items from each part. especially in accountmode, you never see the direct items you are misisng  
    reason2: the gear you get and then can transform into tier, feels more like a bonus, so its more fitting to have it show at the end.  
- [Logic] Modified AddSimpleCollectibleSwap to call AddCollectibleSwap to allow for more complex 'collectible' function swaps  
- [Logic] Move some NPCWithQuest handling into a dedicated NPCWithDualQuest class to reduce ineffective field checks during updates  
- Unremove Nemesis delves which never actually get removed  
- Talebound: A Couple of items grabbed before PTR ended  
- [Docs] Use one AI attribution trailer.  
    Require one Assisted-by line listing all contributing models, separated by commas and spaces, and ending with a period. Clarify that the final period is trailer punctuation, not part of a model name. Preserve actual model names and attribution when amending or squashing commits.  
    Assisted-by: gpt-6-luna, gpt-6.1-terra, gpt-6.1-sol.  
- [Locale] Add zhTW transmog window text.  
    Add the zhTW window title “灰白塑形” and a localized description. Follow existing zhTW terminology for shaping and appearance sources while retaining the game-version and tracking-settings qualification.  
    Assisted-by: gpt-6-luna  
    Assisted-by: gpt-6.1-terra  
    Assisted-by: gpt-6.1-sol  
- Fix a few minor errors  
- [UI] Rename white and gray transmog window.  
    Rename the window suffix, runtime file, and XML entry while preserving the prior commands as aliases. Migrate saved global and profile settings, and prebuild the renamed frame when saved window anchors reference it. Document persisted global/profile window layouts and migration timing with LuaLS annotations.  
    Assisted-by: gpt-6-luna  
    Assisted-by: gpt-6.1-terra  
    Assisted-by: gpt-6.1-sol  
- [Locale] Rename transmog labels.  
    Use the White/Gray title and a localized description. Point the existing window definition and content at the new exported constants.  
    Assisted-by: gpt-6-luna  
    Assisted-by: gpt-6.1-terra  
    Assisted-by: gpt-6.1-sol  
- [Locale] Update All: CategoryDB.  
    Update category names across supported locales.  
    Scope differing client names by locale and flavor.  
    Assisted-by: gpt-6.1-sol  
    Assisted-by: gpt-6-luna  
    Assisted-by: gpt-6.1-terra  
- [Style] Order contributor project settings.  
    - Order existing properties and configuration groups across five contributor projects.  
    - Remove extra blank lines from the CSVCleaner project.  
    - Preserve declared platforms, defaults, and effective build settings.  
    Assisted-by: gpt-6.1-sol  
    Assisted-by: gpt-6.1-terra  
    Assisted-by: gpt-6-luna  
- [Contrib] Ignore an object  
- [DB] Added Pristine WoD Archaelogy items so the currency properly chains to the nested content  
- [DB] Cleaned up Archaeology achievements which are automated  
- [DB] Remove two inaccurate sourceQuests  
- [Logic] Found a fix for loading ATT in Talebound flavor (hopefully Blizzard fixes the TOC path loading and renames the [Game] variable properly)  
- [DB] Bunch of objects from other flavors harvested  
- [Locale] Update zhCN: settings & windows. (#2731)  
    - Add four localization strings for auction settings, window commands,  
      and the White Collectible Transmog window.  
    - Fill in missing zhCN translations for character information,  
      grouping options, dungeon headers, and SoD Phase 8 lore.  
    - Replace hardcoded UI strings with localization constants and  
      register the White Collectible Transmog window name.  
    Assisted-by: deepseek-v4.1-flash  
- [Misc] Added a build batchfile for Talebound flavor  
    [Parser] Added a WARN if config JSON is successfully parsed but results in null  
- [Locale] Update zhTW.  
    Update zhTW interface strings, headers, and world-data text.  
    Retain English fallback names and TODO markers for unverified terminology.  
    Assisted-by: gpt-6.1-sol  
    Assisted-by: gpt-6-luna  
    Assisted-by: gpt-6.1-terra  
- Fix Timelost Saddle  
- [Build] Ship SDK contributor tools.  
    - Convert four .NET Framework tools to SDK-style projects.  
    - Use SDK source inclusion and deterministic defaults.  
    - Include validated executables and runtime configuration files.  
    Assisted-by: gpt-6.1-sol  
    Assisted-by: gpt-6.1-terra  
    Assisted-by: gpt-6-luna  
