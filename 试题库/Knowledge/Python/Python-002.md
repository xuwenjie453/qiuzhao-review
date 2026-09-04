### Python-002-001 | ★★★☆☆

Python怎么处理高并发？

**答案：**
按任务类型选模型：IO密集用asyncio协程（单线程事件循环，万级并发）或多线程/线程池（IO等待释放GIL）；CPU密集用multiprocessing多进程或进程池（绕过GIL真并行）。工程上再结合异步框架（FastAPI+uvicorn）、连接池、缓存、消息队列削峰。Python 3.13起还有free-threading实验方案。


### Python-002-002 | ★★★☆☆

进程和线程的区别是什么？线程相比进程有什么优点？

**答案：**
进程是资源分配的基本单位有独立地址空间，线程是CPU调度的基本单位共享进程资源；线程更轻量、切换开销小、通信成本低。


### Python-002-003 | ★★★☆☆

请阐述Python中迭代器的概念。

**答案：**
迭代器是实现了__iter__()（返回自身）和__next__()的对象，next()逐个返回元素、耗尽后抛出StopIteration。它是有状态、惰性、一次性的（不能回退），for循环本质是iter()取得迭代器后反复调用next()直到StopIteration；可迭代对象（实现__iter__）通过iter()获取迭代器。


### Python-002-004 | ★★★☆☆

迭代器和生成器的区别是什么？

**答案：**
生成器是一种特殊的迭代器：用yield的函数或生成器表达式自动实现迭代器协议，语法更简洁；迭代器是协议层面的概念（任意实现__iter__/__next__的类）。生成器额外支持send/throw/close双向通信，两者都是惰性求值、节省内存，但生成器不能重置只能遍历一次。


### Python-002-005 | ★★★☆☆

手写一个装饰器：统计当前函数执行时间，并打印。

**答案：**
import functools, time；def timer(func): @functools.wraps(func) def wrapper(*args, **kwargs): start = time.perf_counter(); result = func(*args, **kwargs); print(f"{func.__name__} 耗时 {time.perf_counter() - start:.4f}s"); return result；return wrapper。核心：内层wrapper记录前后perf_counter差并打印，functools.wraps保留函数元信息，支持任意参数并返回原结果。


### Python-002-006 | ★★★☆☆

什么是装饰器？如果让你设计一个多线程环境中安全的装饰器，你会如何设计？

**答案：**
装饰器是接收函数并返回新函数的高阶函数，用@语法无侵入地附加日志、缓存、鉴权等逻辑（配合functools.wraps保留元信息）。线程安全设计：装饰器内共享状态（缓存/计数）用threading.Lock/RLock保护临界区；无共享状态则用threading.local做线程本地存储；尽量避免修改全局可变对象，异步环境用asyncio.Lock。


### Python-002-007 | ★★★☆☆

Python多线程有什么好处？Python多进程和多线程分别适用什么场景？什么是Python协程？

**答案：**
GIL使多线程无法并行执行CPU字节码，但IO阻塞时释放GIL，故多线程适合IO密集任务（网络请求、文件读写），好处是共享内存通信简单、切换开销小于进程；多进程适合CPU密集（真并行）；协程由事件循环在单线程内调度（async/await），切换开销极小，适合超高并发IO（爬虫、网关）。


### Python-002-008 | ★★★☆☆

介绍一下Python中的sequence和mapping代表的数据结构。

**答案：**
sequence是有序容器：支持整数索引、切片、len()、in、拼接，代表类型str、list、tuple、range、bytes；mapping是键值映射容器：按键访问、提供keys/values/items视图，代表类型dict及defaultdict/OrderedDict/Counter。两者接口分别由collections.abc中的Sequence和Mapping抽象基类定义。

