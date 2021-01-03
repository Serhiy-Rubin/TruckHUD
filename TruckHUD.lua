script_name("TruckHUD")
script_author("Serhiy_Rubin")
script_version("21.1.3.1")

function try(f, catch_f)
  local status, exception = pcall(f)
  if not status then
    catch_f(exception)
  end
end

try(function()
 sampev, inicfg, dlstatus, vkeys, ffi =
    require "lib.samp.events",
    require "inicfg",
    require("moonloader").download_status,
    require "lib.vkeys",
    require("ffi")
    
  end, function(e)
    sampAddChatMessage(">> Произошла ошибка на этапе загрузки библиотек. Возможно у вас нет SAMP.Lua", 0xff0000)
    sampAddChatMessage(">> Официальная страница Truck HUD: https://vk.com/rubin.mods",0xff0000)
    sampAddChatMessage(e, -1)
    thisScript():unload()
  end)
    
ffi.cdef [[ bool SetCursorPos(int X, int Y); ]]

------- 3d text
local id_3D_text = os.time()
local what_is_uploaded = {[0] = "Рубины", [1] = "Нефть", [2] = "Уголь", [3] = "Дерево"}
local texts_of_reports = {
    ["n1"] = "Нефтезаводе №1",
    ["n2"] = "Нефтезаводе №2",
    ["y1"] = "Складе Угля №1",
    ["y2"] = "Складе Угля №2",
    ["l1"] = "Лесопилке №1",
    ["l2"] = "Лесопилке №2",
    ["lsn"] = "Нефть в ЛС",
    ["lsy"] = "Уголь в ЛС",
    ["lsl"] = "Дерево в ЛС",
    ["sfn"] = "Нефть в СФ",
    ["sfy"] = "Уголь в СФ",
    ["sfl"] = "Дерево в СФ"
}
local find_3dText = {
    ["n1"] = "Нефтезавод №1.*Цена груза: 0.(%d+)",
    ["n2"] = "Нефтезавод №2.*Цена груза: 0.(%d+)",
    ["y1"] = "Склад угля №1.*Цена груза: 0.(%d+)",
    ["y2"] = "Склад угля №2.*Цена груза: 0.(%d+)",
    ["l1"] = "Лесопилка №1.*Цена груза: 0.(%d+)",
    ["l2"] = "Лесопилка №2.*Цена груза: 0.(%d+)",
    ["ls"] = "Порт ЛС.*Нефть: 0.(%d+).*Уголь: 0.(%d+).*Дерево: 0.(%d+)",
    ["sf"] = "Порт СФ.*Нефть: 0.(%d+).*Уголь: 0.(%d+).*Дерево: 0.(%d+)"
}

local menu = {
    [1] = {[1] = "TruckHUD: {06940f}ON", [2] = "TruckHUD: {d10000}OFF", run = false},
    [2] = {[1] = "Load/Unload: {06940f}ON", [2] = "Load/Unload: {d10000}OFF", run = false},
    [3] = {[1] = "Авто-Доклад: {06940f}ON", [2] = "Авто-Доклад: {d10000}OFF", run = false},
    [4] = {[1] = "SMS » Serhiy_Rubin[777]", [2] = "Режим пары: {d10000}OFF", run = false},
    [5] = {[1] = "Дальнобойщики онлайн", [2] = "Дальнобойщики онлайн", run = false},
    [6] = {[1] = "Дальнобойщики со скриптом", [2] = "Дальнобойщики со скриптом", run = false},
    [7] = {[1] = "Настройки", [2] = "Настройки", run = false},
    [8] = {[1] = "Мониторинг цен", [2] = "Мониторинг цен", run = false},
    [9] = {[1] = "Купить груз", [2] = "Купить груз", run = false},
    [10] = {[1] = "Продать груз", [2] = "Продать груз", run = false},
    [11] = {[1] = "Восстановить груз", [2] = "Восстановить груз", run = false}
}

local pair_mode, sms_pair_mode, report_text, pair_mode_id, pair_mode_name, BinderMode = false, "", "", -1, "Нет", true

local script_run, control, auto, autoh, wait_auto, pos = false, false, false, true, 0, {[1] = false, [2] = false, [3] = false}

local price_frozen, timer, antiflood, current_load, load_location, unload_location = false, 0, 0, 0, false, false

local my_nick, server, timer_min, timer_sec, workload = "", "", 0, 0, 0

local mon_life, mon_time, mon_ctime = 0, 0, 0

local prices_3dtext = { n1 = 0, n2 = 0, y1 = 0, y2 = 0, l1 = 0, l2 = 0, lsn = 0, lsy = 0, lsl = 0, sfn = 0, sfy = 0, sfl = 0 }
local prices_mon = { n1 = 0, n2 = 0, y1 = 0, y2 = 0, l1 = 0, l2 = 0, lsn = 0, lsy = 0, lsl = 0, sfn = 0, sfy = 0, sfl = 0 }
local prices_smon = { n1 = 0, n2 = 0, y1 = 0, y2 = 0, l1 = 0, l2 = 0, lsn = 0, lsy = 0, lsl = 0, sfn = 0, sfy = 0, sfl = 0 }

local delay, d = {chatMon = 0, chat = 0, skill = -1, mon = 0, load = 0, unload = 0, sms = 0, dir = 0, paycheck = 0}, {[3] = ""}
local pickupLoad = {
    [1] = {251.32167053223, 1420.3039550781, 11.5}, -- N1
    [2] = {839.09020996094, 880.17510986328, 14.3515625}, -- Y1
    [3] = {-1048.6430664063, -660.54699707031, 33.012603759766}, -- N2
    [4] = {-2913.8544921875, -1377.0952148438, 12.762256622314}, -- y2
    [5] = {-1963.6184082031, -2438.9055175781, 31.625}, -- l2
    [6] = {-457.45620727539, -53.193939208984, 60.938865661621} -- l1
}
local newMarkers = {}
local pair_table = {}
local pair_timestamp = {}
local pair_status = 0
local response_timestamp = 0
local transponder_delay = 500
local ScriptTerminate = false
local msk_timestamp = 0
local responce_delay = 0
local timer_secc = 0
local base = {}
local payday = 0
local chat_mon = {}
local _3dTextplayers = {}


stop_downloading_1, stop_downloading_2, stop_downloading_3, stop_downloading_4, stop_downloading_5 = false, false, false, false, false

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end

    repeat wait(0) until sampGetCurrentServerName() ~= "SA-MP"
    repeat wait(0) until sampGetCurrentServerName():find("Samp%-Rp.Ru") or sampGetCurrentServerName():find("SRP")

    local _, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    my_nick = sampGetPlayerNickname(my_id)
    server = sampGetCurrentServerName():gsub("|", "")
    server =
        (server:find("02") and "Two" or
        (server:find("Revolution") and "Revolution" or
            (server:find("Legacy") and "Legacy" or (server:find("Classic") and "Classic" or ""))))
    if server == "" then
        thisScript():unload()
    end
    AdressConfig = string.format("%s\\moonloader\\config ", getGameDirectory())
    AdressFolder = string.format("%s\\moonloader\\config\\TruckHUD", getGameDirectory())
    AdressJson = string.format("%s\\moonloader\\config\\TruckHUD\\%s-%s.json", getGameDirectory(), server, my_nick)

    if not doesDirectoryExist(AdressConfig) then
        createDirectory(AdressConfig)
    end
    if not doesDirectoryExist(AdressFolder) then
        createDirectory(AdressFolder)
    end
    settings_load()
    lua_thread.create(get_time)
    logAvailable()
    for k,v in pairs(prices_mon) do
        prices_mon[k] = inifiles.tmonitor[k]
    end
    mon_time = inifiles.tmonitor.time

    if inifiles.Settings.ad then
        local fpath = os.getenv("TEMP") .. "\\TruckHUD-version.txt"
        download_id_1 = downloadUrlToFile(
            "https://raw.githubusercontent.com/Serhiy-Rubin/TruckHUD/master/version",
            fpath,
            function(id, status, p1, p2)
                if stop_downloading_1 then
                    stop_downloading_1 = false
                    download_id_1 = nil
                    return false
                end
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    local f = io.open(fpath, "r")
                    if f then
                        local text = f:read("*a")
                        if text ~= nil then
                            if not string.find(text, tostring(thisScript().version)) then
                                sampAddChatMessage( ">> Вышло обновление для Truck HUD, версия " .. text .. ". Текущая версия " ..  thisScript().version, 0xFF2f72f7)
                                sampAddChatMessage( ">> Посмотреть список изменений: /truck up. Включить/Выключить уведомления: /truck ad", 0xFF2f72f7)
                                sampAddChatMessage( ">> Официальная страница Truck HUD: https://vk.com/rubin.mods", 0xFF2f72f7)
                            end
                        end
                        io.close(f)
                        os.remove(fpath)
                    end
                end
            end
        )
    end
    menu[3].run = inifiles.Settings.Report
    font = renderCreateFont(inifiles.Render.FontName, inifiles.Render.FontSize, inifiles.Render.FontFlag)

    --gmap area
    lua_thread.create(transponder)
    lua_thread.create(fastmap)
    lua_thread.create(renderTruckers)
    repeat
        wait(0)
    until msk_timestamp ~= 0 
    while true do
        wait(0)
        logAvailable()
        doControl()
        doSendCMD()
        doDialog()
        doPair()
        doPickup()
        doMarkers()
        if script_run then
            doCruise()
            if not sampIsScoreboardOpen() and sampIsChatVisible() and not isKeyDown(116) and not isKeyDown(121) and fastmapshow == nil then
                doRenderStats()
                doRenderMon()
                doRenderBind()
            end
        end
    end
end

function settings_load()
    local x1, y1 = convertGameScreenCoordsToWindowScreenCoords(14.992679595947, 274.75)
    local x2, y2 = convertGameScreenCoordsToWindowScreenCoords(146.17861938477, 345.91665649414)
    local x3, y3 = convertGameScreenCoordsToWindowScreenCoords(529.42901611328, 158.08332824707)
    defaultMon = 
[[!mn!Скилл: {FFFFFF}!skill! [!skill_poc!%] [!skill_reys!]!n!Ранг: {FFFFFF}!rang! [!rang_poc!%] [!rang_reys!]!n!!mn!Зарплата:{FFFFFF} !zp_hour!/!max_zp!!n!Прибыль: {FFFFFF}!profit!!n!Рейсы: {FFFFFF}!reys_hour!/!reys_day! [!left_reys!] ]]
        local table_std = {
            Settings = {
                Cruise = false,
                chat_in_truck = false,
                blacklist_inversion = false,
                pairinfo = true,
                transponder = true,
                fastmap = true,
                ad = true,
                AutoWait = true,
                highlight_jf = true,
                Stop = true,
                ChatOFF = false,
                ChatDoklad = false,
                X1 = x1,
                Y1 = y1,
                X2 = x2,
                Y2 = y2,
                X3 = x3,
                Y3 = y3,
                AutoOFF = false,
                Tuning = true,
                Report = true,
                Key = 90,
                Key1 = "VK_RBUTTON",
                Key2 = "VK_Z",
                Key3 = "VK_LBUTTON",
                Key4 = 'VK_LSHIFT',
                Binder = true,
                SMSpara = false,
                ColorPara = "ff9900",
                LightingPara = true,
                LightingPrice = true,
                girl = false,
                pickup = true,
                markers = true,
                stats_text = defaultMon,
                renderTruck = true,
                AutoClear = true,
                NewPairMSG = true
            },
            Render = {
                FontName = "Segoe UI",
                FontSize = 10,
                FontFlag = 15,
                Color1 = "2f72f7",
                Color2 = "FFFFFF"
            },
            Trucker = {
                Skill = 1,
                ReysSkill = 0,
                Rank = 1,
                ReysRank = 0,
                ProcSkill = 100.0,
                ProcRank = 100.0,
                MaxZP = 197000
            },
            Price = {
                Load = 500,
                UnLoad = 800
            },
            tmonitor = { 
                time = 0,
                n1 = 0, n2 = 0, y1 = 0, y2 = 0, l1 = 0, l2 = 0, lsn = 0, lsy = 0, lsl = 0, sfn = 0, sfy = 0, sfl = 0 
            },
            binder = { '/r На месте', '/r Загружаюсь', '/r Задержусь', '/r Разгружаюсь' },
            blacklist = {}
        }
    if not doesFileExist(AdressJson) then
        local file, error = io.open(AdressJson, "w")
        if file ~= nil then
            file:write(encodeJson(table_std))
            file:flush()
            io.close(file)
        else
            sampAddChatMessage(error, -1)
        end
    end
    local file, error = io.open(AdressJson, "r")
    if file then
        inifiles = decodeJson(file:read("*a"))
        io.close(file)
    else
        sampAddChatMessage(error, -1)
    end
        for k,v in pairs(table_std) do
            if inifiles[k] == nil then
                inifiles[k] = v
            end
            for i, s in pairs(v) do
                if inifiles[k][i] == nil then
                    inifiles[k][i] = s
                end
            end
        end
    settings_save()
end

function settings_save()
    local file, error = io.open(AdressJson, "w")
    if file ~= nil then
        file:write(encodeJson(inifiles))
        file:flush()
        io.close(file)
    else
        sampAddChatMessage(error, -1)
    end
end

function doControl()
    if
        isKeyDown(vkeys[inifiles.Settings.Key1]) and
            (isTruckCar() or (isKeyDown(vkeys[inifiles.Settings.Key2] or pos[1] or pos[2] or pos[3]))) and
            not sampIsDialogActive() and
            not sampIsScoreboardOpen()
     then
        dialogActiveClock = os.time() 
        sampSetCursorMode(3)
        local X, Y = getScreenResolution()
        if not control then
            ffi.C.SetCursorPos((X / 2), (Y / 2))
        end
        control = true
        local plus = (renderGetFontDrawHeight(font) + (renderGetFontDrawHeight(font) / 10))
        Y = ((Y / 2.2) - (renderGetFontDrawHeight(font) * 3))
        for i = 1, 11 do
            local string_render = (menu[i].run and menu[i][1] or menu[i][2])
            if drawClickableText(string_render, ((X / 2) - (renderGetFontDrawTextLength(font, string_render) / 2)), Y) then
                if i == 1 then
                    script_run = not script_run
                    if script_run then
                        delay.paycheck = 1
                    end
                    menu[i].run = script_run
                end
                if i == 2 then
                    auto = not auto
                    menu[i].run = auto
                end
                if i == 3 then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    settings_save()
                    menu[i].run = inifiles.Settings.Report
                end
                if i == 4 then
                    if pair_mode then
                        sampSetChatInputText("/sms " .. pair_mode_id .. " ")
                        sampSetChatInputEnabled(true)
                    else
                        ShowDialog1(8)
                    end
                end
                if i == 5 then
                    delay.dir = 1
                end
                if i == 6 and script_run then
                    lua_thread.create(showTruckers)
                end
                if i == 7 then
                    ShowDialog1(1)
                end
                if i == 8 then
                    sampSendChat("/truck mon")
                end
                if i == 9 then
                    sampSendChat("/truck load " .. GetGruz())
                end
                if i == 10 then
                    sampSendChat("/truck unload")
                end
                if i == 11 then
                    sampSendChat("/truck trailer")
                end
            end
            if
                i == 4 and pair_mode and
                    drawClickableText(
                        "{e30202}х",
                        ((X / 2) + (renderGetFontDrawTextLength(font, menu[4][1] .. "   ") / 2)),
                        Y
                    )
             then
                pair_mode = false
                menu[4].run = false
            end
            Y = Y + plus
            if i == 7 then
                Y = Y + plus
            end
        end
    else
        if control and not isKeyDown(vkeys[inifiles.Settings.Key1]) and not pos[1] and not pos[2] and not pos[3] then
            control = false
            sampSetCursorMode(0)
        end
    end
end

function doSendCMD()
    local ms = math.ceil(os.clock() * 1000 - antiflood)
    if ms >= 1150 then
        if delay.mon == 1 then
            sampSendChat("/truck mon")
            delay.mon = 2
        end
        if delay.mon == 0 then
            if delay.chat == 1 then
                sampSendChat("/jf chat " .. report_text)
                delay.chat = 2
            end
            if delay.chat == 0 then
                if delay.chatMon == 1 then
                    sampSendChat("/jf chat " .. SendMonText)
                    delay.chatMon = 2
                end
                if delay.chatMon == 0 then
                    if delay.sms == 1 then
                        sampSendChat("/sms " .. pair_mode_id .. " " .. sms_pair_mode)
                        delay.sms = 2
                    end
                    if delay.sms == 0 then
                        if delay.load == 1 then
                            sampSendChat("/truck load " .. GetGruz())
                            delay.load = 2
                        end
                        if delay.load == 0 then
                            if delay.unload == 1 then
                                sampSendChat("/truck unload")
                                delay.unload = 2
                            end
                            if delay.unload == 0 then
                                if delay.dir == 1 then
                                    sampSendChat("/dir")
                                    delay.dir = 2
                                end
                                if delay.dir == 0 then
                                    if delay.skill == 1 then
                                        sampSendChat("/jskill")
                                        delay.skill = 2
                                    end
                                    if delay.skill == 0 then
                                        if delay.paycheck == 1 then
                                            sampSendChat("/paycheck")
                                            delay.paycheck = 2
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function doDialog()
    local result, button, list, input = sampHasDialogRespond(222)
    local caption = sampGetDialogCaption()
    if caption:find('Truck%-HUD: Блокировка') then
        if result then
            doLocalBlock(button, list, input, caption)
        end
    end
    if caption == "Truck-HUD: Настройки" then
        if result and button == 1 then
            if dialogLine ~= nil and dialogLine[list + 1] ~= nil then
                local str = dialogLine[list + 1]
                if str:find("TruckHUD") then
                    script_run = not script_run
                    ShowDialog1(1)
                end
                if str:find("Сменить позицию статистики с таймером") then
                    wait(100)
                    pos[1] = true
                end
                if str:find("Сменить позицию мониторинга цен") then
                    wait(100)
                    pos[2] = true
                end
                if str:find("Сменить позицию биндера") then
                    wait(100)
                    pos[3] = true
                end
                if str:find("Редактировать формат статистики") then
                    editbox_stats = true
                    ShowDialog1(9)
                end
                if str:find("Cruise Control") then
                    if str:find("Кнопка") then
                        ShowDialog1(4, 4)
                    else
                        inifiles.Settings.Cruise = not inifiles.Settings.Cruise
                        if inifiles.Settings.Cruise then 
                            sampAddChatMessage('Для активации когда едете нажмите '..inifiles.Settings.Key4:gsub('VK_', '')..'. Чтобы отключить нажмите W.', -1)
                        end
                        settings_save()
                        ShowDialog1(1)
                    end
                 end
                if str:find("Информация о напарнике на HUD") then
                    inifiles.Settings.pairinfo = not inifiles.Settings.pairinfo
                    settings_save()
                    ShowDialog1(9)
                end
                if str:find("Доклады в рацию") then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    menu[3].run = inifiles.Settings.Report
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Доклады от") then
                    inifiles.Settings.girl = not inifiles.Settings.girl
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Авто загрузка/разгрузка") then
                    auto = not auto
                    menu[2].run = auto
                    ShowDialog1(1)
                end
                if str:find("Режим авто загрузки/разгрузки") then
                    inifiles.Settings.AutoOFF = not inifiles.Settings.AutoOFF
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Убрать тюнинг колес с фур") then
                    inifiles.Settings.Tuning = not inifiles.Settings.Tuning
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Биндер") then
                    inifiles.Settings.Binder = not inifiles.Settings.Binder
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Режим пары ") then
                    if pair_mode then
                        pair_mode = false
                        menu[4].run = false
                        ShowDialog1(9)
                    else
                        ShowDialog1(8)
                    end
                end
                if str:find("Доклады в SMS") then
                    inifiles.Settings.SMSpara = not inifiles.Settings.SMSpara
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Подсветка напарника в чате") then
                    inifiles.Settings.LightingPara = not inifiles.Settings.LightingPara
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Остановка фуры после разгрузки") then
                    inifiles.Settings.Stop = not inifiles.Settings.Stop
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Синхронизация") then
                    inifiles.Settings.transponder = not inifiles.Settings.transponder
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Карта с позицией") then
                    inifiles.Settings.fastmap = not inifiles.Settings.fastmap
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Скрывать чат профсоюза") then
                    inifiles.Settings.ChatOFF = not inifiles.Settings.ChatOFF
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("только в фуре") then
                    inifiles.Settings.chat_in_truck = not inifiles.Settings.chat_in_truck
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Отправка мониторинга в чат") then
                    inifiles.Settings.ChatDoklad = not inifiles.Settings.ChatDoklad
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Выделение Портов") then
                    inifiles.Settings.highlight_jf = not inifiles.Settings.highlight_jf
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Выделение цены") then
                    inifiles.Settings.LightingPrice = not inifiles.Settings.LightingPrice
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Цвет подсветки напарника") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(
                            2,
                            dialogTextToList[list + 1],
                            inifiles.Settings.ColorPara,
                            true,
                            "Settings",
                            "ColorPara"
                        )
                    end
                end
                if str:find("Шрифт") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Render.FontName, true, "Render", "FontName")
                    end
                end
                if str:find("Размер") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(
                            2,
                            dialogTextToList[list + 1],
                            inifiles.Render.FontSize,
                            false,
                            "Render",
                            "FontSize"
                        )
                    end
                end
                if str:find("Стиль") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(
                            2,
                            dialogTextToList[list + 1],
                            inifiles.Render.FontFlag,
                            false,
                            "Render",
                            "FontFlag"
                        )
                    end
                end
                if str:find("Цвет первый") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Render.Color1, true, "Render", "Color1")
                    end
                end
                if str:find("Цвет второй") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Render.Color2, true, "Render", "Color2")
                    end
                end
                if str:find("Цена авто%-загрузки") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Price.Load, false, "Price", "Load")
                    end
                end
                if str:find("Цена авто%-разгрузки") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Price.UnLoad, false, "Price", "UnLoad")
                    end
                end
                if str:find("Кнопка отображения меню") then
                    ShowDialog1(4, 1)
                end
                if str:find("Задержка") then
                    inifiles.Settings.AutoWait = not inifiles.Settings.AutoWait
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("clist 0") then
                    inifiles.Settings.markers = not inifiles.Settings.markers
                    if not inifiles.Settings.markers then
                        deleteMarkers()
                    end
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Кнопка для работы без фуры") then
                    ShowDialog1(4, 2)
                end
                if str:find("Кнопка для отображения карты") then
                    ShowDialog1(4, 3)
                end
                if str:find("Локальная блокировка участников") then
                    LocalBlock(1)
                end
                if str:find("Уведомления когда Вас установили напарником") then
                    inifiles.Settings.NewPairMSG = not inifiles.Settings.NewPairMSG
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Авто%-Очистка неиспользуемой памяти скрипта") then
                    inifiles.Settings.AutoClear = not inifiles.Settings.AutoClear
                    settings_save()
                    ShowDialog1(1)
                end
                if str:find("Очистить неиспользуемую память скрипта") then
                    local mem_do = string.format('%0.2f MB', (tonumber(gcinfo()) / 1000))
                    collectgarbage()
                    sampAddChatMessage('Памяти очищена. Было: '..mem_do..'. Стало: '..string.format('%0.2f MB', (tonumber(gcinfo()) / 1000)), -1)
                    ShowDialog1(1)
                end
                if str:find("Подробная статистика") then
                    ShowStats(1)
                end
                if str:find("Контакты автора") then
                    ShowDialog1(3)
                end
                if str:find("Перезагрузка скрипта") then
                    thisScript():reload()
                end
            end
        end
    end
    if caption == "Truck-HUD: Изменение настроек" then
        if d[7] then
            d[7] = false
            sampSetCurrentDialogEditboxText(inifiles[d[5]][d[6]])
        end
        if result then
            if button == 1 then
                local gou = (d[4] and (#input > 0 and true or false) or (input:find("%d+") and true or false))
                if gou then
                    d[3] = (d[4] and tostring(input) or tonumber(input))
                    inifiles[d[5]][d[6]] = d[3]
                    settings_save()
                    if d[5]:find("Render") then
                        renderReleaseFont(font)
                        font =
                            renderCreateFont(
                            inifiles.Render.FontName,
                            inifiles.Render.FontSize,
                            inifiles.Render.FontFlag
                        )
                    end
                    ShowDialog1(1)
                else
                    ShowDialog1(d[1], d[2], d[3], d[4], d[5], d[6])
                end
            else
                ShowDialog1(1)
            end
        end
    end
    if caption == "Truck-HUD: Редактор HUD" then
        if result then
            if button == 1 then
                local text = getClipboardText()
                if #text > 1 then
                    inifiles.Settings.stats_text = text
                    settings_save()
                else
                    inifiles.Settings.stats_text = defaultMon
                    settings_save()
                end
            end
            ShowDialog1(1)
        end
    end
    if caption == "Truck-HUD: Контакты автора" then
        if result then
            if button == 1 then
                if list == 0 then
                    setClipboardText("Serhiy_Rubin")
                end
                if list == 1 then
                    setClipboardText("https://vk.com/id353828351")
                end
                if list == 2 then
                    setClipboardText("https://vk.com/club161589495")
                end
                if list == 3 then
                    setClipboardText("serhiyrubin")
                end
                if list == 4 then
                    setClipboardText("Serhiy_Rubin#3391")
                end
                ShowDialog1(3)
            else
                ShowDialog1(1)
            end
        end
    end
    if caption == 'Truck-HUD: Биндер' then
        if result then
            if button == 1 and #input > 0 then 
                if d[2] == 1 then
                    inifiles.binder[#inifiles.binder + 1] = input
                    settings_save()
                elseif d[2] == 2 then
                    inifiles.binder[d[3]] = input
                    settings_save()
                end
            end
        end
    end
    if caption == "Truck-HUD: Статистика" then
        if result then
           WhileShowStats(button, list)
        end
    end
    if caption == "Truck-HUD: Режим пары" then
        if result then
            if button == 1 then
                if string.find(input, "(%d+)") then
                    pair_mode_id = tonumber(string.match(input, "(%d+)"))
                    if sampIsPlayerConnected(pair_mode_id) then
                        error_message(1, '')
                        para_message_send = nil
                        pair_mode_name = sampGetPlayerNickname(pair_mode_id)
                        menu[4][1] = "SMS » " .. pair_mode_name .. "[" .. pair_mode_id .. "]"
                        pair_mode = true
                        menu[4].run = true
                        transponder_delay = 100
                    else
                        pair_mode_id = -1
                        pair_mode = false
                        menu[4].run = false
                        sampAddChatMessage("Ошибка! Игрок под этим ID не в сети.", -1)
                    end
                end
            else
                pair_mode = false
                menu[4].run = false
            end
        end
    end
    if caption == "Truck-HUD: Меню" then
        if result then
            if button == 1 then
                if list == 0 then
                    script_run = not script_run
                    ShowDialog1(9)
                end
                if list == 1 then
                    auto = not auto
                    ShowDialog1(9)
                end
                if list == 2 then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    settings_save()
                    ShowDialog1(9)
                end
                if list == 3 then
                    if pair_mode then
                        pair_mode = false
                        menu[4].run = false
                        ShowDialog1(9)
                    else
                        ShowDialog1(8)
                    end
                end
                if list == 4 then
                    inifiles.Settings.Binder = not inifiles.Settings.Binder
                    settings_save()
                    ShowDialog1(9)
                end
                if list >= 5 then
                    local S1 = {[5] = 1, [6] = 2, [7] = 3}
                    pos[S1] = true
                end
            end
        end
    end
end

function doPair()
    if pair_mode then
        if not sampIsPlayerConnected(pair_mode_id) or sampGetPlayerNickname(pair_mode_id) ~= pair_mode_name then
            pair_mode = false
            menu[4].run = false
            sampAddChatMessage(
                "Напарник " .. pair_mode_name .. "[" .. pair_mode_id .. "]" .. " вышел из игры. Режим пары выключен.",
                -1
            )
        end
    end
end

function doPickup()
    if script_run then
        for k, v in pairs(pickupLoad) do
            local X, Y, Z = getDeadCharCoordinates(PLAYER_PED)
            local distance = getDistanceBetweenCoords3d(X, Y, Z, v[1], v[2], v[3])
            if inifiles.Settings.pickup and distance <= 15.0 and isTruckCar() then
                if v.pickup == nil then
                    result, v.pickup = createPickup(19135, 1, v[1], v[2], v[3])
                end
            else
                if v.pickup ~= nil then
                    if doesPickupExist(v.pickup) then
                        removePickup(v.pickup)
                        v.pickup = nil
                    end
                end
            end
        end
    else
        for k, v in pairs(pickupLoad) do
            if v.pickup ~= nil then
                if doesPickupExist(v.pickup) then
                    removePickup(v.pickup)
                    v.pickup = nil
                end
            end
        end
    end
end

function doMarkers()
    if inifiles.Settings.markers then
        for id = 0, 999 do
            if sampIsPlayerConnected(id) then
                local stream, handle = sampGetCharHandleBySampPlayerId(id)
                if stream then
                    if newMarkers[id] == nil then
                        if isTruckCar() and isCharInAnyCar(handle) then
                            newMarkers[id] = addBlipForChar(handle)
                            changeBlipDisplay(newMarkers[id], 2)
                            changeBlipColour(newMarkers[id], 0xFFFFFF25)
                        end
                    else
                        if not isTruckCar() or not isCharInAnyCar(handle) then
                            removeBlip(newMarkers[id])
                            newMarkers[id] = nil
                        end
                    end
                else
                    if newMarkers[id] ~= nil then
                        removeBlip(newMarkers[id])
                        newMarkers[id] = nil
                    end
                end
            end
        end
    else
        deleteMarkers()
    end
end

function deleteMarkers()
    for k, v in pairs(newMarkers) do
        removeBlip(v)
        newMarkers[k] = nil
    end
end

function doCruise()
    if not inifiles.Settings.Cruise then return end
    if cruise == nil then cruise = false end
    if not isCharInAnyCar(playerPed) then
        if cruise then 
            cruise = false
            printStringNow('~R~Cruise Control - OFF', 1500)
        end
        return
    end
    local car = storeCarCharIsInNoSave(playerPed)
    if cruise and not isCarEngineOn(car) then
        cruise = false
        printStringNow('~R~Cruise Control - OFF', 1500)
        return
    end
    if not sampIsChatInputActive(  ) and not sampIsDialogActive(  ) and not sampIsCursorActive(  ) then
        if pressW ~= nil and not isKeyDown(87) then
            pressW = nil 
        end
        if not cruise and isKeyDown(87) and isKeyDown(vkeys[inifiles.Settings.Key4]) and isCarEngineOn(car) and isCharInAnyCar(playerPed) then
            cruise = true
            pressW = true
            printStringNow('~G~Cruise Control - ON', 1500)
        elseif cruise and not isKeyDown(vkeys[inifiles.Settings.Key4]) and isKeyDown(87) and pressW == nil then
            cruise = false
            printStringNow('~R~Cruise Control - OFF', 1500)
        end
    end
    if cruise then
        setGameKeyState(16, 255)
    end
end

function doRenderStats()

    if pos[1] then
        sampSetCursorMode(3)
        local X, Y = getCursorPos()
        inifiles.Settings.X1, inifiles.Settings.Y1 = X, Y + 15
        if isKeyJustPressed(1) then
            settings_save()
            pos[1] = false
            sampSetCursorMode(0)
        end
    end
    local X, Y, c1, c2 = inifiles.Settings.X1, inifiles.Settings.Y1, inifiles.Render.Color1, inifiles.Render.Color2
    local down = (renderGetFontDrawHeight(font) / 6)
    local height = (renderGetFontDrawHeight(font) - (renderGetFontDrawHeight(font) / 20))
    if control then
        if drawClickableText("{" .. c2 .. "}[Смена позиции]", X, Y) then
            pos[1] = true
        end
    end
    Y = Y + height
    timer_secc = 180 - os.difftime(msk_timestamp, timer)
    local ost_time = 3600 - (os.date("%M", msk_timestamp) * 60) + (os.date("%S", msk_timestamp))
    local greys = 0
    if workload == 1 then
        if timer_secc > 0 then
            if ost_time > timer_secc then
                ost_time = ost_time - timer_secc
                greys = 1
            else
                greys = 0
            end
        end
    end
    greys = greys + math.floor(ost_time / 360)
    if timer_secc >= 177 and workload == 0 and isTruckCar() and inifiles.Settings.Stop then
        setGameKeyState(6, 255)
    end
    timer_min, timer_sec = math.floor(timer_secc / 60), timer_secc % 60
    strok =
        (timer_secc >= 0 and
        (workload == 1 and
            string.format(
                "{%s}До разгрузки {%s}%d:%02d",
                inifiles.Render.Color1,
                (timer_secc <= 10 and "b50000" or inifiles.Render.Color2),
                timer_min,
                timer_sec
            ) or
            string.format(
                "{%s}До загрузки {%s}%d:%02d",
                inifiles.Render.Color1,
                (timer_secc <= 10 and "b50000" or inifiles.Render.Color2),
                timer_min,
                timer_sec
            )) or
        (workload == 1 and string.format("{%s}Можно разгружать", inifiles.Render.Color1) or
            string.format("{%s}Можно загружать", inifiles.Render.Color1)))
    if auto then
        if control then
            local delta = getMousewheelDelta()
            if delta ~= 0 then
                ChangeCena(delta)
            end
        end
        local autoColor = (autoh and inifiles.Render.Color2 or "d90b0b")
        str =
            (inifiles.Price[(workload == 1 and "UnLoad" or "Load")] ~= 0 and
            " {" ..
                autoColor ..
                    "}[" ..
                        (workload == 1 and "Un" or "") ..
                            "Load: " .. inifiles.Price[(workload == 1 and "UnLoad" or "Load")] .. "] " or
            " {" .. autoColor .. "}[" .. (workload == 1 and "Un" or "") .. "Load] ")
        if os.difftime(msk_timestamp, timer) > 180 and autoh then
            if workload == 1 then
                if unload_location then
                    local dp = {ls = "sf", sf = "ls"}
                    local dport, ds = string.match(current_warehouse, "(..)(.)")
                    local dcena =
                        (inifiles.tmonitor[dp[dport] .. ds] + inifiles.tmonitor[current_warehouse]) - prices_3dtext[current_warehouse]
                    if inifiles.Price.UnLoad ~= 0 then
                        if price_frozen then
                            if tonumber(prices_3dtext[current_warehouse]) == tonumber(inifiles.Price.UnLoad) then
                                autoh, delay.unload = false, (dcena ~= 900 and 1 or delay.unload)
                            end
                        else
                            if tonumber(prices_3dtext[current_warehouse]) >= tonumber(inifiles.Price.UnLoad) then
                                autoh, delay.unload = false, (dcena ~= 900 and 1 or delay.unload)
                            end
                        end
                    else
                        autoh, delay.unload = false, (dcena ~= 900 and 1 or delay.unload)
                    end
                end
            else
                if load_location then
                    if inifiles.Price.Load ~= 0 then
                        if
                            (price_frozen and
                                tonumber(prices_3dtext[current_warehouse]) == tonumber(inifiles.Price.Load)) or
                                (not price_frozen and
                                    tonumber(prices_3dtext[current_warehouse]) <= tonumber(inifiles.Price.Load))
                         then
                            if inifiles.Settings.AutoWait then
                                if (msk_timestamp - wait_auto) <= 3 then
                                    printStyledString("Wait load " .. (3 - (msk_timestamp - wait_auto)), 1111, 5)
                                end
                                if (msk_timestamp - wait_auto) > 3 then
                                    delay.load, autoh = 1, false
                                end
                            else
                                delay.load, autoh = 1, false
                            end
                        end
                    else
                        delay.load, autoh = 1, false
                    end
                end
            end
        end
        if drawClickableText(str, (X + renderGetFontDrawTextLength(font, strok)), Y) then
            if autoh then
                if workload == 1 then
                    inifiles.Price.UnLoad = 0
                else
                    inifiles.Price.Load = 0
                end
                settings_save()
            else
                delay.load = 0
                delay.unload = 0
                autoh = true
            end
        end
        if price_frozen or control then
            if drawClickableText("=", (X + renderGetFontDrawTextLength(font, strok .. str)), Y) then
                price_frozen = not price_frozen
            end
        end
        if isKeyDown(vkeys[inifiles.Settings.Key1]) and (isTruckCar() or isKeyDown(90)) then
            if
                drawClickableText(
                    "+",
                    (X + renderGetFontDrawTextLength(font, strok) + (renderGetFontDrawTextLength(font, str) / 3)),
                    (Y - height)
                )
             then
                ChangeCena(1)
            end
            if
                drawClickableText(
                    "-",
                    (X + renderGetFontDrawTextLength(font, "+" .. strok) + (renderGetFontDrawTextLength(font, str) / 2)),
                    (Y - height)
                )
             then
                ChangeCena(0)
            end
        end
    end
    drawClickableText(strok, X, Y)
    local stats_array = split(inifiles.Settings.stats_text, '!n!')
    local stats_info = {
        ['!m!'] = string.format('%0.2f mb', (tonumber(gcinfo()) / 1000)),
        ['!skill!'] = inifiles.Trucker.Skill,
        ['!skill_poc!'] = inifiles.Trucker.ProcSkill,
        ['!skill_reys!'] = inifiles.Trucker.ReysSkill,
        ['!rang!'] = inifiles.Trucker.Rank,
        ['!rang_poc!'] = inifiles.Trucker.ProcRank,
        ['!rang_reys!'] = inifiles.Trucker.ReysRank,
        ['!zp_hour!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp,
        ['!max_zp!'] = inifiles.Trucker.MaxZP,
        ['!profit!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day.pribil,
        ['!reys_hour!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].razgruzkacount,
        ['!reys_day!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day.razgruzkacount,
        ['!left_reys!'] = greys,
        ['!profit_hour!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].pribil,
        ['!all_zp!'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day.zp
    }

    for k, v in pairs(stats_array) do
        for i, s in pairs(stats_info) do
            if v:find(i) then
                v = v:gsub(i, s)
            end
        end
        if v:find('!mn!') then
            v = v:gsub('!mn!', '')
            Y = Y + down + height
        else
            Y = Y + height
        end
        drawClickableText(v, X, Y)
    end
    if inifiles.Settings.pairinfo and pair_mode and pair_status == 200 and pair_table ~= nil and pair_table["pos"] ~= nil and base[pair_mode_name] ~= nil then
        local afk = msk_timestamp - pair_timestamp
        local timer_d = 180 - (base[pair_mode_name].timer > 1000 and os.difftime(msk_timestamp, base[pair_mode_name].timer) or 181)
        string_render, Y = string.format(" {%s}%s[%s]%s", c2, pair_mode_name, pair_mode_id, (afk > 9 and ' [AFK: '..math.ceil(afk)..']' or '')), Y + height + down
        drawClickableText(string_render, X, Y)
        local para_pos = FindSklad(pair_table["pos"]["x"], pair_table["pos"]["y"], pair_table["pos"]["z"])
        string_render, Y = string.format("{%s} [{%s}%s{%s}] %s (%s m)", c2, (timer_d < 11 and (timer_d > 0 and 'b50000' or c2) or c2), (timer_d > 0 and string.format('%d:%02d', math.floor(timer_d / 60), timer_d % 60) or '0:00'), c2, para_pos.text, math.ceil(para_pos.dist)), Y + height
        drawClickableText(string_render, X, Y)
    end
    
    if delay.skill == -1 then
        delay.skill = 1
    end
end

function doRenderMon()
    if pos[2] then
        sampSetCursorMode(3)
        local X, Y = getCursorPos()
        inifiles.Settings.X2, inifiles.Settings.Y2 = X, Y
        if isKeyJustPressed(1) then
            settings_save()
            pos[2] = false
            sampSetCursorMode(0)
        end
    end

    local X, Y, c1, c2 = inifiles.Settings.X2, inifiles.Settings.Y2, inifiles.Render.Color1, inifiles.Render.Color2
    local height = renderGetFontDrawHeight(font)

    local A1 = os.difftime(msk_timestamp, mon_time)
    local A2 = os.difftime(msk_timestamp, mon_ctime)
    if A2 >= A1 then
        stimer = A1 
    else
        stimer = A2
    end
    local hour, minute, second = stimer / 3600, math.floor(stimer / 60), stimer % 60
    if hour >= 1 then
        send_time_mon = string.format("%02d:%02d:%02d", math.floor(hour), minute - (math.floor(hour) * 60), second)
        rdtext = string.format("Склады. %s", send_time_mon)
    else
        send_time_mon = string.format("%02d:%02d", minute, second)
        rdtext = string.format("Склады. %s", send_time_mon)
    end
    if drawClickableText(rdtext, X, Y) then
        transponder_delay = 100
    end
    -----
    local secund = os.difftime(msk_timestamp, mon_life)
    if secund == 3 or secund == 1 then
        c2 = "ff0000"
    end
    Y = Y + height
    local string1 = string.format("  {%s}Н1: {%s}%03d", c1, c2, prices_mon.n1)
    local pX, pY, pZ = getDeadCharCoordinates(PLAYER_PED)
    if drawClickableText(string1, X, Y) then
        sampSendChat(
            "/jf chat Еду на Нефтезавод №1. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, 256.02127075195, 1414.8492431641, 10.232398033142)) ..
                    " м."
        )
    end
    local string2 = string.format(" {%s}Н2: {%s}%03d", c1, c2, prices_mon.n2)
    if drawClickableText(string2, (X + renderGetFontDrawTextLength(font, string1)), Y) then
        sampSendChat(
            "/jf chat Еду на Нефтезавод №2. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, -1046.7521972656, -670.66937255859, 31.885597229004)) ..
                    " м."
        )
    end
    Y = Y + height
    local string1 = string.format("  {%s}У1: {%s}%03d", c1, c2, prices_mon.y1)
    if drawClickableText(string1, X, Y) then
        sampSendChat(
            "/jf chat Еду на Склад Угля №1. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, 833.04681396484, 864.35931396484, 12.277567863464)) ..
                    " м."
        )
    end
    local string2 = string.format(" {%s}У2: {%s}%03d", c1, c2, prices_mon.y2)
    if drawClickableText(string2, (X + renderGetFontDrawTextLength(font, string1)), Y) then
        sampSendChat(
            "/jf chat Еду на Склад Угля №2. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, -2913.8544921875, -1377.0952148438, 12.7622566223148)) ..
                    " м."
        )
    end
    Y = Y + height
    local string1 = string.format("  {%s}Л1: {%s}%03d", c1, c2, prices_mon.l1)
    if drawClickableText(string1, X, Y) then
        sampSendChat(
            "/jf chat Еду на Лесопилку №1. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, -448.91455078125, -65.951385498047, 58.959014892578)) ..
                    " м."
        )
    end
    local string2 = string.format(" {%s}Л2: {%s}%03d", c1, c2, prices_mon.l2)
    if drawClickableText(string2, (X + renderGetFontDrawTextLength(font, string1)), Y) then
        sampSendChat(
            "/jf chat Еду на Лесопилку №2. До цели: " ..
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, -1978.8649902344, -2434.9421386719, 30.192840576172)) ..
                    " м."
        )
    end
    Y = Y + height
    if control and workload == 1 then
        if drawClickableText("?", X - renderGetFontDrawTextLength(font, "  "), Y) then
            sampSendChat("/jf chat " .. what_is_uploaded[current_load] .. " в ЛС едет?")
        end
    end
    local string =
        string.format(
        "{%s}Порт ЛС.\n  Н: {%s}%03d {%s}У: {%s}%03d {%s}Л: {%s}%03d",
        c1,
        c2,
        prices_mon.lsn,
        c1,
        c2,
        prices_mon.lsy,
        c1,
        c2,
        prices_mon.lsl
    )
    if drawClickableText(string, X, Y) then
        if workload ~= 0 then
            sampSendChat(
                "/jf chat Везу " ..
                    what_is_uploaded[current_load] ..
                        " в Порт ЛС. До цели: " ..
                            math.ceil(
                                getDistanceBetweenCoords3d(pX, pY, pZ, 2509.04296875, -2231.4343261719, 12.920718193054)
                            ) ..
                                " м."
            )
        else
            sampSendChat(
                "/jf chat Еду в Порт ЛС. До цели: " ..
                    math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, 2509.04296875, -2231.4343261719, 12.920718193054)) ..
                        " м."
            )
        end
    end
    Y = Y + (height * 2)
    if control and workload == 1 then
        if drawClickableText("?", X - renderGetFontDrawTextLength(font, "  "), Y) then
            sampSendChat("/jf chat " .. what_is_uploaded[current_load] .. " в СФ едет?")
        end
    end
    local string =
        string.format(
        "{%s}Порт СФ.\n  Н: {%s}%03d {%s}У: {%s}%03d {%s}Л: {%s}%03d",
        c1,
        c2,
        prices_mon.sfn,
        c1,
        c2,
        prices_mon.sfy,
        c1,
        c2,
        prices_mon.sfl
    )
    if drawClickableText(string, X, Y) then
        if workload ~= 0 then
            sampSendChat(
                "/jf chat Везу " ..
                    what_is_uploaded[current_load] ..
                        " в Порт СФ. До цели: " ..
                            math.ceil(
                                getDistanceBetweenCoords3d(
                                    pX,
                                    pY,
                                    pZ,
                                    -1733.1876220703,
                                    120.08413696289,
                                    3.1192970275879
                                )
                            ) ..
                                " м."
            )
        else
            sampSendChat(
                "/jf chat Еду в Порт СФ. До цели: " ..
                    math.ceil(
                        getDistanceBetweenCoords3d(pX, pY, pZ, -1733.1876220703, 120.08413696289, 3.1192970275879)
                    ) ..
                        " м."
            )
        end
    end
    if control then
        Y = Y + (height * 2)
        if drawClickableText("{" .. inifiles.Render.Color2 .. "}[Смена позиции]", X, Y) then
            pos[2] = true
        end
        Y = Y + height
        if drawClickableText("{" .. inifiles.Render.Color2 .. "}[Отправить в чат]", X, Y) then
            if (unload_location or load_location) then
                delay.mon = 1
                delay.chatMon = -1
            else
                SendMonText =
                    string.format(
                    "/jf chat [ЛС H:%d У:%d Л:%d] [1 H:%d У:%d Л:%d] [2 H:%d У:%d Л:%d] [CФ H:%d У:%d Л:%d] [%s]",
                    (prices_mon.lsn / 100),
                    (prices_mon.lsy / 100),
                    (prices_mon.lsl / 100),
                    (prices_mon.n1 / 100),
                    (prices_mon.y1 / 100),
                    (prices_mon.l1 / 100),
                    (prices_mon.n2 / 100),
                    (prices_mon.y2 / 100),
                    (prices_mon.l2 / 100),
                    (prices_mon.sfn / 100),
                    (prices_mon.sfy / 100),
                    (prices_mon.sfl / 100),
                    send_time_mon
                )
                sampSendChat(SendMonText)
            end
        end
    end
end

function doRenderBind()
    if pos[3] then
        sampSetCursorMode(3)
        local X, Y = getCursorPos()
        inifiles.Settings.X3, inifiles.Settings.Y3 = X, Y + 15
        if isKeyJustPressed(1) then
            settings_save()
            pos[3] = false
            sampSetCursorMode(0)
        end
    end
    if script_run and inifiles.Settings.Binder and control or pos[3] then
        local X, Y = inifiles.Settings.X3, inifiles.Settings.Y3
        local plus = (renderGetFontDrawHeight(font) + (renderGetFontDrawHeight(font) / 10))
        if drawClickableText("{" .. inifiles.Render.Color2 .. "}[Смена позиции]", X, Y) then
            pos[3] = true
        end
        for k, string in pairs(inifiles.binder) do
            if string.find(string, "!НикПары") then
                local nick = " "
                if sampIsPlayerConnected(pair_mode_id) then
                    nick = sampGetPlayerNickname(pair_mode_id):gsub("_", " ")
                end
                string = string:gsub("!НикПары", nick)
            end
            if string.find(string, "!ИдПары") then
                string = string:gsub("!ИдПары", pair_mode_id)
            end
            if string.find(string, "!КД") then
                local min, sec = timer_min, timer_sec
                if min < 0 then min, sec = 0, 0 end
                string = string:gsub("!КД", string.format("%d:%02d", min, sec))
            end
            Y = Y + plus
            if drawClickableText(string, X, Y) then
                sampSendChat(string)
            end
            if drawClickableText("{ff0000}х", (X + renderGetFontDrawTextLength(font, string .. "  ")), Y) then
                inifiles.binder[k] = nil
                settings_save()
            end
            if drawClickableText("{12a61a}/", (X + renderGetFontDrawTextLength(font, string .. "     ")), Y) then
                ShowDialog1(7, 2, k)
            end
        end
        Y = Y + plus
        if drawClickableText("{12a61a}Добавить строку", X, Y) then
            ShowDialog1(7, 1)
        end
    end
end

function doLocalBlock(button, list, input, caption)
    if caption:find('1') then
        if button == 1 then
            if list == 0 then
                LocalBlock(2)
            elseif list == 1 then
                LocalBlock(3)
            elseif list == 2 then
                inifiles.Settings.blacklist_inversion = not inifiles.Settings.blacklist_inversion
                settings_save()
                LocalBlock(1)
            end
        else
            ShowDialog1(1)
        end
    end
    if caption:find('2') then
        if button == 1 then
            if dialogFunc[list + 1] ~= nil then 
                dialogFunc[list + 1]()
            end
            LocalBlock(2)
        else
            LocalBlock(1)
        end
    end
    if caption:find('3') then
        if button == 1 then
            if dialogFunc[list + 1] ~= nil then 
                dialogFunc[list + 1]()
            end
            LocalBlock(3)
        else
            LocalBlock(1)
        end
    end
end

function LocalBlock(int, param)
    if int == 1 then
        dialogText = 'Блокировка мониторинга от пользователей\nБлокировка мониторинга с хостинга\nБлокировка мониторинга из чата\nРежим: '..(inifiles.Settings.blacklist_inversion and 'Как белый список' or 'Как черный список')
        sampShowDialog(222, 'Truck-HUD: Блокировка [1]', dialogText, 'Выбрать', 'Закрыть', 5)
    end
    if int == 2 then
        dialogFunc = {}
        dialogText = '' -- fa3620
        for k, v in pairs(base) do
            if v.tmonitor ~= nil and v.tmonitor.lsn ~= nil then
                local color = ( inifiles.blacklist[k] == nil and 'FFFFFF' or ( inifiles.blacklist[k] == true and 'fa3620' or 'FFFFFF'))
                dialogText = string.format('%s{%s}Игрок: %s\tВремя мониторинга: %s\n', dialogText, color, k, (msk_timestamp - v.tmonitor.time))
                dialogFunc[#dialogFunc + 1] = function()
                    if inifiles.blacklist[k] == nil then
                        inifiles.blacklist[k] = false
                    end
                    inifiles.blacklist[k] = not inifiles.blacklist[k]
                end
                dialogText = string.format('%s{%s}[ЛС Н:%s У:%s Л:%s] [1 Н:%s У:%s Л:%s] [2 Н:%s У:%s Л:%s] [CФ Н:%s У:%s Л:%s\n', dialogText, color, v.tmonitor.lsn, v.tmonitor.lsy,v.tmonitor.lsl,v.tmonitor.n1,v.tmonitor.y1,v.tmonitor.l1,v.tmonitor.n2,v.tmonitor.y2, v.tmonitor.l2, v.tmonitor.sfn,v.tmonitor.sfy,v.tmonitor.sfl)
                dialogFunc[#dialogFunc + 1] = dialogFunc[#dialogFunc] 
                dialogText = string.format('%s \n', dialogText)
                dialogFunc[#dialogFunc + 1] = dialogFunc[#dialogFunc]                                      
            end
        end
        settings_save()
        sampShowDialog(222, 'Truck-HUD: Блокировка [2]', dialogText, 'Выбрать', 'Назад', 2)
    end
    if int == 3 then
        dialogFunc = {}
        dialogText = '' -- fa3620
        for k, v in pairs(chat_mon) do
            if v ~= nil and v.lsn ~= nil then
                local color = ( inifiles.blacklist[k] == nil and 'FFFFFF' or ( inifiles.blacklist[k] == true and 'fa3620' or 'FFFFFF'))
                dialogText = string.format('%s{%s}Игрок: %s\tВремя мониторинга: %s\n', dialogText, color, k, (msk_timestamp - v.time))
                dialogFunc[#dialogFunc + 1] = function()
                    if inifiles.blacklist[k] == nil then
                        inifiles.blacklist[k] = false
                    end
                    inifiles.blacklist[k] = not inifiles.blacklist[k]
                end
                dialogText = string.format('%s{%s}[ЛС Н:%s У:%s Л:%s] [1 Н:%s У:%s Л:%s] [2 Н:%s У:%s Л:%s] [CФ Н:%s У:%s Л:%s\n', dialogText, color, v.lsn, v.lsy,v.lsl,v.n1,v.y1,v.l1,v.n2,v.y2, v.l2, v.sfn,v.sfy,v.sfl)
                dialogFunc[#dialogFunc + 1] = dialogFunc[#dialogFunc] 
                dialogText = string.format('%s \n', dialogText)
                dialogFunc[#dialogFunc + 1] = dialogFunc[#dialogFunc]                                      
            end
        end
        settings_save()
        sampShowDialog(222, 'Truck-HUD: Блокировка [3]', dialogText, 'Выбрать', 'Назад', 2)
    end
end

function ShowStats(int, param)
    dialogINT = int
    if int == 1 then
        dialogKeytoList = { '1' }
        dialogText = 'Статистика за всё время\n'
        local array = {}
        for k,v in pairs(inifiles.log) do
            local day, month, year = string.match(k, '(%d+)%.(%d+)%.%d%d(%d+)')
            local keydate = tonumber( string.format('%02d%02d%02d', year, month, day) )
            array[keydate] = k
        end
        for i = tonumber(os.date('%y%m%d', msk_timestamp)), 1, -1 do
            if array[i] ~= nil then
                dialogText = string.format('%s%s\n', dialogText, array[i])
                dialogKeytoList[#dialogKeytoList + 1] = array[i]
            end
        end
        dialogKeytoList[#dialogKeytoList + 1] = 'nil'
        dialogKeytoList[#dialogKeytoList + 1] = 'del'
        dialogText = string.format('%s\n \nУдалить всю статистику', dialogText)
        sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 2)
    end
    if int == 2 then
        dialogKeytoList = { param[1], param[1], param[1] }
        dialogText = 'Дата: '..param[1]..'\nСтатистика\nУдалить статистику'
        sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 5)
    end
    if int == 3 then
        dialogKeytoList = {}
        dialogText = ''
        local v = inifiles.log[param[1]][param[2]]
            if param[2] == 'day' then
                dialogKeytoList[1] = param[1]
                dialogText = string.format('Дата: %s{FFFFFF}\nПодсчет:\n %d фур на сумму %d вирт\n %d загрузок на сумму %d вирт\n %d разгрузок на сумму %d вирт\n %d заправок на сумму %d вирт\n %d починок на сумму %d вирт\n %d канистр на сумму %d вирт\n %d штрафов на сумму %d вирт\nИтоги:\n Зарплата: %d вирт\n Затраты: %d вирт\n Прибыль: %d вирт', param[1],
                    v.arendacount, v.arenda,
                    v.zagruzkacount, v.zagruzka,
                    v.razgruzkacount, v.razgruzka, 
                    v.refillcount, v.refill,
                    v.repaircount, v.repair,
                    v.kanistrcount, v.kanistr,
                    v.shtrafcount, v.shtraf,
                    v.zp, (v.arenda + v.refill + v.repair + v.kanistr + v.shtraf), v.pribil)
                    dialogText = string.format('%s\n  \n Лог действий:\n', dialogText, v)
                    for k, v in pairs(inifiles.log[param[1]].event) do
                        dialogText = string.format('%s%s\n', dialogText, v)
                    end
                    sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 5)
            else
                local dd = {}
                local list = 0
                for k,v in pairs(v) do
                    dd[tonumber(k) + 1] = string.format('%s%02d:00\n', dialogText, tonumber(k) )
                    list = list + 1
                end
                for i = 1, 25 do
                    if dd[i] ~= nil then
                        dialogText = dd[i]..dialogText
                        dialogKeytoList[list] = { param[1], param[2],  string.format('%02d', i - 1) }
                        list = list -1
                    end
                end
                sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 2)
            end
    end
    if int == 4 then
        dialogKeytoList = {}
        dialogText = ''
        local v = inifiles.log[param[1]][param[2]][param[3]]
        dialogKeytoList[1] = { param[1], param[2] }
        dialogText = string.format('{FFFFFF}%02d:00 | %s\n\nПодсчет:\n %d фур на сумму %d вирт\n %d загрузок на сумму %d вирт\n %d разгрузок на сумму %d вирт\n %d заправок на сумму %d вирт\n %d починок на сумму %d вирт\n %d канистр на сумму %d вирт\n %d штрафов на сумму %d вирт\nИтоги:\n Зарплата: %d вирт\n Затраты: %d вирт\n Прибыль: %d вирт',
            tonumber(param[3]), param[1],
            v.arendacount, v.arenda,
            v.zagruzkacount, v.zagruzka,
            v.razgruzkacount, v.razgruzka, 
            v.refillcount, v.refill,
            v.repaircount, v.repair,
            v.kanistrcount, v.kanistr,
            v.shtrafcount, v.shtraf,
            v.zp, (v.arenda + v.refill + v.repair + v.kanistr + v.shtraf), v.pribil)
        sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 5)
    end
    if int == 5 then
        local all = {
            arenda = 0,
            arendacount = 0,
            zagruzka = 0,
            zagruzkacount = 0,
            razgruzka = 0,
            razgruzkacount = 0,
            pribil = 0,
            shtraf = 0,
            shtrafcount = 0,
            repair = 0,
            repaircount = 0,
            refill = 0,
            refillcount = 0,
            reys = 0,
            kanistr = 0,
            kanistrcount = 0,
            zp = 0
        }
        local day = 0
        for k,v in pairs(inifiles.log) do
            day = day + 1
            for i,s in pairs(v.day) do
                all[i] = all[i] + s
            end
        end
        dialogText = string.format('Статистика за %d суток{FFFFFF}\nПодсчет:\n %d фур на сумму %d вирт\n %d загрузок на сумму %d вирт\n %d разгрузок на сумму %d вирт\n %d заправок на сумму %d вирт\n %d починок на сумму %d вирт\n %d канистр на сумму %d вирт\n %d штрафов на сумму %d вирт\nИтоги:\n Зарплата: %d вирт\n Затраты: %d вирт\n Прибыль: %d вирт', day,
                    all.arendacount, all.arenda,
                    all.zagruzkacount, all.zagruzka,
                    all.razgruzkacount, all.razgruzka, 
                    all.refillcount, all.refill,
                    all.repaircount, all.repair,
                    all.kanistrcount, all.kanistr,
                    all.shtrafcount, all.shtraf,
                    all.zp, (all.arenda + all.refill + all.repair + all.kanistr + all.shtraf), all.pribil)
        sampShowDialog(222, 'Truck-HUD: Статистика', dialogText, 'Выбрать', 'Назад', 5)
    end
end

function WhileShowStats(button, list)
    if dialogINT == 1 then
        if button == 1 and dialogKeytoList[list + 1] ~= nil then
            if list == 0 then
                ShowStats(5)
            else
                if dialogKeytoList[list + 1] == 'nil' then
                    ShowStats(1)
                elseif  dialogKeytoList[list + 1] == 'del' then
                    inifiles.log = {}
                    logAvailable()
                    settings_save()
                    ShowStats(1)
                else
                    ShowStats(2, { dialogKeytoList[list + 1] })
                end
            end
        else
            ShowDialog1(1)
        end
        return
    end
    if dialogINT == 2 then
        if button == 1 and dialogKeytoList[list + 1] ~= nil then
            if list == 1 then
                inifiles.log[dialogKeytoList[list + 1]] = nil
                logAvailable()
                settings_save()
                ShowStats(1)
            else
                ShowStats(3, { dialogKeytoList[list + 1], 'day'})
            end
        else
            ShowStats(1)
        end
        return
    end
    if dialogINT == 3 then
        if type(dialogKeytoList[1]) == 'table' then 
            if button == 1 then
                ShowStats(4, { dialogKeytoList[list + 1][1], dialogKeytoList[list + 1][2], dialogKeytoList[list + 1][3] })
            else
                ShowStats(2, { dialogKeytoList[list + 1][1] })
            end
        else
            if button == 1 then
                ShowStats(2, { dialogKeytoList[1] })
            else
                ShowStats(2, { dialogKeytoList[1] })
            end
        end
        return
    end
    if dialogINT == 4 then
        if button == 1 then
            ShowStats(3, dialogKeytoList[1])
        else
            ShowStats(3, dialogKeytoList[1])
        end
        return
    end
    if dialogINT == 5 then
        ShowStats(1)
    end
end

function ShowDialog1(int, dtext, dinput, string_or_number, ini1, ini2)
    d[1], d[2], d[3], d[4], d[5], d[6] = int, dtext, dinput, string_or_number, ini1, ini2
    if int == 1 then
        dialogLine, dialogTextToList, iniName = {}, {}, {}
        dialogLine[#dialogLine + 1] = (script_run and "TruckHUD\t{59fc30}ON" or "TruckHUD\t{ff0000}OFF")

        if script_run then
            dialogLine[#dialogLine + 1] = "Сменить позицию статистики с таймером\t"
            dialogLine[#dialogLine + 1] = "Сменить позицию мониторинга цен\t"
            if inifiles.Settings.Binder then
                dialogLine[#dialogLine + 1] = "Сменить позицию биндера\t"
            end
        end

        dialogLine[#dialogLine + 1] =
            "Редактировать формат статистики\t"

        dialogLine[#dialogLine + 1] =
            "Cruise Control\t" .. (inifiles.Settings.Cruise == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] = "Информация о напарнике на HUD\t" .. (inifiles.Settings.pairinfo == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] = "Биндер\t" .. (inifiles.Settings.Binder == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] = "Авто загрузка/разгрузка\t" .. (auto and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Режим авто загрузки/разгрузки\t" ..
            (inifiles.Settings.AutoOFF == true and "{59fc30}Разовая" or "{59fc30}Постоянная")

        dialogLine[#dialogLine + 1] =
            "Задержка перед авто-загрузкой\t" .. (inifiles.Settings.AutoWait == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Остановка фуры после разгрузки\t" .. (inifiles.Settings.Stop == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Авто Доклады в рацию\t" .. (inifiles.Settings.Report == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Доклады от?\t" .. (inifiles.Settings.girl == true and "{59fc30}Женщины" or "{59fc30}Мужчины")

        dialogLine[#dialogLine + 1] =
            "Авто Отправка мониторинга в чат\t" .. (inifiles.Settings.ChatDoklad and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            (pair_mode and "Режим пары\t{59fc30}" .. pair_mode_name .. "[" .. pair_mode_id .. "]" or
            "Режим пары\t{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Авто Доклады в SMS (режим пары)\t" .. (inifiles.Settings.SMSpara == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Подсветка напарника в чате (режим пары)\t" ..
            (inifiles.Settings.LightingPara == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Выделение Портов/Складов/Цен в докладах\t" ..
            (inifiles.Settings.highlight_jf == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Выделение цены текущего груза в порту\t" ..
            (inifiles.Settings.LightingPrice == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Показывать игроков с /clist 0 на карте\t" ..
            (inifiles.Settings.markers == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Скрывать чат профсоюза\t" .. (inifiles.Settings.ChatOFF == true and "{59fc30}ON" or "{ff0000}OFF")

        if inifiles.Settings.ChatOFF == false then 
            dialogLine[#dialogLine + 1] =
                "Чат профсоюза только в фуре\t" .. (inifiles.Settings.chat_in_truck == true and "{59fc30}ON" or "{ff0000}OFF")
        end

        dialogLine[#dialogLine + 1] =
            "Убрать тюнинг колес с фур\t" .. (inifiles.Settings.Tuning == false and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Синхронизация с другими пользователями\t" ..
            (inifiles.Settings.transponder == true and "{59fc30}ON" or "{ff0000}OFF")

        if inifiles.Settings.transponder then
            dialogLine[#dialogLine + 1] = 
            "Карта с позицией напарника\t"..
            (inifiles.Settings.fastmap == true and "{59fc30}ON" or "{ff0000}OFF")
        end

        dialogLine[#dialogLine + 1] =
            "Цвет подсветки напарника\t{" .. inifiles.Settings.ColorPara .. "}" .. inifiles.Settings.ColorPara -- 6
        dialogTextToList[#dialogLine] =
            "{FFFFFF}Введите новый цвет в HEX\nПодобрать цвет можно через браузер\nЧтобы скопировать ссылку введите /truck url"

        dialogLine[#dialogLine + 1] = "Шрифт\t" .. inifiles.Render.FontName -- 7
        dialogTextToList[#dialogLine] = "{FFFFFF}Введите название шрифта"

        dialogLine[#dialogLine + 1] = "Размер\t" .. inifiles.Render.FontSize -- 8
        dialogTextToList[#dialogLine] = "{FFFFFF}Введите размер шрифта"

        dialogLine[#dialogLine + 1] = "Стиль\t" .. inifiles.Render.FontFlag -- 9
        dialogTextToList[#dialogLine] =
            "{FFFFFF}Устанавливайте стиль путем сложения.\n\nТекст без особенностей = 0\nЖирный текст = 1\nНаклонность(Курсив) = 2\nОбводка текста = 4\nТень текста = 8\nПодчеркнутый текст = 16\nЗачеркнутый текст = 32\n\nСтандарт: 13"

        dialogLine[#dialogLine + 1] = "Цвет первый\t{" .. inifiles.Render.Color1 .. "}" .. inifiles.Render.Color1 -- 10
        dialogTextToList[#dialogLine] =
            "{FFFFFF}Введите новый цвет в HEX\nПодобрать цвет можно через браузер\nЧтобы скопировать ссылку введите /truck url"

        dialogLine[#dialogLine + 1] = "Цвет второй\t{" .. inifiles.Render.Color2 .. "}" .. inifiles.Render.Color2 -- 11
        dialogTextToList[#dialogLine] =
            "{FFFFFF}Введите новый цвет в HEX\nПодобрать цвет можно через браузер\nЧтобы скопировать ссылку введите /truck url"

        dialogLine[#dialogLine + 1] = "Цена авто-загрузки\t" .. inifiles.Price.Load -- 12
        dialogTextToList[#dialogLine] = "{FFFFFF}Введите цену Авто-Загрузки"

        dialogLine[#dialogLine + 1] = "Цена авто-разгрузки\t" .. inifiles.Price.UnLoad -- 13
        dialogTextToList[#dialogLine] = "{FFFFFF}Введите цену Авто-Разгрузки"

        dialogLine[#dialogLine + 1] = "Кнопка отображения меню\t" .. inifiles.Settings.Key1:gsub("VK_", "") -- 14

        dialogLine[#dialogLine + 1] = "Кнопка для работы без фуры\t" .. inifiles.Settings.Key2:gsub("VK_", "") -- 15

        dialogLine[#dialogLine + 1] = "Кнопка для отображения карты\t" .. inifiles.Settings.Key3:gsub("VK_", "") -- 16

        dialogLine[#dialogLine + 1] = "Кнопка для Cruise Control\t" .. inifiles.Settings.Key4:gsub("VK_", "") -- 16

        dialogLine[#dialogLine + 1] = "Локальная блокировка участников"

        dialogLine[#dialogLine + 1] = "Уведомления когда Вас установили напарником\t" .. (inifiles.Settings.NewPairMSG == true and "{59fc30}ON" or "{ff0000}OFF")            

        dialogLine[#dialogLine + 1] = "Авто-Очистка неиспользуемой памяти скрипта\t" .. (inifiles.Settings.AutoClear == true and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] = "Очистить неиспользуемую память скрипта\t" .. string.format('%0.2f MB', (tonumber(gcinfo()) / 1000))

        dialogLine[#dialogLine + 1] = "Подробная статистика"

        dialogLine[#dialogLine + 1] = "Контакты автора"

        dialogLine[#dialogLine + 1] = "Перезагрузка скрипта"
        local text, list = "", 0
        for k, v in pairs(dialogLine) do
            text = text .. "[" .. list .. "] " .. v .. "\n"
            list = list + 1
        end
        sampShowDialog(222, "Truck-HUD: Настройки", text, "Выбрать", "Закрыть", 4)
    end
    if int == 2 then
        d[7] = true
        sampShowDialog(222, "Truck-HUD: Изменение настроек", dtext, "Выбрать", "Назад", 1)
    end
    if int == 3 then
        sampShowDialog(
            222,
            "Truck-HUD: Контакты автора",
            "{FFFFFF}Выбери что скопировать\t\nНик на Samp-Rp\tSerhiy_Rubin\nСтраничка {4c75a3}VK{FFFFFF}\tvk.com/id353828351\nГруппа {4c75a3}VK{FFFFFF} с модами\tvk.com/club161589495\n{10bef2}Skype{FFFFFF}\tserhiyrubin\n{7289da}Discord{FFFFFF}\tSerhiy_Rubin#3391",
            "Копировать",
            "Назад",
            5
        )
    end
    if int == 4 then
        lua_thread.create(
            function()
                wait(100)
                local key = ""
                repeat
                    wait(0)
                    if not sampIsDialogActive() then
                        sampShowDialog(
                            222,
                            "LUA Truck-HUD: Смена активации",
                            "Нажмите на любую клавишу",
                            "Выбрать",
                            "Закрыть",
                            0
                        )
                    end
                    for k, v in pairs(vkeys) do
                        if wasKeyPressed(v) and k ~= "VK_ESCAPE" and k ~= "VK_RETURN" then
                            key = k
                        end
                    end
                until key ~= ""
                local ini__name = string.format("Key%d", dtext)
                inifiles.Settings[ini__name] = key
                settings_save()
                ShowDialog1(1)
            end
        )
    end
    if int == 7 then
        sampShowDialog(
            222,
            "Truck-HUD: Биндер",
            "{FFFFFF}Поддерживает замены\n!НикПары - Заменится ником напарника\n!ИдПары - Заменится на ID напарника\n!КД - Заменится на время до загрузки/разгрузки",
            "Сохранить",
            "Закрыть",
            1
        )
        if dtext == 2 then
            d[7] = true
        end
    end
    if int == 8 then
        sampShowDialog(
            222,
            "Truck-HUD: Режим пары",
            "\t{FFFFFF}Введите ID напарника\nЕму будут отсылаться SMS сообщения о ваших загрузках/разгрузках",
            "Выбрать",
            "Закрыть",
            1
        )
    end
    if int == 9 then
        setClipboardText(inifiles.Settings.stats_text..'\n\n!n! - Для новой строки\n!mn! - Используется для двойного отступа, после !n!\n!skill! - Скилл\n!skill_poc! - Проценты скилла\n!skill_reys! - Остаток рейсов до нового скилла\n!rang! - Ранг\n!rang_poc! - Проценты ранга\n!rang_reys! - Остаток рейсов для нового ранга\n!reys_hour! - Рейсов в этом часу\n!reys_day! - Рейсов за сутки\n!zp_hour! - Зарплата в этом часу\n!all_zp! - Зарплата за сутки\n!profit_hour! - Прибыль в этом часу\n!profit! - Прибыль за сутки')
        sampShowDialog(
            222,
            "Truck-HUD: Редактор HUD",
            [[{ffffff}Замены для составления HUD статистики

{ff0000}ТЕКУЩИЙ ТЕКСТ HUD ПОМЕЩЕН В ВАШ БУФЕР ОБМЕНА 
СВЕРНИТЕ ИГРУ
{ff0000}ОТКРОЙТЕ БЛОКНОТ В WINDOWS И ВСТАВЬТЕ ТУДА ТЕКСТ CTRL + V
{ff0000}ПОСЛЕ ВНЕСЕНИЯ ИЗМЕНЕНИЙ СКОПИРУЙТЕ КОД СТАТИСТИКИ
РАЗВЕРНИТЕ ИГРУ И НАЖМИТЕ CОХРАНИТЬ В ДИАЛОГЕ
{FFFFFF}

ЧТОБЫ ВЕРНУТЬ ВСЕ ПО УМОЛЧАНИЮ СКОПИРУЙТЕ ЦИФРУ 0 И НАЖМИТЕ CОХРАНИТЬ
ЕСЛИ КОПИРУЮТСЯ ИЕРОГЛИФЫ ВМЕСТО РУССКИХ БУКВ - ПОВТОРИТЕ ВСЕ ТОЖЕ САМОЕ С РУССКОЙ РАКЛАДКОЙ

!n! - Для новой строки
!mn! - Используется для двойного отступа, после !n!

!skill! - Скилл
!skill_poc! - Проценты скилла
!skill_reys! - Остаток рейсов до нового скилла

!rang! - Ранг
!rang_poc! - Проценты ранга
!rang_reys! - Остаток рейсов для нового ранга

!reys_hour! - Рейсов в этом часу
!reys_day! - Рейсов за сутки

!zp_hour! - Зарплата в этом часу
!all_zp! - Зарплата за сутки

!zatrat_hour! - Затраты в этом часу
!zatrat_day! - Затраты за сутки

!profit_hour! - Прибыль в этом часу
!profit! - Прибыль за сутки]],
            "Сохранить",
            "Назад",
            0
        )
    end
end

function FindSklad(x, y, z)
    local minDist, minResult = 1000000, ""
    local pos = {
    ["Нефть 1"] = {x = 256.02127075195, y = 1414.8492431641, z = 10.232398033142},
    ["Уголь 1"] = {x = 832.10766601563, y = 864.03668212891, z = 11.643839836121},
    ["Лес 1"] = {x = -448.91455078125, y = -65.951385498047, z = 58.959014892578},
    ["Нефть 2"] = {x = -1046.7521972656, y = -670.66937255859, z = 31.885597229004},
    ["Уголь 2"] = {x = -2913.8544921875, y = -1377.0952148438, z = 10.762256622314},
    ["Лес 2"] = {x = -1978.8649902344, y = -2434.9421386719, z = 30.192840576172},
    ["Порт ЛС"] = {x = 2614.2241210938, y = -2228.8745117188, z = 12.905993461609},
    ["Порт СФ"] = {x = -1733.1876220703, y = 120.08413696289, z = 3.1192970275879}
    }
    for name, cord in pairs(pos) do
        local distance = getDistanceBetweenCoords3d(x, y, z, cord.x, cord.y, cord.z)
        if distance < minDist then
            minDist = distance
            minResult = name
        end
    end
    return { text = minResult, dist = minDist }
end

function sampev.onServerMessage(color, message)
    if message == " У вас бан чата!" then
        delay.chatMon = 0
        delay.chat = 0
    end
    if script_run and string.find(message, " Вы заработали (.+) вирт%. Деньги будут зачислены на ваш банковский счет в .+") then
        local string = string.match(message, " Вы заработали (.+) вирт%. Деньги будут зачислены на ваш банковский счет в .+")
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp = string:find('/') and string:match('(%d+) /') or string
        if delay.paycheck == 2 then
            delay.paycheck = 0
            return false
        end 
    end
    if string.find(message, " .+<.+>: .+") and inifiles ~= nil then
        if string.find(message, my_nick) then
            if string.find(message, "ЛС Н") then
                delay.chatMon = 0
            else
                delay.chat = 0
            end
        end
        if inifiles.Settings.ChatOFF then
            return false
        else
            if inifiles.Settings.chat_in_truck and not isTruckCar() then
                return false
            end
        end
        if script_run then
            if pair_mode and inifiles.Settings.LightingPara and string.find(message, pair_mode_name) then
                paraColor = inifiles.Settings.ColorPara
                color = "0xFF" .. inifiles.Settings.ColorPara
            else
                paraColor = "30A0A7"
                color = "0xFF30A0A7"
            end
            if inifiles.Settings.highlight_jf then
                if message:find("Еду в Порт .+.") then
                    message = message:gsub("Еду в", "Еду в{ffffff}")
                    message = message:gsub("%.", ".{" .. paraColor .. "}")
                    sampAddChatMessage(message, color)
                    return false
                end
                if message:find("Везу .+ в Порт .+.") then
                    message = message:gsub("Везу ", "Везу {ffffff}")
                    message = message:gsub(" в ", "{" .. paraColor .. "} в {ffffff}")
                    message = message:gsub("%.", ".{" .. paraColor .. "}")
                    sampAddChatMessage(message, color)
                    return false
                end
                if message:find("Еду на .+..") then
                    message = message:gsub("Еду на", "Еду на{ffffff}")
                    message = message:gsub("%.", ".{" .. paraColor .. "}")
                    sampAddChatMessage(message, color)
                    return false
                end
                if message:find("Разгру.+ .+ по %d+") then
                    message = message:gsub("Нефть", "{ffffff}Нефть")
                    message = message:gsub("Уголь", "{ffffff}Уголь")
                    message = message:gsub("Дерево", "{ffffff}Дерево")
                    message = message:gsub("Рубины", "{ffffff}Рубины")
                    message = message:gsub(" по ", "{" .. paraColor .. "} по {ffffff}")
                    sampAddChatMessage(message, color)
                    return false
                end
                if message:find("Загрузи.+ на .+ по %d+") then
                    message = message:gsub(" на ", " на {ffffff}")
                    message = message:gsub(" по ", "{" .. paraColor .. "} по {ffffff}")
                    sampAddChatMessage(message, color)
                    return false
                end
            end
            if pair_mode and inifiles.Settings.LightingPara and string.find(message, pair_mode_name) then
                paraColor = inifiles.Settings.ColorPara
                color = "0xFF" .. inifiles.Settings.ColorPara
                sampAddChatMessage(message, color)
                return false
            end
        end
    end
    if
        string.find(
            message,
            " (.*)<(.*)>: %[ЛС Н:(%d+) У:(%d+) Л:(%d+)%] %[1 Н:(%d+) У:(%d+) Л:(%d+)%] %[2 Н:(%d+) У:(%d+) Л:(%d+)%] %[CФ Н:(%d+) У:(%d+) Л:(%d+)%]"
        )
     then
        if (string.find(message, "Купил") or string.find(message, "Продал")) then
            nick,
                rank,
                prices_smon.lsn,
                prices_smon.lsy,
                prices_smon.lsl,
                prices_smon.n1,
                prices_smon.y1,
                prices_smon.l1,
                prices_smon.n2,
                prices_smon.y2,
                prices_smon.l2,
                prices_smon.sfn,
                prices_smon.sfy,
                prices_smon.sfl,
                _ =
                string.match(
                message,
                " (.*)%[.+%]<(.*)>: %[ЛС Н:(%d+) У:(%d+) Л:(%d+)%] %[1 Н:(%d+) У:(%d+) Л:(%d+)%] %[2 Н:(%d+) У:(%d+) Л:(%d+)%] %[CФ Н:(%d+) У:(%d+) Л:(%d+)%] %[(.*)%]"
            )
        else
            nick,
                rank,
                prices_smon.lsn,
                prices_smon.lsy,
                prices_smon.lsl,
                prices_smon.n1,
                prices_smon.y1,
                prices_smon.l1,
                prices_smon.n2,
                prices_smon.y2,
                prices_smon.l2,
                prices_smon.sfn,
                prices_smon.sfy,
                prices_smon.sfl =
                string.match(
                message,
                " (.*)%[.+%]<(.*)>: %[ЛС Н:(%d+) У:(%d+) Л:(%d+)%] %[1 Н:(%d+) У:(%d+) Л:(%d+)%] %[2 Н:(%d+) У:(%d+) Л:(%d+)%] %[CФ Н:(%d+) У:(%d+) Л:(%d+)%]"
            )
        end
        chat_mon[nick] = prices_smon
        chat_mon[nick].time = msk_timestamp
        if inifiles.blacklist[nick] == nil then
            inifiles.blacklist[nick] = false
        end
        if (not inifiles.Settings.blacklist_inversion and inifiles.blacklist[nick] == false) or (inifiles.Settings.blacklist_inversion and inifiles.blacklist[nick] == true) then
            mon_life = msk_timestamp
            mon_ctime = msk_timestamp
            prices_mon.lsn = prices_smon.lsn * 100
            prices_mon.lsy = prices_smon.lsy * 100
            prices_mon.lsl = prices_smon.lsl * 100
            prices_mon.sfn = prices_smon.sfn * 100
            prices_mon.sfy = prices_smon.sfy * 100
            prices_mon.sfl = prices_smon.sfl * 100
            prices_mon.n1 = prices_smon.n1 * 100
            prices_mon.n2 = prices_smon.n2 * 100
            prices_mon.y1 = prices_smon.y1 * 100
            prices_mon.y2 = prices_smon.y2 * 100
            prices_mon.l1 = prices_smon.l1 * 100
            prices_mon.l2 = prices_smon.l2 * 100
        end
    end

    if string.find(message, " Нефть: (%d+) / (%d+)") then
        if current_load ~= 0 then
            check_noLoad = true
        end
        local S1, S2 = string.match(message, " Нефть: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 1
            check_noLoad = false
        end
    end
    if string.find(message, " Уголь: (%d+) / (%d+)") then
        local S1, S2 = string.match(message, " Уголь: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 2
            check_noLoad = false
        end
    end
    if string.find(message, " Дерево: (%d+) / (%d+)") then
        local S1, S2 = string.match(message, " Дерево: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 3
            check_noLoad = false
        end
        if check_noLoad and current_load ~= 0 then
            current_load = 0
        end
    end
    if string.find(message, " Извините, мы вас немного задержим, нужно подготовить груз. Осталось (%d+) секунд") then
        local S1 =
            string.match(message, " Извините, мы вас немного задержим, нужно подготовить груз. Осталось (%d+) секунд")
        if tonumber(S1) > 3 then
            delay.load = 0
            delay.unload = 0
        end
    end

    if
        message == " У вас недостаточно денег" or message == " Нужно находиться у склада" or
            message == " Нужно находиться в порту" or
            message == " У вас нет продуктов" or
            message == " Вы прибыли без прицепа"
     then
        delay.load = 0
        delay.unload = 0
        if auto then
            autoh = false
        end
    end -- /truck load unload error

    if
        message == " Вы не в служебной машине. Нужно быть водителем" or
            message == " Вы должны находиться в порту, или на складе" or
            message == " Вы должны устроиться на работу дальнобойщика"
     then
        delay.mon, delay.chatMon = 0, 0
        delay.load = 0
        delay.unload = 0
    end

    if message == " Вам не доступен этот чат!" or message == " Введите: /r или /f [text]" then
        delay.chat = 0
        delay.chatMon = 0
    end -- /jf chat error

    if string.find(message, "===============%[(%d+):(%d+)%]===============") then
        payday = msk_timestamp
        write_table_log('payday', {0}, 9)
        settings_save()
    end -- Log update

    if
        message == " Сообщение доставлено" or message == " Игрок оффлайн" or
            message == " Введите: /sms [playerid / phonenumber] [текст]" or
            message == " Телефон вне зоны доступа сети"
     then
        delay.sms = 0
    end

    if string.find(message, "Загружено %d+ груза, на сумму (%d+) вирт. Скидка: %d+ вирт") and isTruckCar() then
        timer = msk_timestamp
        local Z1, Z2, Z3 = string.match(message, " Загружено (%d+) груза, на сумму (%d+) вирт. Скидка: (%d+) вирт")
        gruzLOAD = Z1
        if texts_of_reports[current_warehouse] ~= nil then
            local cena = (Z2 + Z3) / (Z1 / 1000)
            local sklad = texts_of_reports[current_warehouse]
            local modelId = getCharModel(PLAYER_PED)
            report_text =
                (not inifiles.Settings.girl and "Загрузился" or "Загрузилась") .. " на " .. sklad .. " по " .. cena
            sms_pair_mode = report_text
            if inifiles.Settings.Report then
                delay.chat = 1
            end
            if pair_mode and inifiles.Settings.SMSpara then
                delay.sms = 1
            end
        end
        write_table_log('zagruzka', {Z2}, 1)
        delay.load = 0
        if script_run then
            if inifiles.Settings.ChatDoklad then
                delay.chatMon = -1
            end
            delay.mon = 1
        end
        workload = 1
        autoh = true
        if inifiles.Settings.AutoOFF then
            auto = false
        end
    end

    if string.find(message, "Вы заработали (%d+) вирт, из которых (%d+) вирт будет добавлено к вашей зарплате") and isTruckCar() then
        timer = msk_timestamp
        local Z1, Z2 =
            string.match(message, " Вы заработали (%d+) вирт, из которых (%d+) вирт будет добавлено к вашей зарплате")
        if texts_of_reports[current_warehouse] ~= nil and gruzLOAD ~= nil then
            local cena = Z1 / (gruzLOAD / 1000)
            local sklad = texts_of_reports[current_warehouse]
            local modelId = getCharModel(PLAYER_PED)
            report_text = "Разгрузил" .. (not inifiles.Settings.girl and " " or "а ") .. sklad .. " по " .. cena
            sms_pair_mode = report_text
            if inifiles.Settings.Report then
                delay.chat = 1
            end
            if pair_mode and inifiles.Settings.SMSpara then
                delay.sms = 1
            end
        end
        if inifiles.Trucker.MaxZP > tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp + Z2) then
            write_table_log('razgruzka', {Z1, Z2, (Z1 - Z2)}, 2)
        else
            if tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp) ~= inifiles.Trucker.MaxZP then
                local param4 = ((tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp) + Z2) - 
                    inifiles.Trucker.MaxZP - Z2)
                local param5 = string.match(param4, "-(.*)")
                write_table_log('razgruzka', {param5, param5, 0}, 2)
            end 
        end
        delay.unload = 0
        if script_run then
            if inifiles.Settings.ChatDoklad then
                delay.chatMon = -1
            end
            delay.mon = 1
            delay.skill = 1
        end
        workload = 0
        current_load = 0
        autoh = true
        if inifiles.Settings.AutoOFF then
            auto = false
        end
        delay.paycheck = 1
    end
    if message == " Не флуди!" then
        if delay.skill == 2 then
            delay.skill = 1
        end
        if delay.load == 2 then
            delay.load = 1
        end
        if delay.unload == 2 then
            delay.unload = 1
        end
        if delay.sms == 2 then
            delay.sms = 1
        end
        if delay.chat == 2 then
            delay.chat = 1
        end
        if delay.chatMon == 2 then
            delay.chatMon = 1
        end
        if delay.dir == 2 then
            delay.dir = 1
        end
    end
    if message == " У вас нет телефонного справочника!" then
        delay.dir = 0
    end
    if string.find(message, " Вы арендовали транспортное средство") and isTruckCar() then
        local message = sampGetDialogText()
        if string.find(message, "Стоимость") then
            local Z1 = string.match(message, "Стоимость аренды: {FFFF00}(%d+) вирт")
            write_table_log('arenda', {Z1}, 3)
        end
    end
    if string.find(message, " Вы заплатили штраф (%d+) вирт, Офицеру (%g+)") then
        local Z1, Z2 = string.match(message, " Вы заплатили штраф (%d+) вирт, Офицеру (%g+)")
        write_table_log('shtraf', {Z1, message}, 4)
    end
    if string.find(message, " Вашу машину отремонтировал%(а%) за (%d+) вирт, Механик (%g+)") and isTruckCar() then
        local Z1, Z2 = string.match(message, " Вашу машину отремонтировал%(а%) за (%d+) вирт, Механик (%g+)")
        write_table_log('repair', {Z1}, 5)
    end
    if string.find(message, " Автомеханик (%g+) заправил ваш автомобиль на 300 за (%d+) вирт") and isTruckCar() then
        local Z1, Z2 = string.match(message, " Автомеханик (%g+) заправил ваш автомобиль на 300 за (%d+) вирт")
        write_table_log('refill', {Z2}, 6)
    end
    if string.find(message, " Машина заправлена, за: (%d+) вирт") and isTruckCar() then
        local Z1 = string.match(message, " Машина заправлена, за: (%d+) вирт")
        write_table_log('refill', {Z1}, 7)
    end
    if string.find(message, " Вы купили канистру с 50 литрами бензина за (%d+) вирт") and isTruckCar() then
        local Z1 = string.match(message, " Вы купили канистру с 50 литрами бензина за (%d+) вирт")
        write_table_log('kanistr', {Z1}, 8)
    end
end

function sampev.onShowDialog(DdialogId, Dstyle, Dtitle, Dbutton1, Dbutton2, Dtext)
    if Dstyle == 0 and string.find(Dtext, "{00AB06}Дальнобойщик{CECECE}") and string.find(Dtext, "{00AB06}Механик{CECECE}") then
        local Skill, SkillP, Rank, RankP = string.match( Dtext, ".+{00AB06}Дальнобойщик{CECECE}.*Скилл: (%d+)\tОпыт: .+ (%d+%.%d+)%%.*{CECECE}Ранг: (%d+)  \tОпыт: .+ (%d+%.%d+)%%")
        if SkillP ~= nil then
            SkillP = tonumber(SkillP)
            RankP = tonumber(RankP)
            if inifiles.Trucker.ProcSkill ~= SkillP then
                Skill = tonumber(Skill)
                local gruzs =
                    (Skill < 10 and 10000 or
                    (Skill < 20 and 20000 or (Skill < 30 and 30000 or (Skill < 40 and 40000 or (Skill >= 40 and 50000)))))
                local S1 = gruzs / 100 * (1.1 ^ (50 - inifiles.Trucker.Skill))
                local S2 = 10000 * (1.1 ^ inifiles.Trucker.Skill)
                local S3 = (S1 * 100) / S2
                inifiles.Trucker.ReysSkill = math.ceil((100.0 - inifiles.Trucker.ProcSkill) / S3)
                inifiles.Trucker.ProcSkill = SkillP
            end
            if inifiles.Trucker.ProcRank ~= RankP then
                inifiles.Trucker.ReysRank = math.ceil((100.0 - RankP) / (RankP - inifiles.Trucker.ProcRank))
                inifiles.Trucker.ProcRank = RankP
            end
            inifiles.Trucker.Skill = Skill
            inifiles.Trucker.Rank = Rank
            inifiles.Trucker.MaxZP = math.ceil( 50000 + (2500 * (1.1 ^ Skill)) + (2500 * (1.1 ^ Rank)) )
            settings_save()
        end
        if delay.skill ~= 0 then
            delay.skill = 0
            return false
        end
    end

    if DdialogId == 22 and Dstyle == 0 and string.find(Dtext, "Заводы") then
        delay.mon = 0
        mon_life = msk_timestamp
        mon_time = msk_timestamp
        prices_mon.n1, prices_mon.n2, prices_mon.y1, prices_mon.y2, prices_mon.l1, prices_mon.l2, prices_mon.lsn, prices_mon.lsy, prices_mon.lsl, prices_mon.sfn, prices_mon.sfy, prices_mon.sfl = string.match( Dtext, "[Заводы].*Нефтезавод №1.*.*Нефть: 0.(%d+) вирт.*Нефтезавод №2.*.*Нефть: 0.(%d+) вирт.*Склад угля №1.*.*Уголь: 0.(%d+) вирт.*Склад угля №2.*.*Уголь: 0.(%d+) вирт.*Лесопилка №1.*.*Дерево: 0.(%d+) вирт.*Лесопилка №2.*.*Дерево: 0.(%d+) вирт.*[Порты].*Порт ЛС.*.*Нефть: 0.(%d+) вирт.*.*Уголь: 0.(%d+) вирт.*.*Дерево: 0.(%d+) вирт.*Порт СФ.*.*Нефть: 0.(%d+) вирт.*.*Уголь: 0.(%d+) вирт.*.*Дерево: 0.(%d+) вирт" )

        for k, v in pairs(prices_mon) do
            if string.find(tostring(prices_mon[k]), "99") then
                prices_mon[k] = tonumber(prices_mon[k]) + 1
            end
        end

        inifiles.tmonitor = {
            n1 = prices_mon.n1,
            n2 = prices_mon.n2,
            y1 = prices_mon.y1,
            y2 = prices_mon.y2,
            l1 = prices_mon.l1,
            l2 = prices_mon.l2,
            lsn = prices_mon.lsn,
            lsy = prices_mon.lsy,
            lsl = prices_mon.lsl,
            sfn = prices_mon.sfn,
            sfy = prices_mon.sfy,
            sfl = prices_mon.sfl,
            time = msk_timestamp
        }
        settings_save()

        if delay.chatMon == -1 then
            SendMonText =
                string.format(
                "[ЛС Н:%d У:%d Л:%d] [1 Н:%d У:%d Л:%d] [2 Н:%d У:%d Л:%d] [CФ Н:%d У:%d Л:%d]",
                (prices_mon.lsn / 100),
                (prices_mon.lsy / 100),
                (prices_mon.lsl / 100),
                (prices_mon.n1 / 100),
                (prices_mon.y1 / 100),
                (prices_mon.l1 / 100),
                (prices_mon.n2 / 100),
                (prices_mon.y2 / 100),
                (prices_mon.l2 / 100),
                (prices_mon.sfn / 100),
                (prices_mon.sfy / 100),
                (prices_mon.sfl / 100)
            )
            delay.chatMon = 1
        end
        if script_run then
            transponder_delay = 100
            return false
        end
    end

    if delay.dir ~= 0 then
        if string.find(Dtitle, "Тел.справочник") and delay.dir == 2 then
            sampSendDialogResponse(DdialogId, 1, 1, "")
            delay.dir = 3
            return false
        end

        if string.find(Dtitle, "Работы") and delay.dir == 3 then
            lua_thread.create(
                function()
                    repeat
                        wait(0)
                    until delay.dir == 4
                    wait(150)
                    sampSendDialogResponse(DdialogId, 1, 9, "[9] Дальнобойщик")
                end
            )
            delay.dir = 4
            return false
        end

        if string.find(Dtitle, "Меню") and string.find(Dtext, "AFK секунд") and delay.dir == 4 then
            delay.dir = 0
            sampShowDialog(222, Dtitle, Dtext, Dbutton1, Dbutton2, Dstyle)
            return false
        end
    end
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text) -- f3d1
    lua_thread.create(
        function(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, textt)
            for k, v in pairs(find_3dText) do
                if string.find(text, v) then
                    if (msk_timestamp - id_3D_text) > 1 then
                        wait_auto = msk_timestamp
                    end
                    id_3D_text = id
                    if text:find("Порт") then
                        unload_location = true
                        prices_3dtext[k .. "n"], prices_3dtext[k .. "y"], prices_3dtext[k .. "l"] =
                            string.match(text, v)
                        for k, v in pairs(prices_3dtext) do
                            if string.find(tostring(prices_3dtext[k]), "99") then
                                prices_3dtext[k] = tonumber(prices_3dtext[k]) + 1
                            end
                        end
                        local port = (text:find("ЛС") and "ЛС" or "СФ")
                        local ctext =
                            string.format(
                            "Порт %s\nНефть: 0.%s\nУголь: 0.%s\nДерево: 0.%s ",
                            port,
                            prices_3dtext[k .. "n"],
                            prices_3dtext[k .. "y"],
                            prices_3dtext[k .. "l"]
                        )
                        current_warehouse =
                            (current_load == 1 and k .. "n" or
                            (current_load == 2 and k .. "y" or (current_load == 3 and k .. "l" or "")))
                        repeat
                            wait(0)
                        until sampIs3dTextDefined(id)
                        if inifiles.Settings.LightingPrice then
                            if current_load == 1 then
                                ctext = ctext:gsub("Нефть:", "{FFFFFF}Нефть:")
                                ctext = ctext:gsub("Уголь:", "{FFFF00}Уголь:")
                            elseif current_load == 2 then
                                ctext = ctext:gsub("Уголь:", "{FFFFFF}Уголь:")
                                ctext = ctext:gsub("Дерево:", "{FFFF00}Дерево:")
                            elseif current_load == 3 then
                                ctext = ctext:gsub("Дерево:", "{FFFFFF}Дерево:")
                            end
                        end
                        sampCreate3dTextEx(
                            id,
                            ctext,
                            0xFFFFFF00,
                            position.x,
                            position.y,
                            position.z,
                            distance,
                            testLOS,
                            attachedPlayerId,
                            attachedVehicleId
                        )
                    else
                        prices_3dtext[k] = string.match(text, v)
                        load_location = true
                        current_warehouse = k
                    end
                end
            end
        end,
        id,
        color,
        position,
        distance,
        testLOS,
        attachedPlayerId,
        attachedVehicleId,
        text
    )
end

function sampev.onRemove3DTextLabel(Cid) -- f3d2
    if id_3D_text == Cid then
        id_3D_text = msk_timestamp
        load_location = false
        unload_location = false
        current_warehouse = "none"
    end
end

function write_table_log(key, param, Log)
    if Log >= 3 and Log ~= 9 then
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] - tonumber(param[1])
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] - tonumber(param[1])

        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] + tonumber(param[1])
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] + tonumber(param[1])
    end
    if inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key..'count'] ~= nil then
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key..'count'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key..'count'] + 1
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key..'count'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key..'count'] + 1
    end

    if key == 'zagruzka' then
        inifiles.Settings.DataLoad = os.date("%d.%m.%Y", msk_timestamp)
        inifiles.Settings.HourLoad = os.date("%H", msk_timestamp)
        if inifiles.Trucker.MaxZP > tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp) then
            inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] - tonumber(param[1])
            inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] - tonumber(param[1])

            inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] + tonumber(param[1])
            inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] + tonumber(param[1])
        end
    end

    if key == 'razgruzka' then
        if inifiles.Trucker.MaxZP > tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp)then 
            if inifiles.Settings.HourLoad ~= os.date("%H", msk_timestamp) or inifiles.Settings.DataLoad ~= os.date("%d.%m.%Y", msk_timestamp)  then
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['zp'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['zp'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['zp'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['zp'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] + tonumber(param[1])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] + tonumber(param[1])
            else
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['zp'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['zp'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['zp'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['zp'] + tonumber(param[2])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)]['pribil'] + tonumber(param[1])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day['pribil'] + tonumber(param[1])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)][key] + tonumber(param[1])
                inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] = inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].day[key] + tonumber(param[1])
            end
            inifiles.Settings.HourLoad = os.date("%H", msk_timestamp)
            inifiles.Settings.DataLoad = os.date("%d.%m.%Y", msk_timestamp)
        end
    end

    local text_to_log = {
        [1] = { string.format('Загрузка за %s$ %s', param[1], (inifiles.Trucker.MaxZP < tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp) and ' [Достигнут лимит зарплаты]' or '') )},
        [2] = { string.format('Разгрузка за %s$ | Заработано %s$ %s', param[1], param[2], (inifiles.Trucker.MaxZP < tonumber(inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)].zp) and ' [Достигнут лимит зарплаты]' or '')) },
        [3] = { string.format('Аренда фуры за %s$', param[1]) },
        [4] = { string.format('Штраф %s$ офицеру %s', param[1], param[2]) },
        [5] = { string.format('Починка фуры за %s$', param[1]) },
        [6] = { string.format('Заправка фуры за %s$', param[1]) },
        [7] = { string.format('Заправка фуры за %s$', param[1]) },
        [8] = { string.format('Покупка канистры за %s$', param[1]) },
        [9] = { string.format('PayDay') }
    }
    for k, v in pairs(text_to_log[Log]) do
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].event[#inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].event + 1] = os.date("%X", msk_timestamp).." | "..v
    end
    settings_save()
end

function logAvailable()
    if msk_timestamp == 0 then return end
    if inifiles.log == nil then
        inifiles.log = {}
        settings_save()
    end
    if inifiles.log[os.date("%d.%m.%Y", msk_timestamp)] == nil then
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)] = { 
            event = {}, 
            hour = {},
            day = {
                arenda = 0,
                arendacount = 0,
                zagruzka = 0,
                zagruzkacount = 0,
                razgruzka = 0,
                razgruzkacount = 0,
                pribil = 0,
                shtraf = 0,
                shtrafcount = 0,
                repair = 0,
                repaircount = 0,
                refill = 0,
                refillcount = 0,
                kanistr = 0,
                kanistrcount = 0,
                zp = 0
            }
        }
        settings_save()
    end
    if inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)] == nil then
        inifiles.log[os.date("%d.%m.%Y", msk_timestamp)].hour[os.date("%H", msk_timestamp)] = {
            arenda = 0,
            arendacount = 0,
            zagruzka = 0,
            zagruzkacount = 0,
            razgruzka = 0,
            razgruzkacount = 0,
            pribil = 0,
            shtraf = 0,
            shtrafcount = 0,
            repair = 0,
            repaircount = 0,
            refill = 0,
            refillcount = 0,
            kanistr = 0,
            kanistrcount = 0,
            zp = 0
        }
        settings_save()
    end
end

function isTruckCar()
    if isCharInModel(PLAYER_PED, 403) or isCharInModel(PLAYER_PED, 514) or isCharInModel(PLAYER_PED, 515) then --463 ubrat or isCharInModel(PLAYER_PED, 463)
        if getDriverOfCar(getCarCharIsUsing(playerPed)) == playerPed then
            return true
        else
            return false
        end
    else
        return false
    end
end

function sampev.onSendChat(message)
    antiflood = os.clock() * 1000
end
function sampev.onSendCommand(cmd)
    local command, params = string.match(cmd, "^%/([^ ]*)(.*)")
    if command ~= nil and params ~= nil and command:lower() == "truck" then
        if params == ' test' then
            write_table_log('arenda', {'10000'}, 3)
        end
        if params:lower() == " ad" then
            inifiles.Settings.ad = not inifiles.Settings.ad
            settings_save()
            sampAddChatMessage(
                string.format(
                    "Уведомления об обновлениях Truck HUD %s",
                    (inifiles.Settings.ad and "включены" or "выключены")
                ),
                0xFF2f72f7
            )
            return false
        end
        if params:lower() == " up" then
            lua_thread.create(
                function()
                    local fpath = os.getenv("TEMP") .. "\\TruckHUD-up.txt"
                    download_id_3 = downloadUrlToFile(
                        "https://raw.githubusercontent.com/Serhiy-Rubin/TruckHUD/master/changelog",
                        fpath,
                        function(id, status, p1, p2)
                            if stop_downloading_3 then
                                stop_downloading_3 = false
                                download_id_3 = nil
                                return false
                            end
                            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                                local f = io.open(fpath, "r")
                                if f then
                                    local text = f:read("*a")
                                    if text ~= nil then
                                        sampShowDialog(222, "Обновления TruckHUD", "{FFFFFF}" .. Utf8ToAnsi(text), "Закрыть", "", 0)
                                    end
                                    io.close(f)
                                    os.remove(fpath)
                                end
                            end
                        end
                    )
                end
            )
            return false
        end
        if params:lower() == " menu" then
            ShowDialog1(1)
            return false
        end
        if params:lower() == " cmd" then
            local text =
                " /truck hud\tВкл/Выкл скрипт\n /truck auto\tВкл/Выкл Auto-Load/Unload\n /truck chat\tВкл/Выкл доклады в рацию\n /truck para\tВкл/Выкл режим пары\n /truck menu\tМеню настроек скрипта\n /truck play\tДополнительное меню управления скриптом\n /truck mon [ID]\tОтправить мониторинг другому игроку в СМС"
            sampShowDialog(222, "Команды скрипта TruckHUD", text, "Закрыть", "", 4)
            return false
        end
        if params:lower() == " hud" then
            script_run = not script_run
            return false
        end
        if params:lower() == " auto" then
            auto = not auto
            return false
        end
        if params:lower() == " chat" then
            inifiles.Settings.Report = not inifiles.Settings.Report
            sampAddChatMessage(
                string.format("Авто Доклад в рацию %s", (inifiles.Settings.Report and "активирован" or "деактивирован")),
                0xFF2f72f7
            )
            settings_save()
            return false
        end
        if params:lower() == " para" then
            if pair_mode then
                pair_mode = false
            else
                ShowDialog1(8)
            end
            return false
        end
        if params:lower() == " url" then
            setClipboardText("https://colorscheme.ru/color-converter.html")
            return false
        end
        if params:lower():find(" mon (%d+)") then
            local id = params:lower():match(" mon (%d+)")
            return {
                string.format(
                    "/sms %s [ЛС H:%d У:%d Л:%d][1 H:%d У:%d Л:%d][2 H:%d У:%d Л:%d][CФ H:%d У:%d Л:%d]",
                    id,
                    (prices_mon.lsn / 100),
                    (prices_mon.lsy / 100),
                    (prices_mon.lsl / 100),
                    (prices_mon.n1 / 100),
                    (prices_mon.y1 / 100),
                    (prices_mon.l1 / 100),
                    (prices_mon.n2 / 100),
                    (prices_mon.y2 / 100),
                    (prices_mon.l2 / 100),
                    (prices_mon.sfn / 100),
                    (prices_mon.sfy / 100),
                    (prices_mon.sfl / 100)
                )
            }
        end
    end
    if params:lower():find(" server_help") then
        sampShowDialog(0, 'TruckHUD: Server Help', [[{FFFFFF}   << Основные причины проблем соединения с сервером >>

1. Сервер отключился. Поспрашивайте других дальнобойщиков нет ли у них такой проблемы
Если у всех такая проблема - значит сервер упал. Сообщите в группу разработчику.

2. У скрипта нет доступа в интернет. Установлен антистиллер.]], 'Закрыть', '', 0)
        return false
    end
    antiflood = os.clock() * 1000
end
function sampev.onVehicleStreamIn(vehicleId, data)
    if inifiles ~= nil and not inifiles.Settings.Tuning and (data.type == 403 or data.type == 515) then
        data.modSlots[8] = 0
        return {vehicleId, data}
    end
end

function GetGruz()
    local gruz = 0
    if isCharInModel(PLAYER_PED, 514) then
        local Vehicle = storeCarCharIsInNoSave(PLAYER_PED)
        local Color1, Color2 = getCarColours(Vehicle)
        gruz = 10000
    end
    if isCharInModel(PLAYER_PED, 403) then
        local Vehicle = storeCarCharIsInNoSave(PLAYER_PED)
        local Color1, Color2 = getCarColours(Vehicle)
        if Color1 == 36 and Color2 == 36 then
            gruz = 30000
        else
            gruz = 20000
        end
    end
    if isCharInModel(PLAYER_PED, 515) then
        local Vehicle = storeCarCharIsInNoSave(PLAYER_PED)
        local Color1, Color2 = getCarColours(Vehicle)
        if Color1 == 34 and Color2 == 36 then
            gruz = 50000
        else
            gruz = 40000
        end
    end
    return gruz
end

function ChangeCena(st)
    if st > 0 then
        if workload == 1 then
            if inifiles.Price.UnLoad >= 0 and inifiles.Price.UnLoad < 900 then
                inifiles.Price.UnLoad = inifiles.Price.UnLoad + 100
                settings_save()
            end
        else
            if inifiles.Price.Load >= 0 and inifiles.Price.Load < 900 then
                inifiles.Price.Load = inifiles.Price.Load + 100
                settings_save()
            end
        end
    else
        if workload == 1 then
            if inifiles.Price.UnLoad > 0 and inifiles.Price.UnLoad <= 900 then
                inifiles.Price.UnLoad = inifiles.Price.UnLoad - 100
                settings_save()
            end
        else
            if inifiles.Price.Load > 0 and inifiles.Price.Load <= 900 then
                inifiles.Price.Load = inifiles.Price.Load - 100
                settings_save()
            end
        end
    end
end

function Utf8ToAnsi(s)
    local nmdc = {
        [36] = "$",
        [124] = "|"
    }
    local utf8_decode = {
        [128] = {
            [147] = "\150",
            [148] = "\151",
            [152] = "\145",
            [153] = "\146",
            [154] = "\130",
            [156] = "\147",
            [157] = "\148",
            [158] = "\132",
            [160] = "\134",
            [161] = "\135",
            [162] = "\149",
            [166] = "\133",
            [176] = "\137",
            [185] = "\139",
            [186] = "\155"
        },
        [130] = {[172] = "\136"},
        [132] = {[150] = "\185", [162] = "\153"},
        [194] = {
            [152] = "\152",
            [160] = "\160",
            [164] = "\164",
            [166] = "\166",
            [167] = "\167",
            [169] = "\169",
            [171] = "\171",
            [172] = "\172",
            [173] = "\173",
            [174] = "\174",
            [176] = "\176",
            [177] = "\177",
            [181] = "\181",
            [182] = "\182",
            [183] = "\183",
            [187] = "\187"
        },
        [208] = {
            [129] = "\168",
            [130] = "\128",
            [131] = "\129",
            [132] = "\170",
            [133] = "\189",
            [134] = "\178",
            [135] = "\175",
            [136] = "\163",
            [137] = "\138",
            [138] = "\140",
            [139] = "\142",
            [140] = "\141",
            [143] = "\143",
            [144] = "\192",
            [145] = "\193",
            [146] = "\194",
            [147] = "\195",
            [148] = "\196",
            [149] = "\197",
            [150] = "\198",
            [151] = "\199",
            [152] = "\200",
            [153] = "\201",
            [154] = "\202",
            [155] = "\203",
            [156] = "\204",
            [157] = "\205",
            [158] = "\206",
            [159] = "\207",
            [160] = "\208",
            [161] = "\209",
            [162] = "\210",
            [163] = "\211",
            [164] = "\212",
            [165] = "\213",
            [166] = "\214",
            [167] = "\215",
            [168] = "\216",
            [169] = "\217",
            [170] = "\218",
            [171] = "\219",
            [172] = "\220",
            [173] = "\221",
            [174] = "\222",
            [175] = "\223",
            [176] = "\224",
            [177] = "\225",
            [178] = "\226",
            [179] = "\227",
            [180] = "\228",
            [181] = "\229",
            [182] = "\230",
            [183] = "\231",
            [184] = "\232",
            [185] = "\233",
            [186] = "\234",
            [187] = "\235",
            [188] = "\236",
            [189] = "\237",
            [190] = "\238",
            [191] = "\239"
        },
        [209] = {
            [128] = "\240",
            [129] = "\241",
            [130] = "\242",
            [131] = "\243",
            [132] = "\244",
            [133] = "\245",
            [134] = "\246",
            [135] = "\247",
            [136] = "\248",
            [137] = "\249",
            [138] = "\250",
            [139] = "\251",
            [140] = "\252",
            [141] = "\253",
            [142] = "\254",
            [143] = "\255",
            [144] = "\161",
            [145] = "\184",
            [146] = "\144",
            [147] = "\131",
            [148] = "\186",
            [149] = "\190",
            [150] = "\179",
            [151] = "\191",
            [152] = "\188",
            [153] = "\154",
            [154] = "\156",
            [155] = "\158",
            [156] = "\157",
            [158] = "\162",
            [159] = "\159"
        },
        [210] = {[144] = "\165", [145] = "\180"}
    }
    local a, j, r, b = 0, 0, ""
    for i = 1, s and s:len() or 0 do
        b = s:byte(i)
        if b < 128 then
            if nmdc[b] then
                r = r .. nmdc[b]
            else
                r = r .. string.char(b)
            end
        elseif a == 2 then
            a, j = a - 1, b
        elseif a == 1 then
            a, r = a - 1, r .. utf8_decode[j][b]
        elseif b == 226 then
            a = 2
        elseif b == 194 or b == 208 or b == 209 or b == 210 then
            j, a = b, 1
        else
            r = r .. "_"
        end
    end
    return r
end

function drawClickableText(text, posX, posY)
    if text ~= nil and posX ~= nil and posY ~= nil then
        renderFontDrawText(font, text, posX, posY, "0xFF" .. inifiles.Render.Color1)
        local textLenght = renderGetFontDrawTextLength(font, text)
        local textHeight = renderGetFontDrawHeight(font)
        local curX, curY = getCursorPos()
        if curX >= posX and curX <= posX + textLenght and curY >= posY and curY <= posY + textHeight then
            if control or sampIsChatInputActive() then
                renderFontDrawText(font, text, posX, posY, "0x70" .. inifiles.Render.Color2)
                if isKeyJustPressed(1) then
                    return true
                else
                    return false
                end
            end
        end
    else
        return false
    end
end

--------------------------------------------------------------------------------
--------------------------------------GMAP--------------------------------------
--------------------------------------------------------------------------------
delay_start = 0
function transponder()
    new_pair = {}
    error_array = {}
    while true do
        wait(0)
        if script_run and inifiles.Settings.transponder then
            delay_start = os.clock()
            repeat
                wait(0)
            until os.clock() * 1000 - (delay_start * 1000) > transponder_delay
            if inifiles.Settings.transponder then
                local request_table = {}
                request_table["request"] = 1
                local ip, port = sampGetCurrentServerAddress()
                local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                local x, y, z = getCharCoordinates(playerPed)
                local result, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                local myname = sampGetPlayerNickname(myid)
                
                request_table["info"] = {
                    server = ip .. ":" .. tostring(port),
                    sender = myname,
                    pos = {x = x, y = y, z = z, heading = getCharHeading(playerPed)},
                    data = { 
                        pair_mode_name = pair_mode_name,
                        is_truck = isTruckCar(),
                        gruz = current_load,
                        skill = inifiles.Trucker.Skill,
                        rank = inifiles.Trucker.Rank,
                        id = myid,
                        paraid = pair_mode_id,
                        timer = timer,
                        tmonitor = inifiles.tmonitor
                    }
                }
                request_table['random'] = tostring(os.clock()):gsub('%.', '')

                if pair_mode and pair_mode_name ~= nil then
                    request_table["info"]['data']["pair_mode_name"] = pair_mode_name
                else
                    request_table["info"]['data']["pair_mode_name"] = "____"
                end

                download_call = 0
                collecting_data = false
                wait_for_response = true
                local response_path = os.tmpname()
                down = false
                --setClipboardText("http://185.139.68.104:43136/" .. encodeJson(request_table))
                download_id_4 = downloadUrlToFile(
                    "http://185.139.68.104:43136/" .. encodeJson(request_table),
                    response_path,
                    function(id, status, p1, p2)
                        if stop_downloading_4 then
                            stop_downloading_4 = false
                            download_id_4 = nil
                            return false
                        end
                        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                            down = true
                            download_id_4 = nil
                        end
                        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                            wait_for_response = false
                            download_id_4 = nil
                        end
                    end
                )
                while wait_for_response do
                    wait(10)
                end
                processing_response = true

                if down and doesFileExist(response_path) then
                    local f = io.open(response_path, "r")
                    if f then
                        local fileText = f:read("*a")
                        if fileText ~= nil and #fileText > 0 then
                            info = decodeJson(fileText)
                            if info == nil then
                                print("{ff0000}[" .. string.upper(thisScript().name) .. "]: Был получен некорректный ответ от сервера.")
                            else
                                if download_call == 0 then
                                    transponder_delay = info.delay
                                    response_timestamp = info.timestamp
                                    if info.base ~= nil then
                                        base = info.base
                                        error_message('2', '')
                                        local minKD = 1000000
                                        local dialogText = 'Имя[ID]\tСкилл\tФура/Груз\tНапарник\n'
                                        local tmonitor = {}
                                        for k,v in pairs(base) do
                                            if v.pair_mode_name == myname then
                                                if new_pair[k] == nil then
                                                    new_pair[k] = true
                                                    sampAddChatMessage('TruckHUD: Игрок '..k..'['..v.id..'] добавил Вас в режим пары.', -1)
                                                end
                                            end
                                            if new_pair[k] ~= nil and v.pair_mode_name ~= myname then
                                                sampAddChatMessage('TruckHUD: Игрок '..k..'['..v.id..'] убрал Вас из режима пары.', -1)
                                                new_pair[k] = nil
                                            end
                                            if inifiles.blacklist[k] == nil then
                                                inifiles.blacklist[k] = false
                                            end
                                            if (not inifiles.Settings.blacklist_inversion and inifiles.blacklist[k] == false) or (inifiles.Settings.blacklist_inversion and inifiles.blacklist[k] == true) then
                                                if v.tmonitor ~= nil and v.tmonitor.lsn ~= nil and tonumber(v.tmonitor.lsn) ~= 0 then
                                                    local monKD = msk_timestamp - v.tmonitor.time
                                                    if monKD > 0 then
                                                        if monKD < minKD then
                                                            minKD = monKD
                                                            tmonitor = v.tmonitor
                                                        end
                                                    end                                        
                                                end
                                            end
                                        end
                                        if minKD ~= 1000000 then
                                            if mon_ctime < tmonitor.time then 
                                                mon_time = tmonitor.time
                                                for k, v in pairs(prices_mon) do
                                                    if tmonitor[k] ~= nil then
                                                        prices_mon[k] = tmonitor[k]
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if info.result == "para" then
                                        error_message('2', '')
                                        pair_timestamp = info.data.timestamp
                                        base[pair_mode_name].pos = { x = info.data.x, y = info.data.y, z = info.data.z }
                                        base[pair_mode_name].heading = info.data.heading
                                        pair_table = base[pair_mode_name] 
                                        pair_status = 200
                                        if para_message_send == nil then
                                            para_message_send = 1
                                            sampAddChatMessage("Установлен напарник "..pair_mode_name.."["..pair_mode_id.."]"..". Теперь вы можете пользоваться картой.", -1)
                                            sampAddChatMessage(string.format("Активация в фуре: %s. Без фуры: %s + %s.", inifiles.Settings.Key3:gsub("VK_", ""), inifiles.Settings.Key3:gsub("VK_", ""), inifiles.Settings.Key2:gsub("VK_", "")), -1)
                                        end
                                    elseif info.result == "error" then
                                        if info.reason ~= nil then
                                            if info.reason == 403 then
                                                error_message('2', '')
                                                pair_status = info.reason
                                                error_message('1', pair_mode_name.."["..pair_mode_id.."] пока не установил Вас напарником в своем TruckHUD.")
                                            elseif info.reason == 404 then
                                                error_message('2', '')
                                                pair_status = info.reason
                                                error_message('1', pair_mode_name.."["..pair_mode_id.."] не найден в базе игроков TruckHUD")
                                            elseif info.reason == 425 then   
                                                error_message('2', 'Слишком частые запросы на хостинг. Разберитесь с этим или обратитесь за помощью в группу vk.com/rubin.mods')
                                            end
                                        end
                                    end
                                end
                                wait_for_response = false
                                info = nil
                            end
                        end
                        fileText = nil
                        f:close()
                        f = nil
                    end
                else
                    error_message('2', 'Не получил ответа от хостинга. Найдите причину с помощью /truck server_help или напишите о проблеме в группу vk.com/rubin.mods.')
                end
                if doesFileExist(response_path) then
                    os.remove(response_path)
                end
                request_table = nil
                processing_response = false
            end
        end
    end
end

function error_message(key, text)
    if text ~= '' then
        if error_array[key] == nil then
            error_array[key] = true
            sampAddChatMessage(text, -1)
        end
    else
        if error_array[key] ~= nil then
            if key == '2' or key == '3' then
                sampAddChatMessage('Связь с сервером TruckHUD возобновлена.', -1)
            end
            error_array[key] = nil
        end
    end
end

function count_next()
        local count = (transponder_delay - (os.clock() * 1000 - delay_start * 1000)) / 1000
        if count >= 0 then
            return string.format("%0.3fс", count)
        elseif wait_for_response then
            return "Ожидание ответа" -- WAITING FOR RESPONSE
        elseif processing_response then
            return "Обработка ответа" -- PROCESSING RESPONSE
        else
            return "Выполнение запроса" -- PERFOMING REQUEST
        end
end

function dn(nam)
    file = getGameDirectory() .. "\\moonloader\\resource\\TruckHUD\\" .. nam
    if not doesFileExist(file) then
        downloadUrlToFile(
            "https://raw.githubusercontent.com/Serhiy-Rubin/TruckHUD/master/resource/TruckHUD/" .. nam,
            file
        )
    end
end

function init()
    if not doesDirectoryExist(getGameDirectory() .. "\\moonloader\\resource") then
        createDirectory(getGameDirectory() .. "\\moonloader\\resource")
    end
    if not doesDirectoryExist(getGameDirectory() .. "\\moonloader\\resource\\TruckHUD") then
        createDirectory(getGameDirectory() .. "\\moonloader\\resource\\TruckHUD")
    end
    dn("truck.png")
    dn("pla.png")

    for i = 1, 16 do
        dn(i .. ".png")
    end

    player = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/pla.png")
    truck = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/truck.png")

    font10 = renderCreateFont("Segoe UI", 10, 13)

    resX, resY = getScreenResolution()
    m1 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/1.png")
    m2 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/2.png")
    m3 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/3.png")
    m4 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/4.png")
    m5 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/5.png")
    m6 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/6.png")
    m7 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/7.png")
    m8 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/8.png")
    m9 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/9.png")
    m10 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/10.png")
    m11 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/11.png")
    m12 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/12.png")
    m13 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/13.png")
    m14 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/14.png")
    m15 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/15.png")
    m16 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/16.png")

    if resX > 1024 and resY >= 1024 then
        bX = (resX - 1024) / 2
        bY = (resY - 1024) / 2
        size = 1024
        iconsize = 32
    elseif resX > 720 and resY >= 720 then
        bX = (resX - 720) / 2
        bY = (resY - 720) / 2
        size = 720
        iconsize = 24
    else
        bX = (resX - 512) / 2
        bY = (resY - 512) / 2
        size = 512
        iconsize = 16
    end
end

function fastmap()
    init()

    while true do
        wait(0)
        if inifiles.Settings.transponder and inifiles.Settings.fastmap then
            if sampIsDialogActive() then
                dialogActiveClock = os.time() 
            end

            if pair_mode and
                pair_status == 200 and
                not sampIsDialogActive() and 
                (os.time() - dialogActiveClock) > 1 and 
                not sampIsScoreboardOpen() and
                not isSampfuncsConsoleActive() and 
               ( (isKeyDown(vkeys[inifiles.Settings.Key3]) and isKeyDown(vkeys[inifiles.Settings.Key2]) or (isTruckCar() and isKeyDown(vkeys[inifiles.Settings.Key3]))))
            then
                fastmapshow = true
                local x, y = getCharCoordinates(playerPed)
                renderDrawTexture(m1, bX, bY, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m2, bX + size / 4, bY, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m3, bX + 2 * (size / 4), bY, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m4, bX + 3 * (size / 4), bY, size / 4, size / 4, 0, 0xFFFFFFFF)

                renderDrawTexture(m5, bX, bY + size / 4, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m6, bX + size / 4, bY + size / 4, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m7, bX + 2 * (size / 4), bY + size / 4, size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m8, bX + 3 * (size / 4), bY + size / 4, size / 4, size / 4, 0, 0xFFFFFFFF)

                renderDrawTexture(m9, bX, bY + 2 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m10, bX + size / 4, bY + 2 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m11, bX + 2 * (size / 4), bY + 2 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m12, bX + 3 * (size / 4), bY + 2 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)

                renderDrawTexture(m13, bX, bY + 3 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m14, bX + size / 4, bY + 3 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m15, bX + 2 * (size / 4), bY + 3 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)
                renderDrawTexture(m16, bX + 3 * (size / 4), bY + 3 * (size / 4), size / 4, size / 4, 0, 0xFFFFFFFF)

                renderDrawBoxWithBorder(bX, bY + size - size / 42, size, size / 45, -1, 2, -2)

                if pair_table ~= {} then
                    status_string = string.format( "Синхронизированы с %s. UPD: %s", pair_mode_name, count_next())
                end

                renderFontDrawText(font10, status_string, bX, (bY + size - size / 45) - (renderGetFontDrawHeight(font10) / 4), 0xFF00FF00)
                
                if isTruckCar() then
                    renderDrawTexture( truck, getX(x), getY(y), iconsize, iconsize, -getCharHeading(playerPed) + 90, -1 )
                else
                    renderDrawTexture( player, getX(x), getY(y), iconsize, iconsize, -getCharHeading(playerPed), -1 )
                end

                if pair_table ~= nil and pair_table["pos"] ~= nil and pair_table["pos"]["x"] ~= nil then
                    color = 0xFFdedbd2
                    if pair_table["is_truck"] then
                        renderDrawTexture(truck, getX(pair_table["pos"]["x"]), getY(pair_table["pos"]["y"]), iconsize, iconsize, -pair_table["heading"] + 90, -1 )
                    else
                        renderDrawTexture(player, getX(pair_table["pos"]["x"]), getY(pair_table["pos"]["y"]), iconsize, iconsize, -pair_table["heading"], -1 )
                    end
                end
            else
                fastmapshow = nil
            end
        end
    end
end

function getX(x)
    x = math.floor(x + 3000)
    return bX + x * (size / 6000) - iconsize / 2
end

function getY(y)
    y = math.floor(y * -1 + 3000)
    return bY + y * (size / 6000) - iconsize / 2
end
 
function onScriptTerminate(LuaScript, quitGame)
    if LuaScript == thisScript() then
        stop_downloading_1 = true
        stop_downloading_2 = true
        stop_downloading_3 = true
        stop_downloading_4 = true
        stop_downloading_5 = true
        for k, v in pairs(pickupLoad) do
            if v.pickup ~= nil then
                if doesPickupExist(v.pickup) then
                    removePickup(v.pickup)
                    v.pickup = nil
                end
            end
        end
        delete_all__3dTextplayers()
        deleteMarkers()
    end
end

function get_time()
    if inifiles.Settings.transponder then
        local adress = os.getenv('TEMP')..'\\TruckHUD-time.txt'
        local url = 'http://185.139.68.104/sampbot/msk_timestamp.php'
        downloadUrlToFile(url, adress, function(id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                _time = os.time()
                if doesFileExist(adress) then
                local f = io.open(adress, 'r')
                    if f then
                      local time = f:read('*a')
                      msk_timestamp = tonumber(time)
                      f:close()
                      os.remove(adress)
                    else
                        msk_timestamp = os.time()
                        sampAddChatMessage('TruckHUD: Ошибка получения точного времени. Используется локальное.', -1)
                    end
                end
            end
            if status == 58 then
                if msk_timestamp == 0 then
                    msk_timestamp = os.time()
                    sampAddChatMessage('TruckHUD: Ошибка получения точного времени. Используется локальное.', -1)
                end
            end
        end)
    else
        msk_timestamp = os.time()
        sampAddChatMessage('TruckHUD: Ошибка получения точного времени. Используется локальное.', -1)
    end

    repeat wait(0) until msk_timestamp > 0

    while true do
        wait(500)
        msk_timestamp = msk_timestamp + (os.time() - _time)
        _time = os.time()
        if inifiles.Settings.AutoClear then
            collectgarbage()
        end
    end
end

function split(str, delim, plain)
    local tokens, pos, plain = {}, 1, not (plain == false) --[[ delimiter is plain text by default ]]
    repeat
        local npos, epos = string.find(str, delim, pos, plain)
        table.insert(tokens, string.sub(str, pos, npos and npos - 1))
        pos = epos and epos + 1
    until not pos
    return tokens
end

function showTruckers()
    local dialogText = 'Имя[ID] AFK\tСкилл / Ранг\tФура / Груз\tНапарник\n'
    local trucker_count = 0

    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    for k,v in pairs(base) do
        if v.pair_mode_name ~= nil and v.is_truck ~= nil and v.gruz ~= nil and v.skill ~= nil and v.id ~= nil and v.paraid ~= nil and v.timer ~= nil and v.tmonitor ~= nil then
            if (sampIsPlayerConnected(v.id) or myid == v.id) and sampGetPlayerNickname(v.id) == k then
                trucker_count = trucker_count + 1
                local afk = math.ceil(msk_timestamp - v.timestamp)
                dialogText = string.format('%s%s[%s] %s\t%s / %s\t%s\t%s\n', dialogText, k, v.id, (afk > 10 and '[AFK: '..afk..']' or ''), v.skill, v.rank, ( (v.is_truck and 'Да ' or 'Нет ')..(v.gruz == 0 and '/ Нет' or (v.gruz == 1 and '/ Нефть' or (v.gruz == 2 and '/ Уголь' or (v.gruz == 3 and '/ Дерево' or '/ Рубины')))) ), ( v.pair_mode_name == '____' and 'Нет' or v.pair_mode_name..'['..v.paraid..']'))
            end
        end                                   
    end
    sampShowDialog(0, 'Дальнобойщики со скриптом в сети: '..trucker_count, (#dialogText == 0 and 'Список пуст' or dialogText), 'Выбрать', 'Закрыть', 5)
end

function renderTruckers()
    font_t = renderCreateFont(inifiles.Render.FontName, inifiles.Render.FontSize, inifiles.Render.FontFlag)
    _3dTextplayers = {}
    while true do
        wait(0)
        if script_run then
            for id = 0, 999 do
                if sampIsPlayerConnected(id) then
                    local nickname = sampGetPlayerNickname(id)
                    if base[nickname] ~= nil then
                        local stream, ped = sampGetCharHandleBySampPlayerId(id)
                        if stream then
                            if (isCharInModel(ped, 403) or isCharInModel(ped, 514) or isCharInModel(ped, 515)) then
                                local car = storeCarCharIsInNoSave(ped)
                                local result, idcar = sampGetVehicleIdByCarHandle(car)
                                if _3dTextplayers[id] == nil and result then
                                    _3dTextplayers[id] = sampCreate3dText(' ', -1, 0.0, 0.0, 0.0, 30.0, false, -1, idcar) 
                                end
                                if _3dTextplayers[id] ~= nil and result then
                                    local timer_player = 180 - (base[nickname].timer > 1000 and os.difftime(msk_timestamp, base[nickname].timer) or 181)
                                    local color = (timer_player <= 0 and inifiles.Render.Color2 or (timer_player <= 10 and 'b50000' or inifiles.Render.Color2))
                                    local kd_player = (timer_player > 0 
                                        and 
                                        string.format('{%s}<< {%s}%d:%02d {%s}>>', inifiles.Render.Color1, color, math.floor(timer_player / 60), timer_player % 60, inifiles.Render.Color1) 
                                        or 
                                        string.format('{%s}<< {%s}0:00 {%s}>>', inifiles.Render.Color1, inifiles.Render.Color2, inifiles.Render.Color1)
                                    )
                                    local gruz_player = string.format('{%s}%s', inifiles.Render.Color2, 
                                    (base[nickname].gruz == 0 and 'Нет груза' or (base[nickname].gruz == 1 and 'Нефть' or (base[nickname].gruz == 2 and 'Уголь' or (base[nickname].gruz == 3 and 'Дерево' or 'Рубины'))))
                                    )
                                    local para_player = string.format('{%s}%s', inifiles.Render.Color2,
                                    (base[nickname].pair_mode_name ~= '____' and base[nickname].pair_mode_name..'['..base[nickname].paraid..']' or 'Нет напарника')
                                    )
                                    local pair_kd = ''
                                    if base[nickname].pair_mode_name ~= '____' and base[base[nickname].pair_mode_name] ~= nil then
                                    local timer_d = 180 - (base[base[nickname].pair_mode_name].timer > 1000 and os.difftime(msk_timestamp, base[base[nickname].pair_mode_name].timer) or 181)
                                    local color = (timer_d <= 0 and inifiles.Render.Color2 or (timer_d <= 10 and 'b50000' or inifiles.Render.Color2))
                                    pair_kd = string.format('(%s{%s})', (timer_d > 0 and string.format('{%s}%d:%02d', color, math.floor(timer_d / 60), timer_d % 60) or string.format('{%s}0:00', inifiles.Render.Color2)), inifiles.Render.Color2)
                                    end

                                    sampSet3dTextString(_3dTextplayers[id], string.format('%s\n%s\n%s %s', kd_player, gruz_player, para_player, pair_kd))
                                end
                                if not result and _3dTextplayers[id] ~= nil then
                                    sampDestroy3dText(_3dTextplayers[id])
                                    _3dTextplayers[id] = nil
                                end
                            else
                                if _3dTextplayers[id] ~= nil then
                                    sampDestroy3dText(_3dTextplayers[id])
                                    _3dTextplayers[id] = nil
                                end
                            end
                        else
                            if _3dTextplayers[id] ~= nil then
                                sampDestroy3dText(_3dTextplayers[id])
                                _3dTextplayers[id] = nil
                            end
                        end
                    end
                else
                    if _3dTextplayers[id] ~= nil then
                        sampDestroy3dText(_3dTextplayers[id])
                        _3dTextplayers[id] = nil
                    end
                end
            end
        else
            delete_all__3dTextplayers()
        end
    end
end

function delete_all__3dTextplayers()
    for k, v in pairs(_3dTextplayers) do
        sampDestroy3dText(_3dTextplayers[k])
        _3dTextplayers[k] = nil
    end
end