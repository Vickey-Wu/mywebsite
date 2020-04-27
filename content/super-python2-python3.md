---
title: "python2 python3的super"
date: 2019-06-11T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/452EAA2FD34C4F5F86BB3043219A667F?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "python"
tags:
  - "python"
---

#### python2

```
# python2
class MyParentClass(object):
    def __init__(self):
        pass
class SubClass(MyParentClass):
    def __init__(self):
        super(SubClass, self).__init__()        # 使用这种方法时，要求继承链的最顶层父类必须要继承 object。即MyParentClass(object)
        # super(SubClass, self).__init__(para)  # if parentclass have para

class MutilSubClass(MyParentClass, SubClass):
    def __init__(self):
        super(MutilSubClass, self).__init__()   # 第一重继承
        SubClass.__init__(self)                 # 第二重继承， 对于多重继承，如果有多个构造函数需要调用， 我们必须用传统的方法SubClass.__init__(self) 。
        
# python2 e.g        
class AbstractSecurityManager():
    pass
class BaseSecurityManager(AbstractSecurityManager):
    def __init__(self, appbuilder):
        super(BaseSecurityManager, self).__init__(appbuilder)
```

#### python3

```
class MyParentClass():
    def __init__(self, x, y):
        pass

class SubClass(MyParentClass):
    def __init__(self, x, y):
        super().__init__(x, y)
        # super()   # no need init if parentclass init have no para
```
