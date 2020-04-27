---
title: "python超类 元类"
date: 2019-06-12T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/A4805FD3D4FC45C28FFFC30E95BF4C1A?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "python"
tags:
  - "python"
  - "metaclass"
---

#### python超类

>type就是Python在背后用来创建所有类的超类

>str是用来创建字符串对象的类，而int是用来创建整数对象的类。type就是创建类对象的类。type就是创建类对象的类。你可以通过检查__class__属性来看到这一点。Python中所有的东西，注意，我是指所有的东西——都是对象。这包括整数、字符串、函数以及类。它们全部都是对象，而且它们都是从一个类创建而来。

```
>>> a = 6
>>> a.__class__
<class 'int'>
>>> b = 'string'
>>> b.__class__
<class 'str'>
# int和str的__class__是type
>>> a.__class__.__class__
<class 'type'>
>>> b.__class__.__class__
<class 'type'>
# type用来创建所有类的超类，没有比type更基础的类了
>>> a.__class__.__class__.__class__
<class 'type'>
```

#### python自定义超类

>type就是Python的内建超类，当然了，你也可以创建自定义超类。

>超类的主要目的就是为了当创建类时能够自动地改变类。

>通过设定__metaclass__来实现,这个模块中的所有类都会通过这个超类来创建

###### 使用函数创建自定义超类

```
def upper_attr(future_class_name, future_class_parents, future_class_attr):
    '''返回一个类对象，将属性都转为大写形式'''
    #选择所有不以'__'开头的属性
    attrs = ((name, value) for name, value in future_class_attr.items() if not name.startswith('__'))
    # 将它们转为大写形式
    uppercase_attr = dict((name.upper(), value) for name, value in attrs)
    #通过'type'来做类对象的创建
    return type(future_class_name, future_class_parents, uppercase_attr)#返回一个类

class Foo(object):
    __metaclass__ = upper_attr
    bar = 'bip'


print(hasattr(Foo, 'bar'))
# 输出: False
print(hasattr(Foo, 'BAR'))
# 输出:True
 
f = Foo()
print(f.BAR)
# 输出:'bip'
```

>例子输出(跑了下参考博客的这个例子，貌似没实现将属性转成大写，结果也与博客给出的输出相反，不过没关系，基本不用这种方法。)

```
root@ubuntu:/home/vickey/test# python t.py 
True
False
Traceback (most recent call last):
  File "t.py", line 131, in <module>
    print(f.BAR)
AttributeError: 'Foo' object has no attribute 'BAR'
```

###### 使用class自定义超类

>如果我们希望能够控制对象的创建，可以通过改写`__new__`实现

>`__new__`是在`__init__`之前被调用的类方法，`__new__`是用来创建对象并返回对象的方法，而`__init__`只是用来将传入的参数初始化给对象，它是在对象创建之后执行的方法。

```
# v1
class UpperAttrMetaclass(type):
    def __new__(upperattr_metaclass, future_class_name, future_class_parents, future_class_attr):
        attrs = ((name, value) for name, value in future_class_attr.items() if not name.startswith('__'))
        uppercase_attr = dict((name.upper(), value) for name, value in attrs)
        # 复用type.__new__方法
        # 这就是基本的OOP编程，没什么魔法。由于type是超类也就是类，因此它本身也是通过__new__方法生成其实例，只不过这个实例是一个类.
        return type.__new__(upperattr_metaclass, future_class_name, future_class_parents, uppercase_attr)


# v2
class UpperAttrMetaclass(type):
    def __new__(cls, name, bases, dct):
        attrs = ((name, value) for name, value in dct.items() if not name.statswith('__'))
        uppercase_attr = dict((name.upper(), value) for name, value in attrs)
        return type.__new(cls, name, bases, uppercase_attr)


# v3
class UpperAttrMetaclass(type):
    def __new__(cls, name, bases, dct):
        attrs = ((name, value) for name, value in dct.items() if not name.startswith('__'))
        uppercase_attr = dict((name.upper(), value) for name, value in attrs)
        # 使用super方法的话，我们还可以使它变得更清晰一些
        return super(UpperAttrMetaclass, cls).__new__(cls, name, bases, uppercase_attr)
```

###### [github上的应用例子](https://github.com/Germey/ProxyPool/blob/master/proxypool/getter.py)

```
class ProxyMetaclass(type):
    def __new__(cls, name, bases, attrs):
        count = 0
        attrs['__CrawlFunc__'] = []
        for k, v in attrs.item():
            if 'crawl_' in k:
                attrs['__CrawlFunc__'].append(k)
                count += 1
        attrs['__CrawlFuncCount__'] = count
        return type.__new__(cls, name, bases, attrs)

# 调用自定义超类
class FreeProxyGetter(object, metaclass=ProxyMetaclass):
    def get_raw_proxies(self, callback):
        proxies = []
        print('Callback', callback)
        for proxy in eval("self.{}()".format(callback)):
            print('Getting', proxy, 'from', callback)
            proxies.append(proxy)
        return proxies
```

在要创建的类中使用参数`metaclass=YourMetaclass`调用自定义的超类，这样就可以为所有调用了这个超类的类添加相同的属性了。例子会添加`__CrawlFunc__`和`__CrawlFuncCount__`两个属性用于表示爬虫函数，和爬虫函数个数

#### reference

>https://www.cnblogs.com/tkqasn/p/6524879.html
