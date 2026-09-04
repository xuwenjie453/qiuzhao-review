### Greedy-002-001 | ★★★★☆

数位贪心手撕题（字节 C++ 后端面经原题：给你 n=23311 和一个数字数组 [2,4,9]，求用这个数组里的数字能组成的、严格小于 n 的最大数，示例答案为 22999）。给定整数 n 和可选数字集合 digits（可重复使用），求由 digits 中数字拼出的、位数不超过 n 且严格小于 n 的最大整数；不存在输出 -1。要求现场写代码：将 n 转字符串，贪心地从左到右尝试每一位选"小于当前位且在 digits 中的最大数字"，后面全填 digits 最大值；若某位选不出则回溯到前一位减小；若连首位都无法满足则只能比 n 少一位并全填最大数字。

**答案（Python 3）：**

```python
def max_less_than(n, digits):
    '''digits 中数字可重复使用，拼出严格小于 n 的最大整数；不存在返回 -1'''
    s = str(n)
    L = len(s)
    dmax = max(digits)
    dset = set(digits)

    def build(prefix, d):
        # 与 n 前 len(prefix) 位相同，随后一位放 d，剩余位全填最大数字
        return int(''.join(map(str, prefix)) + str(d) + str(dmax) * (L - len(prefix) - 1))

    prefix = []
    last_break = None    # 最近一个可断点 (前缀快照, 该位放的更小数字)
    for i in range(L):
        c = int(s[i])
        smaller = [d for d in digits if d < c]
        if smaller:
            last_break = (prefix[:], max(smaller))   # 在该位断开、后面全填最大值
        if c in dset:
            prefix.append(c)    # 能取相等就保持 tight（公共前缀越长数越大），继续右移
        else:
            break               # 该位取不到相等，后面无法保持 tight，停止
    if last_break:
        return build(*last_break)
    # 同长度无解：退化为位数少一位、全部填最大数字（位数不超过 n 的最大数）
    return int(str(dmax) * (L - 1)) if L >= 2 else -1

if __name__ == '__main__':
    print(max_less_than(23311, [2, 4, 9]))   # 22999
```

**解析：**
贪心保持与 n 最长的公共前缀（各位尽量取相等），记录最后一个能放「小于当前位」数字的位置作为断点，断点处放可选的最大数字、其后全填最大值；同长度无解则少一位全填最大数；时间 O(L×|digits|)。示例 23311 与 [2,4,9]：保持前缀 2，第 2 位只能放 2，后面补 999 得 22999。

