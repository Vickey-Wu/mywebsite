---
title: "python装饰器decorator"
date: 2019-09-16T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/E89AFE6CBA8E4D1CB52E1F17DBEC703E?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "python"
tags:
  - "python"
  - "decorator"
---

### 前言

在上几篇笔记中涉及了比较多的装饰器的使用，所以去看了一些装饰器的文章，看到一篇很全的关于装饰器的文章，这篇笔记记录了主要的例子并加了点自己的理解，有兴趣的童鞋可到文末查看原文。

### 正文

#### 1、概念

>装饰器是一个函数（也可以是类），它在不显式修改它的情况下扩展另一个函数并扩展后一个函数的行为。

#### 2、使用函数装饰示例

>将被修饰函数作为参数传给装饰函数

```
def my_decorator(func):
    def wrapper():
        print("Something is happening before the function is called.")
        func()
        print("Something is happening after the function is called.")
    return wrapper

def say_whee():
    print("Whee!")

say_whee = my_decorator(say_whee)

>>> say_whee()
Something is happening before the function is called.
Whee!
Something is happening after the function is called.
```

#### 3、使用'@'装饰示例

>使用'@'语法糖来作为装饰器装饰函数

```
def my_decorator(func):
    def wrapper():
        print("Something is happening before the function is called.")
        func()
        print("Something is happening after the function is called.")
    return wrapper

@my_decorator
def say_whee():
    print("Whee!")
```

#### 4、修饰带参数函数的修饰器

>如果被装饰函数带有参数，则装饰器需要带上`*args, **kwargs`等以接受参数，否则会报错。

```
def do_twice(func):
    def wrapper_do_twice(*args, **kwargs):
        func(*args, **kwargs)
        func(*args, **kwargs)
    return wrapper_do_twice


@do_twice
def greet(name):
    print(f"Hello {name}")


>>> greet("World")
Hello World
Hello World
```

#### 5、从装饰器返回值

>使用`return func(*args, **kwargs)`或`value = func(*args, **kwargs) return value`

```
import functools


def do_twice(func):
    # functools.wraps()用于在运行时能正确获取被装饰函数自身的真名和文档注释等属性
    @functools.wraps(func)
    def wrapper_do_twice(*args, **kwargs):
        func(*args, **kwargs)
        # return func()也算一次调用被装饰函数
        return func(*args, **kwargs)
    return wrapper_do_twice

@do_twice
def return_greeting(name):
    print("Creating greeting")
    return f"Hi {name}"


>>> return_greeting("Adam")
Creating greeting
Creating greeting
'Hi Adam'
```

#### 6、自带参数的修饰器

>如果装饰器带有参数，得再嵌套一个函数用于接收装饰器的参数。

>逐层进入到修饰器最里面的函数`func`即`greet`函数，执行函数`greet`，循环4次格式化打印`Hello World`，并赋值给`value`，然后逐层退出函数。

```
def repeat(num_times):
    def decorator_repeat(func):
        @functools.wraps(func)
        def wrapper_repeat(*args, **kwargs):
            for _ in range(num_times):
                value = func(*args, **kwargs)
            return value
        return wrapper_repeat
    return decorator_repeat


@repeat(num_times=4)
def greet(name):
    print(f"Hello {name}")


>>> greet("World")
Hello World
Hello World
Hello World
Hello World
```

#### 7、函数装饰器常用模板

```
import functools

def decorator(func):
    @functools.wraps(func)
    def wrapper_decorator(*args, **kwargs):
        # Do something before
        value = func(*args, **kwargs)
        # Do something after
        return value
    return wrapper_decorator


@decorator
def yourmethod(args):
    pass
```

#### 8、装饰器实现计时功能

- 用timer装饰函数
```
import functools
import time

def timer(func):
    """Print the runtime of the decorated function"""
    @functools.wraps(func)
    def wrapper_timer(*args, **kwargs):
        start_time = time.perf_counter()    # 1
        value = func(*args, **kwargs)
        end_time = time.perf_counter()      # 2
        run_time = end_time - start_time    # 3
        print(f"Finished {func.__name__!r} in {run_time:.4f} secs")
        return value
    return wrapper_timer

@timer
def waste_some_time(num_times):
    for _ in range(num_times):
        sum([i**2 for i in range(10000)])


>>> waste_some_time(1)
Finished 'waste_some_time' in 0.0010 secs

>>> waste_some_time(999)
Finished 'waste_some_time' in 0.3260 secs
```

- 用timer装饰类

```
@timer
class TimeWaster:
    def __init__(self, max_num):
        self.max_num = max_num

    def waste_time(self, num_times):
        for _ in range(num_times):
            sum([i**2 for i in range(self.max_num)])

>>> tw = TimeWaster(1000)
Finished 'TimeWaster' in 0.0000 secs

>>> tw.waste_time(999)
>>>    
```

#### 9、装饰器实现debug功能

>f-string文档：https://www.python.org/dev/peps/pep-0498/#s-r-and-a-are-redundant

```
import functools

def debug(func):
    """Print the function signature and return value"""
    @functools.wraps(func)
    def wrapper_debug(*args, **kwargs):
        args_repr = [repr(a) for a in args]                      # 1
        kwargs_repr = [f"{k}={v!r}" for k, v in kwargs.items()]  # 2
        signature = ", ".join(args_repr + kwargs_repr)           # 3
        print(f"Calling {func.__name__}({signature})")
        value = func(*args, **kwargs)
        # f-string: 有效字符变量: 's', 'r', 'a'，f'{a!r}'等于f'{repr(a)}'，f'{a!s}'等于f'{str(a)}'，f'{a!a}'等于f'{ascii(a)}'
        print(f"{func.__name__!r} returned {value!r}")           # 4
        return value
    return wrapper_debug


@debug
def make_greeting(name, age=None):
    if age is None:
        return f"Howdy {name}!"
    else:
        return f"Whoa {name}! {age} already, you are growing up!"


>>> make_greeting("Benjamin")
Calling make_greeting('Benjamin')
'make_greeting' returned 'Howdy Benjamin!'
'Howdy Benjamin!'

>>> make_greeting("Richard", age=112)
Calling make_greeting('Richard', age=112)
'make_greeting' returned 'Whoa Richard! 112 already, you are growing up!'
'Whoa Richard! 112 already, you are growing up!'

>>> make_greeting(name="Dorrisile", age=116)
Calling make_greeting(name='Dorrisile', age=116)
'make_greeting' returned 'Whoa Dorrisile! 116 already, you are growing up!'
'Whoa Dorrisile! 116 already, you are growing up!'
```

#### 10、函数装饰器装饰类里面的函数

>上面写的函数装饰器用于装饰类里面的函数

```
from decorators import debug, timer

class TimeWaster:
    @debug
    def __init__(self, max_num):
        self.max_num = max_num

    @timer
    def waste_time(self, num_times):
        for _ in range(num_times):
            sum([i**2 for i in range(self.max_num)])


>>> tw = TimeWaster(1000)
Calling __init__(<time_waster.TimeWaster object at 0x7efccce03908>, 1000)
'__init__' returned None

>>> tw.waste_time(999)
Finished 'waste_time' in 0.3376 secs
```

#### 11、嵌套使用装饰器

>多个装饰器可以嵌套装饰同一个函数

```
@debug
@do_twice
def greet(name):
    print(f"Hello {name}")


>>> greet("Eva")
Calling greet('Eva')
Hello Eva
Hello Eva
'greet' returned None
```

#### 12、装饰器实现添加插件功能

>调用了`@register`装饰后会将函数名加入到字典`PLUGINS = dict()`

```
import random
PLUGINS = dict()

def register(func):
    """Register a function as a plug-in"""
    PLUGINS[func.__name__] = func
    return func

@register
def say_hello(name):
    return f"Hello {name}"

@register
def be_awesome(name):
    return f"Yo {name}, together we are the awesomest!"

def randomly_greet(name):
    greeter, greeter_func = random.choice(list(PLUGINS.items()))
    print(f"Using {greeter!r}")
    return greeter_func(name)


>>> PLUGINS
{'say_hello': <function say_hello at 0x7f768eae6730>,
 'be_awesome': <function be_awesome at 0x7f768eae67b8>}

>>> randomly_greet("Alice")
Using 'say_hello'
'Hello Alice'
```

#### 13、装饰器记录函数调用次数功能（使用函数装饰器）

>这里使用函数的`num_calls`来实现函数调用次数统计，没看到哪里有定义这个变量，搜文档也搜不到这个属性，但是执行并不报错，有知道的童鞋告知一下，谢谢！
```
import functools

def count_calls(func):
    @functools.wraps(func)
    def wrapper_count_calls(*args, **kwargs):
        wrapper_count_calls.num_calls += 1
        print(f"Call {wrapper_count_calls.num_calls} of {func.__name__!r}")
        return func(*args, **kwargs)
    wrapper_count_calls.num_calls = 0
    return wrapper_count_calls

@count_calls
def say_whee():
    print("Whee!")

say_whee()
say_whee()
print(say_whee.num_calls)

output:
Call 1 of 'say_whee'
Whee!
Call 2 of 'say_whee'
Whee!
2
```

#### 14、装饰器记录函数调用次数功能（使用类装饰器）

>使用类的魔法方法`__call__`实现函数调用次数统计
```
import functools

class CountCalls:
    def __init__(self, func):
        functools.update_wrapper(self, func)
        self.func = func
        self.num_calls = 0

    def __call__(self, *args, **kwargs):
        self.num_calls += 1
        print(f"Call {self.num_calls} of {self.func.__name__!r}")
        return self.func(*args, **kwargs)

@CountCalls
def say_whee():
    print("Whee!")


>>> say_whee()
Call 1 of 'say_whee'
Whee!

>>> say_whee()
Call 2 of 'say_whee'
Whee!

>>> say_whee.num_calls
2
```

### 结语
>这篇文章基本是一步步深入的，所以按步骤去看会比较容易易理解

- 文章原文:https://realpython.com/primer-on-python-decorators/)
- 示例源码：https://github.com/realpython/materials/tree/master/primer-on-python-decorators

#### 类的内置装饰器

>参考文章里面还提到类的内置装饰器，但没有具体讲，下一篇笔记来看看内置装饰器`staticmethod`、`classmethod`、`property`
