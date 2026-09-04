### DesignPatterns-001-001 | ★★★★★

单例模式有哪几种写法？哪种最好？

**答案：**
按推荐度排序四种：①静态内部类（Holder）：JVM 类加载机制保证懒加载+线程安全，无锁，最常用；②枚举：天然防反射与反序列化破坏，Effective Java 推荐；③双重检查锁（DCL）：`volatile` 实例 + 两次判空 + synchronized，面试考察 volatile 理解的经典载体（K-JUC-003）；④饿汉式：类加载即创建，简单但无懒加载。破坏单例的三种手段与防御：反射调私有构造器（构造器中检测二次创建抛异常）、反序列化（readResolve）、克隆（不实现 Cloneable）。再补一层认知：Spring 的 Bean 默认单例由容器保证，业务代码需要真正全局唯一实例的场景已经很少——大多数"想要单例"的诉求本质是"需要无状态共享"。


### DesignPatterns-001-002 | ★★★★☆

策略模式 + 工厂模式怎么组合消除 if-else？结合 Spring 举例。

**答案：**
套路三步：①定义策略接口（如 PayHandler：pay()/refund()）；②每个实现类标注唯一标识（@Component("ALIPAY") 或自定义注解）；③注入 Spring 的 `Map<String, PayHandler>`（key 即 Bean 名）或 `List + 注解扫描自建路由表`，业务入口按渠道参数 O(1) 路由。新增支付渠道只加一个类，不改存量代码——开闭原则落地。没有 Spring 的场合用枚举单例策略或工厂+注册表。要会对比方案：if-else（直观、改历史代码）；Map 路由（本方案）；规则引擎（复杂决策多维条件时才值得引入，别过度设计）。


### DesignPatterns-001-003 | ★★★☆☆

观察者模式和发布订阅有什么区别？模板方法呢？

**答案：**
观察者是"对象间一对多依赖"：Subject 持有 Observer 列表直接通知，双方知道彼此存在（同进程、同步/异步均可）；发布订阅则多一个中间 broker，发布者与订阅者完全解耦、互不知道（Spring Event 的 multicaster 是进程内中介，MQ 是跨进程中介）。模板方法：父类固化算法骨架，子类实现差异步骤（钩子方法），典型如 JdbcTemplate/AbstractList；配合回调（好莱坞原则"别调用我们，我们会调用你"）。Spring 生态映射：ApplicationEvent=发布订阅；JdbcTemplate/事务基础设施=模板方法；AOP=动态代理；适配器=HandlerAdapter。


### DesignPatterns-001-004 | ★★★☆☆

SOLID 原则分别是什么？举反例说明。

**答案：**
S 单一职责：一个类只因一个原因变化——反例：OrderService 同时做校验、计算、落库、发通知，任何需求都改它。O 开闭：扩展开放修改关闭——用策略路由替代修改 switch（K-SWE-002）。L 里氏替换：子类必须能无缝替换父类——反例：正方形继承长方形后 setWidth 破坏父类语义。I 接口隔离：接口小而专——反例：万能 Manager 接口迫使实现类写一堆空方法。D 依赖倒置：依赖抽象不依赖具体——Service 依赖 Repository 接口而非 MySQL 实现类，便于替换与测试。收束一句：原则是权衡工具不是教条，过度设计违反的恰恰是"简单性"。


### DesignPatterns-001-005 | ★★★★☆

设计模式识别：单例

JDK 中 Runtime 类、Spring 容器中的 Bean 默认作用域，体现的模式是：

A. 工厂模式
B. 单例模式
C. 观察者模式
D. 建造者模式

**答案：** B

**解析：**
Runtime.geteRuntime 全局唯一；Spring singleton scope 容器级单例；A/C/D 与场景不符。

单例两种实现：容器管理（Spring）/静态内部类、枚举。


### DesignPatterns-001-006 | ★★★☆☆

设计模式识别：代理与装饰

Spring AOP 给 Bean 织入事务/日志能力，其结构模式是：

A. 代理模式（控制访问并增强）
B. 装饰器模式（动态叠加职责）
C. 适配器模式
D. 组合模式

**答案：** A

**解析：**
AOP 用 JDK 动态代理/CGLIB 生成代理对象包目标，控制访问并增强；装饰器强调"逐层叠加同接口职责"，AOP 是横切注入；C 接口转换；D 树形结构。

代理 vs 装饰：意图不同（访问控制 vs 职责叠加），结构相似。

