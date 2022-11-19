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
current_port = p.port

received_data = requests.post(url, json = uuid)

p = Payload(received_data.text)
new_port = p.port

if(current_port != new_port):
    data = get_config()
    config = Payload(data)
    new_config = "{\"uuid\":\"" + data.uuid + "\", \"serial_number\":\"" + data.serial_number + "\", \"device_name\":\"" + data.device_name + "\",\"port\":\"" + str(new_port) + "\"}"
    f = open("config.json", "w")
    f.write(new_config)
    f.close()