---
title: "python内置装饰器"
date: 2019-09-17T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/1DEE64A6D9A84BA0BC3C7A02725B811D?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "python"
tags:
  - "python"
  - "decorator"
---

#### 前言

接着上一篇笔记，我们来看看内置装饰器`property`、`staticmethod`、`classmethod`

#### 一、property装饰器

##### 1. 普通方式修改属性值

- code

```
class Celsius:
    def __init__(self, temperature = 0):
        self.temperature = temperature

    def to_fahrenheit(self):
        return (self.temperature * 1.8) + 32

man = Celsius(-280)
print('dirctly get:', man.temperature)
print('to_fahrenheit', man.to_fahrenheit())
# 查看示例的属性
print(man.__dict__)
```

- output

```
dirctly get: -280
to_fahrenheit: -472.0
{'temperature': -280}
```
这里直接通过实例来修改类的属性值，但从输出可以看到温度超过了绝对零度-273.15却没有保错，这是一个bug，下面来修复下。

##### 2. 使用`get_xxx`, `set_xxx`方法修改类的属性值

- code

```
class Celsius:
    def __init__(self, temperature = 0):
        self.set_temperature(temperature)

    def to_fahrenheit(self):
        return (self.get_temperature() * 1.8) + 32

    # new update
    def get_temperature(self):
        return self._temperature

    def set_temperature(self, value):
        if value < -273:
            raise ValueError("Temperature below -273 is not possible")
        self._temperature = value


# 超过绝对零度报错
# man = Celsius(-280)
man = Celsius(-28)
# temperature改为_temperature了
#print('dirctly get:', man.temperature)
print('dirctly get:', man._temperature)
print('use get_temperature get:', man.get_temperature())
print('to_fahrenheit:', man.to_fahrenheit())
# 查看示例的属性
print(man.__dict__)
```

- output

```
dirctly get: -28
use get_temperature get: -28
to_fahrenheit: -18.4
{'_temperature': -28}
```

这里用一个私有变量`_temperature`来对`temperature`做限制。新增了`get_xxx`, `set_xxx`方法来修复了bug，但这样的话用到了这个类的代码都要修改了，获取温度值要将`obj.temperature`修改为`obj.get_temperature()`，修改温度值要将`obj.temperature = val`修改为`obj.set_temperature(val)`。如果有成千上万行代码用到这个类的话，显然这样修改是不行的，下面使用`@property`来解决。

##### 3. 使用`@property`装饰器修改类的属性值
- code
```
class Celsius:
    def __init__(self, temperature = 0):
        # 不知道是不是作者写多了‘_’下划线，如果用私有变量_temperature的话，
        # 在类初始化时就赋值并不会调用setter判断温度是否大于-273度，所以还会出现bug
        # self._temperature = temperature
        self.temperature = temperature

    def to_fahrenheit(self):
        return (self.temperature * 1.8) + 32

    @property
    def temperature(self):
        print("Getting value")
        return self._temperature

    @temperature.setter
    def temperature(self, value):
        print('vvvvvv', value)
        if value < -273:
            raise ValueError("Temperature below -273 is not possible")
        print("Setting value")
        self._temperature = value


man = Celsius(-28)
print('dirctly get:', man.temperature)

# man.temperature(-28)会报错：TypeError: 'int' object is not callable
# 使用property后temperture(self, value)只能通过属性赋值方式更改
# print('use @temperature.setter:', man.temperature(-28))
man.temperature = -88

print('to_fahrenheit:', man.to_fahrenheit())
print(man.__dict__)
```

- output

```
vvvvvv -28
Setting value
Getting value
dirctly get: -28
vvvvvv -88
Setting value
Getting value
to_fahrenheit: -126.4
{'_temperature': -88}
```

`@property`装饰器就是调用了python内置方法`property(fget=None, fset=None, fdel=None, doc=None)`，上面`@temperature.setter`就相当于`fset=temperature`方法。**使用了`@property`装饰器，就可以在不影响原有代码的情况下修改类的属性值**。

- 参考文章

>`https://www.programiz.com/python-programming/property`

#### 二、staticmethod装饰器(静态方法)

静态方法的用得很少，当需要一个**不访问类的任何属性，但它属于该类的实用函数**时就可以用**静态方法，它只处理传入的参数**。比如下面的静态方法就单纯接收一个参数`date`更改下它的连接符就返回了，但因为跟类`Dates`放一起比较好归类管理才放到类里面的。可以**用类直接调用静态方法**，也可以**用类的实例调用静态方法**。

- code

```
class Dates:
    def __init__(self, date):
        self.date = date
        
    def getDate(self):
        return self.date

    @staticmethod
    def toDashDate(date):
        return date.replace("/", "-")

date = Dates("15-12-2016")
dateFromDB = "15/12/2016"
# 用类直接调用静态方法
dateWithDash = Dates.toDashDate(dateFromDB)
# 用类的实例调用静态方法
dateWithDash_1 = date.toDashDate(dateFromDB)

if(date.getDate() == dateWithDash):
    print("Equal")
if(date.getDate() == dateWithDash_1):
    print("Equal_1")
else:
    print("Unequal")
```

- output

```
Equal
Equal_1
```

- 参考文章

>`https://www.programiz.com/python-programming/methods/built-in/staticmethod`

#### 三、classmethod装饰器(类方法)

- code

```
from datetime import date

# random Person
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    @classmethod
    def fromBirthYear(cls, name, birthYear):
        return cls(name, date.today().year - birthYear)

    def display(self):
        print(self.name + "'s age is: " + str(self.age))

person = Person('Adam', 19)
person.display()

person1 = Person.fromBirthYear('John',  1985)
person1.display()
```
- output

```
Adam's age is: 19
John's age is: 34
```

从上面的例子可以看到，类方法需要有一个必需参数`cls`，而不是`self`(也可以是其他名字，但约定俗成用cls)，因为**类方法的参数`cls`就是这个类本身。**，所以`cls(name, date.today().year - birthYear)`等同于调用了`Person(name, date.today().year - birthYear)`。**当我们调用的类方法`return cls(arg1,arg2)`后**，因为类方法的参数`cls`就是这个类本身，所以就**会将这些参数赋值给类的`__init__`函数再次初始化**。

有些童鞋应该发现了上面的示例**也可以用静态方法来实现**，但这样的话它**创建的实例就硬编码为只属于基类**了(当我们不希望类的子类更改/重写方法的特定实现时，静态方法就派上用场了)。也就是用确定的一个类`Person`代替了`cls`，这样就是硬编码创建的实例只属于基类`Person`了。如果有类继承基类的话，使用静态方法创建的实例只属于基类，继承了基类的子类都不属于实例，而**使用类方法的话，继承了基类的子类创建的实例，既属于基类也属于继承了基类的子类**。看下面代码就懂了。

- code

```
from datetime import date

# random Person
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    @staticmethod
    def fromBirthYearStaticmethod(name, birthYear):
        return Person(name, date.today().year - birthYear)

    @classmethod
    def fromBirthYearClassmethod(cls, name, birthYear):
        return cls(name, date.today().year - birthYear)

    def display(self):
        print(self.name + "'s age is: " + str(self.age))

class Man(Person):
    sex = 'Male'

class MoreMan(Man):
    sex = 'Unknown'


man = Man.fromBirthYearClassmethod('John', 1985)
print('使用类方法')
man.display()
print('man是类Man的实例吗', isinstance(man, Man))
print('man是类Person的实例吗', isinstance(man, Person))

man1 = Man.fromBirthYearStaticmethod('John', 1985)
print('使用静态方法')
man1.display()
print('man1是类Man的实例吗', isinstance(man1, Man))
print('man1是类Person的实例吗', isinstance(man1, Person))

man2 = MoreMan.fromBirthYearClassmethod('John', 1985)
print('使用类方法')
man2.display()
print('man2是类Man的实例吗', isinstance(man2, Man))
print('man2是类MoreMan的实例吗', isinstance(man2, MoreMan))
print('man2是类Person的实例吗', isinstance(man2, Person))

man3 = MoreMan.fromBirthYearStaticmethod('John', 1985)
print('使用静态方法')
man3.display()
print('man3是类Man的实例吗', isinstance(man3, Man))
print('man3是类MoreMan的实例吗', isinstance(man3, MoreMan))
print('man3是类Person的实例吗', isinstance(man3, Person))
```

- output

```
使用类方法
John's age is: 34
man是类Man的实例吗 True
man是类Person的实例吗 True
使用静态方法
John's age is: 34
man1是类Man的实例吗 False
man1是类Person的实例吗 True
使用类方法
John's age is: 34
man2是类Man的实例吗 True
man2是类MoreMan的实例吗 True
man2是类Person的实例吗 True
使用静态方法
John's age is: 34
man3是类Man的实例吗 False
man3是类MoreMan的实例吗 False
man3是类Person的实例吗 True
```

从上面的输出就可以看出来了，虽然静态方法也可以实现功能，但在继承的时候却没有继承给子类。所以如果一个方法需要被继承的子类使用的话还是用类方法。相反，当我们不希望类的子类更改/重写方法的特定实现时，就用静态方法。

- 参考文章

>`https://www.programiz.com/python-programming/methods/built-in/classmethod`

#### 四、综合比较

实例方法，类方法，静态方法的综合比较，异同见代码注释。

- code

```
class C():
    # instance method
    def ins(self):
        print("instance method")
    @staticmethod
    def sta():
        print("static method")
    @classmethod
    def cla(cls, c_arg):
        print("class method %s" % c_arg)

# 实例化类C()
ins_cls = C()

# 实例方法只能用实例调用，不可用直接用类调用，会报错：“TypeError: ins() missing 1 required positional argument: 'self'”
# C.ins()
ins_cls.ins()
# 静态方法可以通过类调用，也可以通过实例调用
C.sta()
ins_cls.sta()
# 类方法可以通过类调用，也可以通过实例调用cla(cls)中的参数cls就是调用它的类本身，cls跟self差不多，用的时候只需传实际参数c_arg即可
C.cla("class_arg")
ins_cls.cla("class_arg")
```
- output
```
instance method
static method
static method
class method
class method
```
