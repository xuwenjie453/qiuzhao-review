### Design-001-001 | ★★★★★

手写 LRU 缓存（阿里面经原题：说一下 LRU 缓存结构的实现，HashMap + 双向链表；腾讯云面经同样追问 LRU 中 makeRecently(key) 的作用）。设计并实现 LRUCache 类：LRUCache(capacity) 以正整数容量初始化；get(key) 如果 key 存在返回其值并把它标记为最近使用，否则返回 -1；put(key, value) 写入/更新键值对，若容量超限淘汰最久未使用的 key。要求 get 与 put 都是 O(1)：哈希表定位节点 + 双向链表（头部最近、尾部最久）维护顺序，现场写出节点移动到头部、删除尾节点等细节。示例：capacity=2，put(1,1)、put(2,2) 后 get(1)=1，put(3,3) 淘汰 2，get(2)=-1，put(4,4) 淘汰 1，get(1)=-1，get(3)=3，get(4)=4。

**答案（Python 3）：**

```python
class Node:
    __slots__ = ('key', 'val', 'prev', 'next')

    def __init__(self, key=0, val=0):
        self.key = key
        self.val = val
        self.prev = None
        self.next = None

class LRUCache:
    '''LRU 缓存：哈希表 O(1) 定位节点 + 双向链表维护顺序（头部最近、尾部最久）'''
    def __init__(self, capacity: int):
        self.cap = capacity
        self.map = {}
        self.head, self.tail = Node(), Node()   # 头尾哨兵，省去边界判断
        self.head.next = self.tail
        self.tail.prev = self.head

    def _remove(self, node):                    # 摘除节点
        node.prev.next = node.next
        node.next.prev = node.prev

    def _add_front(self, node):                 # 头插（表示最近使用）
        node.next = self.head.next
        node.prev = self.head
        self.head.next.prev = node
        self.head.next = node

    def _make_recently(self, node):
        '''makeRecently：先摘除再头插，把节点移动到头部表示刚被使用'''
        self._remove(node)
        self._add_front(node)

    def _evict_last(self):                      # 删除尾部节点（最久未使用）
        last = self.tail.prev
        self._remove(last)
        del self.map[last.key]

    def get(self, key: int) -> int:
        if key not in self.map:
            return -1
        node = self.map[key]
        self._make_recently(node)
        return node.val

    def put(self, key: int, value: int) -> None:
        if key in self.map:
            node = self.map[key]
            node.val = value
            self._make_recently(node)
            return
        if len(self.map) >= self.cap:
            self._evict_last()                  # 容量超限，淘汰最久未使用
        node = Node(key, value)
        self.map[key] = node
        self._add_front(node)

# 验证：cap=2：put(1,1) put(2,2) 后 get(1)=1；put(3,3) 淘汰 2，get(2)=-1；
# put(4,4) 淘汰 1，get(1)=-1，get(3)=3，get(4)=4
```

**解析：**
哈希表 key→节点 + 带头尾哨兵的双向链表，get/put 均 O(1)；makeRecently（摘除+头插）是核心动作，put 超容量时删尾节点并同步删哈希表项。


### Design-001-002 | ★★★★☆

LFU 缓存。设计并实现最不经常使用（LFU）缓存：LFUCache(capacity) 初始化；get(key) 存在则返回值并使其使用频次 +1，否则 -1；put(key, value) 写入，容量满时淘汰"使用频次最低"的键，频次相同时淘汰最久未使用的键。要求 get 与 put 均为 O(1)：哈希表 + 按频次分桶的双向链表（或 freq -> LinkedHashSet）。示例：capacity=2，put(1,1)、put(2,2) 后 get(1)=1，put(3,3) 淘汰 2（频次 1 且更旧），get(2)=-1，get(3)=3。

**答案（Python 3）：**

```python
from collections import defaultdict, OrderedDict

class LFUCache:
    '''LFU 缓存：key -> (val, freq) 哈希表 + freq -> OrderedDict 按频次分桶，get/put 均 O(1)'''
    def __init__(self, capacity: int):
        self.cap = capacity
        self.kv = {}                                # key -> (val, freq)
        self.buckets = defaultdict(OrderedDict)     # freq -> {key: None}，桶内插入序即访问序
        self.min_freq = 0                           # 全局最低频次

    def _touch(self, key, val, freq):
        '''频次 +1：从旧桶移除、加入新桶尾部；旧桶空则删除并维护 min_freq'''
        del self.buckets[freq][key]
        if not self.buckets[freq]:
            del self.buckets[freq]
            if self.min_freq == freq:
                self.min_freq += 1
        self.buckets[freq + 1][key] = None
        self.kv[key] = (val, freq + 1)

    def get(self, key: int) -> int:
        if key not in self.kv:
            return -1
        val, freq = self.kv[key]
        self._touch(key, val, freq)
        return val

    def put(self, key: int, value: int) -> None:
        if self.cap <= 0:
            return
        if key in self.kv:
            val, freq = self.kv[key]
            self._touch(key, value, freq)           # 更新值并频次 +1
            return
        if len(self.kv) >= self.cap:
            # 淘汰最低频次桶中「最久未使用」的 key（桶内 OrderedDict 头部）
            evict_key, _ = self.buckets[self.min_freq].popitem(last=False)
            del self.kv[evict_key]
        self.kv[key] = (value, 1)                   # 新 key 频次为 1
        self.buckets[1][key] = None
        self.min_freq = 1

# 验证：cap=2：put(1,1) put(2,2) 后 get(1)=1；put(3,3) 淘汰 2（频次 1 且更旧），
# get(2)=-1，get(3)=3
```

**解析：**
按频次分桶，桶内 OrderedDict 的插入顺序即访问顺序：频次+1 时旧桶删、新桶尾插；淘汰时取 min_freq 桶的头部（最旧），get/put 均摊 O(1)。


### Design-001-003 | ★★★★☆

用 Rand7() 实现 Rand10()。给定接口 rand7() 可均匀生成 1~7 的随机整数，试用它实现 rand10() 均匀生成 1~10 的随机整数，要求期望次数尽量少并证明均匀性：拒绝采样 (rand7()-1)*7 + rand7() 得到 1~49，大于 40 时重采样，%10+1。输入：无；输出：[1,10] 内均匀分布的整数。追问：为什么 %10 之前要先把 41~49 拒绝掉。

**答案（Python 3）：**

```python
import random

def rand7():
    return random.randint(1, 7)     # 题目给定接口：均匀生成 1~7

class Solution:
    def rand10(self) -> int:
        while True:
            # 拒绝采样：(rand7()-1)*7 + rand7() 把两次结果均匀映射到 1~49
            num = (rand7() - 1) * 7 + rand7()
            if num <= 40:                   # 只保留 1~40（10 的倍数个），41~49 重采样
                return (num - 1) % 10 + 1   # 1~40 中每个余数恰好对应 4 个原值，均匀

# 追问：为什么 %10 前要先把 41~49 拒绝掉？
#   49 不是 10 的倍数：若直接对 1~49 取余，余数 1~9 各出现 5 次而 0 只出现 4 次，
#   分布不均；拒绝到恰好 40 个（10 的倍数）后每个余数对应 4 个原值，才严格均匀。
# 期望次数：每轮成功概率 40/49，期望调用 rand7 约 2 * 49/40 ≈ 2.45 次。
```

**解析：**
经典拒绝采样：两次 rand7 拼出 1~49 的均匀数，只接受前 40 个再 %10+1，每个输出概率恰为 4/49；期望约 2.45 次 rand7 调用，拒绝到 10 的倍数个是均匀性的前提。


### Design-001-004 | ★★★★☆

手写深拷贝（前端面经原题：模拟实现一个深拷贝，并考虑对象相互引用以及 Symbol 拷贝的情况）。实现 deepClone(obj)：支持基本类型、普通对象、数组、Date、RegExp，能正确处理循环引用（用 WeakMap 缓存已拷贝对象），能拷贝 Symbol 作为键的属性（Reflect.ownKeys），能保留原型链。示例：const a = {n: 1}; a.self = a; const b = deepClone(a); b.self === b 且 b !== a。

**答案（Python 3）：**

```python
// 手写深拷贝（题干为前端 JS 语义：Symbol 键、原型链，故用 JavaScript 实现）
function deepClone(obj, map = new WeakMap()) {
  if (obj === null || typeof obj !== 'object') return obj;             // 基本类型/函数直接返回
  if (obj instanceof Date) return new Date(obj);                       // Date
  if (obj instanceof RegExp) return new RegExp(obj.source, obj.flags); // RegExp
  if (map.has(obj)) return map.get(obj);   // 循环引用：命中缓存直接返回，避免无限递归
  // 保留原型链：数组用 []，普通对象用 Object.create(原原型)
  const clone = Array.isArray(obj) ? [] : Object.create(Object.getPrototypeOf(obj));
  map.set(obj, clone);
  // Reflect.ownKeys = string 键 + Symbol 键（含不可枚举），保证 Symbol 属性也被拷贝
  for (const key of Reflect.ownKeys(obj)) {
    clone[key] = deepClone(obj[key], map);
  }
  return clone;
}
// 验证：const a = { n: 1 }; a.self = a;
// const b = deepClone(a);  b.self === b  且  b !== a
```

**解析：**
WeakMap 缓存已拷贝对象解决循环引用，Reflect.ownKeys 同时拷贝 Symbol 键，Object.create 保留原型链，Date/RegExp 特判；整体时间 O(n)。


### Design-001-005 | ★★★★☆

手写防抖与节流（前端高频面经题：什么是防抖和节流？有什么区别？如何实现？）。实现 debounce(fn, wait)：事件停止触发 wait 毫秒后才执行一次 fn，期间再次触发则重新计时（返回新函数，维护 timer，支持用闭包保存 this 和参数）；实现 throttle(fn, interval)：每隔 interval 最多执行一次 fn（时间戳版与定时器版）。示例：input 输入时用防抖做搜索联想；scroll 监听用节流做埋点。追问：是否需要立即执行一次（leading）、取消功能如何实现。

**答案（Python 3）：**

```python
// 手写防抖与节流（前端语义，JavaScript 实现）
// 防抖 debounce：停止触发 wait 毫秒后才执行一次，期间再触发则重新计时
function debounce(fn, wait, immediate = false) {
  let timer = null;
  function debounced(...args) {
    if (immediate && !timer) fn.apply(this, args);   // 追问：leading 首次立即执行
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      if (!immediate) fn.apply(this, args);          // 闭包保存 this 与参数
      timer = null;
    }, wait);
  }
  debounced.cancel = () => { clearTimeout(timer); timer = null; };  // 追问：取消功能
  return debounced;
}

// 节流 throttle（时间戳版）：每隔 interval 最多执行一次，首次立即执行
function throttle(fn, interval) {
  let last = 0;
  return function (...args) {
    const now = Date.now();
    if (now - last >= interval) {
      last = now;
      fn.apply(this, args);
    }
  };
}

// 节流（定时器版）：停止触发后还会补执行最后一次
function throttleTimer(fn, interval) {
  let timer = null;
  return function (...args) {
    if (timer) return;
    timer = setTimeout(() => {
      timer = null;
      fn.apply(this, args);
    }, interval);
  };
}
// 场景：input 输入用防抖做搜索联想；scroll 监听用节流做埋点
```

**解析：**
防抖=最后一次触发后延迟执行（适合搜索联想），节流=固定周期内至多一次（适合滚动埋点）；均用闭包保存 timer/this/args，immediate 与 cancel 是常见追问扩展。


### Design-001-006 | ★★★★☆

手写 call / apply。实现 Function.prototype.myCall(context, ...args) 与 Function.prototype.myApply(context, argsArray)：将函数的 this 指向 context 并立即调用。要求：context 为 null/undefined 时绑定为全局对象；以 Symbol/唯一属性临时挂到 context 上调用后删除；处理参数展开与返回值透传。示例：function f(a, b) { return this.v + a + b; } f.myCall({v: 1}, 2, 3) === 6。

**答案（Python 3）：**

```python
// 手写 call / apply（前端语义，JavaScript 实现）
Function.prototype.myCall = function (context, ...args) {
  // null/undefined 绑定为全局对象，原始值包装成对象
  context = (context === null || context === undefined) ? globalThis : Object(context);
  const key = Symbol('fn');          // 唯一属性名，避免覆盖 context 已有属性
  context[key] = this;               // 临时挂载：作为对象方法调用时 this 隐式指向 context
  const result = context[key](...args);
  delete context[key];               // 调用后删除临时属性
  return result;
};

Function.prototype.myApply = function (context, argsArray) {
  context = (context === null || context === undefined) ? globalThis : Object(context);
  const key = Symbol('fn');
  context[key] = this;
  const result = context[key](...(argsArray || []));   // apply：参数为数组展开传入
  delete context[key];
  return result;
};
// 验证：function f(a, b) { return this.v + a + b; }
// f.myCall({ v: 1 }, 2, 3) === 6   f.myApply({ v: 1 }, [2, 3]) === 6
```

**解析：**
核心是「以 context 的方法形式调用」：用 Symbol 临时属性挂载函数让隐式 this 绑定生效，调用后删除并透传返回值；call 展开参数、apply 接收数组。


### Design-001-007 | ★★★★☆

手写 bind。实现 Function.prototype.myBind(context, ...presetArgs)：返回一个新函数，新函数 this 固定为 context 并可合并预设参数与调用时参数；作为构造函数调用时（new）this 应绑定到新实例而不是 context，且能继承原函数原型。示例：const fn = say.myBind(obj, 'a'); fn('b') 等价于 say.call(obj, 'a', 'b')。

**答案（Python 3）：**

```python
// 手写 bind（前端语义，JavaScript 实现）
Function.prototype.myBind = function (context, ...presetArgs) {
  const fn = this;                       // 原函数
  function bound(...args) {
    // new 调用时 this 是 bound 的新实例，此时应绑定新实例而不是 context
    return fn.apply(this instanceof bound ? this : context, [...presetArgs, ...args]);
  }
  // 继承原函数原型：new bound() 的实例 instanceof 原函数成立
  if (fn.prototype) bound.prototype = Object.create(fn.prototype);
  return bound;
};
// 验证：const fn = say.myBind(obj, 'a'); fn('b') 等价于 say.call(obj, 'a', 'b')
// new 出的实例 instanceof 原函数 === true
```

**解析：**
返回闭包函数合并预设参数与调用参数；用 this instanceof bound 区分 new 调用（this 绑到新实例），Object.create 继承原型保证 instanceof 与原型链正确。


### Design-001-008 | ★★★★☆

手写 new。实现函数 myNew(Fn, ...args)：创建一个空对象并继承 Fn.prototype；以该对象为 this 执行 Fn(args)；若执行结果为对象则返回该结果，否则返回新创建的对象。示例：function P(name) { this.name = name; } const p = myNew(P, 'x'); p instanceof P === true 且 p.name === 'x'。

**答案（Python 3）：**

```python
// 手写 new（前端语义，JavaScript 实现）
function myNew(Fn, ...args) {
  const obj = Object.create(Fn.prototype);   // 1. 创建空对象并继承 Fn.prototype
  const result = Fn.apply(obj, args);        // 2. 以 obj 为 this 执行构造函数
  // 3. 构造函数显式返回对象/函数时用该返回值，否则返回新建对象
  return (result !== null && (typeof result === 'object' || typeof result === 'function'))
    ? result
    : obj;
}
// 验证：function P(name) { this.name = name; }
// const p = myNew(P, 'x');  p instanceof P === true  且  p.name === 'x'
```

**解析：**
myNew 三步曲：Object.create 挂原型链、apply 绑 this 执行构造函数、按返回值类型决定返回构造结果还是新对象；instanceof 成立靠第一步建立的原型链。


### Design-001-009 | ★★★★☆

函数柯里化（前端面经原题：请实现一个 add 函数，满足 add(1)(2)(3) === 6 及 add(1, 2)(3) === 6）。实现 curry(fn) 将多参函数转换为可分步传参的柯里化函数：不断收集参数，参数数量达到 fn.length 时执行并返回结果，否则返回继续收集参数的新函数。示例：const cAdd = curry((a,b,c) => a+b+c); cAdd(1,2,3) === 6; cAdd(1)(2,3) === 6; cAdd(1)(2)(3) === 6。

**答案（Python 3）：**

```python
// 函数柯里化（前端语义，JavaScript 实现）
function curry(fn) {
  return function curried(...args) {
    if (args.length >= fn.length) {       // 参数数量达到 fn 的形参个数：直接执行
      return fn.apply(this, args);
    }
    return function (...args2) {          // 否则返回继续收集参数的新函数
      return curried.apply(this, [...args, ...args2]);
    };
  };
}
// 验证：const cAdd = curry((a, b, c) => a + b + c);
// cAdd(1, 2, 3) === 6;  cAdd(1)(2, 3) === 6;  cAdd(1)(2)(3) === 6
```

**解析：**
递归收集参数：args 达到 fn.length 就执行原函数，否则返回拼接了已收集参数的新函数，任意分组传参方式都成立。


### Design-001-010 | ★★★★☆

数组扁平化（前端面经原题：使用迭代的方式实现 flatten 函数）。实现 flatten(arr) 将多维数组展开为一维：输入 [1, [2, [3, [4, 5]]]]，输出 [1, 2, 3, 4, 5]。要求：不使用 Array.prototype.flat 的情况下手写；既会递归写法，也会迭代写法（用栈/队列保存元素与深度，或 while 循环 concat 展开），并支持控制展开深度。

**答案（Python 3）：**

```python
// 数组扁平化（前端语义，JavaScript 实现）
// 递归写法：depth 控制展开深度（默认全部展开）
function flattenRecursive(arr, depth = Infinity) {
  const res = [];
  for (const item of arr) {
    if (Array.isArray(item) && depth > 0) {
      res.push(...flattenRecursive(item, depth - 1));
    } else {
      res.push(item);
    }
  }
  return res;
}

// 迭代写法：用栈保存 [元素, 剩余深度]，不使用递归和 Array.prototype.flat
function flatten(arr, depth = Infinity) {
  const res = [];
  const stack = [];
  for (let i = arr.length - 1; i >= 0; i--) stack.push([arr[i], depth]);
  while (stack.length) {
    const [item, d] = stack.pop();
    if (Array.isArray(item) && d > 0) {
      // 倒序压栈，保证出栈顺序与原数组一致
      for (let i = item.length - 1; i >= 0; i--) stack.push([item[i], d - 1]);
    } else {
      res.push(item);
    }
  }
  return res;
}
// 验证：flatten([1, [2, [3, [4, 5]]]]) => [1, 2, 3, 4, 5]
//       flatten([1, [2, [3]]], 1)      => [1, 2, [3]]
```

**解析：**
递归版遇数组且深度未用尽就下钻；迭代版用栈显式模拟，元素携带剩余深度、倒序压栈保证顺序，两种写法都支持 depth 控制展开层数。


### Design-001-011 | ★★★★☆

手写 Promise.all。实现 myPromiseAll(promises)：接收一个 Promise 可迭代对象，全部成功时按传入顺序 resolve 结果数组；任意一个 reject 时立即 reject 该错误（不等待其余 Promise）。要求处理空数组（立即 resolve []）、非 Promise 值（用 Promise.resolve 包装）、计数器逻辑。示例：myPromiseAll([p1, 2, p3]).then(console.log) 输出 [r1, 2, r3]。

**答案（Python 3）：**

```python
// 手写 Promise.all（前端语义，JavaScript 实现）
function myPromiseAll(promises) {
  return new Promise((resolve, reject) => {
    const list = Array.from(promises);            // 兼容任意可迭代对象
    const results = new Array(list.length);
    let count = 0;                                // 已完成计数器
    if (list.length === 0) return resolve([]);    // 空数组：立即 resolve []
    list.forEach((p, i) => {
      Promise.resolve(p).then(value => {          // 非 Promise 值用 Promise.resolve 包装
        results[i] = value;                       // 按传入下标存放，保证结果有序
        if (++count === list.length) resolve(results);
      }, reject);                                 // 任一失败：立即 reject，不等待其余
    });
  });
}
// 验证：myPromiseAll([p1, 2, p3]).then(console.log) 输出 [r1, 2, r3]
```

**解析：**
三个关键点：按下标 i 写结果保证顺序、count 计数到 n 才 resolve、任一 then 的失败回调立即 reject；空数组与非 Promise 值分别用短路和 Promise.resolve 处理。


### Design-001-012 | ★★★★☆

实现 Promise.retry（前端面经原题：成功后 resolve 结果，失败后重试，尝试超过一定次数才真正的 reject）。实现 retry(promiseFactory, times, delay)：调用 promiseFactory() 返回 Promise，成功则 resolve；失败则重试，最多尝试 times 次，全部失败后 reject 最后一次的错误，可支持每次重试间隔 delay 毫秒。示例：retry(fetchData, 3) 当 fetchData 前 2 次失败第 3 次成功时最终成功。

**答案（Python 3）：**

```python
// 实现 Promise.retry（前端语义，JavaScript 实现）
function retry(promiseFactory, times, delay = 0) {
  return new Promise((resolve, reject) => {
    const attempt = left => {
      promiseFactory()
        .then(resolve)                          // 成功：resolve 结果
        .catch(err => {
          if (left <= 1) return reject(err);    // 次数用尽：reject 最后一次的错误
          if (delay > 0) {
            setTimeout(() => attempt(left - 1), delay);   // 支持每次重试间隔 delay
          } else {
            attempt(left - 1);
          }
        });
    };
    attempt(times);                             // 总共最多尝试 times 次
  });
}
// 示例：retry(fetchData, 3)：前 2 次失败第 3 次成功 => 最终成功
```

**解析：**
递归尝试：成功即 resolve，失败且次数未用尽则（可延迟 delay 毫秒后）递归调用工厂函数，用尽才 reject 最后一次错误；times 为总尝试次数。


### Design-001-013 | ★★★★☆

Promise 串行执行 + 失败重试（拼多多前端笔试真题）。实现函数 promiseSeries(tasks, retryTimes)：tasks 是返回 Promise 的任务函数数组，要求按顺序串行执行（前一个完成才执行下一个）；每个任务失败时自动重试最多 retryTimes 次；某个任务重试次数用尽仍失败时，整个序列停止执行并 reject。示例：tasks = [task1, task2(失败), task3]，retryTimes = 2 时 task1 完成后 task2 尝试 3 次都失败，promiseSeries 整体 reject 且 task3 不执行。

**答案（Python 3）：**

```python
// Promise 串行执行 + 失败重试（前端语义，JavaScript 实现）
function promiseSeries(tasks, retryTimes) {
  // 单个任务：失败自动重试，首次 + 重试共 retryTimes + 1 次
  function runWithRetry(task) {
    return new Promise((resolve, reject) => {
      const attempt = left => {
        task().then(resolve).catch(err => {
          if (left <= 0) return reject(err);    // 次数用尽：整个序列 reject
          attempt(left - 1);
        });
      };
      attempt(retryTimes);
    });
  }
  // 串行：前一个完成才把下一个接上链
  let chain = Promise.resolve();
  for (const task of tasks) {
    chain = chain.then(() => runWithRetry(task));
  }
  return chain;
}
// 示例：tasks=[task1, task2(必失败), task3]，retryTimes=2：
// task1 完成后 task2 共尝试 3 次都失败 => 整体 reject，task3 不会执行
```

**解析：**
串行靠 then 链依次衔接（前一个完成才执行下一个），每个任务包一层带计数器的重试 Promise；某任务次数用尽即整链 reject，后续任务自然不再执行。


### Design-001-014 | ★★★★☆

Promise 并发限制（前端高频面经原题：实现一个批量请求函数 multiRequest(urls, maxNum)）。给定 URL 数组 urls 和最大并发数 maxNum，要求：任意时刻正在进行的请求数不超过 maxNum；某个请求完成后立即用队列中的下一个请求补位；全部完成后按 urls 原始顺序返回结果数组（成功放结果、失败放错误对象），实现请求调度循环（递归/while + Promise.all 包装）。示例：multiRequest(['/a','/b','/c','/d','/e'], 2) 任意时刻最多 2 个请求在飞。

**答案（Python 3）：**

```python
// Promise 并发限制 multiRequest（前端语义，JavaScript 实现）
function multiRequest(urls = [], maxNum) {
  const len = urls.length;
  if (len === 0) return Promise.resolve([]);
  const results = new Array(len);   // 按原始顺序放结果（成功放结果，失败放错误对象）
  let index = 0;                    // 调度游标：下一个要发的请求下标
  let finished = 0;

  return new Promise(resolve => {
    function request() {
      if (index >= len) return;     // 队列取空，不再发新请求
      const i = index++;
      fetch(urls[i])
        .then(res => { results[i] = res; })
        .catch(err => { results[i] = err; })
        .finally(() => {
          finished++;
          request();                // 完成一个立即补位下一个，保证并发数 <= maxNum
          if (finished === len) resolve(results);
        });
    }
    const start = Math.min(maxNum, len);
    for (let i = 0; i < start; i++) request();   // 先启动 maxNum 个请求
  });
}
// 示例：multiRequest(['/a','/b','/c','/d','/e'], 2)：任意时刻最多 2 个请求在飞
```

**解析：**
全局游标 index + 先启动 maxNum 个请求，每个请求在 finally 中立刻调度下一个补位；结果按发起时的下标 i 写入，天然保证返回数组与 urls 同序。


### Design-001-015 | ★★★★☆

用 setTimeout 实现 setInterval（前端面经原题：用 setTimeout 实现 setInterval，阐述实现的效果与 setInterval 的差异）。实现 myInterval(fn, interval)：用递归 setTimeout 保证每次执行完 fn 后再计时下一次，避免 setInterval 的任务堆积与执行间隔漂移；提供 clear 取消能力；说明二者差异（setInterval 是固定间隔排队、可能连续执行，递归 setTimeout 间隔从上次执行结束算起）。

**答案（Python 3）：**

```python
// 用 setTimeout 实现 setInterval（前端语义，JavaScript 实现）
function myInterval(fn, interval, ...args) {
  let timer = null;
  let stopped = false;
  function loop() {
    timer = setTimeout(() => {
      fn(...args);              // 先执行 fn，执行完再安排下一次 => 间隔从上次执行结束算起
      if (!stopped) loop();
    }, interval);
  }
  loop();
  return function clear() {     // clear 取消能力
    stopped = true;
    clearTimeout(timer);
  };
}

// 使用：const clear = myInterval(() => console.log('tick'), 1000); 调用 clear() 停止
// 与 setInterval 的差异：
// 1) setInterval 固定间隔把回调排队，回调执行慢于间隔时任务会堆积、连续执行；
//    递归 setTimeout 每次执行完才开始计时，不会堆积。
// 2) 递归 setTimeout 的实际间隔 = interval + fn 执行时间，节奏更稳不漂移。
```

**解析：**
注释"节奏更稳不漂移"有歧义：递归 setTimeout 的相邻间隔约为 interval + fn 执行时长，相对绝对时间仍会逐次后移（漂移）；其真正优点是不会像 setInterval 那样任务堆积。

### Design-001-016 | ★★★★☆

设计 LazyMan 类（前端面经原题：要求设计 LazyMan 类，实现以下功能：LazyMan('Hank') 输出 Hi! This is Hank!；LazyMan('Hank').sleep(10).eat('dinner') 先输出 Hi! This is Hank!，10 秒后输出 Wake up after 10 秒，再输出 Eat dinner~；LazyMan('Hank').eat('lunch').sleep(2).eat('dinner') 依次输出吃完午餐、睡 2 秒醒、吃晚餐；LazyMan('Hank').sleepFirst(5).eat('supper') 先睡 5 秒再打招呼）。核心：链式调用 + 任务队列 + 首次同步执行时把 sleepFirst 插队到队首，用 Promise/next 逐个消费队列。

**答案（Python 3）：**

```python
// 设计 LazyMan 类（前端语义，JavaScript 实现）：链式调用 + 任务队列
// 核心机制：所有方法同步收集任务；构造器用 setTimeout(0) 等同步链式调用结束后开始逐个消费队列
class LazyManClass {
  constructor(name) {
    this.tasks = [];
    console.log('Hi! This is ' + name + '!');   // 同步先打招呼
    setTimeout(() => this.next(), 0);           // 延迟到同步代码执行完再消费任务队列
  }
  next() {
    const task = this.tasks.shift();    // 取出队首任务执行
    task && task();
  }
  sleep(time) {
    this.tasks.push(() => {             // 尾插任务
      setTimeout(() => {
        console.log('Wake up after ' + time + '秒');
        this.next();
      }, time * 1000);
    });
    return this;                        // 链式调用
  }
  sleepFirst(time) {
    this.tasks.unshift(() => {          // 插队到队首
      setTimeout(() => {
        console.log('Wake up after ' + time + '秒');
        this.next();
      }, time * 1000);
    });
    return this;
  }
  eat(food) {
    this.tasks.push(() => {
      console.log('Eat ' + food + '~');
      this.next();                      // 同步任务执行完立刻调度下一个
    });
    return this;
  }
}
function LazyMan(name) {
  return new LazyManClass(name);
}
// LazyMan('Hank').eat('lunch').sleep(2).eat('dinner')  按序输出
// LazyMan('Hank').sleepFirst(5).eat('supper')  先睡 5 秒再打招呼
```
**解析：**
三个关键点：每个方法 return this 支持链式调用、所有行为先作为任务入队、构造器用 setTimeout(0) 等同步收集结束后逐个消费；sleepFirst 用 unshift 插队到队首。


### Design-001-017 | ★★★★☆

手写发布-订阅模式（EventEmitter）。实现一个 EventEmitter 类：on(event, listener) 订阅；off(event, listener) 取消指定订阅；once(event, listener) 只触发一次后自动移除；emit(event, ...args) 依次触发该事件的所有监听器并支持参数透传。示例：em.on('log', (...a) => console.log(...a)); em.emit('log', 1, 2) 输出 1 2；em.once('once', fn); em.emit('once'); em.emit('once') 时 fn 只执行一次。追问：与观察者模式的区别（事件中心解耦）。

**答案（Python 3）：**

```python
// 手写发布-订阅模式 EventEmitter（前端语义，JavaScript 实现）
class EventEmitter {
  constructor() {
    this.events = new Map();            // event -> listeners 数组（事件中心）
  }
  on(event, listener) {
    if (!this.events.has(event)) this.events.set(event, []);
    this.events.get(event).push(listener);
    return this;
  }
  once(event, listener) {
    const wrapper = (...args) => {
      this.off(event, wrapper);         // 触发前先移除自身：保证只执行一次
      listener(...args);
    };
    wrapper._origin = listener;         // 记录原函数，便于 off 时按原监听器匹配
    this.on(event, wrapper);
    return this;
  }
  off(event, listener) {
    const list = this.events.get(event);
    if (!list) return this;
    const idx = list.findIndex(fn => fn === listener || fn._origin === listener);
    if (idx !== -1) list.splice(idx, 1);
    return this;
  }
  emit(event, ...args) {
    const list = this.events.get(event);
    if (!list) return false;
    [...list].forEach(fn => fn(...args));   // 拷贝后遍历，防止触发过程中增删监听器出错
    return true;
  }
}
// 验证：em.on('log', (...a) => console.log(...a)); em.emit('log', 1, 2) 输出 1 2
// em.once('once', fn); em.emit('once'); em.emit('once')  => fn 只执行一次
// 追问：与观察者模式的区别 —— 发布-订阅有事件中心解耦，发布者/订阅者互不感知；
// 观察者模式中目标直接持有并通知观察者，两者耦合。
```
**解析：**
Map 存事件到监听器数组的映射；once 用包装器先 off 再执行、_origin 支持按原函数取消；emit 拷贝数组遍历防止遍历中修改；与观察者模式的区别在于有无事件中心解耦。

