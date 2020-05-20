---
title: "scrapy基本用法"
date: 2019-07-08T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/CC82F34E4CAB458F913FD79C5ED2FDA1?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "scrapy"
tags:
  - "scrapy"
  - "docker"
---

#### 前言

>reference: `https://www.tutorialspoint.com/scrapy/scrapy_quick_guide.htm`

>offical doc: `http://doc.scrapy.org/en/1.0/intro/tutorial.html`

#### 安装

>reference: `http://doc.scrapy.org/en/1.0/intro/install.html#intro-install`

- 启动个容器安装scrapy(耗时比较长)

```
root@ubuntu:/home/vickey# docker run -itd --name test-scrapy ubuntu
root@ubuntu:/home/vickey# docker exec -it test-scrapy /bin/bash
root@8b825656f58b:/# apt-get update
...
root@8b825656f58b:/# apt-get install python-dev python-pip libxml2-dev libxslt1-dev zlib1g-dev libffi-dev libssl-dev
...
root@8b825656f58b:/# pip install scrapy
...
root@8b825656f58b:/# scrapy -v 
Scrapy 1.6.0 - no active project
...
```

- 还可以直接用本人做好的镜像: vickeywu/scrapy-python3

```
root@ubuntu:/home/vickey# docker pull vickeywu/scrapy-python3
Using default tag: latest
latest: Pulling from vickeywu/scrapy-python3
Digest: sha256:e1bdf37f93ac7ced9168a7a697576ce905e73fb4775f7cb80de196fa2df5a549
Status: Downloaded newer image for vickeywu/scrapy-python3:latest
root@ubuntu:/home/vickey# docker run -itd --name test-scrapy vickeywu/scrapy-python3
```

#### 相关命令

- 创建项目：`scrapy startproject scrapy_project_name`
- 创建项目爬虫(需先进入`scrapy_project_name`目录)：`scrapy genspider spider_name domain_name.com`
- 运行项目爬虫(需先进入`scrapy_project_name`目录)：`scrapy crawl spider_name`
- 使用`scrapy -h`查看更多命令。如下：

```
root@2fb0da64a933:/home/test_scrapy# scrapy -h
Scrapy 1.5.0 - project: test_scrapy

Usage:
  scrapy <command> [options] [args]

Available commands:
  bench         Run quick benchmark test
  check         Check spider contracts
  crawl         Run a spider
  edit          Edit spider
  fetch         Fetch a URL using the Scrapy downloader
  genspider     Generate new spider using pre-defined templates
  list          List available spiders
  parse         Parse URL (using its spider) and print the results
  runspider     Run a self-contained spider (without creating a project)
  settings      Get settings values
  shell         Interactive scraping console
  startproject  Create new project
  version       Print Scrapy version
  view          Open URL in browser, as seen by Scrapy

Use "scrapy <command> -h" to see more info about a command
```

#### 创建项目

>reference: `http://doc.scrapy.org/en/1.0/intro/tutorial.html#creating-a-project`

```
root@ubuntu:/home/vickey# docker exec -it test-scrapy /bin/bash
root@2fb0da64a933:/# cd /home
root@2fb0da64a933:/home# scrapy startproject test_scrapy
New Scrapy project 'test_scrapy', using template directory '/usr/local/lib/python2.7/dist-packages/scrapy/templates/project', created in:
    /home/test_scrapy

You can start your first spider with:
    cd test_scrapy
    scrapy genspider example example.com
```

#### 创建项目爬虫

```
root@2fb0da64a933:/home/test_scrapy# cd test_scrapy/
root@2fb0da64a933:/home/test_scrapy/test_scrapy# scrapy genspider test_spider baidu.com
Created spider 'test_spider' using template 'basic' in module:
  test_scrapy.spiders.test_spider
```

#### 项目及爬虫文件

- 概览

```
root@8b825656f58b:/home# tree -L 2 test_scrapy/
test_scrapy/                                            # Deploy the configuration file
|-- scrapy.cfg                                          # Name of the project
`-- test_scrapy
    |-- __init__.py
    |-- items.py                                        # It is project's items file
    |-- middlewares.py                                  # It is project's pipelines file
    |-- pipelines.py                                    # It is project's pipelines file
    |-- settings.py                                     # It is project's settings file
    `-- spiders
        |-- __init__.py
        `-- test_spider.py                              # It is project's spiders file

2 directories, 6 files
```

- scrapy.cfg

```
root@2fb0da64a933:/home# cd test_scrapy/                # 进入创建的项目
root@2fb0da64a933:/home/test_scrapy# ls
scrapy.cfg  test_scrapy
root@2fb0da64a933:/home/test_scrapy# cat scrapy.cfg 
# Automatically created by: scrapy startproject
#
# For more information about the [deploy] section see:
# https://scrapyd.readthedocs.io/en/latest/deploy.html

[settings]
default = test_scrapy.settings                          # default = 项目名.settings  

[deploy]
#url = http://localhost:6800/
project = test_scrapy                                   # project = 项目名
root@2fb0da64a933:/home/test_scrapy# cd test_scrapy/
root@2fb0da64a933:/home/test_scrapy/test_scrapy# ls     # 创建项目时默认创建的文件
__init__.py  __init__.pyc  items.py  middlewares.py  pipelines.py  settings.py	settings.pyc  spiders
```

- items.py
> 设置数据库字段

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy# cat items.py 
# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://doc.scrapy.org/en/latest/topics/items.html

import scrapy


class TestScrapyItem(scrapy.Item):
    # define the fields for your item here like:
    # name = scrapy.Field()
    pass
```

- middlewares.py(暂忽略)

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy# cat middlewares.py 
# -*- coding: utf-8 -*-

# Define here the models for your spider middleware
#
# See documentation in:
# https://doc.scrapy.org/en/latest/topics/spider-middleware.html

from scrapy import signals


class TestScrapySpiderMiddleware(object):
    # Not all methods need to be defined. If a method is not defined,
    # scrapy acts as if the spider middleware does not modify the
    # passed objects.

    ...


class TestScrapyDownloaderMiddleware(object):
    # Not all methods need to be defined. If a method is not defined,
    # scrapy acts as if the downloader middleware does not modify the
    # passed objects.
    ...
```

- pipelines.py
> 连接、写入数据库的操作等写在这里(先看模版，之后会给出实例)

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy# cat pipelines.py 
# -*- coding: utf-8 -*-

# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://doc.scrapy.org/en/latest/topics/item-pipeline.html


class TestScrapyPipeline(object):
    def process_item(self, item, spider):
        return item
```

- settings.py

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy# cat settings.py|grep -v ^# |grep -v ^$
BOT_NAME = 'test_scrapy'
SPIDER_MODULES = ['test_scrapy.spiders']
NEWSPIDER_MODULE = 'test_scrapy.spiders'
ROBOTSTXT_OBEY = True
```

- 项目爬虫文件

>reference: `https://docs.scrapy.org/en/latest/topics/spiders.html?highlight=filter#scrapy-spider`

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy# cd spiders/
root@2fb0da64a933:/home/test_scrapy/test_scrapy/spiders# ls
__init__.py test_spider.py                              # test.spider.py就是创建的爬虫文件，创建的所有同一项目爬虫都会放在这里
root@2fb0da64a933:/home/test_scrapy/test_scrapy/spiders# cat test_spider.py 
# -*- coding: utf-8 -*-
import scrapy


class TestSpiderSpider(scrapy.Spider):                  # 类名为：爬虫名+Spider
    name = 'test_spider'                                # 创建爬虫时定义的爬虫名
    allowed_domains = ['baidu.com']                     # 创建爬虫时定义的爬虫要爬的域名或URL
    start_urls = ['http://baidu.com/']                  # 爬虫要爬取信息的根URL，是个列表类型

    def parse(self, response):
        pass
```


#### 运行项目爬虫

- 不带参数运行爬虫

> 官方文档说需要回到项目顶层目录运行爬虫，但实际上好像不用，只要在项目目录内就行

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy/spiders# scrapy crawl test_spider
2019-06-26 07:02:52 [scrapy.utils.log] INFO: Scrapy 1.5.0 started (bot: test_scrapy)
......
2019-06-26 07:02:53 [scrapy.core.engine] INFO: Spider closed (finished)
```

- 带参数运行爬虫

> 前提是需要在`__init__`中先接收该传入参数

```
root@2fb0da64a933:/home/test_scrapy/test_scrapy/spiders# cat test_spider.py
# -*- coding: utf-8 -*-
import scrapy


class TestSpiderSpider(scrapy.Spider):
    name = 'test_spider'
    allowed_domains = ['baidu.com']
    start_urls = ['http://baidu.com/']

    def __init__(self, group, *args, **kargs):
        super(TestSpiderSpider, self).__init__(*args, **kwargs)
        self.start_urls = ['http://www.example.com/group/%s' % group]

    def parse(self, response):
        pass
root@2fb0da64a933:/home/test_scrapy/test_scrapy/spiders# scrapy crawl test_spider -a group=aa
2019-06-27 03:11:35 [scrapy.utils.log] INFO: Scrapy 1.5.0 started (bot: test_scrapy)
......
2019-06-27 03:11:35 [scrapy.core.engine] INFO: Spider closed (finished)
```

#### 电影天堂爬虫实战

> 内容太多，放到下一篇笔记吧
