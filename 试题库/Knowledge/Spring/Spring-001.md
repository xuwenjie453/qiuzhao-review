### Spring-001-001 | ★★★★★

说一下 Spring Bean 的生命周期。

**答案：**
主线四段：实例化（反射调构造器，可能是工厂方法）、属性填充（依赖注入，处理 @Autowired/@Resource）、初始化（Aware 回调 → BeanPostProcessor 前置 → InitializingBean.afterPropertiesSet → 自定义 init-method → 后置处理）、使用与销毁（容器关闭时 DestructionAwareBeanPostProcessor → DisposableBean.destroy → destroy-method）。两条扩展主线同样重要：BeanFactoryPostProcessor 在 Bean 实例化之前修改 BeanDefinition（占位符解析就在这）；BeanPostProcessor 包裹每个 Bean 的初始化前后，AOP 代理就是在这里生成的。

**解析：**
初始化阶段的精确顺序（高频追问点）：①XxxAware 注入（BeanNameAware/BeanFactoryAware/ApplicationContextAware，经 BeanPostProcessor 的 invokeAwareMethods）；②BeanPostProcessor.postProcessBeforeInitialization（@PostConstruct 就由 CommonAnnotationBeanPostProcessor 在此触发）；③InitializingBean.afterPropertiesSet；④init-method；⑤postProcessAfterInitialization（返回包装对象——AOP 在此生效）。

销毁顺序与初始化对称相反：@PreDestroy → DisposableBean.destroy → destroy-method。单例 Bean 随容器销毁触发；prototype Bean 的销毁回调由用户负责（容器不跟踪）。


### Spring-001-002 | ★★★★☆

Spring IoC 的启动流程？BeanFactory 和 FactoryBean 的区别？

**答案：**
两个概念先分开：BeanFactory 是 IoC 容器的底层接口（延迟实例化、只管 Bean 定义与获取）；FactoryBean 是一个特殊的 Bean——用户实现 getObject() 来生产复杂对象，容器里注册的是工厂，getBean("&name") 才拿到工厂本身，MyBatis 的 SqlSessionFactoryBean 是典型。容器启动（AnnotationConfigApplicationContext.refresh()）主流程：解析配置类生成 BeanDefinition → BeanFactoryPostProcessor 处理定义（如 PlaceholderConfigurer）→ 注册 BeanPostProcessor → 国际化/事件广播器等基础设施 → 按需实例化单例 Bean（依赖注入+初始化+代理）→ 发布 ContextRefreshedEvent。

**解析：**
ConfigurationClassPostProcessor 是最关键的 BeanFactoryPostProcessor：解析 @ComponentScan/@Import/@Bean/@Conditional，把配置类展开为一批 BeanDefinition。refresh 的十二步不用死背，抓住三个阶段：定义就绪 → 扩展点就位 → 实例化单例。

FactoryBean 的价值：把"复杂构建过程"封装成 Bean，容器统一管理其生命周期但屏蔽构建细节；AOP 代理、RPC client stub 常用它。isSingleton 决定 getObject 产物的缓存语义。

getBean 的加载：单例先查一级缓存，不存在走 createBean；配合三级缓存解决循环依赖（K-SPRING-003）。


### Spring-001-003 | ★★★★★

Spring 怎么解决循环依赖？为什么需要三级缓存？构造器注入为什么不行？

**答案：**
单例字段注入的循环依赖靠三级缓存解决：一级缓存 singletonObjects 放成品 Bean；二级缓存 earlySingletonObjects 放提前曝光的半成品；三级缓存 singletonFactories 放 ObjectFactory 工厂。A 创建中发现依赖 B → 创建 B → B 依赖 A 时从三级缓存的工厂拿到 A 的早期引用（若是 AOP Bean，工厂提前生成代理）放进二级缓存，B 完成后 A 继续完成。必须三级的原因：没有 AOP 时二级就够；有 AOP 时不能在实例化后立刻给所有 Bean 生成代理（违背生命周期设计），于是用工厂延迟决策——只有真被循环依赖"提前要"时才提前生成代理并记录。构造器注入无法解决：实例还没构造完就要依赖对方，早期引用不存在。Spring Boot 2.6 起默认禁止循环依赖（允许循环引用开关默认关闭），鼓励设计层面解耦。

**解析：**
getEarlyBeanReference 是三级缓存工厂的回调：SmartInstantiationAwareBeanPostProcessor 的实现（AOP 自动代理创建器）在此判断是否需要提前生成代理。普通 Bean 直接返回原始对象——因此三级缓存的代价对无 AOP Bean 几乎为零。

为什么不把所有 Bean 都提前代理：代理生成的正确时机在初始化完成后（K-SPRING-001），提前生成会让 BeanPostProcessor 二次处理、事件时序混乱；三级缓存是"最小侵入"的折中。

prototype 循环依赖无法解决：每次都要新实例，提前曝光的引用无法代表"未来实例"。


### Spring-001-004 | ★★★★★

Spring AOP 的原理？切面在什么时机织入？

**答案：**
Spring AOP 是运行期代理实现：容器为匹配切点的 Bean 生成代理（JDK 接口代理或 CGLIB 子类代理，Boot 2.x 起默认 CGLIB），织入发生在 Bean 初始化完成后的 BeanPostProcessor 阶段（AnnotationAwareAspectJAutoProxyCreator）。五类通知执行顺序：@Around 包裹前后、@Before 目标方法前、@AfterReturning/@AfterThrowing 正常/异常后、@After（finally）——Spring 5.2.7 起按 AspectJ 语义，同一切面内顺序为 Around前→Before→业务→AfterReturning/Throwing→After→Around后（5.2.7 之前 @After 在 @AfterReturning 之前）；多个切面按 Order 排序外层先执行。切点表达式 @annotation(自定义注解) 是业务切面最常用姿势。

**解析：**
拦截器链机制：代理方法调用 → 创建 ReflectiveMethodInvocation → 按 order 排序的 MethodInterceptor 链 → proceed() 递归推进（责任链）。@Around 内部必须调 proceed()，忘调则目标方法不执行且不报错——高频坑。

自调用失效原因：内部 this 调用不经过代理对象（K-JAVA-011 已述），解决：AopContext.currentProxy()（需 exposeProxy=true）、自注入、拆类。

切面失效的其他场景：private/final 方法、非容器对象、static 方法、内部 new 的对象。


### Spring-001-005 | ★★★★★

Spring 事务的传播行为有哪些？REQUIRES_NEW 和 NESTED 的区别？

**答案：**
七种传播行为，重点掌握三种：REQUIRED（默认，有事务加入，没有新建）；REQUIRES_NEW（挂起当前事务，新开独立事务，两者提交/回滚互不影响，连接是独立的）；NESTED（在当前事务内建保存点 SAVEPOINT，内层回滚只回滚到保存点，外层可以选择继续；但没有外层事务时行为同新建，且同一物理连接）。其余：SUPPORTS/NOT_SUPPORTED/MANDATORY/NEVER 表达"要不要、可不可以有事务"。常见业务映射：主流程失败连带日志也回滚→REQUIRED；审计/通知记录必须独立成功→REQUIRES_NEW；批量子步骤可部分失败→NESTED。

**解析：**
REQUIRES_NEW 的代价与坑：①外层持有的行锁内层拿不到（同库），死锁风险；②外层未提交数据对内层不可见（隔离级别语义），内层查不到外层刚写的记录；③连接池占用翻倍。NESTED 依赖 JDBC 保存点，仅 DataSourceTransactionManager/JpaTransactionManager 支持，JTA 环境不支持。

回滚规则：默认只对 RuntimeException/Error 回滚；受检异常不回滚——rollbackFor=Exception.class 是国内工程事实标准。事务边界内的"内部 catch 不抛"也会导致不回滚（异常没到代理层）。


### Spring-001-006 | ★★★★★

@Transactional 事务失效的场景有哪些？

**答案：**
高频清单（按出现率排序）：①同类自调用（绕过代理）；②方法非 public；③异常被方法内 try-catch 吞掉；④抛的是受检异常且没设 rollbackFor；⑤类没被 Spring 管理（new 出来的对象）；⑥传播行为配置错误（NOT_SUPPORTED/NEVER）；⑦多线程调用（事务绑定 ThreadLocal 连接，子线程不在事务内）；⑧存储引擎不支持事务（MyISAM）；⑨数据源/事务管理器配置错误或多数据源切错。排查心法：先确认代理是否生效（断点看类是否 CGLIB 子类），再确认异常是否真的抛到了代理层。

**解析：**
自调用的三种修复：注入自身代理（@Autowired 自实例，注意循环依赖许可）、AopContext.currentProxy()（exposeProxy = true）、把需要事务的方法拆到另一个 Bean。

多线程的原理：事务上下文（Connection 绑定）存在 ThreadLocal 的 DataSourceUtils 中，新线程拿不到，等于各自自动提交；跨线程事务需要编程式 TransactionTemplate 手动在各线程内开启（且各线程独立提交，非同一事务）。

catch 吞异常的细节：catch 后想保留事务又能记录日志，可 catch 内 `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()` 标记回滚。


### Spring-001-007 | ★★★☆☆

@Autowired 和 @Resource 的区别？构造器注入为什么更推荐？

**答案：**
来源与匹配规则不同：@Autowired 是 Spring 注解，默认按类型（byType）注入，多个同类型候选时结合 @Qualifier 或字段名匹配；@Resource 是 JSR-250 标准注解，默认按名称（byName）匹配，找不到再退化为按类型。注入位置：两者都可用于字段/setter；@Autowired 额外支持构造器与多参方法。推荐构造器注入的理由：依赖在编译期显式暴露（参数列表即依赖清单）、不可变（final 字段）、不会 NPE、单测无需容器直接 new、循环依赖在启动期直接报错倒逼解耦。Spring 官方文档与团队规范普遍推荐单构造器时省略注解的隐式注入。

**解析：**
required 属性：@Autowired(required=false) 允许无候选（可选依赖）。集合注入：注入 List<T>/Map<String,T> 会收集全部实现 Bean（策略模式常用，配合 @Order 排序）。

@Primary vs @Qualifier：前者定"默认首选"，后者点名具体 Bean。

构造器注入循环依赖直接启动失败（K-SPRING-003），这是"快速失败"优点也是迁移遗留代码的阻力。


### Spring-001-008 | ★★★☆☆

Bean 的作用域有哪些？prototype 依赖 singleton 会有什么问题？

**答案：**
常用作用域：singleton（默认，容器内唯一）、prototype（每次获取新建）、web 环境的 request/session/application，以及 websocket。prototype 依赖 singleton 的问题：singleton 创建时注入的那份 prototype 被永久持有，之后不再是"每次新实例"。解法：注入 ObjectFactory/Provider 延迟获取（每次 getObject 都新建）、或 @Lookup 方法注入、或用 ObjectProvider。另一个注意点：容器不管理 prototype 的完整销毁回调，释放资源由使用方负责。

**解析：**
request/session 作用域在非 web 上下文访问会报错；在单例中注入需要 scoped proxy（@Scope(proxyMode=TARGET_CLASS)）——注入的是代理，调用时按当前请求解析真实实例，原理与 @Lazy 类似。

singleton 并非"全局单例"而是"每容器每名称单例"；多个容器存在时同名 Bean 可以各有实例。


### Spring-001-009 | ★★★★☆

Spring MVC 的请求处理流程？

**答案：**
主线：请求进入 DispatcherServlet（前端控制器）→ HandlerMapping 找到匹配的 Handler（RequestMappingHandlerMapping 按 URL+方法+生产消费类型匹配，含拦截器链）→ HandlerAdapter 调用（参数解析：HandlerMethodArgumentResolver 绑定参数、消息转换：HttpMessageConverter 反序列化 body、校验 @Valid）→ 执行 Controller 方法 → 返回值由 HandlerMethodReturnValueHandler 处理（@ResponseBody 走消息转换写 JSON）→ 异常由 HandlerExceptionResolver（@ControllerAdvice 全局处理）→ 渲染/响应。过滤器和拦截器的位置：Filter 在 Servlet 层最外，Interceptor 是 Spring 的 Handler 执行前后。

**解析：**
细节考点：①类型转换与格式化由 ConversionService 支持（@DateTimeFormat）；②@RequestBody vs @RequestParam：前者经 HttpMessageConverter，后者来自 query/form；③拦截器三个时机 preHandle（可短路）→postHandle（视图前）→afterCompletion（finally 语义，清理 MDC/资源）；④异常处理优先级：方法内 → 本类 @ExceptionHandler → 全局 @ControllerAdvice → 默认；⑤Content negotiation 按 Accept 与 produces 协商。


### Spring-001-010 | ★★★☆☆

BeanPostProcessor 和 BeanFactoryPostProcessor 的区别？

**答案：**
作用对象与时机不同：BeanFactoryPostProcessor 作用于 BeanDefinition（配方）层面，在所有 Bean 实例化之前执行，可增删改定义——占位符替换（PropertySourcesPlaceholderConfigurer）、条件注册都在这里；BeanPostProcessor 作用于 Bean 实例，在每个 Bean 初始化前后回调，可返回包装/代理对象——@Autowired 处理、@PostConstruct 触发、AOP 代理都由具体 BPP 实现。一句话：BFPP 改"图纸"，BPP 加工"成品"。顺序规则：BPP 必须先于普通单例注册才生效；PriorityOrdered/Ordered 决定 BPP 之间顺序。

**解析：**
典型内置 BPP：AutowiredAnnotationBeanPostProcessor（@Autowired 注入）、CommonAnnotationBeanPostProcessor（@Resource/@PostConstruct）、ApplicationContextAwareProcessor（Aware 注入）、AbstractAutoProxyCreator（AOP）。理解这些后，"Spring 的魔法"就拆解成了一个个扩展点实现。

自定义实践：BPP 里扫描自定义注解生成元数据缓存；BFPP 里按配置动态注册 BeanDefinition（如按配置批量注册任务）。


### Spring-001-011 | ★★★★★

Spring Boot 自动配置的原理？

**答案：**
@SpringBootApplication = @SpringBootConfiguration + @EnableAutoConfiguration + @ComponentScan。自动配置的核心是 @EnableAutoConfiguration：通过 AutoConfigurationImportSelector 读取所有 jar 中 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 文件（Boot 2.7 前是 spring.factories 的 EnableAutoConfiguration 键），拿到候选配置类列表，再经过 @Conditional 条件过滤（@ConditionalOnClass 类路径有该类、OnMissingBean 容器没有、OnProperty 配置开关等），最终把满足条件的配置类中的 @Bean 注册进容器。写 starter 的套路：自动配置类 + 条件注解 + 配置属性绑定（@ConfigurationProperties + @EnableConfigurationProperties）+ 可选的 SPI 注册文件。

**解析：**
条件评估顺序：先按 OnClass 粗筛（不加载类本身用 ASM 读元数据，避免 NoClassDefFoundError），运行期再评估其余条件。@ConditionalOnMissingBean 的顺序敏感性：自动配置类在用户配置之后处理，所以"用户定义优先、缺省兜底"成立——这也是为什么自己的同名 Bean 会覆盖 starter 默认。

配置绑定：@ConfigurationProperties 宽松绑定（kebab-case）、校验（@Validated）、元数据提示（additional-spring-configuration-metadata.json）。

Boot 3 变化：基于 JDK 17/Spring 6，jakarta 命名空间；AOT/native 支持要求自动配置类通过 imports 文件注册。


### Spring-001-012 | ★★★☆☆

Spring 事件机制的原理和应用场景？

**答案：**
观察者模式的容器内实现：ApplicationEventPublisher.publishEvent(事件) → ApplicationEventMulticaster（默认 SimpleApplicationEventMulticaster）分发给所有匹配的 @EventListener（或实现 ApplicationListener 的 Bean）。默认同步执行——监听器异常会传播、耗时会计入发布方；@Async 监听器实现异步；@TransactionalEventListener( phase = AFTER_COMMIT ) 解决"事务提交后再执行"的经典问题（发消息、清缓存）。适用场景：模块内解耦（订单完成后的积分/通知/统计）、领域事件的进程内表达；不适合跨服务一致性（那是 MQ 的事）。

**解析：**
关键细节：①事件继承体系——监听器监听父类事件会收到子类事件；②泛型事件 ResolvableType 支持 `Event<OrderCreatedEvent<Long>>` 这类匹配；③同步监听在调用线程执行，事务传播跟随发布方事务，所以 AFTER_COMMIT 才是"确定提交后"；④异步监听要配线程池与异常处理，且事务上下文不可见。

与 MQ 的分工：Spring 事件是进程内的方法调用级解耦，无持久化、无重试语义；跨服务/需可靠投递必须 MQ。混用清楚边界是加分项。


### Spring-001-013 | ★★★☆☆

Spring 循环依赖在 Spring Boot 2.6 之后默认禁止了，怎么应对存量代码？

**答案：**
应对分三层：①临时开关 `spring.main.allow-circular-references=true` 让老项目先跑起来；②定位循环链（启动异常已打印完整依赖链），区分"真循环"与"A 需要 B 的某功能"式伪循环；③按类型修复——提取公共逻辑到第三个类、改事件/回调解耦、@Lazy 注入破坏创建时序、接口拆分。长期看默认禁止是好约束：循环依赖几乎总意味着职责边界不清，开关只能作为迁移过渡。构造器注入的项目受影响最大（构造器循环本来就不可解），这也是 Boot 官方推构造器注入+禁止循环的组合逻辑。


### Spring-001-014 | ★★★☆☆

BeanFactory 和 ApplicationContext 的区别？

**答案：**
BeanFactory 是最底层 IoC 容器接口：BeanDefinition 注册与 getBean，默认懒加载。ApplicationContext 在其之上叠加企业级能力：事件发布/监听、国际化 MessageSource、资源加载（Resource/ResourceLoader，统一 classpath:/file:/http:）、Environment 配置抽象、以及启动时预实例化单例（尽早暴露配置错误）。日常用的 ClassPathXmlApplicationContext/AnnotationConfigApplicationContext/SpringBootApplication 都是 ApplicationContext 体系。可以理解为：BeanFactory 是引擎，ApplicationContext 是整车。

**解析：**
预实例化 vs 懒加载的取舍：预实例化让错误在启动期暴露（fail-fast），代价是启动时间；大型单体可对重 Bean 设 lazy 但要配套启动校验。

SmartInitializingSingleton：所有单例初始化完成后回调（区别于 BeanPostProcessor 的逐 Bean 视角），适合"等全部就绪后再统一做事"。


### Spring-001-015 | ★★★★☆

Spring Bean 默认作用域与线程安全

Spring 单例 Bean 中定义了可变的成员变量 count 并在请求处理中 count++，会怎样？

A. Spring 会为每个请求创建新实例，无并发问题
B. 单例被并发共享，count 出现竞态；无状态 Bean 才天然线程安全
C. Spring 自动加锁保护
D. 编译报错

**答案：** B

**解析：**
单例全容器共享，可变成员在并发请求下竞态；A 错（默认 singleton）；C 错（不提供）；D 错。

Service 层保持无状态；需请求级状态用 ThreadLocal 或 prototype/request 作用域。


### Spring-001-016 | ★★★★★

Spring 事务失效综合

下列会导致 @Transactional 不生效的有：

A. 同类中方法 A（无注解）调用方法 B（有注解）
B. 事务方法抛出受检异常且未配置 rollbackFor
C. 方法为 private
D. 异常在方法内被 catch 吞掉未重新抛出

**答案：** A、B、C、D

**解析：**
A 自调用绕过代理；B 默认只回滚 RuntimeException/Error；C 代理不拦截私有方法；D 异常未达代理层，事务无感知。

事务四大失效：自调用/非 public/异常被吞/rollbackFor 缺失。


### Spring-001-017 | ★★★★☆

Spring Boot 自动配置文件

Spring Boot 2.7+ 中自动配置类的注册文件是：

A. META-INF/spring.factories
B. META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
C. application.yml
D. META-INF/MANIFEST.MF

**答案：** B

**解析：**
2.7 起自动配置迁至 imports 文件（3.x 仅支持），spring.factories 保留给其他扩展点；C 是应用配置；D 是 jar 清单。

自动配置=imports 注册+@Conditional 条件装配。

