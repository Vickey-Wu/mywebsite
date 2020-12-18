---
title: "zabbix使用自定义脚本"
date: 2018-12-18T03:10:06Z
description:  "zabbix使用自定义脚本"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/E356E5CED4294D23888BCE36326FD4D0?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "zabbix"
  - "python"
tags:
  - "zabbix"
  - "python"
---

#### 服务端自定义脚本配置

zabbix_agentd配置文件
/etc/zabbix/zabbix-agentd.conf
```
Timeout=30
AllowRoot=1
Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf
UnsafeUserParameters=1
```
zabbix_agentd自定义脚本存在处
```
/etc/zabbix/bin
e.g: /etc/zabbix/bin/interface_monitor.py
```
zabbix_server配置文件
```
/etc/zabbix/zabbix_server.conf
default:/usr/local/src/zabbix-3.4.5/conf/zabbix_server.conf
```
zabbix_server.conf定义server脚本存放处
```
DBHost=
DBName=
DBUser=
DBPassword=
DBPort=
LogSlowQueries=3000
AlertScriptsPath=/home/zabbix/alertscripts
e.g:/home/zabbix/alertscripts/phone.py      //phone.py见下
```
agentd调用自定义脚本配置文件存放处
```
/etc/zabbix/zabbix_agentd.conf.d
e.g: /etc/zabbix/zabbix_agentd.conf.d/interface.conf
```
interface.conf, 监控项键值调用格式（详见下面`在监控项应用自定义脚本`截图）`e.g: interface.url[link_key1]`
```
UserParameter=interface.url[*],/usr/bin/python /etc/zabbix/bin/interface_monitor.py $1 $2 ...
```

- interface_monitor.py
```
#!/usr/bin/python
# -*- coding: UTF-8 -*-
"""
获取linux服务器输入参数argv，根据argv在字典找到对应要监控的接口链接作为参数传入相应的函数验证状态，
如果链接返回参数是正常的则返回1，否则返回0，zabbix前台"报警媒介类型"创建使用脚本dingding.py发送告警信息到钉钉，
严重的打电话phone.py
"""
import json
import urllib2
import re
import requests
import sys


def get_status(interface_url):
    """
    :param interface_url:
    :return:
    """
    pre = re.findall("http://", interface_url)
    if not pre:
        interface_url = "http://" + interface_url
    try:
        response = urllib2.urlopen(interface_url, timeout=5)
    except:
        return 0
    try:
        status = json.loads(response.read())["status"]
        if status == "UP":
            return 1
        else:
            return 0
    except:
        return 0


def main():
    interface_dict = {"link1": "api/link1",
                      "link2": "api/link2",
                      "test": "api/test.xml",
    # get linux os input arg
    try:
        interface = sys.argv[1]
    except:
        print(0)
        return 0
    if interface != "" and interface in interface_dict.keys():
        if interface == "live" or interface == "live-https":
            status = xml_status(interface_dict[interface])
        else:
            status = get_status(interface_dict[interface])
        print(status)
        return status
    else:
        print(0)
        return 0

if __name__ == '__main__':
    main()
```
- dingding.py
```
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import requests
import json
import os
import sys
# 这个是钉钉群组的机器人
access_token = '***'


def get_token():
    url_token = 'https://oapi.dingtalk.com/robot/send?access_token=%s' % access_token
    return url_token


# url钉钉群机器人链接 content：要发送的告警信息
def send_notification(url, content):
    '''
    msgtype : 类型
    content : 内容
    '''
    msgtype = 'text'
    values = {
        "msgtype": "text",
        msgtype: {
            "content": content
        },
        "at": {
            "atMobiles": ["188888888888"]
        },
    }
    headers = {"Content-Type": "application/json; charset=UTF-8"}
    values = json.dumps(values)
    res = requests.post(url, values, headers=headers)
    errmsg = json.loads(res.text)['errmsg']
    if errmsg == 'ok':
        return "ok"
    return "fail: %s" % res.text


if __name__ == '__main__':
    url_token = get_token()
    content = '\n'.join(sys.argv[2:])       # 接受传入参数作为发送的信息
    print(sys.argv[2:])
    if not content:
        content = '测试'
    print send_notification(url_token, content)
```
- phone.py

```
#!/usr/bin/python
#-*- coding:utf-8 -*-
from qcloudsms_py import SmsVoicePromptSender
from qcloudsms_py.httpclient import HTTPError

phone_numbers = ["18888888888"]
result = ''
vpsender = SmsVoicePromptSender('***', '****')
try:
    result = vpsender.send("86", phone_numbers[0], 2, "云服务器:server,网站异常,故障原因:网站故障,及时跟进处理", 2)
except HTTPError as e:
    print(e)
except Exception as e:
    print(e)

print(result['errmsg'])
```

>`https://pypi.org/project/qcloudsms-py/`

#### 客户端自定义脚本配置

设置自定义脚本参数

![alarm-media-config](https://note.youdao.com/yws/api/personal/file/E9E4A607D05E4476A3B8A5EA06B15416?method=download&shareKey=1f419c60b8293e9b102e9f2ecb021f88)

在监控项应用自定义脚本，监控项键值调用格式需要与上面服务端agentd调用自定义脚本配置文件一致。`e.g: interface.url[link_key1]`

![use-script-in-monitor-item](https://note.youdao.com/yws/api/personal/file/24AAFD02426E43A6AECA99381003129D?method=download&shareKey=5bac38042d11a655962c11c49f6b984a)

在触发器应用自定义脚本

![use-script-in-monitor-trigger](https://note.youdao.com/yws/api/personal/file/52F77B3510964776B9BB8FACEA56EEF8?method=download&shareKey=0b5cb25d737b98423f63eef9f64d9272)
