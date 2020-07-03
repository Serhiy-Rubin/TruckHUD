script_name("TruckHUD")
script_author("Serhiy_Rubin")
script_version("03/04/2020")
local sampev, inicfg, dlstatus, vkeys, ffi =
    require "lib.samp.events",
    require "inicfg",
    require("moonloader").download_status,
    require "lib.vkeys",
    require("ffi")
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
    [6] = {[1] = "Настройки", [2] = "Настройки", run = false},
    [7] = {[1] = "Мониторинг цен", [2] = "Мониторинг цен", run = false},
    [8] = {[1] = "Купить груз", [2] = "Купить груз", run = false},
    [9] = {[1] = "Продать груз", [2] = "Продать груз", run = false},
    [10] = {[1] = "Восстановить груз", [2] = "Восстановить груз", run = false}
}

local pair_mode, sms_pair_mode, report_text, pair_mode_id, pair_mode_name, BinderMode =
    false,
    "",
    "",
    999,
    "Nick_Name",
    true
local script_run, control, auto, autoh, wait_auto, pos =
    false,
    false,
    false,
    true,
    0,
    {[1] = false, [2] = false, [3] = false}
local price_frozen, timer, antiflood, current_load, load_location, unload_location = false, 0, 0, 0, false, false
local my_nick, server, timer_min, timer_sec, workload = "", "", 0, 0, 0
local mon_life, mon_kd, mon_secund, mon_time, mon_ctime, stop_thread = 0, 0, 0, 0, 0, false
local log, log_files = {ReysH = 0, Reys = 0, ZPH = 0, ZP = 0, PribH = 0, Prib = 0, ZatrH = 0, Zatr = 0}, {}
local prices_3dtext = {
    n1 = 0,
    n2 = 0,
    y1 = 0,
    y2 = 0,
    l1 = 0,
    l2 = 0,
    lsn = 0,
    lsy = 0,
    lsl = 0,
    sfn = 0,
    sfy = 0,
    sfl = 0
}
local prices_mon = {
    n1 = 0,
    n2 = 0,
    y1 = 0,
    y2 = 0,
    l1 = 0,
    l2 = 0,
    lsn = 0,
    lsy = 0,
    lsl = 0,
    sfn = 0,
    sfy = 0,
    sfl = 0
}
local prices_smon = {
    n1 = 0,
    n2 = 0,
    y1 = 0,
    y2 = 0,
    l1 = 0,
    l2 = 0,
    lsn = 0,
    lsy = 0,
    lsl = 0,
    sfn = 0,
    sfy = 0,
    sfl = 0
}
local delay, d = {chatMon = 0, chat = 0, skill = -1, mon = 0, load = 0, unload = 0, sms = 0, dir = 0}, {[3] = ""}
local pickupLoad = {
    [1] = {251.32167053223, 1420.3039550781, 11.5}, -- N1
    [2] = {839.09020996094, 880.17510986328, 14.3515625}, -- Y1
    [3] = {-1048.6430664063, -660.54699707031, 33.012603759766}, -- N2
    [4] = {-1863.361328125, -1724.2398681641, 22.75}, -- y2
    [5] = {-1963.6184082031, -2438.9055175781, 31.625}, -- l2
    [6] = {-457.45620727539, -53.193939208984, 60.938865661621} -- l1
}
local newMarkers = {}
local pair_table = {}
local pair_timestamp = {}
local pair_status = 0
local response_timestamp = 0

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(0)
    end

    repeat
        wait(0)
    until sampGetCurrentServerName() ~= "SA-MP"
    repeat
        wait(0)
    until sampGetCurrentServerName():find("Samp%-Rp.Ru")

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
    AdressBind = string.format("%s\\moonloader\\config\\TruckHUD\\Binder.txt", getGameDirectory())
    AdressFolder = string.format("%s\\moonloader\\config\\TruckHUD\\%s-%s", getGameDirectory(), server, my_nick)
    AdressLogFolder = string.format("%s\\Log\\", AdressFolder)
    AdressIni = string.format("TruckHUD\\%s-%s\\Settings.ini", server, my_nick)

    if not doesDirectoryExist(AdressConfig) then
        createDirectory(AdressConfig)
    end
    if not doesDirectoryExist(AdressLogFolder) then
        createDirectory(AdressLogFolder)
    end
    local x1, y1 = convertGameScreenCoordsToWindowScreenCoords(14.992679595947, 274.75)
    local x2, y2 = convertGameScreenCoordsToWindowScreenCoords(146.17861938477, 345.91665649414)
    local x3, y3 = convertGameScreenCoordsToWindowScreenCoords(529.42901611328, 158.08332824707)
    inifiles =
        inicfg.load(
        {
            Settings = {
                ad = true,
                AutoWait = true,
                highlight_jf = true,
                Style = true,
                Stop = true,
                MonDownload = true,
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
                Binder = true,
                SMSpara = false,
                ColorPara = "ff9900",
                LightingPara = true,
                LightingPrice = true,
                girl = false,
                pickup = true,
                markers = true
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
            map = {
                sqr = false
            },
            transponder = {
                allow_occupied = true,
                allow_unlocked = false,
                catch_srp_start = true,
                catch_srp_stop = true,
                catch_srp_gz = true,
                delay = 5999
            },
            Stats = {
                Hour = true,
                Day = true
            },
            Price = {
                Load = 500,
                UnLoad = 800
            }
        },
        AdressIni
    )

    inicfg.save(inifiles, AdressIni)

    if inifiles.Settings.ad then
        local fpath = os.getenv("TEMP") .. "\\TruckHUD-version.txt"
        downloadUrlToFile(
            "https://raw.githubusercontent.com/Serhiy-Rubin/TruckHUD/master/version",
            fpath,
            function(id, status, p1, p2)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    local f = io.open(fpath, "r")
                    if f then
                        local text = f:read("*a")
                        if text ~= nil then
                            if not string.find(text, tostring(thisScript().version)) then
                                sampAddChatMessage(
                                    ">> Вышло обновление для Truck HUD, версия от " ..
                                        text .. ". Текущая версия от " .. thisScript().version,
                                    0xFF2f72f7
                                )
                                sampAddChatMessage(
                                    ">> Посмотреть список изменений: /truck up. Включить/Выключить уведомления: /truck ad",
                                    0xFF2f72f7
                                )
                                sampAddChatMessage(
                                    ">> Официальная страница Truck HUD: https://vk.com/rubin.mods",
                                    0xFF2f72f7
                                )
                            end
                        end
                        io.close(f)
                    end
                end
            end
        )
    end

    if not doesFileExist(AdressBind) then
        local text = "кд !КД\nНа месте\nБеру\nРазгружаю\nБерем по КД\nСдаем по КД\nЗадержусь\n"
        file = io.open(AdressBind, "a")
        file:write(text)
        file:flush()
        io.close(file)
    end
    menu[3].run = inifiles.Settings.Report
    font = renderCreateFont(inifiles.Render.FontName, inifiles.Render.FontSize, inifiles.Render.FontFlag)
    ReadLog()

    lua_thread.create(transponder)

    init()

    while true do
        wait(0)
        doControl()
        doSendCMD()
        doDialog()
        doPair()
        doPickup()
        doMarkers()
        if pair_mode then
            fastmap()
        end

        if script_run then
            if not sampIsScoreboardOpen() and sampIsChatVisible() and not isKeyDown(116) and not isKeyDown(121) then
                doRenderStats()
                doRenderMon()
                doRenderBind()
            end
        end
    end
end

function doControl()
    if
        isKeyDown(vkeys[inifiles.Settings.Key1]) and
            (isTruckCar() or (isKeyDown(vkeys[inifiles.Settings.Key2] or pos[1] or pos[2] or pos[3]))) and
            not sampIsDialogActive() and
            not sampIsScoreboardOpen()
     then
        sampSetCursorMode(3)
        local X, Y = getScreenResolution()
        if not control then
            ffi.C.SetCursorPos((X / 2), (Y / 2))
            Binder(1)
        end
        control = true
        local plus = (renderGetFontDrawHeight(font) + (renderGetFontDrawHeight(font) / 10))
        Y = ((Y / 2.2) - (renderGetFontDrawHeight(font) * 3))
        for i = 1, 10 do
            local string_render = (menu[i].run and menu[i][1] or menu[i][2])
            if drawClickableText(string_render, ((X / 2) - (renderGetFontDrawTextLength(font, string_render) / 2)), Y) then
                if i == 1 then
                    script_run = not script_run
                    menu[i].run = script_run
                    if script_run then
                        ReadLog()
                    end
                end
                if i == 2 then
                    auto = not auto
                    menu[i].run = auto
                end
                if i == 3 then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    inicfg.save(inifiles, AdressIni)
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
                if i == 6 then
                    ShowDialog1(1)
                end
                if i == 7 then
                    sampSendChat("/truck mon")
                end
                if i == 8 then
                    sampSendChat("/truck load " .. GetGruz())
                end
                if i == 9 then
                    sampSendChat("/truck unload")
                end
                if i == 10 then
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
            if i == 6 then
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
    if caption == "Truck-HUD: Настройки" then
        if result and button == 1 then
            if dialogLine ~= nil and dialogLine[list + 1] ~= nil then
                local str = dialogLine[list + 1]
                if str:find("TruckHUD") then
                    script_run = not script_run
                    if script_run then
                        ReadLog()
                    end
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
                if str:find("Компактная статистика") then
                    inifiles.Settings.Style = not inifiles.Settings.Style
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Статистика за час") then
                    inifiles.Stats.Hour = not inifiles.Stats.Hour
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Статистика за сутки") then
                    inifiles.Stats.Day = not inifiles.Stats.Day
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Доклады в рацию") then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    menu[3].run = inifiles.Settings.Report
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Доклады от") then
                    inifiles.Settings.girl = not inifiles.Settings.girl
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Авто загрузка/разгрузка") then
                    auto = not auto
                    menu[2].run = auto
                    ShowDialog1(1)
                end
                if str:find("Режим авто загрузки/разгрузки") then
                    inifiles.Settings.AutoOFF = not inifiles.Settings.AutoOFF
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Убрать тюнинг колес с фур") then
                    inifiles.Settings.Tuning = not inifiles.Settings.Tuning
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Биндер") then
                    inifiles.Settings.Binder = not inifiles.Settings.Binder
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Режим пары	") then
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
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Подсветка напарника в чате") then
                    inifiles.Settings.LightingPara = not inifiles.Settings.LightingPara
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Остановка фуры после разгрузки") then
                    inifiles.Settings.Stop = not inifiles.Settings.Stop
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Получение мониторинга с Хостинга") then
                    inifiles.Settings.MonDownload = not inifiles.Settings.MonDownload
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Скрывать чат профсоюза") then
                    inifiles.Settings.ChatOFF = not inifiles.Settings.ChatOFF
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Отправка мониторинга в чат") then
                    inifiles.Settings.ChatDoklad = not inifiles.Settings.ChatDoklad
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Выделение Портов") then
                    inifiles.Settings.highlight_jf = not inifiles.Settings.highlight_jf
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Выделение цены") then
                    inifiles.Settings.LightingPrice = not inifiles.Settings.LightingPrice
                    inicfg.save(inifiles, AdressIni)
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
                if str:find("Цена авто-загрузки") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Price.Load, false, "Price", "Load")
                    end
                end
                if str:find("Цена авто-разгрузки") then
                    if dialogTextToList[list + 1] ~= nil then
                        ShowDialog1(2, dialogTextToList[list + 1], inifiles.Price.UnLoad, false, "Price", "UnLoad")
                    end
                end
                if str:find("Кнопка отображения меню") then
                    ShowDialog1(4, 1)
                end
                if str:find("Задержка") then
                    inifiles.Settings.AutoWait = not inifiles.Settings.AutoWait
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("clist 0") then
                    inifiles.Settings.markers = not inifiles.Settings.markers
                    if not inifiles.Settings.markers then
                        deleteMarkers()
                    end
                    inicfg.save(inifiles, AdressIni)
                    ShowDialog1(1)
                end
                if str:find("Кнопка для работы меню без фуры") then
                    ShowDialog1(4, 2)
                end
                if str:find("Подробная статистика") then
                    ShowDialog1(5)
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
                    inicfg.save(inifiles, AdressIni)
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
    if caption == "Truck-HUD: Статистика" then
        if result then
            if button == 1 then
                ReadLog(AdressLogFolder .. log_files[list], log_files[list])
            else
                ShowDialog1(1)
            end
        end
    end
    if caption == tostring(d[3]) then
        if result then
            ShowDialog1(5)
        end
    end
    if caption == "Truck-HUD: Биндер" then
        if d[2] == 2 and d[7] then
            d[7] = false
            sampSetCurrentDialogEditboxText(d[3])
        end
        if result and button == 1 then
            if #input > 0 then
                if d[2] == 1 then
                    local file = io.open(AdressBind, "a")
                    file:write(input .. "\n")
                    file:flush()
                    io.close(file)
                end
                if d[2] == 2 then
                    local file = io.open(AdressBind, "r")
                    local fileText = ""
                    local List = 0
                    if file ~= nil then
                        for line in file:lines() do
                            List = List + 1
                            if List == BinderList then
                                line = input
                            end
                            fileText = fileText .. line .. "\n"
                        end
                        io.close(file)
                    end
                    file = io.open(AdressBind, "w")
                    file:write(fileText)
                    file:flush()
                    io.close(file)
                end
            else
                ShowDialog1(d[1], d[2])
            end
        end
    end
    if caption == "Truck-HUD: Режим пары" then
        if result then
            if button == 1 then
                if string.find(input, "(%d+)") then
                    pair_mode_id = tonumber(string.match(input, "(%d+)"))
                    if sampIsPlayerConnected(pair_mode_id) then
                        pair_mode_name = sampGetPlayerNickname(pair_mode_id)
                        menu[4][1] = "SMS » " .. pair_mode_name .. "[" .. pair_mode_id .. "]"
                        pair_mode = true
                        menu[4].run = true
                    else
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
                    if script_run then
                        ReadLog()
                    end
                    ShowDialog1(9)
                end
                if list == 1 then
                    auto = not auto
                    ShowDialog1(9)
                end
                if list == 2 then
                    inifiles.Settings.Report = not inifiles.Settings.Report
                    inicfg.save(inifiles, AdressIni)
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
                    inicfg.save(inifiles, AdressIni)
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
    for k, v in pairs(pickupLoad) do
        local X, Y, Z = getDeadCharCoordinates(PLAYER_PED)
        local distance = getDistanceBetweenCoords3d(X, Y, Z, v[1], v[2], v[3])
        if inifiles.Settings.pickup and distance <= 15.0 and isTruckCar() then
            if v.pickup == nil then
                result, v.pickup = createPickup(19197, 1, v[1], v[2], v[3])
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

function doRenderStats()
    if pos[1] then
        sampSetCursorMode(3)
        local X, Y = getCursorPos()
        inifiles.Settings.X1, inifiles.Settings.Y1 = X, Y + 15
        inicfg.save(inifiles, AdressIni)
        if isKeyJustPressed(1) then
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
    timer_secc = 180 - os.difftime(os.time(), timer)
    local ost_time = 3600 - (os.date("%M", os.time()) * 60) + (os.date("%S", os.time()))
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
        if os.difftime(os.time(), timer) > 180 and autoh then
            if workload == 1 then
                if unload_location then
                    local dp = {ls = "sf", sf = "ls"}
                    local dport, ds = string.match(current_warehouse, "(..)(.)")
                    local dcena =
                        (prices_mon[dp[dport] .. ds] + prices_mon[current_warehouse]) - prices_3dtext[current_warehouse]
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
                                if (os.time() - wait_auto) <= 3 then
                                    printStyledString("Wait load " .. (3 - (os.time() - wait_auto)), 1111, 5)
                                end
                                if (os.time() - wait_auto) > 3 then
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
                inicfg.save(inifiles, AdressIni)
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
    string_render, Y =
        string.format(
            "{%s}Скилл: {%s}%s [%s%%] [%s]",
            c1,
            c2,
            inifiles.Trucker.Skill,
            inifiles.Trucker.ProcSkill,
            inifiles.Trucker.ReysSkill
        ),
        Y + height + down
    drawClickableText(string_render, X, Y)
    string_render, Y =
        string.format(
            "{%s}Ранг: {%s}%s [%s%%] [%s]",
            c1,
            c2,
            inifiles.Trucker.Rank,
            inifiles.Trucker.ProcRank,
            inifiles.Trucker.ReysRank
        ),
        Y + height
    drawClickableText(string_render, X, Y)
    if inifiles.Settings.Style then
        string_render, Y =
            string.format("{%s}Зарплата: {%s}%d/%d", c1, c2, log.ZPH, inifiles.Trucker.MaxZP),
            Y + height + down
        drawClickableText(string_render, X, Y)
        string_render, Y = string.format("{%s}Прибыль: {%s}%d", c1, c2, log.Prib), Y + height
        drawClickableText(string_render, X, Y)
        string_render, Y = string.format("{%s}Рейсы: {%s}%d/%d [%d]", c1, c2, log.ReysH, log.Reys, greys), Y + height
        drawClickableText(string_render, X, Y)
    else
        if inifiles.Stats.Hour then
            string_render, Y = string.format("{%s}Статистика за час", c1), Y + height + down
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Рейсов: {%s}%d [%d]", c1, c2, log.ReysH, greys), Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y =
                string.format("{%s} Зарплата: {%s}%d/%d", c1, c2, log.ZPH, inifiles.Trucker.MaxZP),
                Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Прибыль: {%s}%d", c1, c2, log.PribH), Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Затраты: {%s}%d", c1, c2, log.ZatrH), Y + height
            drawClickableText(string_render, X, Y)
        end
        if inifiles.Stats.Day then
            string_render, Y = string.format("{%s}Статистика за сутки", c1), Y + height + down
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Рейсов: {%s}%d", c1, c2, log.Reys), Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Зарплата: {%s}%d", c1, c2, log.ZP), Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Прибыль: {%s}%d", c1, c2, log.Prib), Y + height
            drawClickableText(string_render, X, Y)
            string_render, Y = string.format("{%s} Затраты: {%s}%d", c1, c2, log.Zatr), Y + height
            drawClickableText(string_render, X, Y)
        end
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
        inicfg.save(inifiles, AdressIni)
        if isKeyJustPressed(1) then
            pos[2] = false
            sampSetCursorMode(0)
        end
    end
    local X, Y, c1, c2 = inifiles.Settings.X2, inifiles.Settings.Y2, inifiles.Render.Color1, inifiles.Render.Color2
    local height = renderGetFontDrawHeight(font)
    if mon_secund ~= -2 then
        mon_secund = os.time() - mon_kd
        local A1 = os.difftime(os.time(), mon_time)
        local A2 = os.difftime(os.time(), mon_ctime)
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
    end
    if drawClickableText(rdtext, X, Y) then
        mon_secund = 20
    end
    if (mon_secund >= 20 or mon_secund == -2) and inifiles.Settings.MonDownload then
        mon_secund = 0
        mon_kd = os.time()
        local fpath = os.getenv("TEMP") .. "\\TruckHUD-monitoring.txt"
        downloadUrlToFile(
            "http://truck.hud.xsph.ru/" .. server,
            fpath,
            function(id, status, p1, p2)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    local f = io.open(fpath, "r")
                    if f then
                        local text = f:read("*a")
                        if
                            string.find(
                                text,
                                "%[LS N:%d+ Y:%d+ L:%d+%] %[1 N:%d+ Y:%d+ L:%d+%] %[2 N:%d+ Y:%d+ L:%d+%] %[SF N:%d+ Y:%d+ L:%d+%] (%d+)"
                            )
                         then
                            G1 =
                                string.match(
                                text,
                                "%[LS N:%d+ Y:%d+ L:%d+%] %[1 N:%d+ Y:%d+ L:%d+%] %[2 N:%d+ Y:%d+ L:%d+%] %[SF N:%d+ Y:%d+ L:%d+%] (%d+)"
                            )
                            G2 = os.difftime(os.time(), G1) -- Из сервера
                            G3 = os.difftime(os.time(), mon_ctime) -- из чата
                            if tonumber(G3) > tonumber(G2) then
                                S1 = mon_time
                                prices_mon.n1,
                                    prices_mon.n2,
                                    prices_mon.y1,
                                    prices_mon.y2,
                                    prices_mon.l1,
                                    prices_mon.l2,
                                    prices_mon.lsn,
                                    prices_mon.lsy,
                                    prices_mon.lsl,
                                    prices_mon.sfn,
                                    prices_mon.sfy,
                                    prices_mon.sfl,
                                    mon_time =
                                    string.match(
                                    text,
                                    "%[LS N:(%d+) Y:(%d+) L:(%d+)%] %[1 N:(%d+) Y:(%d+) L:(%d+)%] %[2 N:(%d+) Y:(%d+) L:(%d+)%] %[SF N:(%d+) Y:(%d+) L:(%d+)%] (%d+)"
                                )
                                if S1 ~= mon_time then
                                    mon_life = os.time()
                                end
                            end
                        end
                        io.close(f)
                    end
                end
            end
        )
    end
    -----
    local secund = os.difftime(os.time(), mon_life)
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
                math.ceil(getDistanceBetweenCoords3d(pX, pY, pZ, -1872.8674316406, -1720.0148925781, 21.322338104248)) ..
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
        inicfg.save(inifiles, AdressIni)
        if isKeyJustPressed(1) then
            pos[3] = false
            sampSetCursorMode(0)
        end
    end
    if script_run and BindText ~= nil and inifiles.Settings.Binder and control or pos[3] then
        local X, Y = inifiles.Settings.X3, inifiles.Settings.Y3
        local plus = (renderGetFontDrawHeight(font) + (renderGetFontDrawHeight(font) / 10))
        if not pair_mode and not BinderMode then
            BinderMode = true
        end
        if
            drawClickableText(
                string.format(
                    "{%s}[ %sРация {%s}%s{%s}]",
                    inifiles.Render.Color2,
                    (BinderMode and "{12a61a}" or "{ff0000}"),
                    inifiles.Render.Color2,
                    (not BinderMode and "| {12a61a}CMC " or (pair_mode and "| {ff0000}CMC " or "")),
                    inifiles.Render.Color2
                ),
                X,
                Y - renderGetFontDrawHeight(font)
            )
         then
            BinderMode = not BinderMode
        end
        if drawClickableText("{" .. inifiles.Render.Color2 .. "}[Смена позиции]", X, Y) then
            pos[3] = true
        end
        local List, string = 0, ""
        for i = 1, #EditLine do
            if EditLine[i] ~= nil then
                string = EditLine[i]
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
                    if min < 0 then
                        min, sec = 0, 0
                    end
                    string = string:gsub("!КД", string.format("%d:%02d", min, sec))
                end
                List = List + 1
                Y = Y + plus
                if drawClickableText(string, X, Y) then
                    sampSendChat((BinderMode and "/jf chat " or "/sms " .. pair_mode_id .. " ") .. string)
                end
                if drawClickableText("{ff0000}х", (X + renderGetFontDrawTextLength(font, string .. "  ")), Y) then
                    BinderList = List
                    lua_thread.create(
                        function()
                            file = io.open(AdressBind, "r")
                            local fileText = ""
                            local List = 0
                            if file ~= nil then
                                for line in file:lines() do
                                    List = List + 1
                                    if List ~= BinderList then
                                        fileText = fileText .. line .. "\n"
                                    end
                                end
                                io.close(file)
                            end
                            file = io.open(AdressBind, "w")
                            file:write(fileText)
                            file:flush()
                            io.close(file)
                        end
                    )
                    Binder(1)
                end
                if drawClickableText("{12a61a}/", (X + renderGetFontDrawTextLength(font, string .. "     ")), Y) then
                    BinderList = List
                    ShowDialog1(7, 2, string)
                end
            end
        end
        Y = Y + plus
        if drawClickableText("{12a61a}Добавить строку", X, Y) then
            ShowDialog1(7, 1)
        end
    end
end

function Binder(int)
    if int == 0 or int == 1 then -- Чтение
        BindText = ""
        BindTextEdit = ""
        EditLine = {}
        file = io.open(AdressBind, "r")
        if file ~= nil then
            for string in file:lines() do
                EditLine[#EditLine + 1] = string
                BindTextEdit = BindTextEdit .. string .. "\n"
                BindText = string.format("%s%s\n", BindText, string)
            end
            io.close(file)
        end
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
            "Компактная статистика\t" .. (inifiles.Settings.Style == true and "{59fc30}ON" or "{ff0000}OFF")
        if not inifiles.Settings.Style then
            dialogLine[#dialogLine + 1] =
                "Статистика за час\t" .. (inifiles.Stats.Hour == true and "{59fc30}ON" or "{ff0000}OFF")
            dialogLine[#dialogLine + 1] =
                "Статистика за сутки\t" .. (inifiles.Stats.Day == true and "{59fc30}ON" or "{ff0000}OFF")
        end

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

        dialogLine[#dialogLine + 1] =
            "Убрать тюнинг колес с фур\t" .. (inifiles.Settings.Tuning == false and "{59fc30}ON" or "{ff0000}OFF")

        dialogLine[#dialogLine + 1] =
            "Получение мониторинга с Хостинга\t" ..
            (inifiles.Settings.MonDownload == true and "{59fc30}ON" or "{ff0000}OFF")

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

        dialogLine[#dialogLine + 1] = "Кнопка для работы меню без фуры\t" .. inifiles.Settings.Key2:gsub("VK_", "") -- 15

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
                        if wasKeyPressed(v) and k ~= "VK_ESCAPE" and k ~= "VK_RETURN" and k ~= "VK_LBUTTON" then
                            key = k
                        end
                    end
                until key ~= ""
                local ini__name = (dtext == 1 and "Key1" or "Key2")
                inifiles.Settings[ini__name] = key
                inicfg.save(inifiles, AdressIni)
                ShowDialog1(1)
            end
        )
    end
    if int == 5 then
        if doesDirectoryExist(AdressFolder) then
            local FileHandle, FileName = findFirstFile(AdressFolder .. "\\Log\\*")
            if FileHandle ~= nil then
                local list = 0
                while FileName ~= nil do
                    if FileName ~= nil and FileName ~= ".." and FileName ~= "." then
                        log_files[list] = FileName
                        list = list + 1
                    end
                    FileName = findNextFile(FileHandle)
                end
                findClose(FileHandle)
            end
        end
        local text = ""
        for k, v in pairs(log_files) do
            text = text .. log_files[k] .. "\n"
        end
        sampShowDialog(222, "Truck-HUD: Статистика", text, "Открыть", "Назад", 2)
    end
    if int == 6 then
        sampShowDialog(222, dinput, dtext, "Назад", "", 0)
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
end
--[[
function FindSklad()
	local result = ""
	local pos = {
	["n1"] = {x = 256.02127075195, y = 1414.8492431641, z = 10.232398033142},
	["y1"] = {x = 608.63952636719, y = 847.59533691406, z = -43.589405059814},
	["l1"] = {x = -448.91455078125, y = -65.951385498047, z = 58.959014892578},
	["n2"] = {x = -1046.7521972656, y = -670.66937255859, z = 31.885597229004},
	["y2"] = {x = -1872.8674316406, y = -1720.0148925781, z = 21.322338104248},
	["l2"] = {x = -1978.8649902344, y = -2434.9421386719, z = 30.192840576172},
	["ls"] = {x = 2614.2241210938, y = -2228.8745117188, z = 12.905993461609},
	["sf"] = {x = -1733.1876220703, y = 120.08413696289, z = 3.1192970275879}
    }
	for name, cord in pairs(pos) do
		local X, Y, Z = getDeadCharCoordinates(PLAYER_PED)
		local distance = getDistanceBetweenCoords3d(X, Y, Z, cord.x, cord.y, cord.z)
		if distance <= 23.8 then
			result = name
		end
	end
end]]
function sampev.onServerMessage(color, message)
    if message == " У вас бан чата!" then
        delay.chatMon = 0
        delay.chat = 0
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
        mon_life = os.time()
        mon_ctime = os.time()
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
                " (.*)<(.*)>: %[ЛС Н:(%d+) У:(%d+) Л:(%d+)%] %[1 Н:(%d+) У:(%d+) Л:(%d+)%] %[2 Н:(%d+) У:(%d+) Л:(%d+)%] %[CФ Н:(%d+) У:(%d+) Л:(%d+)%] %[(.*)%]"
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
                " (.*)<(.*)>: %[ЛС Н:(%d+) У:(%d+) Л:(%d+)%] %[1 Н:(%d+) У:(%d+) Л:(%d+)%] %[2 Н:(%d+) У:(%d+) Л:(%d+)%] %[CФ Н:(%d+) У:(%d+) Л:(%d+)%]"
            )
        end
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

    if string.find(message, " Нефть: (%d+) / (%d+)") then
        local S1, S2 = string.match(message, " Нефть: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 1
        end
    end
    if string.find(message, " Уголь: (%d+) / (%d+)") then
        local S1, S2 = string.match(message, " Уголь: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 2
        end
    end
    if string.find(message, " Дерево: (%d+) / (%d+)") then
        local S1, S2 = string.match(message, " Дерево: (%d+) / (%d+)")
        if tonumber(S1) ~= 0 then
            current_load = 3
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
        ReadLog()
    end -- Log update

    if
        message == " Сообщение доставлено" or message == " Игрок оффлайн" or
            message == " Введите: /sms [playerid / phonenumber] [текст]" or
            message == " Телефон вне зоны доступа сети"
     then
        delay.sms = 0
    end

    if string.find(message, "Загружено %d+ груза, на сумму (%d+) вирт. Скидка: %d+ вирт") and isTruckCar() then
        WriteLog(message, 1)
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

    if
        string.find(message, "Вы заработали (%d+) вирт, из которых (%d+) вирт будет добавлено к вашей зарплате") and
            isTruckCar()
     then
        WriteLog(message, 2)
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
        WriteLog(message, 3)
    end
    if string.find(message, " Вы заплатили штраф (%d+) вирт, Офицеру (%g+)") then
        WriteLog(message, 4)
    end
    if string.find(message, " Вашу машину отремонтировал%(а%) за (%d+) вирт, Механик (%g+)") and isTruckCar() then
        WriteLog(message, 5)
    end
    if string.find(message, " Автомеханик (%g+) заправил ваш автомобиль на 300 за (%d+) вирт") and isTruckCar() then
        WriteLog(message, 6)
    end
    if string.find(message, " Машина заправлена, за: (%d+) вирт") and isTruckCar() then
        WriteLog(message, 7)
    end
    if string.find(message, " Вы купили канистру с 50 литрами бензина за (%d+) вирт") and isTruckCar() then
        WriteLog(message, 8)
    end
end

function sampev.onShowDialog(DdialogId, Dstyle, Dtitle, Dbutton1, Dbutton2, Dtext)
    if
        Dstyle == 0 and string.find(Dtext, "{00AB06}Дальнобойщик{CECECE}") and
            string.find(Dtext, "{00AB06}Механик{CECECE}")
     then
        local Skill, SkillP, Rank, RankP =
            string.match(
            Dtext,
            ".+{00AB06}Дальнобойщик{CECECE}.*Скилл: (%d+)	Опыт: .+ (%d+%.%d+)%%.*{CECECE}Ранг: (%d+)  	Опыт: .+ (%d+%.%d+)%%"
        )
        if SkillP ~= nil then
            SkillP = tonumber(SkillP)
            RankP = tonumber(RankP)
            if inifiles.Trucker.ProcSkill ~= SkillP then
                --inifiles.Trucker.ReysSkill = math.ceil((100.0 - SkillP) / (SkillP - inifiles.Trucker.ProcSkill))
                --inifiles.Trucker.ProcSkill = SkillP
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
            inifiles.Trucker.MaxZP = 50000 + (2500 * (1.1 ^ Skill)) + (2500 * (1.1 ^ Rank))
            inicfg.save(inifiles, AdressIni)
        end
        if delay.skill ~= 0 then
            delay.skill = 0
            return false
        end
    end

    if DdialogId == 22 and Dstyle == 0 and string.find(Dtext, "Заводы") then
        mon_life = os.time()
        delay.mon = 0
        prices_mon.n1,
            prices_mon.n2,
            prices_mon.y1,
            prices_mon.y2,
            prices_mon.l1,
            prices_mon.l2,
            prices_mon.lsn,
            prices_mon.lsy,
            prices_mon.lsl,
            prices_mon.sfn,
            prices_mon.sfy,
            prices_mon.sfl =
            string.match(
            Dtext,
            "[Заводы].*Нефтезавод №1.*.*Нефть: 0.(%d+) вирт.*Нефтезавод №2.*.*Нефть: 0.(%d+) вирт.*Склад угля №1.*.*Уголь: 0.(%d+) вирт.*Склад угля №2.*.*Уголь: 0.(%d+) вирт.*Лесопилка №1.*.*Дерево: 0.(%d+) вирт.*Лесопилка №2.*.*Дерево: 0.(%d+) вирт.*[Порты].*Порт ЛС.*.*Нефть: 0.(%d+) вирт.*.*Уголь: 0.(%d+) вирт.*.*Дерево: 0.(%d+) вирт.*Порт СФ.*.*Нефть: 0.(%d+) вирт.*.*Уголь: 0.(%d+) вирт.*.*Дерево: 0.(%d+) вирт"
        )
        for k, v in pairs(prices_mon) do
            if string.find(tostring(prices_mon[k]), "99") then
                prices_mon[k] = tonumber(prices_mon[k]) + 1
            end
        end
        local data =
            string.format(
            "[LS N:%d Y:%d L:%d] [1 N:%d Y:%d L:%d] [2 N:%d Y:%d L:%d] [SF N:%d Y:%d L:%d]",
            prices_mon.n1,
            prices_mon.n2,
            prices_mon.y1,
            prices_mon.y2,
            prices_mon.l1,
            prices_mon.l2,
            prices_mon.lsn,
            prices_mon.lsy,
            prices_mon.lsl,
            prices_mon.sfn,
            prices_mon.sfy,
            prices_mon.sfl
        )
        downloadUrlToFile("http://truck.hud.xsph.ru/index.php?server=" .. server .. "&text=" .. data)
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
        mon_secund = -2
        if script_run then
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
                    if (os.time() - id_3D_text) > 1 then
                        wait_auto = os.time()
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
        id_3D_text = os.time()
        load_location = false
        unload_location = false
        current_warehouse = "none"
    end
end

function WriteLog(message, Log)
    Write = 0
    WriteText = ""
    if Log == 1 then
        timer = os.time()
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
        if inifiles.Trucker.MaxZP > log.ZPH then
            WriteText = os.date("%X", os.time()) .. " | Загрузка " .. Z2 .. "\n"
            log_save_text = os.date("%X", os.time()) .. " | Загрузка " .. Z2
            Write = 1
        end
    end
    if Log == 2 then
        timer = os.time()
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
        local Z3 = Z1 - Z2
        if inifiles.Trucker.MaxZP > (log.ZPH + Z2) then
            if workload == 1 then
                WriteText =
                    os.date("%X", os.time()) ..
                    " | Загрузка " ..
                        Z3 ..
                            "\n" ..
                                os.date("%X", os.time()) ..
                                    " | Разгрузка " ..
                                        Z1 .. "\n" .. os.date("%X", os.time()) .. " | Заработано " .. Z2 .. "\n"
                Write = 2
            else
                WriteText =
                    os.date("%X", os.time()) ..
                    " | Разгрузка " .. Z1 .. "\n" .. os.date("%X", os.time()) .. " | Заработано " .. Z2 .. "\n"
                Write = 1
            end
        else
            if log.ZPH ~= inifiles.Trucker.MaxZP then
                local Z4 = ((log.ZPH + Z2) - inifiles.Trucker.MaxZP - Z2)
                local Z5 = string.match(Z4, "-(.*)")
                if workload == 1 then
                    WriteText =
                        os.date("%X", os.time()) ..
                        " | Загрузка 0\n" ..
                            os.date("%X", os.time()) ..
                                " | Разгрузка " ..
                                    Z5 .. "\n" .. os.date("%X", os.time()) .. " | Заработано " .. Z5 .. "\n"
                    Write = 2
                else
                    WriteText =
                        os.date("%X", os.time()) ..
                        " | Разгрузка " .. Z5 .. "\n" .. os.date("%X", os.time()) .. " | Заработано " .. Z5 .. "\n"
                    Write = 1
                end
            end
        end
    end
    if Log == 3 then
        local message = sampGetDialogText()
        if string.find(message, "Стоимость") then
            local Z1 = string.match(message, "Стоимость аренды: {FFFF00}(%d+) вирт")
            WriteText = os.date("%X", os.time()) .. " | Аренда " .. Z1 .. "\n"
            Write = 1
        end
    end
    if Log == 4 then
        local Z1, Z2 = string.match(message, " Вы заплатили штраф (%d+) вирт, Офицеру (%g+)")
        WriteText = os.date("%X", os.time()) .. " | Штраф " .. Z1 .. "\n"
        Write = 1
    end
    if Log == 5 then
        local Z1, Z2 = string.match(message, " Вашу машину отремонтировал%(а%) за (%d+) вирт, Механик (%g+)")
        WriteText = os.date("%X", os.time()) .. " | Ремонт " .. Z1 .. "\n"
        Write = 1
    end
    if Log == 6 then
        local Z1, Z2 = string.match(message, " Автомеханик (%g+) заправил ваш автомобиль на 300 за (%d+) вирт")
        WriteText = os.date("%X", os.time()) .. " | Заправка " .. Z2 .. "\n"
        Write = 1
    end
    if Log == 7 then
        local Z1 = string.match(message, " Машина заправлена, за: (%d+) вирт")
        WriteText = os.date("%X", os.time()) .. " | Заправка " .. Z1 .. "\n"
        Write = 1
    end
    if Log == 8 then
        local Z1 = string.match(message, " Вы купили канистру с 50 литрами бензина за (%d+) вирт")
        WriteText = os.date("%X", os.time()) .. " | Покупка канистры " .. Z1 .. "\n"
        Write = 1
    end
    if Write > 0 then
        local adress = AdressLogFolder .. os.date("%d.%m.%Y") .. ".txt"
        if Write == 1 then
            file = io.open(adress, "a")
            file:write(WriteText)
            file:flush()
            io.close(file)
        end
        if Write == 2 then
            file = io.open(adress, "r")
            local fileText = ""
            if file ~= nil then
                for line in file:lines() do
                    if line ~= log_save_text then
                        fileText = fileText .. line .. "\n"
                    end
                end
                io.close(file)
            end
            file = io.open(adress, "w")
            file:write(fileText .. WriteText)
            file:flush()
            io.close(file)
        end
        ReadLog()
    end
end

function ReadLog(is, ss)
    local logs = {
        arenda = 0,
        arendah = 0,
        zagruzka = 0,
        zagruzkah = 0,
        razgruzka = 0,
        razgruzkah = 0,
        pribil = 0,
        pribilh = 0,
        shtraf = 0,
        shtrafh = 0,
        repair = 0,
        repairh = 0,
        refill = 0,
        refillh = 0,
        reys = 0,
        reysh = 0,
        kanistr = 0,
        kanistrh = 0
    }
    if is == nil then
        adress = AdressLogFolder .. os.date("%d.%m.%Y") .. ".txt"
    else
        adress = is
    end
    local file = io.open(adress, "r")
    if file ~= nil then
        local time = os.date("%X", os.time())
        local H, M, S = string.match(time, "(%d+):(%d+):(%d+)")
        for line in file:lines() do
            if string.find(line, "Аренда") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Аренда (%d+)")
                local time = os.date("%X", os.time())
                local H, M, S = string.match(time, "(%d+):(%d+):(%d+)")
                if H == H1 then
                    logs.arendah = logs.arendah + A
                    logs.arenda = logs.arenda + A
                else
                    logs.arenda = logs.arenda + A
                end
            end
            if string.find(line, "Загрузка") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Загрузка (%d+)")
                if H == H1 then
                    logs.zagruzkah = logs.zagruzkah + A
                    logs.zagruzka = logs.zagruzka + A
                else
                    logs.zagruzka = logs.zagruzka + A
                end
            end
            if string.find(line, "Разгрузка") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Разгрузка (%d+)")
                if H == H1 then
                    logs.reys = logs.reys + 1
                    logs.reysh = logs.reysh + 1
                    logs.razgruzkah = logs.razgruzkah + A
                    logs.razgruzka = logs.razgruzka + A
                else
                    logs.reys = logs.reys + 1
                    logs.razgruzka = logs.razgruzka + A
                end
            end
            if string.find(line, "Заработано") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Заработано (%d+)")
                if H == H1 then
                    logs.pribilh = logs.pribilh + A
                    logs.pribil = logs.pribil + A
                else
                    logs.pribil = logs.pribil + A
                end
            end
            if string.find(line, "Штраф") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Штраф (%d+)")
                if H == H1 then
                    logs.shtrafh = logs.shtraf + A
                    logs.shtraf = logs.shtraf + A
                else
                    logs.shtraf = logs.shtraf + A
                end
            end
            if string.find(line, "Ремонт") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Ремонт (%d+)")
                if H == H1 then
                    logs.repairh = logs.repairh + A
                    logs.repair = logs.repair + A
                else
                    logs.repair = logs.repair + A
                end
            end
            if string.find(line, "Заправка") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Заправка (%d+)")
                if H == H1 then
                    logs.refillh = logs.refillh + A
                    logs.refill = logs.refill + A
                else
                    logs.refill = logs.refill + A
                end
            end
            if string.find(line, "Покупка канистры") then
                local H1, M1, S1, A = string.match(line, "(%d+):(%d+):(%d+) | Покупка канистры (%d+)")
                if H == H1 then
                    logs.kanistrh = logs.kanistrh + A
                    logs.kanistr = logs.kanistr + A
                else
                    logs.kanistr = logs.kanistr + A
                end
            end
        end
        io.close(file)
    end
    if is == nil then
        log.ReysH = logs.reysh
        log.Reys = logs.reys
        log.ZPH = logs.pribilh
        log.ZP = logs.pribil
        log.PribH =
            logs.razgruzkah - logs.zagruzkah - logs.shtrafh - logs.repairh - logs.refillh - logs.arendah - logs.kanistrh
        log.Prib = logs.razgruzka - logs.zagruzka - logs.shtraf - logs.repair - logs.refill - logs.arenda - logs.kanistr
        log.ZatrH = log.ZPH - log.PribH
        log.Zatr = log.ZP - log.Prib
    else
        local prib =
            logs.razgruzka - logs.zagruzka - logs.shtraf - logs.repair - logs.refill - logs.arenda - logs.kanistr
        local text =
            "{FFFFFF}     Статистика за сутки\n Рейсов сделано: " ..
            logs.reys ..
                "\n Зарплаты получено: " ..
                    logs.pribil ..
                        "$\n Прибыль: " ..
                            prib ..
                                "$\n\n\tЗатраты\n Аренда: " ..
                                    logs.arenda ..
                                        "$\n Заправка: " ..
                                            logs.refill ..
                                                "$\n Починка: " ..
                                                    logs.repair ..
                                                        "$\n Канистры: " ..
                                                            logs.kanistr ..
                                                                "$\n Штрафы: " ..
                                                                    logs.shtraf ..
                                                                        "$\n Все затраты: " ..
                                                                            (logs.arenda + logs.refill + logs.repair +
                                                                                logs.kanistr +
                                                                                logs.shtraf) ..
                                                                                "$"
        ShowDialog1(6, text, ss)
    end
end

function isTruckCar()
    if isCharInModel(PLAYER_PED, 403) or isCharInModel(PLAYER_PED, 514) or isCharInModel(PLAYER_PED, 515) then
        return true
    else
        return false
    end
end

function sampev.onSendChat(message)
    antiflood = os.clock() * 1000
end
function sampev.onSendCommand(cmd)
    local command, params = string.match(cmd, "^%/([^ ]*)(.*)")
    if command ~= nil and command:lower() == "coord" then
        local X, Y, Z = getCharCoordinates(PLAYER_PED)
        Z = getGroundZFor3dCoord(X, Y, Z)
        setClipboardText(X .. ", " .. Y .. ", " .. Z)
    end
    if command ~= nil and params ~= nil and command:lower() == "truck" then
        if params:lower() == " ad" then
            inifiles.Settings.ad = not inifiles.Settings.ad
            inicfg.save(inifiles, AdressIni)
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
                    downloadUrlToFile(
                        "https://raw.githubusercontent.com/Serhiy-Rubin/TruckHUD/master/changelog",
                        fpath,
                        function(id, status, p1, p2)
                            if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                                local f = io.open(fpath, "r")
                                if f then
                                    local text = f:read("*a")
                                    if text ~= nil then
                                        --Utf8ToAnsi(text)
                                        sampShowDialog(222, "Обновления TruckHUD", "{FFFFFF}" .. text, "Закрыть", "", 0)
                                    end
                                    io.close(f)
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
            inicfg.save(inifiles, AdressIni)
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
                inicfg.save(inifiles, AdressIni)
            end
        else
            if inifiles.Price.Load >= 0 and inifiles.Price.Load < 900 then
                inifiles.Price.Load = inifiles.Price.Load + 100
                inicfg.save(inifiles, AdressIni)
            end
        end
    else
        if workload == 1 then
            if inifiles.Price.UnLoad > 0 and inifiles.Price.UnLoad <= 900 then
                inifiles.Price.UnLoad = inifiles.Price.UnLoad - 100
                inicfg.save(inifiles, AdressIni)
            end
        else
            if inifiles.Price.Load > 0 and inifiles.Price.Load <= 900 then
                inifiles.Price.Load = inifiles.Price.Load - 100
                inicfg.save(inifiles, AdressIni)
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
            renderFontDrawText(font, text, posX, posY, "0x70" .. inifiles.Render.Color2)
            if isKeyJustPressed(1) and (control or sampIsChatInputActive()) then
                return true
            else
                return false
            end
        end
    else
        return false
    end
end

function onScriptTerminate()
    for k, v in pairs(pickupLoad) do
        if v.pickup ~= nil then
            if doesPickupExist(v.pickup) then
                removePickup(v.pickup)
                v.pickup = nil
            end
        end
    end
    deleteMarkers()
end

--------------------------------------------------------------------------------
--------------------------------------GMAP--------------------------------------
--------------------------------------------------------------------------------
function transponder()
    while true do
        wait(0)
        if pair_mode and pair_mode_name ~= nil then
            delay_start = os.time()
            wait(inifiles.transponder.delay)
            if getActiveInterior() == 0 then
                request_table = {}
                local ip, port = sampGetCurrentServerAddress()
                local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                x, y, z = getCharCoordinates(playerPed)

                request_table["info"] = {
                    server = ip .. ":" .. tostring(port),
                    sender = sampGetPlayerNickname(myid),
                    pos = {x = x, y = y, z = z},
                    heading = getCharHeading(playerPed),
                    health = getCharHealth(playerPed),
                    pair_name = pair_mode_name
                }

                collecting_data = false
                wait_for_response = true
                local response_path = os.tmpname()
                down = false
                downloadUrlToFile(
                    "http://185.204.2.156:43136/" .. encodeJson(request_table),
                    response_path,
                    function(id, status, p1, p2)
                        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                            down = true
                        end
                        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                            wait_for_response = false
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
                        local info = decodeJson(f:read("*a"))
                        if info == nil then
                            sampAddChatMessage(
                                "{ff0000}[" ..
                                    string.upper(thisScript().name) ..
                                        "]: Был получен некорректный ответ от сервера. Работа скрипта завершена.",
                                0x348cb2
                            )
                        else
                            if info.result == "ok" then
                                response_timestamp = info.timestamp
                                if info.data ~= nil then
                                    pair_status = 200
                                    pair_timestamp = info.timestamp
                                    pair_table = info.data
                                end
                            elseif info.result == "error" then
                                if info.reason ~= nil then
                                    if info.reason == 403 then
                                        pair_status = 403
                                        sampfuncsLog("ваш напарник уже спарился с кем-то другим")
                                    end
                                    if info.reason == 404 then
                                        pair_status = 404
                                        sampfuncsLog("ваш напарник не найден на сервере, может он не спарился с вами?")
                                    end
                                end
                            end
                            wait_for_response = false
                        end
                        f:close()
                        --setClipboardText(response_path)
                        os.remove(response_path)
                    end
                else
                    print(
                        "{ff0000}[" ..
                            string.upper(thisScript().name) ..
                                "]: Мы не смогли получить ответ от сервера. Возможно слишком много машин, проблема с интернетом, сервер упал.",
                        0x348cb2
                    )
                end
                if doesFileExist(response_path) then
                    os.remove(response_path)
                end
                processing_response = false
            end
        end
    end
end

function count_next()
    if getActiveInterior() == 0 then
        local count = math.floor(settings.transponder.delay / 1000) - tonumber(os.time() - delay_start)
        if count >= 0 then
            return tostring(count) .. "c"
        elseif wait_for_response then
            return "WAITING FOR RESPONSE"
        elseif processing_response then
            return "PROCESSING RESPONSE"
        else
            return "PERFOMING REQUEST"
        end
    else
        return "выйди из инт"
    end
end

active = false
mapmode = 1
modX = 2
modY = 2

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
    dn("waypoint.png")
    dn("matavoz.png")
    dn("pla.png")

    for i = 1, 16 do
        dn(i .. ".png")
        dn(i .. "k.png")
    end

    player = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/pla.png")
    matavoz = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/matavoz.png")
    font = renderCreateFont("Impact", 8, 4)
    font10 = renderCreateFont("Impact", 10, 4)
    font12 = renderCreateFont("Impact", 12, 4)

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
    m1k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/1k.png")
    m2k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/2k.png")
    m3k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/3k.png")
    m4k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/4k.png")
    m5k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/5k.png")
    m6k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/6k.png")
    m7k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/7k.png")
    m8k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/8k.png")
    m9k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/9k.png")
    m10k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/10k.png")
    m11k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/11k.png")
    m12k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/12k.png")
    m13k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/13k.png")
    m14k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/14k.png")
    m15k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/15k.png")
    m16k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/TruckHUD/16k.png")
    if resX > 1024 and resY >= 1024 then
        bX = (resX - 1024) / 2
        bY = (resY - 1024) / 2
        size = 1024
    elseif resX > 720 and resY >= 720 then
        bX = (resX - 720) / 2
        bY = (resY - 720) / 2
        size = 720
    else
        bX = (resX - 512) / 2
        bY = (resY - 512) / 2
        size = 512
    end
end

function fastmap()
    if not sampIsChatInputActive() and isKeyDown(0xA4) then
        while isKeyDown(77) or isKeyDown(188) do
            wait(0)

            x, y = getCharCoordinates(playerPed)
            if not sampIsChatInputActive() and wasKeyPressed(0x4B) then
                inifiles.map.sqr = not inifiles.map.sqr
                inicfg.save(inifiles, AdressIni)
            end
            if isKeyDown(77) then
                mapmode = 0
            elseif isKeyDown(188) or mapmode ~= 0 then
                mapmode = getMode(modX, modY)
                if wasKeyPressed(0x25) then
                    if modY > 1 then
                        modY = modY - 1
                    end
                elseif wasKeyPressed(0x27) then
                    if modY < 3 then
                        modY = modY + 1
                    end
                elseif wasKeyPressed(0x26) then
                    if modX < 3 then
                        modX = modX + 1
                    end
                elseif wasKeyPressed(0x28) then
                    if modX > 1 then
                        modX = modX - 1
                    end
                end
            end
            if mapmode == 0 or mapmode == -1 then
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

                renderDrawBoxWithBorder(bX, bY + size - size / 42, size, size / 42, -1, 2, -2)

                if pair_table ~= {} then
                    if pair_status == 200 then
                        local status_string =
                            string.format(
                            "UPD: %s || STATUS: %s || Напарник: %s, он спарен с {%s}. Последние данные от напарника: %sc",
                            count_next(),
                            pair_status,
                            pair_table["sender"],
                            pair_table["pair_name"],
                            response_timestamp - pair_timestamp
                        )
                    elseif pair_status == 403 then
                        local status_string =
                            string.format(
                            "UPD: %s || STATUS: %s || Напарник: %s спаривается с кем-то другим",
                            count_next(),
                            pair_status,
                            pair_table["sender"]
                        )
                    elseif pair_status == 404 then
                        local status_string =
                            string.format(
                            "UPD: %s || STATUS: %s || Напарник: %s не найден на сервере",
                            count_next(),
                            pair_status,
                            pair_table["sender"]
                        )
                    end
                end

                renderFontDrawText(font10, status_string, bX, bY + size - size / 45, 0xFF00FF00)

                if size == 1024 then
                    iconsize = 16
                end
                if size == 720 then
                    iconsize = 12
                end
                if size == 512 then
                    iconsize = 10
                end
            else
                if size == 1024 then
                    iconsize = 32
                end
                if size == 720 then
                    iconsize = 24
                end
                if size == 512 then
                    iconsize = 16
                end
            end
            if mapmode == 1 then
                if inifiles.map.sqr then
                    renderDrawTexture(m9k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m13k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m14k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m9, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m13, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m14, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 2 then
                if inifiles.map.sqr then
                    renderDrawTexture(m10k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m14k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m15k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m10, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m14, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m15, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 3 then
                if inifiles.map.sqr then
                    renderDrawTexture(m11k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m12k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m15k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m16k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m11, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m12, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m15, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m16, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 4 then
                if inifiles.map.sqr then
                    renderDrawTexture(m5k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m9k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m5, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m9, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 5 then
                if inifiles.map.sqr then
                    renderDrawTexture(m6k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m6, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m10, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 6 then
                if inifiles.map.sqr then
                    renderDrawTexture(m7k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m8k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m12k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m7, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m8, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m11, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m12, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 7 then
                if inifiles.map.sqr then
                    renderDrawTexture(m1k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m2k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m5k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m1, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m2, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m5, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 8 then
                if inifiles.map.sqr then
                    renderDrawTexture(m2k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m3k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m2, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m3, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m6, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if mapmode == 9 then
                if inifiles.map.sqr then
                    renderDrawTexture(m3k, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m4k, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7k, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m8k, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                else
                    renderDrawTexture(m3, bX, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m4, bX + size / 2, bY, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m7, bX, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                    renderDrawTexture(m8, bX + size / 2, bY + size / 2, size / 2, size / 2, 0, 0xFFFFFFFF)
                end
            end
            if getQ(x, y, mapmode) or mapmode == 0 then
                renderDrawTexture(player, getX(x), getY(y), iconsize, iconsize, -getCharHeading(playerPed), -1)
            end
            if getQ(pair_table["data"]["pos"]["x"], pair_table["data"]["pos"]["y"], mapmode) or mapmode == 0 then
                color = 0xFFdedbd2
                if response_timestamp - pair_timestamp > 5 then
                    if mapmode == 0 then
                        renderFontDrawText(
                            font,
                            string.format("%.0f?", response_timestamp - pair_timestamp),
                            getX(pair_table["data"]["pos"]["x"]) + 17,
                            getY(pair_table["data"]["pos"]["y"]) + 2,
                            color
                        )
                    else
                        renderFontDrawText(
                            font12,
                            string.format("%.0f?", response_timestamp - pair_timestamp),
                            getX(pair_table["data"]["pos"]["x"]) + 31,
                            getY(pair_table["data"]["pos"]["y"]) + 4,
                            color
                        )
                    end
                end
                if pair_table["data"]["health"] ~= nil then
                    if mapmode == 0 then
                        renderFontDrawText(
                            font,
                            pair_table["data"]["health"] .. " hp",
                            getX(pair_table["data"]["pos"]["x"]) - 30,
                            getY(pair_table["data"]["pos"]["y"]) + 2,
                            color
                        )
                    else
                        renderFontDrawText(
                            font12,
                            pair_table["data"]["health"] .. " hp",
                            getX(pair_table["data"]["pos"]["x"]) -
                                string.len(pair_table["data"]["health"] .. " dl") * 9.4,
                            getY(pair_table["data"]["pos"]["y"]) + 4,
                            color
                        )
                    end
                end
                renderDrawTexture(
                    player,
                    getX(pair_table["data"]["pos"]["x"]),
                    getY(pair_table["data"]["pos"]["y"]),
                    iconsize,
                    iconsize,
                    -pair_table["data"]["heading"] + 90,
                    -1
                )
            end
        end
    end
end

function getMode(x, y)
    if x == 1 then
        if y == 1 then
            return 1
        end
        if y == 2 then
            return 2
        end
        if y == 3 then
            return 3
        end
    end
    if x == 2 then
        if y == 1 then
            return 4
        end
        if y == 2 then
            return 5
        end
        if y == 3 then
            return 6
        end
    end
    if x == 3 then
        if y == 1 then
            return 7
        end
        if y == 2 then
            return 8
        end
        if y == 3 then
            return 9
        end
    end
end

function getQ(x, y, mp)
    if mp == 1 then
        if x <= 0 and y <= 0 then
            return true
        end
    end
    if mp == 2 then
        if x >= -1500 and x <= 1500 and y <= 0 then
            return true
        end
    end
    if mp == 3 then
        if x >= 0 and y <= 0 then
            return true
        end
    end
    if mp == 4 then
        if x <= 0 and y >= -1500 and y <= 1500 then
            return true
        end
    end
    if mp == 5 then
        if x >= -1500 and x <= 1500 and y >= -1500 and y <= 1500 then
            return true
        end
    end

    if mp == 6 then
        if x >= 0 and y >= -1500 and y <= 1500 then
            return true
        end
    end

    if mp == 7 then
        if x <= 0 and y >= 0 then
            return true
        end
    end
    if mp == 8 then
        if x >= -1500 and x <= 1500 and y >= 0 then
            return true
        end
    end
    if mp == 9 then
        if x >= 0 and y >= 0 then
            return true
        end
    end
    return false
end

function getX(x)
    if mapmode == 0 then
        x = math.floor(x + 3000)
        return bX + x * (size / 6000) - iconsize / 2
    end
    if mapmode == 3 or mapmode == 9 or mapmode == 6 then
        return bX - iconsize / 2 + math.floor(x) * (size / 3000)
    end
    if mapmode == 1 or mapmode == 7 or mapmode == 4 then
        return bX - iconsize / 2 + math.floor(x + 3000) * (size / 3000)
    end
    if mapmode == 2 or mapmode == 8 or mapmode == 5 then
        return bX - iconsize / 2 + math.floor(x + 1500) * (size / 3000)
    end
end

function getY(y)
    if mapmode == 0 then
        y = math.floor(y * -1 + 3000)
        return bY + y * (size / 6000) - iconsize / 2
    end
    if mapmode == 7 or mapmode == 9 or mapmode == 8 then
        return bY + size - iconsize / 2 - math.floor(y) * (size / 3000)
    end
    if mapmode == 1 or mapmode == 3 or mapmode == 2 then
        return bY + size - iconsize / 2 - math.floor(y + 3000) * (size / 3000)
    end
    if mapmode == 4 or mapmode == 5 or mapmode == 6 then
        return bY + size - iconsize / 2 - math.floor(y + 1500) * (size / 3000)
    end
end
