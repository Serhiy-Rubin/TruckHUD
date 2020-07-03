#!/usr/bin/env python3
from aiohttp import web
from datetime import datetime
import urllib.parse
import time
import linecache
import json

data = {}
last_clear = time.time()
async def handle(request):
    timer = time.time()
    global last_clear
    global vehicles
    info = json.loads(urllib.parse.unquote(request.path.replace("/","")))
    if info:
        timer = time.time()
        ip = info["info"]["server"]
        sender = info["info"]["sender"]
        request_model = info["info"]["request"]
        allow_occupied = info["info"]["allow_occupied"]
        allow_unlocked = info["info"]["allow_unlocked"]
        print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Пришел запрос от {sender}. Он передал информацию о {len(info['vehicles'])} т/с и запросил координаты транспорта с model {request_model}. allow_unlocked: {allow_unlocked}, allow_occupied: {allow_occupied}")
        if ip not in data:
            data[ip] = {}
            data[ip]["vehicles"] = {}
            data[ip]["senders"] = {}
        if time.time() - last_clear > 400:
            print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Запускаю очистку")
            del_list = []
            last_clear = time.time()
            for k, v in data[ip]["vehicles"].items():
                if int(time.time()) - v["timestamp"] > 360:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Vehicle {k} теперь в списке смерти")
                    del_list.append(k)
            for item in del_list:
                del data[ip]["vehicles"][item]
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Транспорт с ID {item} удален")
            del_list = []
            for k, v in data[ip]["senders"].items():
                print(k,v)
                if int(time.time()) - v > 360:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Sender {k} добавлен в список удаления")
                    del_list.append(k)
            for item in del_list:
                del data[ip]["senders"][item]
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Sender {item} удален")
        data[ip]["senders"][sender] = time.time()
        for item in info["vehicles"]:
            item["timestamp"] = time.time()
            data[ip]["vehicles"][item["id"]] = item
        print(f"""{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Активных сендеров: {len(data[ip]["senders"])}, машин: {len(data[ip]["vehicles"])}""")
        if request_model != -1:
            response_cars = []
            for k, item in data[ip]["vehicles"].items():
                if item["model"] == request_model:
                    if item["occupied"] and not allow_occupied:
                        continue
                    if not item["locked"] and not allow_unlocked:
                        continue
                    response_cars.append(item)
            if response_cars == []:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хотел model {request_model}, но их не нашлось. (ОТКР: {allow_unlocked}, ЗАН: {allow_occupied}). Обработка заняла: {(time.time()-timer):.6f} с")
                return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"]), "response": "no cars"}))
            else:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хотел model {request_model}, мы нашли {len(response_cars)} вариантов. (ОТКР: {allow_unlocked}, ЗАН: {allow_occupied}). Обработка заняла: {(time.time()-timer):.6f} с")
                return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"]), "response": response_cars}))
        else:
            print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он не запрашивал машину. Обработка заняла: {(time.time()-timer):.6f} с")
            return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(),  "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"])}))
    return web.Response(text='error')


app = web.Application()
app.router.add_get('/{name}', handle)
web.run_app(app, host = '0.0.0.0', port=43136)

