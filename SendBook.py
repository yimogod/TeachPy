import requests
import json
from urllib import request

APP_ID = "cli_9e2b196f8837d00e"
APP_SECRET = "NhCkgLTQTD7Z6IPj7xBPwfjtEkIiqDqi"

def get_tenant_access_token():
        url = "http://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal/"
        headers = {
            "Content-Type" : "application/json"
        }
        req_body = {
            "app_id": APP_ID,
            "app_secret": APP_SECRET
        }

        data = bytes(json.dumps(req_body), encoding='utf8')
        req = request.Request(url=url, data=data, headers=headers, method='POST')
        try:
            response = request.urlopen(req)
        except Exception as e:
            print(e.read().decode())
            return ""

        rsp_body = response.read().decode('utf-8')
        rsp_dict = json.loads(rsp_body)
        code = rsp_dict.get("code", -1)
        if code != 0:
            print("get tenant_access_token error, code =", code)
            return ""
        return rsp_dict.get("tenant_access_token", "")

def upload_image(token, image_path):
    """上传图片
    Args:
        image_path: 文件上传路径
        image_type: 图片类型
    Return
        {
            "ok": true,
            "image_key": "xxx",
            "url": "https://xxx"
        }
    Raise:
        Exception
            * file not found
            * request error
    """
    with open(image_path, 'rb') as f:
        image = f.read()

    resp = requests.post(
        url="https://open.feishu.cn/open-apis/image/v4/put/",
        headers={ "Authorization": "Bearer " + token},
        files={
            "image": image
        },
        data={
            "image_type": "message"
        },
        stream=True)

    content = resp.json()

    if content.get("code") == 0:
        return content.get("data")["image_key"]
    else:
        raise Exception("Call Api Error, errorCode is %s" % content["code"])

def get_chat(token):
    resp = requests.get(
        url="https://open.feishu.cn/open-apis/chat/v4/list?page_size=20",
        headers={ "Authorization": "Bearer " + token},
        )
    content = resp.json()
    print(content)
    groups = content.get("data")["groups"]
    for g in groups:
        if g["name"] == "剑二程序群":
            return g["chat_id"]
    return None

def send_message(token, image_key):
    resp = requests.post(
        url="https://open.feishu.cn/open-apis/message/v4/send/",
        headers={"Content-Type" : "application/json", "Authorization": "Bearer " + token},
        data={
            "msg_type": "image",
            "email": "liuzhibin@kingsoft.com",
            "content": {
                "text": "hello",
                "image_key": image_key,
            },
        })

    content = resp.json()
    print(content)

def send_message2(token, image_key, chat_id):
        url = "http://open.feishu.cn/open-apis/message/v4/send/"

        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + token
        }
        req_body = {
            "chat_id": chat_id,
            "msg_type": "image",
            "content": {
                "chat_id": chat_id,
                "text": "helloworld",
                "image_key": image_key,
            },
        }

        data = bytes(json.dumps(req_body), encoding='utf8')
        req = request.Request(url=url, data=data, headers=headers, method='POST')
        try:
            response = request.urlopen(req)
        except Exception as e:
            print(e.read().decode())
            return

        rsp_body = response.read().decode('utf-8')
        rsp_dict = json.loads(rsp_body)
        code = rsp_dict.get("code", -1)
        if code != 0:
            print("send message error, code = ", code, ", msg =", rsp_dict.get("msg", ""))


access_token = get_tenant_access_token()
image_key = upload_image(access_token, "./1.png")
#image_key = "img_32a63ed8-5d0f-4957-a421-280d713a4dfg"
print(image_key)
#chat_id 固定的. 获取玩一次就可以了 
#chat_id = get_chat(access_token)
#print(chat_id)
chat_id = "oc_f4113243b2e5526d52eb0e571fc0eab2"
send_message2(access_token, image_key, chat_id)

