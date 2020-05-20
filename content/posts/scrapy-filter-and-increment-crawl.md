---
title: "scrapy过滤和增量爬取"
date: 2019-07-25T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/0AB76AB0B7C848789E612895D36062C9?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "scrapy"
tags:
  - "scrapy"
  - "docker"
---

### 前言

这篇笔记基于上上篇笔记的---《[**scrapy电影天堂实战(二)创建爬虫项目**](https://mp.weixin.qq.com/s/3WWwgIdjcUuoN4jCGPsPsQ)》，而这篇又涉及redis，所以又先熟悉了下redis，记录了下《[**redis基础笔记**](https://mp.weixin.qq.com/s/A1f137iEGDKpMVyO4GDtRw)》，这篇为了节省篇幅所以只添加改动部分代码。

#### 个人实现思路

- 过滤重复数据

在pipeline写个redispipeline，要爬的内容hash后的键`movie_hash`通过pipeline时与从redis获取的`movie_hash`（set类型）比对，如果在`redis`里面则在pipeline里`raise DropItem`将这个item去掉，在通过pipeline的mysqlpipeline存入数据库时就不会有重复数据了。

- 增量爬取

虽然没有重复数据了，但是不能增量爬取，一旦停止了爬虫，又会从头爬取，效率很低。想到在`downloader middleware`中增加对request和response的url进行处理将它放到redis，然后比对，有在redis里面就`raise IgnoreRequest`忽略掉这个请求，测试也的确忽略了，但其实还是从头开始爬取，只不过忽略了这个请求，效率并没有提升多少，好像并不是增量爬取。最后默默删掉自己的代码。。。

#### 求助

折腾了许久，熬不住了，还是求助吧。其实之前google就搜到了一个scrapy-redis的开源项目就实现了这些功能，但自己试了下没有实现效果（我自己的问题），所以想找本书系统看看scrapy，然后就找了下python scrapy相关的pdf（穷逼买不起书）。找到了一本也引用了scrapy-redis这个项目的书，什么书就不说了，尊重别人的劳动，土豪另当别论。按照书里的配置了下，过滤重复数据是ok了，但增量爬取死活不行，一旦停止、重新爬取，它只会将redis里面的requests爬完就完了，之后再重启爬虫都不会有新的requests生成了。又折腾了许久，在某个群里有个大佬回答了，将爬取page的链接的yield那设置`dont_filter = True`，自己设置测试了下，的确实现了增量爬取。再次感谢那位大佬的帮助。

### 具体实现

#### 创建个redis容器

具体查看《[**redis基础笔记**](https://mp.weixin.qq.com/s/A1f137iEGDKpMVyO4GDtRw)》的`使用redis镜像`这里的方法，这里不再赘述。

#### 引用scrapy-redis

>修改settings.py添加配置，完整配置查看：`https://github.com/rmax/scrapy-redis#usage`

```
###### scrapy-redis settings start ######
# https://github.com/rmax/scrapy-redis
# Enables scheduling storing requests queue in redis.
SCHEDULER = "scrapy_redis.scheduler.Scheduler"

# Ensure all spiders share same duplicates filter through redis.
DUPEFILTER_CLASS = "scrapy_redis.dupefilter.RFPDupeFilter"

# Specify the full Redis URL for connecting (optional).
# If set, this takes precedence over the REDIS_HOST and REDIS_PORT settings.
REDIS_URL = 'redis://:123123@192.168.229.128:8889'

# Don't cleanup redis queues, allows to pause/resume crawls.
SCHEDULER_PERSIST = True

###### scrapy-redis settings end ######
```

#### 修改spider

>我一开始引用了scrapy-redis不成功的原因是我将这个参数设置成了`dont_filter = False`，还有就是爬取下一页和详情页的顺序反了，应该先爬页链接在爬详情页。

```
    def parse(self, response):
        item = MovieHeavenBarItem()
        domain = "https://www.dytt8.net"

        # 爬取下一页
        last_page_num = response.xpath('//select[@name="sldd"]//option[last()]/text()').extract()[0]
        last_page_url = 'list_23_' + last_page_num + '.html'
        next_page_url = response.xpath('//div[@class="x"]//a[last() - 1]/@href').extract()[0]
        next_page_num = next_page_url.split('_')[-1].split('.')[0]
        if next_page_url != last_page_url:
            url = 'https://www.dytt8.net/html/gndy/dyzz/' + next_page_url
            logging.log(logging.INFO, f'***************** crawling page {next_page_num} ***************** ')
            yield Request(url=url, callback=self.parse, meta={'item': item}, dont_filter = True)

        # 爬取详情页
        urls = response.xpath('//b/a/@href').extract()     # list type
        #print('urls', urls)
        for url in urls:
            url = domain + url
            yield Request(url=url, callback=self.parse_single_page, meta={'item': item}, dont_filter = False)
```

### 见证奇迹的时刻

#### 日志输出

> `2019-07-24 09:45:31 [scrapy.crawler] INFO: Received SIGINT, shutting down gracefully. Send again to force
`从中可以看到我按了两次ctrl+c强行停止了爬虫，在这之前是在爬取这个链接的`2019-07-24 09:45:30 [root] INFO: movie_link: https://www.dytt8.net/html/gndy/dyzz/20180826/57328.html
`，然后我重新启动爬虫看到接着爬取这个链接了`2019-07-24 09:46:03 [root] INFO: crawling url: https://www.dytt8.net/html/gndy/dyzz/20180718/57146.html`

```
忽略部分...
2019-07-24 09:45:30 [root] INFO: crawling url: https://www.dytt8.net/html/gndy/dyzz/20180826/57328.html
2019-07-24 09:45:30 [root] INFO: **************** movie detail log ****************
2019-07-24 09:45:30 [root] INFO: movie_link: https://www.dytt8.net/html/gndy/dyzz/20180826/57328.html
2019-07-24 09:45:30 [root] INFO: movie_name: 金蝉脱壳2/金蝉脱壳2：冥府
2019-07-24 09:45:30 [root] INFO: movie_publish_date: 2018-06-13(菲律宾)/2018-06-29(中国)/2018-06-29(美国)
2019-07-24 09:45:30 [root] INFO: movie_score: 4.0/10 from 1,180 users
2019-07-24 09:45:30 [root] INFO: movie_directors: 史蒂芬·C·米勒 Steven C. Miller
2019-07-24 09:45:30 [root] INFO: ***************** commit to mysql *****************
2019-07-24 09:45:31 [scrapy.crawler] INFO: Received SIGINT, shutting down gracefully. Send again to force
2019-07-24 09:45:31 [scrapy.core.engine] INFO: Closing spider (shutdown)
2019-07-24 09:45:58 [scrapy.extensions.telnet] INFO: Telnet Password: 4e5dbb60f52f81fe
2019-07-24 09:45:58 [scrapy.middleware] INFO: Enabled extensions:
['scrapy.extensions.corestats.CoreStats',
 'scrapy.extensions.telnet.TelnetConsole',
 'scrapy.extensions.memusage.MemoryUsage',
 'scrapy.extensions.logstats.LogStats']
2019-07-24 09:45:58 [scrapy.middleware] INFO: Enabled downloader middlewares:
['scrapy.downloadermiddlewares.robotstxt.RobotsTxtMiddleware',
 'scrapy.downloadermiddlewares.httpauth.HttpAuthMiddleware',
 'scrapy.downloadermiddlewares.downloadtimeout.DownloadTimeoutMiddleware',
 'scrapy.downloadermiddlewares.defaultheaders.DefaultHeadersMiddleware',
 'scrapy.downloadermiddlewares.useragent.UserAgentMiddleware',
 'movie_heaven_bar.middlewares.MovieHeavenBarDownloaderMiddleware',
 'scrapy.downloadermiddlewares.retry.RetryMiddleware',
 'scrapy.downloadermiddlewares.redirect.MetaRefreshMiddleware',
 'scrapy.downloadermiddlewares.httpcompression.HttpCompressionMiddleware',
 'scrapy.downloadermiddlewares.redirect.RedirectMiddleware',
 'scrapy.downloadermiddlewares.cookies.CookiesMiddleware',
 'scrapy.downloadermiddlewares.httpproxy.HttpProxyMiddleware',
 'scrapy.downloadermiddlewares.stats.DownloaderStats']
2019-07-24 09:45:58 [scrapy.middleware] INFO: Enabled spider middlewares:
['scrapy.spidermiddlewares.httperror.HttpErrorMiddleware',
 'scrapy.spidermiddlewares.offsite.OffsiteMiddleware',
 'scrapy.spidermiddlewares.referer.RefererMiddleware',
 'scrapy.spidermiddlewares.urllength.UrlLengthMiddleware',
 'scrapy.spidermiddlewares.depth.DepthMiddleware']
2019-07-24 09:45:58 [scrapy.middleware] INFO: Enabled item pipelines:
['movie_heaven_bar.pipelines.MovieHeavenBarPipeline']
2019-07-24 09:45:58 [scrapy.core.engine] INFO: Spider opened
2019-07-24 09:45:58 [scrapy.extensions.logstats] INFO: Crawled 0 pages (at 0 pages/min), scraped 0 items (at 0 items/min)
2019-07-24 09:45:58 [newest_movie] INFO: Spider opened: newest_movie
2019-07-24 09:45:58 [scrapy.extensions.telnet] INFO: Telnet console listening on 127.0.0.1:6023
2019-07-24 09:46:03 [root] INFO: crawling url: https://www.dytt8.net/html/gndy/dyzz/20180718/57146.html
2019-07-24 09:46:03 [root] INFO: **************** movie detail log ****************
2019-07-24 09:46:03 [root] INFO: movie_link: https://www.dytt8.net/html/gndy/dyzz/20180718/57146.html
2019-07-24 09:46:03 [root] INFO: movie_name: Operation Red Sea
2019-07-24 09:46:03 [root] INFO: movie_publish_date: 2018-02-16(中国)
2019-07-24 09:46:03 [root] INFO: movie_score: 8.3/10 from 433,101 users
2019-07-24 09:46:03 [root] INFO: movie_directors: 林超贤 Dante Lam
2019-07-24 09:46:03 [root] INFO: movie_actors: 张译 Yi Zhang , 黄景瑜 Jingyu Huang , 海清 Hai-Qing , 杜江 Jiang Du , 蒋璐霞 Luxia Jiang , 尹昉 Fang Yin , 王强 Qiang Wang , 郭郁滨 Yubin Guo , 王雨甜 Yutian Wang , 麦亨利 Henry Mai , 张涵>予 Hanyu Zhang , 王彦霖 Yanlin Wang
2019-07-24 09:46:03 [root] INFO: movie_download_link: magnet:?xt=urn:btih:3c1188fdbec2f63ce1e30d2061913fcba15ebb90&dn=%e9%98%b3%e5%85%89%e7%94%b5%e5%bd%b1www.ygdy8.com.%e7%ba%a2%e6%b5%b7%e8%a1%8c%e5%8a%a8.BD.720p.%e5%9b%bd%e8%af%ad%e4%b8%ad%e5%ad%97.mkv&tr=udp%3a%2f%2ftracker.leechers-paradise.org%3a6969%2fannounce&tr=udp%3a%2f%2ftracker.opentrackr.org%3a1337%2fannounce&tr=udp%3a%2f%2feddie4.nl%3a6969%2fannounce&tr=udp%3a%2f%2fshadowshq.eddie4.nl%3a6969%2fannounce
2019-07-24 09:46:03 [root] INFO: ***************** commit to mysql *****************
忽略部分...
```

#### 查看redis key的变化

>scrapy-redis 会在redis生成两个set，用于存储请求有序集合requests和过滤链接无序集合dupefilter，当请求消费完了，有序集合requests就会被干掉，直到有新请求时才重新生成，如果未消费完就一直追加。而无序集合dupefilter由于设置了`SCHEDULER_PERSIST = True`就不会被干掉，有新的请求就会追加进来。

```
root@fa2b076097e9:/data# redis-cli 
127.0.0.1:6379> AUTH 123123
OK
127.0.0.1:6379> KEYS *
1) "newest_movie:requests"
2) "newest_movie:dupefilter"
127.0.0.1:6379> TYPE newest_movie:requests
zset
127.0.0.1:6379> TYPE newest_movie:dupefilter
set
127.0.0.1:6379> ZCARD newest_movie:requests
(integer) 47
127.0.0.1:6379> ZCARD newest_movie:requests
(integer) 45
127.0.0.1:6379> ZCARD newest_movie:requests
(integer) 0
忽略部分...
127.0.0.1:6379> KEYS *
1) "newest_movie:dupefilter"
127.0.0.1:6379> SCARD newest_movie:dupefilter
(integer) 775
127.0.0.1:6379> ZRANGE newest_movie:requests 0 -1
 1) "\x80\x04\x95\x7f\x01\x00\x00\x00\x00\x00\x00}\x94(\x8c\x03url\x94\x8c8https://www.dytt8.net/html/gndy/dyzz/20180107/56002.html\x94\x8c\bcallback\x94\x8c\x11parse_single_page\x94\x8c\aerrback\x94N\x8c\x06method\x94\x8c\x03GET\x94\x8c\aheaders\x94}\x94C\aReferer\x94]\x94C4https://www.dytt8.net/html/gndy/dyzz/list_23_31.html\x94as\x8c\x04body\x94C\x00\x94\x8c\acookies\x94}\x94\x8c\x04meta\x94}\x94(\x8c\x04item\x94\x8c\x16movie_heaven_bar.items\x94\x8c\x12MovieHeavenBarItem\x94\x93\x94)\x81\x94}\x94\x8c\a_values\x94}\x94sb\x8c\x05depth\x94K\x1fu\x8c\t_encoding\x94\x8c\x05utf-8\x94\x8c\bpriority\x94K\x00\x8c\x0bdont_filter\x94\x89\x8c\x05flags\x94]\x94u."
 2) "\x80\x04\x95\x7f\x01\x00\x00\x00\x00\x00\x00}\x94(\x8c\x03url\x94\x8c8https://www.dytt8.net/html/gndy/dyzz/20180108/56021.html\x94\x8c\bcallback\x94\x8c\x11parse_single_page\x94\x8c\aerrback\x94N\x8c\x06method\x94\x8c\x03GET\x94\x8c\aheaders\x94}\x94C\aReferer\x94]\x94C4https://www.dytt8.net/html/gndy/dyzz/list_23_31.html\x94as\x8c\x04body\x94C\x00\x94\x8c\acookies\x94}\x94\x8c\x04meta\x94}\x94(\x8c\x04item\x94\x8c\x16movie_heaven_bar.items\x94\x8c\x12MovieHeavenBarItem\x94\x93\x94)\x81\x94}\x94\x8c\a_values\x94}\x94sb\x8c\x05depth\x94K\x1fu\x8c\t_encoding\x94\x8c\x05utf-8\x94\x8c\bpriority\x94K\x00\x8c\x0bdont_filter\x94\x89\x8c\x05flags\x94]\x94u."
忽略部分...
127.0.0.1:6379> SMEMBERS newest_movie:dupefilter
  1) "1bff65c147e71ea6d43b7e4a4ac86fc982375939"
  2) "9d99491255ee83dd4ffb72c3c59c17c938dbe08f"
忽略部分...
```

#### 检查数据

>将数据库数据导出到excel发现500条记录还是有4条重复值，这可能是我多次测试强行停止导致，所以也算是基本实现了过滤重复数据，增量爬取数据的功能了。

![newest_movie](https://note.youdao.com/yws/api/personal/file/BA24B4E1CB6B4A55A4606F2BDAF6C9E9?method=download&shareKey=7126c6e376e946e18b014fe9d239d832)


### 结语

这个项目基本功能是实现了，但还是有写细节要处理下，而且scrapy-redis的原理还不了解，下一篇就了解下scrapy-redis的原理。
