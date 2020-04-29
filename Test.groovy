import groovy.json.JsonOutput

String ReadImg(String path) {
    def file = new File(path)
    def bytes = file.bytes
    def base64Str = bytes.encodeBase64Url().toString()
    return base64Str
}

void SendMessage(String title, String desc, String url_desc, String imageCode, String image_name) {
    data = [
            "to_user_list": {},
            "to_chat_name": "平台功能组",
            "msg_content": [
                    "title"   : title,
                    "desc"    : desc,
                    "url_desc": url_desc,
                    "url"     : "http://git.jx2.bjxsj.site/pirate/SwordGame",
                    "image"   : [
                            "name"  : image_name,
                            "data"  : imageCode,
                            "width" : 300,
                            "height": 300
                    ]
            ]
    ]

    String json = JsonOutput.toJson(data)
    println JsonOutput.prettyPrint(json)

    try{
        String body = json
        httpRequest consoleLogResponseBody: true, contentType: 'APPLICATION_JSON', httpMode: 'POST', requestBody: "${body}", responseHandle: 'NONE', url: 'http://10.89.128.227:8080/api/larkrelay/sendmsg'
    }catch (any) {
        println "Send Failed"
        println any
    }
}

def imgCode = ReadImg("./1.png")
SendMessage("LuaCheck结果", "请各位尽快修复LuaCheck检查结果", "点击打开Git", imgCode, "checker.jpg")