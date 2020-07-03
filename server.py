#!/usr/bin/env python3
from aiohttp import web
from datetime import datetime
import urllib.parse
import time
import linecache
import json
import sys

try:
    sys.argv[1]
    int(sys.argv[1])
except IndexError:
    print("usage: python3 server3.py [DELAY (MS)]")
    sys.exit(0)

DELAY = int(sys.argv[1])

data = {}
async def handle(request):
    timer = time.time()
    info = json.loads(urllib.parse.unquote(request.path.replace("/","")))

    if info:
        if info["request"] == 1:
            ip = info["info"]["server"]
            sender = info["info"]["sender"]
            pos = info["info"]["pos"]
            heading = info["info"]["heading"]
            health = info["info"]["health"]
            pair_name = info["info"]["pair_mode_name"]
            is_truck = info["info"]["is_truck"]
            rabotaet = info["info"]["chtoto_randomnoe"]
            gruz = info["info"]["gruz"]
            print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Пришел запрос от {sender}. Скрипт работает: {rabotaet}с | Трак: {is_truck}, груз: {gruz} Координаты: {pos['x']}, {pos['y']}, {pos['z']}. Напарник: {pair_name}. Угол: {heading}, здоровье: {health}")
            if ip not in data:
                data[ip] = {}
                data[ip]["senders"] = {}
            if sender not in data[ip]["senders"]:
                data[ip]["senders"][sender] = {}
            data[ip]["senders"][sender]["timestamp"] = time.time()
            data[ip]["senders"][sender]["data"] = info["info"]

            if pair_name == "____":
                return web.Response(text=json.dumps({"result": "gotu"}))

            if pair_name in data[ip]["senders"]:
                if data[ip]["senders"][pair_name]["data"]["pair_mode_name"] == sender:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он спарен с {pair_name}. Отправлены данные: {json.dumps(data[ip]['senders'][pair_name])} Обработка заняла: {(time.time()-timer):.6f} с")
                    return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "data": data[ip]['senders'][pair_name], "delay": DELAY}))
                else:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, а {pair_name} уже спаривается с {data[ip]['senders'][pair_name]['data']['pair_mode_name']}. Обработка заняла: {(time.time()-timer):.6f} с")
                    return web.Response(text=json.dumps({"result": "error", "timestamp": time.time(), "reason": 403, "delay": DELAY}))
            else:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, но {pair_name} не найден в словаре сервера. Обработка заняла: {(time.time()-timer):.6f} с")
                return web.Response(text=json.dumps({"result": "error", "timestamp": time.time(), "reason": 404, "delay": DELAY}))
      
    return web.Response(text='error')


app = web.Application()
app.router.add_get('/{name}', handle)
web.run_app(app, host = '0.0.0.0', port=43136)

