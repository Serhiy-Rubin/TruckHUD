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
    info = json.loads(urllib.parse.unquote(request.path.replace("/", "")))
    if info:
        timer = time.time()
        ip = info["info"]["server"]
        sender = info["info"]["sender"]
        request_model = info["info"]["request"]
        allow_occupied = info["info"]["allow_occupied"]
        allow_unlocked = info["info"]["allow_unlocked"]
        print(
            f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: ������ ������ �� {sender}. �� ������� ���������� � {len(info['vehicles'])} �/� � �������� ���������� ���������� � model {request_model}. allow_unlocked: {allow_unlocked}, allow_occupied: {allow_occupied}")
        if ip not in data:
            data[ip] = {}
            data[ip]["vehicles"] = {}
            data[ip]["senders"] = {}
        if time.time() - last_clear > 400:
            print(
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: �������� �������")
            del_list = []
            last_clear = time.time()
            for k, v in data[ip]["vehicles"].items():
                if int(time.time()) - v["timestamp"] > 360:
                    print(
                        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Vehicle {k} ������ � ������ ������")
                    del_list.append(k)
            for item in del_list:
                del data[ip]["vehicles"][item]
                print(
                    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: ��������� � ID {item} ������")
            del_list = []
            for k, v in data[ip]["senders"].items():
                print(k, v)
                if int(time.time()) - v > 360:
                    print(
                        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Sender {k} �������� � ������ ��������")
                    del_list.append(k)
            for item in del_list:
                del data[ip]["senders"][item]
                print(
                    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: Sender {item} ������")
        data[ip]["senders"][sender] = time.time()
        for item in info["vehicles"]:
            item["timestamp"] = time.time()
            data[ip]["vehicles"][item["id"]] = item
        print(
            f"""{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: �������� ��������: {len(data[ip]["senders"])}, �����: {len(data[ip]["vehicles"])}""")
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
                print(
                    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: ����������� ����� ��� {sender}. �� ����� model {request_model}, �� �� �� �������. (����: {allow_unlocked}, ���: {allow_occupied}). ��������� ������: {time.time()-timer}:.6f �")
                return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"]), "response": "no cars"}))
            else:
                print(
                    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: ����������� ����� ��� {sender}. �� ����� model {request_model}, �� ����� {len(response_cars)} ���������. (����: {allow_unlocked}, ���: {allow_occupied}). ��������� ������: {time.time()-timer}:.6f �")
                return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(), "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"]), "response": response_cars}))
        else:
            print(
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S || ')}[{ip}]: ����������� ����� ��� {sender}. �� �� ���������� ������. ��������� ������: {(time.time()-timer):.6f} �")
            return web.Response(text=json.dumps({"result": "ok", "timestamp": time.time(),  "active": len(data[ip]["senders"]), "count": len(data[ip]["vehicles"])}))
    return web.Response(text='error')


app = web.Application()
app.router.add_get('/{name}', handle)
web.run_app(app, host='0.0.0.0', port=46547)
