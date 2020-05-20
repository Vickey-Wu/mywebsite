---
title: "scrapy电影天堂实战---创建爬虫"
date: 2019-07-16T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/5302B30E77E641CB80D8AAAE3A118014?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "scrapy"
tags:
  - "scrapy"
  - "spider"
  - "docker"
---

#### 创建数据库

>我在上一篇笔记中已经创建了数据库，具体查看《[scrapy电影天堂实战(一)创建数据库](https://mp.weixin.qq.com/s/X2kSH5O3QDLU8bHHUbOaCg)》，这篇笔记创建scrapy实例，先熟悉下要用到到xpath知识

#### 用到的xpath相关知识

>reference: `https://germey.gitbooks.io/python3webspider/content/4.1-XPath%E7%9A%84%E4%BD%BF%E7%94%A8.html`

```
nodename	选取此节点的所有子节点
/	        从当前节点选取直接子节点
//	        从当前节点选取子孙节点
.	        选取当前节点
..	        选取当前节点的父节点
@	        选取属性
```

>//title[@lang='eng']，
这就是一个 XPath 规则，它就代表选择所有名称为 title，同时属性 lang 的值为 eng 的节点。

- 属性多值匹配

```
from lxml import etree
text = '''
<li class="li li-first"><a href="link.html">first item</a></li>
'''
html = etree.HTML(text)
result = html.xpath('//li[@class="li"]/a/text()')
print(result)
```

>在这里 HTML 文本中的 li 节点的 class 属性有两个值 li 和 li-first，但是此时如果我们还想用之前的属性匹配获取就无法匹配了, 如果属性有多个值就需要用 contains() 函数了

```
result = html.xpath('//li[contains(@class, "li")]/a/text()')
```

- 多属性匹配

```
from lxml import etree
text = '''
<li class="li li-first" name="item"><a href="link.html">first item</a></li>
'''
html = etree.HTML(text)
result = html.xpath('//li[contains(@class, "li") and @name="item"]/a/text()')
print(result)
```

>在这里 HTML 文本的 li 节点又增加了一个属性 name，这时候我们需要同时根据 class 和 name 属性来选择，就可以 and 运算符连接两个条件，两个条件都被中括号包围。

- 按序选择

```
result = html.xpath('//li[position()<3]/a/text()')
result = html.xpath('//li[last()-2]/a/text()')
```

#### scrapy-python3的dockerfile(可忽略)
>可用该dockerfile自行构建镜像

```
FROM ubuntu:latest
MAINTAINER vickeywu <vickeywu557@gmail.com>

RUN apt-get update

RUN apt-get install -y python3.6 python3-pip python3-dev && \
	 ln -snf /usr/bin/python3.6 /usr/bin/python

RUN apt-get clean && \
	rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip3 install --upgrade pip && \
	    ln -snf /usr/local/bin/pip3.6 /usr/bin/pip && \
        pip install --upgrade scrapy && \
        pip install --upgrade pymysql && \
        pip install --upgrade redis && \
        pip install --upgrade bitarray && \
        pip install --upgrade mmh3

WORKDIR /home/scrapy_project

CMD touch /var/log/scrapy.log && tail -f /var/log/scrapy.log
```

#### python2环境设置编码使用utf8 (使用python3环境可忽略)

- set var in settings.py

```
PAGE_ENCODING = 'utf8'
```

- quote in other file.py: 

```
from scrapy.utils.project import get_project_settings
settings = get_project_settings()
PAGE_ENCODING = settings.get('PAGE_ENCODING')
```

- set utf8 directly

```
sys.setdefaultencoding('utf8')
body = (response.body).decode('utf8','ignore')
body = str((response.body).decode('utf16','ignore')).encode('utf8')
```

#### 创建爬虫

>现在正式创建scrapy实例

```
root@ubuntu:/home/vickey# docker pull vickeywu/scrapy-python3
root@ubuntu:/home/vickey# mkdir scrapy_project      # 创建个文件夹存放scrapy项目
root@ubuntu:/home/vickey# cd scrapy_project/
root@ubuntu:/home/vickey/scrapy_project# docker run -itd --name scrapy_movie -v /usr/share/zoneinfo:/usr/share/zoneinfo -v /home/vickey/scrapy_project/:/home/scrapy_project/ vickeywu/scrapy-python3     # 使用已构建好的镜像创建容器
84ae2ee9f02268c68e59cabaf3040d8a8d67c1b2d1442a66e16d4e3e4563d8b8
root@ubuntu:/home/vickey/scrapy_project# docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED             STATUS              PORTS                               NAMES
84ae2ee9f022        vickeywu/scrapy-python3   "scrapy shell --nolog"   3 seconds ago       Up 2 seconds                                            scrapy_movie
d8afb121afc6        mysql                     "docker-entrypoint.s…"   4 days ago          Up 3 hours          33060/tcp, 0.0.0.0:8886->3306/tcp   scrapy_mysql
root@ubuntu:/home/vickey/scrapy_project# docker exec -it scrapy_movie /bin/bash
root@84ae2ee9f022:/home/scrapy_project# TIME_ZONE=Asia/Shanghai             # 将时区改为上海时间
root@84ae2ee9f022:/home/scrapy_project# ln -snf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone
root@84ae2ee9f022:/home/scrapy_project# ls      # 挂载的目录暂时没有任何东西，等下创建了项目便会将文件挂载到宿主机，方便修改
root@84ae2ee9f022:/home/scrapy_project# scrapy --help       #　查看帮助命令
略
root@84ae2ee9f022:/home/scrapy_project# scrapy startproject movie_heaven_bar        # 创建项目名为movie_heaven_bar
New Scrapy project 'movie_heaven_bar', using template directory '/usr/local/lib/python3.6/dist-packages/scrapy/templates/project', created in:
    /home/scrapy_project/movie_heaven_bar

You can start your first spider with:
    cd movie_heaven_bar
    scrapy genspider example example.com
root@84ae2ee9f022:/home/scrapy_project# ls
movie_heaven_bar
root@84ae2ee9f022:/home/scrapy_project# cd movie_heaven_bar/       # 进入项目后再创建爬虫
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar# ls
movie_heaven_bar  scrapy.cfg
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar# scrapy genspider movie_heaven_bar www.dytt8.net        #　创建爬虫名为movie_heaven_bar失败，不能与项目同名。。改个名
Cannot create a spider with the same name as your project
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar# scrapy genspider newest_movie www.dytt8.net     # 创建爬虫名为newest_movie
Created spider 'newest_movie' using template 'basic' in module:
  movie_heaven_bar.spiders.newest_movie
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar# cd movie_heaven_bar/
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar/movie_heaven_bar# ls
__init__.py  __pycache__  items.py  middlewares.py  pipelines.py  settings.py  spiders
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar/movie_heaven_bar# cd spiders/
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar/movie_heaven_bar/spiders# ls       # 创建的爬虫文件会在项目的spiders文件夹下
__init__.py  __pycache__  newest_movie.py
root@84ae2ee9f022:/home/scrapy_project/movie_heaven_bar/movie_heaven_bar/spiders# exit     # 退出容器
exit
root@ubuntu:/home/vickey/scrapy_project# ls     # 退出容器后可以看到创建的项目文件已经挂载到宿主机本地，接下来在宿主机撸代码即可
movie_heaven_bar
```

#### 撸代码

- items.py

```
# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://doc.scrapy.org/en/latest/topics/items.html

import scrapy
from scrapy.item import Item, Field


class MovieHeavenBarItem(scrapy.Item):
    # define the fields for your item here like:
    # name = scrapy.Field()
    #pass

    movie_link = Field()
    movie_name = Field()
    movie_director = Field()
    movie_actors = Field()
    movie_publish_date = Field()
    movie_score = Field()
    movie_download_link = Field()
```

- settings.py

>数据库设置、延时设置、启用pipeline、日志设置，暂时只用到这些

```
BOT_NAME = 'movie_heaven_bar'

SPIDER_MODULES = ['movie_heaven_bar.spiders']
NEWSPIDER_MODULE = 'movie_heaven_bar.spiders'

# db settings
DB_SETTINGS = {
            'DB_HOST': '192.168.229.128',
            'DB_PORT': 8886,
            'DB_DB': 'movie_heaven_bar',
            'DB_USER': 'movie',
            'DB_PASSWD': '123123',
        }

# obey ROBOTS.txt set True if raise error set False
ROBOTSTXT_OBEY = True

# delay 3 seconds
DOWNLOAD_DELAY = 3

# enable pipeline
ITEM_PIPELINES = {
    'movie_heaven_bar.pipelines.MovieHeavenBarPipeline': 300,
}

# log settings
LOG_LEVEL = 'INFO'
LOG_FILE = '/var/log/scrapy.log'
```

- pipelines.py

>reference: `https://docs.scrapy.org/en/latest/topics/item-pipeline.html?highlight=filter#item-pipeline`

>项目爬虫(`scrapy genspider spidername`命令生成到爬虫文件)抓取到数据之后将它们发送到项目管道(项目下到`pipelines.py`文件里定义到各种`class`)，管道通过`settings.py`里面定义的`ITEM_PIPELINES`优先级顺序(0~1000从小到大)来处理数据。

>作用：1.清洗数据 2.验证数据（检查项目是否包含某些字段） 3.检查重复项（并删除它们） 4.将数据存储到数据库

>reference: `http://scrapingauthority.com/scrapy-database-pipeline/`


```
# -*- coding: utf-8 -*-

# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://doc.scrapy.org/en/latest/topics/item-pipeline.html

import pymysql
from scrapy.exceptions import NotConfigured


class MovieHeavenBarPipeline(object):
    def __init__(self, host, port, db, user, passwd):
        self.host = host
        self.port = port
        self.db = db
        self.user = user
        self.passwd = passwd

    # reference: doc.scrapy.org/en/latest/topics/item-pipeline.html#from_crawler
    @classmethod
    def from_crawler(cls, crawler):
        db_settings = crawler.settings.getdict('DB_SETTINGS')
        if not db_settings:
            raise NotConfigured
        host = db_settings['DB_HOST']
        port = db_settings['DB_PORT']
        db = db_settings['DB_DB']
        user = db_settings['DB_USER']
        passwd = db_settings['DB_PASSWD']
        return cls(host, port, db, user, passwd)

    def open_spider(self, spider):
        self.conn = pymysql.connect(
                                       host=self.host,
                                       port=self.port,
                                       db=self.db,
                                       user=self.user,
                                       passwd=self.passwd,
                                       charset='utf8',
                                       use_unicode=True,
                                   )
        self.cursor = self.conn.cursor()

    def process_item(self, item, spider):
        sql = 'INSERT INTO newest_movie(movie_link, movie_name, movie_director, movie_actors, movie_publish_date, movie_score, movie_download_link) VALUES (%s, %s, %s, %s, %s, %s, %s)'
        self.cursor.execute(sql, (item.get('movie_link'), item.get('movie_name'), item.get('movie_director'), item.get('movie_actors'), item.get('movie_publish_date'), item.get('movie_score'), item.get('movie_download_link')))
        self.conn.commit()
        return item

    def close_spider(self, spider):
        self.conn.close()
```

- spiders/newest_movie.py

```
# -*- coding: utf-8 -*-
import scrapy
import time
import logging
from scrapy.http import Request
from movie_heaven_bar.items import MovieHeavenBarItem


class NewestMovieSpider(scrapy.Spider):
    name = 'newest_movie'
    allowed_domains = ['www.dytt8.net']
    #start_urls = ['http://www.dytt8.net/']
    # 从该urls列表开始爬取
    start_urls = ['http://www.dytt8.net/html/gndy/dyzz/']

    def parse(self, response):
        item = MovieHeavenBarItem()
        domain = "https://www.dytt8.net"
        urls = response.xpath('//b/a/@href').extract()     # list type
        #print('urls', urls)
        for url in urls:
            url = domain + url
            yield Request(url=url, callback=self.parse_single_page, meta={'item': item}, dont_filter = False)

        # 爬取下一页
        last_page_num = response.xpath('//select[@name="sldd"]//option[last()]/text()').extract()[0]
        last_page_url = 'list_23_' + last_page_num + '.html'
        next_page_url = response.xpath('//div[@class="x"]//a[last() - 1]/@href').extract()[0]
        if next_page_url != last_page_url:
            url = 'https://www.dytt8.net/html/gndy/dyzz/' + next_page_url
            logging.log(logging.INFO, '***************** page num ***************** ')
            logging.log(logging.INFO, 'crawling page: ' + next_page_url)
            yield Request(url=url, callback=self.parse, meta={'item': item}, dont_filter = False)

    def parse_single_page(self, response):
        item = response.meta['item']
        item['movie_link'] = response.url
        detail_row = response.xpath('//*[@id="Zoom"]//p/text()').extract()		# str type list
        # 将网页提取的str列表类型数据转成一个长字符串, 以圆圈为分隔符，精确提取各个字段具体内容
        detail_list = ''.join(detail_row).split('◎')

        logging.log(logging.INFO, '******************log movie detail*******************')
        item['movie_name'] = detail_list[1][5:].replace(6*u'\u3000', u', ')
        logging.log(logging.INFO, 'movie_link: ' + item['movie_link'])
        logging.log(logging.INFO, 'movie_name: ' + item['movie_name'])
        # 找到包含特定字符到字段
        for field in detail_list:
            if '主\u3000\u3000演' in field:
                # 将字段包含杂质去掉[5:].replace(6*u'\u3000', u', ')
                item['movie_actors'] = field[5:].replace(6*u'\u3000', u', ')
                logging.log(logging.INFO, 'movie_actors: ' + item['movie_actors'])
            if '导\u3000\u3000演' in field:
                item['movie_director'] = field[5:].replace(6*u'\u3000', u', ')
                logging.log(logging.INFO, 'movie_directors: ' + item['movie_director'])
            if '上映日期' in field:
                item['movie_publish_date'] = field[5:].replace(6*u'\u3000', u', ')
                logging.log(logging.INFO, 'movie_publish_date: ' + item['movie_publish_date'])
            if '豆瓣评分' in field:
                item['movie_score'] = field[5:].replace(6*u'\u3000', u', ')
                logging.log(logging.INFO, 'movie_score: ' + item['movie_score'])

        # 此处获取的是迅雷磁力链接，安装好迅雷，复制该链接到浏览器地址栏迅雷会自动打开下载链接，个别网页结构不一致会获取不到链接
        try:
            item['movie_download_link'] = ''.join(response.xpath('//p/a/@href').extract())
            logging.log(logging.INFO, 'movie_download_link: ' + item['movie_download_link'])
        except Exception as e:
            item['movie_download_link'] = response.url
            logging.log(logging.WARNING, e)
        yield item
```

#### 启动爬虫

```
root@ubuntu:/home/vickey/scrapy_project/movie_heaven_bar# docker exec -it scrapy_movie /bin/bash
root@1040aa3b7363:/home/scrapy_project# ls
movie_heaven_bar
root@1040aa3b7363:/home/scrapy_project# cd movie_heaven_bar/
root@1040aa3b7363:/home/scrapy_project/movie_heaven_bar# ls
movie_heaven_bar  run.sh  scrapy.cfg
root@1040aa3b7363:/home/scrapy_project/movie_heaven_bar# sh run.sh &       # 后台运行脚本，日志输出可以在/var/log/scrapy.log中看到
root@1040aa3b7363:/home/scrapy_project/movie_heaven_bar# exit
exit
root@ubuntu:/home/vickey/scrapy_project/movie_heaven_bar# ls
movie_heaven_bar  README.md  run.sh  scrapy.cfg
root@ubuntu:/home/vickey/scrapy_project/movie_heaven_bar# docker logs -f scrapy_movie        # 使用docker logs -f --tail 20 scrapy_movie也可以看到scrapy的日志输出。
```

- scrapy爬虫日志截图

![scrapy-log](https://note.youdao.com/yws/api/personal/file/473FD1771D124198B3DBA88DB9176A1C?method=download&shareKey=d38d802fc0fba0db272461d35b297ec9)

- scrapy数据库截图

![scrapy-db](https://note.youdao.com/yws/api/personal/file/24AE6302AC0E442EB99B84B9DB55A6A7?method=download&shareKey=bcd6dfbff8b8086c10ce31bee2a9901d)

#### 结语

大功告成，现在我想看哪部电影只需要将`movie_download_link`的**链接复制到浏览器打开，即可自动打开迅雷链接下载电影了**(前提是已经安装迅雷)，然后就可以在迅雷边下边看了，**美滋滋**。

**不过**，如果我中途停止了爬取，又要从头开始爬，所以就会有**数据重复**，很烦。**下一篇笔记写下scrapy的去重方法**，这样就不会有数据重复了，也可以节省爬取耗时。

>代码已上传至github: `https://github.com/Vickey-Wu/movie_heaven_bar`
