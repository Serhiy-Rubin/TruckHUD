#!/usr/bin/env python3
from aiohttp import web
from datetime import datetime
import urllib.parse
import time
import linecache
import json

data = {}
async def handle(request):
    timer = time.time()
    info = json.loads(urllib.parse.unquote(request.path.replace("/","")))

    if info:
        ip = info["info"]["server"]
        sender = info["info"]["sender"]
        pos = info["info"]["pos"]
        heading = info["info"]["heading"]
        health = info["info"]["health"]
        pair_name = info["info"]["pair_mode_name"]
        print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Пришел запрос от {sender}. Координаты: {x}, {y}, {z}. Напарник: {pair_name}. Угол: {heading}, здоровье: {health}")
        if ip not in data:
            data[ip] = {}
            data[ip]["senders"] = {}
        if sender not in data[ip]["senders"]:
            data[ip]["senders"][sender] = {}
        data[ip]["senders"][sender]["timestamp"] = time.time()
        data[ip]["senders"][sender]["data"] = info["info"]

        if pair_name in data[ip]["senders"]:
            if data[ip]["senders"][pair_name]["data"]["pair_name"] == sender:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он спарен с {pair_name}. Отправлены данные: {json.dumps(data[ip]['senders'][pair_name]['data'])} Обработка заняла: {(time.time()-timer):.6f} с")
                return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "data": data[ip]['senders'][pair_name]}))
            else:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, а {pair_name} уже спаривается с {data[ip]['senders'][pair_name]['data']['pair_name']}. Обработка заняла: {(time.time()-timer):.6f} с")
                return web.Response(text=json.dumps({"result": "error", "timestamp": time.time(), "reason": 403}))
        else:
            print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, но {pair_name} не найден в словаре сервера. Обработка заняла: {(time.time()-timer):.6f} с")
            return web.Response(text=json.dumps({"result": "error", "timestamp": time.time(), "reason": 404}))
    return web.Response(text='error')


app = web.Application()
app.router.add_get('/{name}', handle)
web.run_app(app, host = '0.0.0.0', port=43136)

