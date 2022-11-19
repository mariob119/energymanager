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

if(p.serial_number == ""):
    r = requests.get(get_url() + "/registerdevice")
    print("Get new UUID, Serial Number and Device Name\n")
    data = Payload(r.text)
    print("Your UUID is: " + data.uuid)
    print("Your Serial Number is: " + data.serial_number)
    print("The Device Name is: " + data.device_name)
    with open("config.json", "w") as f:
        f.write(r.text)
else:
    data = get_config()
    config = Payload(data)
    print("Your UUID is: " + config.uuid)
    print("Your Serial Number is: " + config.serial_number)
    print("The Device Name is: " + config.device_name)