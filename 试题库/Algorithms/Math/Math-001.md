### Math-001-001 | ★★★☆☆

**题目：** 统计质数

统计小于 n 的质数个数（质数是大于 1 且只能被 1 和自身整除的数）。

**输入格式**

一行一个整数 n（0 ≤ n ≤ 1e7）。

**输出格式**

一个整数。

**示例输入**

```
10
```

**示例输出**

```
4
```

**答案（Python 3）：**

```python
import sys

def solve():
    n = int(sys.stdin.read().split()[0])
    if n < 2:
        print(0)
        return
    is_composite = bytearray(n)
    cnt = 0
    for i in range(2, int(n ** 0.5) + 1):
        if not is_composite[i]:
            for j in range(i * i, n, i):
                is_composite[j] = 1
    print(sum(1 for i in range(2, n) if not is_composite[i]))

if __name__ == "__main__":
    solve()
```

**解析：**
埃拉托斯特尼筛：从 2 开始，把每个质数的倍数标记为合数，只需筛到 sqrt(n)；进一步用"从 i*i 开始标记"避免重复。逐个试除是 O(n√n)，1e7 会超时——筛法是本题考点。


### Math-001-002 | ★★★☆☆

**题目：** 快速幂

计算 a 的 b 次方对 m 取模的结果（0 ≤ b，m ≥ 1）。

**输入格式**

一行三个整数 a, b, m（0 ≤ a, b ≤ 1e18，1 ≤ m ≤ 1e18；a 需先对 m 取模）。

**输出格式**

一个整数，即 (a^b) mod m。注意 b=0 时结果为 1 mod m。

**示例输入**

```
2 10 1000
```

**示例输出**

```
24
```

**答案（Python 3）：**

```python
import sys

def solve():
    a, b, m = map(int, sys.stdin.read().split())
    a %= m
    res = 1 % m
    while b > 0:
        if b & 1:
            res = res * a % m
        a = a * a % m
        b >>= 1
    print(res)

if __name__ == "__main__":
    solve()
```

**解析：**
快速幂（二分乘方）：b 按二进制拆解，a^b = a^(b二进制各位展开) 的乘积，每步平方底数、b 右移，位为 1 时乘入结果。每步取模防溢出（Python 不会溢出但取模保持常数大小，速度快）。


### Math-001-003 | ★★★☆☆

**题目：** 最大公约数与最小公倍数

给定两个正整数 a、b，输出它们的最大公约数 gcd 与最小公倍数 lcm。

**输入格式**

一行两个正整数 a, b（1 ≤ a, b ≤ 1e12）。

**输出格式**

一行两个整数：gcd(a,b) 与 lcm(a,b)，空格分隔。

**示例输入**

```
12 18
```

**示例输出**

```
6 36
```

**答案（Python 3）：**

```python
import sys

def solve():
    a, b = map(int, sys.stdin.read().split())
    x, y = a, b
    while y:
        x, y = y, x % y
    g = x
    print(g, a // g * b)

if __name__ == "__main__":
    solve()
```

**解析：**
辗转相除：gcd(a,b)=gcd(b, a mod b)，边界 gcd(a,0)=a，迭代写法避免递归开销。lcm = a / gcd(a,b) * b——**先除后乘**防止溢出（Python 无溢出但 C/Java 必须这么写，是通用习惯）。


### Math-001-004 | ★★★☆☆

**题目：** 判断质数

判断 q 个整数是否为质数（大于 1 且仅能被 1 和自身整除）。

**输入格式**

第一行 q（1 ≤ q ≤ 100）。第二行 q 个整数 x（0 ≤ x ≤ 1e12）。

**输出格式**

每行输出 `Yes` 或 `No`。

**示例输入**

```
3
2 15 999999999989
```

**示例输出**

```
Yes
No
Yes
```

**答案（Python 3）：**

```python
import sys

def is_prime(x):
    if x < 2:
        return False
    if x % 2 == 0:
        return x == 2
    i = 3
    while i * i <= x:
        if x % i == 0:
            return False
        i += 2
    return True

def solve():
    data = sys.stdin.read().split()
    q = int(data[0])
    xs = data[1:1+q]
    out = []
    for tok in xs:
        out.append("Yes" if is_prime(int(tok)) else "No")
    print("\n".join(out))

if __name__ == "__main__":
    solve()
```

**解析：**
试除到 √x（x 可达 1e12，√=1e6 次试除 ×100 个数可过）；O(√x) 判定，注意用 i*i <= x 防浮点误差。

