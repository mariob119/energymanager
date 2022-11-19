import requests
import json

class Payload(object):
    def __init__(self, j):
        self.__dict__ = json.loads(j)

def get_config():
    with open("config.json", "r") as read_file:
        for line in read_file:
            data = line
    return data

def get_url():
    with open("url.json", "r") as read_file:
        for line in read_file:
            data = line
    data = Payload(data)
    url = data.url
    return url

p = Payload(get_config())
url = get_url() + '/getport'
uuid = {"uuid": p.uuid}

received_data = requests.post(url, json = uuid)

p = Payload(received_data.text)

if(p.port > 0):
    print("Geht")
else:
    print("Geht ned!")