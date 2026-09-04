### Spring-003-001 | ★★★★★

Spring 是怎么解决循环依赖的？为什么要用三级缓存，二级缓存不行吗？

**答案：**
用 singletonObjects/singletonFactories/earlySingletonObjects 三级缓存，A 创建中先把 ObjectFactory 放入三级缓存，B 注入时提前拿到 A 的早期引用；三级缓存延迟生成代理对象，保证 AOP 场景下代理只在需要时创建且 Bean 生命周期不被打乱，二级缓存无法同时满足代理与正常生命周期顺序。


### Spring-003-002 | ★★★★★

@Lazy 能解决循环依赖吗？SpringBoot 允许循环依赖发生吗？

**答案：**
@Lazy 注入代理，首次使用才初始化目标 Bean，可打断构造器阶段的循环依赖；SpringBoot 2.6 前默认允许循环依赖，2.6 起默认禁止，需显式开启 spring.main.allow-circular-references=true。


### Spring-003-003 | ★★★★☆

Spring 的事务什么情况下会失效？使用 this 调用事务方法生效吗？
SRC2: https://notes.kamacoder.com/interview/java/kuaishou-interview.html

**答案：**
this 内部调用不走代理所以失效；还有方法非 public、异常被 catch 吞掉、默认只回滚 RuntimeException/Error（需 rollbackFor=Exception.class）、传播行为设置错误、数据库引擎不支持事务、多线程调用等。


### Spring-003-004 | ★★★★☆

Spring 事务如果没有回滚可能是什么原因？

**答案：**
常见原因：异常被 try-catch 吞掉、抛的是受检异常且未配置 rollbackFor、同类内部调用绕过代理、事务传播 REQUIRES_NEW 隔离、底层引擎 MyISAM 不支持事务。


### Spring-003-005 | ★★★★☆

介绍 Spring 的事务传播行为有哪些？
SRC2: https://www.xiaolincoding.com/backend_interview/telecommunication/huawei.html

**答案：**
7 种：REQUIRED（默认，有则加入无则新建）、REQUIRES_NEW（挂起当前新建）、SUPPORTS、NOT_SUPPORTED、MANDATORY、NEVER、NESTED（保存点子事务，外层回滚才连带回滚）。


### Spring-003-006 | ★★★★☆

Bean 的生命周期说一下？Bean 的单例和非单例，生命周期是否一样？Spring 容器里存的是什么？

**答案：**
实例化→属性填充→Aware 回调→BeanPostProcessor 前置→初始化（InitializingBean/init-method）→后置处理（AOP 代理在此生成）→使用→销毁回调；单例由容器缓存全程管理，prototype 每次新建且容器不负责其完整销毁。容器单例池里存的是成品 Bean（单例）。


### Spring-003-007 | ★★★★☆

在 Spring 中，bean 加载/销毁前后想实现某些逻辑可以怎么做？Spring 提供的扩展点有哪些？

**答案：**
可实现 BeanPostProcessor（初始化前后增强，AOP 代理就生成在这里）、InitializingBean/@PostConstruct、DisposableBean/@PreDestroy、BeanFactoryPostProcessor 修改 BeanDefinition（如占位符解析）、Aware 接口、ApplicationListener 等。


### Spring-003-008 | ★★★★☆

BeanFactoryPostProcessor 和 BeanPostProcessor 有什么区别？

**答案：**
BeanFactoryPostProcessor 在 Bean 实例化之前对 BeanDefinition 元数据进行加工（如 PropertySourcesPlaceholderConfigurer 解析占位符）；BeanPostProcessor 作用于 Bean 实例初始化前后，返回包装/代理对象，属于 Bean 级别的扩展。


### Spring-003-009 | ★★★★☆

介绍一下 Spring Boot 整体的启动流程？

**答案：**
SpringApplication.run → 创建 SpringApplication（推断应用类型、加载 Initializer/Listener）→ 准备 Environment → 创建 ApplicationContext → prepareContext 注册主类并刷新 → refresh() 完成扫描、自动配置与 Bean 创建（内嵌 Web 容器在此启动）→ 回调 Runner（ApplicationRunner/CommandLineRunner）。


### Spring-003-010 | ★★★★☆

SpringBoot 自动装配原理是什么？springboot 怎么做到导入依赖就可以直接使用的？

**答案：**
@SpringBootApplication 内含 @EnableAutoConfiguration，通过 AutoConfigurationImportSelector 读取各 starter jar 中 META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports（旧版 spring.factories）加载自动配置类，再结合 @ConditionalOnClass/@ConditionalOnMissingBean 等条件注解按需注册 Bean。


### Spring-003-011 | ★★★★☆

了解 SpringCloud 吗？说一下它和 SpringBoot 的区别？用过哪些微服务组件？
SRC2: https://notes.kamacoder.com/interview/java/hikvision-interview-1-22.html

**答案：**
SpringBoot 是快速构建单个应用，SpringCloud 是在其上做微服务治理。常用组件：注册中心 Nacos/Eureka、配置中心 Nacos/Apollo、网关 Gateway、负载均衡 LoadBalancer/Ribbon、熔断 Sentinel/Resilience4j、链路追踪 SkyWalking。


### Spring-003-012 | ★★★★☆

Spring Cloud Gateway 的工作流程是什么？如何实现动态路由？

**答案：**
请求进来先由 Predicate 匹配路由，再经过 GlobalFilter 与 GatewayFilter 链（如转发、限流、鉴权）最终转发到下游；动态路由是把路由定义放 Nacos/DB 并监听变更，通过 ApplicationEvent 刷新内存 RouteDefinition。

