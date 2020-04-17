---
title: "使用hugo建站"
date: 2018-11-28T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://s1.ax1x.com/2020/04/16/JF8ZOf.md.jpg"
categories:
  - "hugo"
  - "docker"
tags:
  - "hugo"
  - "docker"
  - "website"
---

#### 概要

使用docker版hugo建立个人静态网站。

#### init website

```
root@vickey:/home# mkdir website
root@vickey:/home# cd website
root@vickey:/home/website# docker run --rm -it -v $PWD:/src -p 1313:1313 vijaymateti/hugo:latest hugo new site .
Congratulations! Your new Hugo site is created in /src.

Just a few more steps and you're ready to go:

1. Download a theme into the same-named folder.
   Choose a theme from https://themes.gohugo.io/ or
   create your own with the "hugo new theme <THEMENAME>" command.
2. Perhaps you want to add some content. You can add single files
   with "hugo new <SECTIONNAME>/<FILENAME>.<FORMAT>".
3. Start the built-in live server via "hugo server".

Visit https://gohugo.io/ for quickstart guide and full documentation.
root@vickey:/home/website# ls
archetypes  config.toml  content  data  layouts  static  themes
```

#### apply themes

```
root@vickey:/home/website# cd themes/
root@vickey:/home/website/themes# git clone git@github.com:themefisher/parsa-hugo.git
Cloning into 'parsa-hugo'...
root@vickey:/home/website/themes# ls
parsa-hugo
root@vickey:/home/website/themes# cd parsa-hugo/exampleSite/
root@vickey:/home/website/themes/parsa-hugo/exampleSite# ls
config.toml  content  static
root@vickey:/home/website/themes/parsa-hugo/exampleSite# cp -R * /home/website/
root@vickey:/home/website/themes/parsa-hugo/exampleSite# cd -
/home/website
root@vickey:/home/website# ls content/
about                         Charming-Evening-Field.2.md  Charming-Evening-Field.6.md  Charming-Evening-Field.md  Organize-Your-Life.3.md
Charming-Evening-Field.10.md  Charming-Evening-Field.3.md  Charming-Evening-Field.7.md  contact                    Organize-Your-Life.4.md
Charming-Evening-Field.11.md  Charming-Evening-Field.4.md  Charming-Evening-Field.8.md  Organize-Your-Life.1.md    Organize-Your-Life.md
Charming-Evening-Field.1.md   Charming-Evening-Field.5.md  Charming-Evening-Field.9.md  Organize-Your-Life.2.md    search
root@vickey:/home/website# ls static/images/
author.jpg  banner-img.png  contact.jpg  featured-post  logo.png  masonary-post  post-img.jpg
```

#### change config.toml

```
root@vickey:/home/website# vim config.toml 
# default config
baseURL = "https://yourwebsite.com"
```

#### run hugo server

```
root@vickey:/home/website# hugo server --bind=0.0.0.0 --liveReloadPort=443 -v -w  -p 80 -b http://yourserverip
port 80 already in use, attempting to use an available port
INFO 2020/04/15 11:17:23 No translation bundle found for default language "en"
INFO 2020/04/15 11:17:23 Translation func for language en not found, use default.
INFO 2020/04/15 11:17:23 i18n not initialized; if you need string translations, check that you have a bundle in /i18n that matches the site language or the default language.
INFO 2020/04/15 11:17:23 Using config file: 
Building sites … INFO 2020/04/15 11:17:23 syncing static files to /

                   | EN  
-------------------+-----
  Pages            | 56  
  Paginator pages  |  6  
  Non-page files   |  0  
  Static files     | 48  
  Processed images |  0  
  Aliases          | 16  
  Sitemaps         |  1  
  Cleaned          |  0  

Built in 207 ms
Watching for changes in /home/website/{archetypes,content,data,layouts,static,themes}
Watching for config changes in /home/website/config.toml
Environment: "development"
Serving pages from memory
Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
Web Server is available at http://yourserverip:35035/ (bind address 0.0.0.0)
Press Ctrl+C to stop
```

访问输出打印的地址即`http://yourserverip:35035/`可看到网站已经可以访问了

#### use nginx as server

##### 1. hugo build website

```
root@vickey:/home/website# docker run --rm -it -v $PWD:/src -p 1313:1313 vijaymateti/hugo:latest hugo 

                   | EN  
-------------------+-----
  Pages            | 56  
  Paginator pages  |  6  
  Non-page files   |  0  
  Static files     | 48  
  Processed images |  0  
  Aliases          | 16  
  Sitemaps         |  1  
  Cleaned          |  0  

Total in 170 ms
root@vickey:/home/website# ls
archetypes  config.toml  content  data  layouts  public  resources  static  themes
```

##### 2. use nginx proxy resouces

将nginx的`/`根目录代理到网站生成的静态资源目录`/home/website/public`即可不使用`hugo server`来运行你的网站了。
```
default.conf
    location / {
        root   /home/website/public;
        index  index.html index.htm index.php;
    }
```
