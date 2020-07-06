#!/usr/bin/env python3
from sanic import Sanic
from sanic.response import json
from sanic.response import text
from sanic.exceptions import NotFound
from datetime import datetime
import urllib.parse
import time
import linecache
import json as js
import sys


try:
    sys.argv[1]
    int(sys.argv[1])
except IndexError:
    print("usage: python3 server3.py [DELAY (MS)]")
    sys.exit(0)

DELAY = int(sys.argv[1])

data = {}
app = Sanic()

@app.exception(NotFound)
async def handle(request, exception):
    timer = time.time()
    info = js.loads(urllib.parse.unquote(request.url[27:]))

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
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Напарника нет {pair_name}. Отправлена заглушка. Обработка заняла: {(time.time()-timer):.6f} с")
                return json({"result": "gotu"})

            if pair_name in data[ip]["senders"]:
                if data[ip]["senders"][pair_name]["data"]["pair_mode_name"] == sender:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он спарен с {pair_name}. Отправлены данные: {js.dumps(data[ip]['senders'][pair_name])} Обработка заняла: {(time.time()-timer):.6f} с")
                    return json({"result": "ok", "timestamp": time.time(), "data": data[ip]['senders'][pair_name], "delay": DELAY})
                else:
                    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, а {pair_name} уже спаривается с {data[ip]['senders'][pair_name]['data']['pair_mode_name']}. Обработка заняла: {(time.time()-timer):.6f} с")
                    return json({"result": "error", "timestamp": time.time(), "reason": 403, "delay": DELAY})
            else:
                print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Подготовлен ответ для {sender}. Он хочет спариться с {pair_name}, но {pair_name} не найден в словаре сервера. Обработка заняла: {(time.time()-timer):.6f} с")
                return json({"result": "error", "timestamp": time.time(), "reason": 404, "delay": DELAY})
        if info["request"] == 843:
            if info["server"] in data:
                temp = data[info["server"]]
                for item in temp["senders"].keys():
                    temp["senders"][item]["data"].pop("pos", None)
                return json({"data": temp})
            else:
                return text('error')
    return text('error')


if __name__ == '__main__':
        app.run(host='0.0.0.0', port=43136, access_log=False)
