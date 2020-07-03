script_name("locator")
script_author("qrlk")
script_version("27.06.2020")
script_description("Локатор машин для угонщиков")

local inicfg = require "inicfg"
local dlstatus = require("moonloader").download_status

select_car_dialog = {}
vhinfo = {}
request_model = -1
request_model_last = -1
marker_placed = false
response_timestamp = 0
ser_active = "?"
ser_count = "?"
delay_start = os.time()
color = 0x7ef3fa

settings =
    inicfg.load(
    {
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
    },
    "locator"
)
no_sampev = false
function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then
        return
    end

    while not isSampAvailable() do
        wait(100)
    end
    transponder_thread = lua_thread.create(transponder)

    init()

    while true do
        wait(0)
        fastmap()
    end
end


function transponder()
    while true do
        wait(0)
        delay_start = os.time()
        wait(settings.transponder.delay)
        if getActiveInterior() == 0 then
            request_table = {}
            local ip, port = sampGetCurrentServerAddress()
            local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
            request_table["info"] = {
                server = ip .. ":" .. tostring(port),
                sender = sampGetPlayerNickname(myid),
                request = request_model,
                allow_occupied = settings.transponder.allow_occupied,
                allow_unlocked = settings.transponder.allow_unlocked
            }
            request_table["vehicles"] = {}
            if doesCharExist(playerPed) then
                -- игнорируем ту машину, которой пользуемся, чтобы не воровали нашу машину
                local ped_car = getCarCharIsUsing(playerPed)
                for k, v in pairs(getAllVehicles()) do
                    if v ~= ped_car then
                        if doesVehicleExist(v) then
                            _res, _id = sampGetVehicleIdByCarHandle(v)
                            if _res then
                                _x, _y, _z = getCarCoordinates(v)
                                table.insert(
                                    request_table["vehicles"],
                                    {
                                        id = _id,
                                        pos = {
                                            x = _x,
                                            y = _y,
                                            z = _z
                                        },
                                        heading = getCarHeading(v),
                                        health = getCarHealth(v),
                                        model = getCarModel(v),
                                        occupied = doesCharExist(getDriverOfCar(v)),
                                        locked = getCarDoorLockStatus(v)
                                    }
                                )
                            end
                        end
                    end
                end
            end
            collecting_data = false
            wait_for_response = true
            local response_path = os.tmpname()
            down = false
            downloadUrlToFile(
                "http://locator.qrlk.me:46547/" .. encodeJson(request_table),
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
                        thisScript():unload()
                    else
                        if info.result == "ok" then
                            response_timestamp = info.timestamp
                            ser_active = info.active
                            ser_count = info.count
                            if info.response ~= nil then
                                if info.response == "no cars" then
                                    vhinfo = {}
                                    if settings.handler.clear_mark and marker_placed then
                                        removeWaypoint()
                                    end
                                else
                                    vhinfo = info.response
                                    if settings.handler.mark_coolest then
                                        mark_coolest_car()
                                    end
                                end
                            else
                                if settings.handler.clear_mark and marker_placed then
                                    removeWaypoint()
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
                            "]: Мы не смогли получить ответ от сервера. Возможно слишком много машин, проблема с интернетом, сервер упал или автор ТРАГИЧЕСКИ ПОГИБ.",
                    0x348cb2
                )
                print(
                    "{ff0000}[" ..
                        string.upper(thisScript().name) ..
                            "]: Если вы отключили автообновление, возможно поменялся айпи сервера. Включите его вручную в конфиге скрипта (папка config в ml).",
                    0x348cb2
                )
                print(
                    "{ff0000}[" ..
                        string.upper(thisScript().name) ..
                            "]: Если автор всё-таки кормит червей, возможно кто-то другой захостил у себя скрипт, погуглите.",
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



--------------------------------------------------------------------------------
--------------------------------------GMAP--------------------------------------
--------------------------------------------------------------------------------
active = false
mapmode = 1
modX = 2
modY = 2

function dn(nam)
    file = getGameDirectory() .. "\\moonloader\\resource\\locator\\" .. nam
    if not doesFileExist(file) then
        downloadUrlToFile("https://raw.githubusercontent.com/Serhiy-Rubin/locator/master/resource/locator/" .. nam, file)
    end
end

function init()
    if not doesDirectoryExist(getGameDirectory() .. "\\moonloader\\resource") then
        createDirectory(getGameDirectory() .. "\\moonloader\\resource")
    end
    if not doesDirectoryExist(getGameDirectory() .. "\\moonloader\\resource\\locator") then
        createDirectory(getGameDirectory() .. "\\moonloader\\resource\\locator")
    end
    dn("waypoint.png")
    dn("matavoz.png")
    dn("pla.png")

    for i = 1, 16 do
        dn(i .. ".png")
        dn(i .. "k.png")
    end

    player = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/pla.png")
    matavoz = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/matavoz.png")
    font = renderCreateFont("Impact", 8, 4)
    font10 = renderCreateFont("Impact", 10, 4)
    font12 = renderCreateFont("Impact", 12, 4)

    resX, resY = getScreenResolution()
    m1 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/1.png")
    m2 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/2.png")
    m3 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/3.png")
    m4 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/4.png")
    m5 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/5.png")
    m6 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/6.png")
    m7 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/7.png")
    m8 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/8.png")
    m9 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/9.png")
    m10 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/10.png")
    m11 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/11.png")
    m12 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/12.png")
    m13 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/13.png")
    m14 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/14.png")
    m15 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/15.png")
    m16 = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/16.png")
    m1k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/1k.png")
    m2k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/2k.png")
    m3k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/3k.png")
    m4k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/4k.png")
    m5k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/5k.png")
    m6k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/6k.png")
    m7k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/7k.png")
    m8k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/8k.png")
    m9k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/9k.png")
    m10k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/10k.png")
    m11k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/11k.png")
    m12k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/12k.png")
    m13k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/13k.png")
    m14k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/14k.png")
    m15k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/15k.png")
    m16k = renderLoadTextureFromFile(getGameDirectory() .. "/moonloader/resource/locator/16k.png")
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
                settings.map.sqr = not settings.map.sqr
                inicfg.save(settings, "locator")
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

                """renderFontDrawText(
                    font10,
                    string.format(
                        "UPD: %s || Текущая цель: %s   Найдено: %s   Активных источников: %s   Машин в базе: %s",
                        count_next(),
                        carsids[request_model],
                        #vhinfo,
                        ser_active,
                        ser_count
                    ),
                    bX,
                    bY + size - size / 45,
                    0xFF00FF00
                )"""

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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
                if settings.map.sqr then
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
            --renderDrawTexture(matavoz, getX(0), getY(0), 16, 16, 0, - 1)
            if getQ(x, y, mapmode) or mapmode == 0 then
                renderDrawTexture(player, getX(x), getY(y), iconsize, iconsize, -getCharHeading(playerPed), -1)
            end
            if
                settings.transponder.catch_srp_gz and gz_squareStart["x"] ~= nil and gz_squareEnd["y"] ~= nil and
                    (getQ(gz_squareStart["x"], gz_squareEnd["y"], mapmode) or mapmode == 0)
             then
                renderDrawBox(
                    getX(gz_squareStart["x"]) + iconsize / 2,
                    getY(gz_squareEnd["y"]) + iconsize / 2,
                    getX(gz_squareEnd["x"]) - getX(gz_squareStart["x"]),
                    getY(gz_squareStart["y"]) - getY(gz_squareEnd["y"]),
                    0x80FFFFFF
                )
            end

            for z, v1 in pairs(vhinfo) do
                if getQ(v1["pos"]["x"], v1["pos"]["y"], mapmode) or mapmode == 0 then
                    if v1["locked"] == 2 then
                        color = 0xFF00FF00
                    else
                        color = 0xFFdedbd2
                    end

                    if v1["occupied"] then
                        color = 0xFFFF0000
                    end

                    if response_timestamp - v1["timestamp"] > 2 then
                        if mapmode == 0 then
                            renderFontDrawText(
                                font,
                                string.format("%.0f?", response_timestamp - v1["timestamp"]),
                                getX(v1["pos"]["x"]) + 17,
                                getY(v1["pos"]["y"]) + 2,
                                color
                            )
                        else
                            renderFontDrawText(
                                font12,
                                string.format("%.0f?", response_timestamp - v1["timestamp"]),
                                getX(v1["pos"]["x"]) + 31,
                                getY(v1["pos"]["y"]) + 4,
                                color
                            )
                        end
                    end
                    if v1["health"] ~= nil then
                        if mapmode == 0 then
                            renderFontDrawText(
                                font,
                                v1["health"] .. " dl",
                                getX(v1["pos"]["x"]) - 30,
                                getY(v1["pos"]["y"]) + 2,
                                color
                            )
                        else
                            renderFontDrawText(
                                font12,
                                v1["health"] .. " dl",
                                getX(v1["pos"]["x"]) - string.len(v1["health"] .. " dl") * 9.4,
                                getY(v1["pos"]["y"]) + 4,
                                color
                            )
                        end
                    end
                    renderDrawTexture(
                        matavoz,
                        getX(v1["pos"]["x"]),
                        getY(v1["pos"]["y"]),
                        iconsize,
                        iconsize,
                        -v1["heading"] + 90,
                        -1
                    )
                end
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