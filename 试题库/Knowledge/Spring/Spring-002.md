### Spring-002-001 | ★★★★☆

介绍一下Spring的AOP和IOC？

**答案：**
IoC控制反转：对象创建与依赖装配交给容器；AOP面向切面：把日志、事务等横切逻辑通过动态代理织入目标方法。


### Spring-002-002 | ★★★★☆

Java中（Spring）Bean的生命周期了解过吗？

**答案：**
实例化→属性注入→Aware回调→BeanPostProcessor前置处理→初始化（InitializingBean/init-method）→后置处理→使用→容器关闭时销毁回调。


### Spring-002-003 | ★★★★☆

Spring的AOP怎么实现？

**答案：**
运行时动态代理：目标类有接口默认JDK动态代理，否则CGLIB子类代理；由AnnotationAwareAspectJAutoProxyCreator（BeanPostProcessor）在初始化后生成代理对象。


### Spring-002-004 | ★★★★☆

AOP什么时候使用JDK代理，什么时候使用CGLIB（子类代理）？

**答案：**
有接口可用JDK代理，无接口用CGLIB；Spring Boot 2.x起默认统一使用CGLIB代理。


### Spring-002-005 | ★★★★☆

如果目标是一个final类，也没有接口，还能做AOP切面吗？

**答案：**
JDK和CGLIB都无法代理final类；可改用AspectJ的编译期/加载期织入。


### Spring-002-006 | ★★★★☆

什么是循环引用？循环引用的情况下，Spring能正常初始化Bean吗？

**答案：**
构造器注入的循环依赖无法解决会启动失败；setter/字段注入的单例循环依赖可通过三级缓存提前暴露引用解决，prototype作用域不行。


### Spring-002-007 | ★★★★☆

Spring的循环引用是怎么解决的？

**答案：**
三级缓存：singletonObjects成品、earlySingletonObjects早期引用、singletonFactories工厂；实例化后先放入工厂暴露早期引用供对方注入。


### Spring-002-008 | ★★★★☆

FactoryBean有什么作用？

**答案：**
允许自定义复杂Bean的创建逻辑，getObject()返回的对象才注册进容器；MyBatis的SqlSessionFactoryBean等大量使用。


### Spring-002-009 | ★★★★☆

@Autowired和@Resource的区别？

**答案：**
@Autowired是Spring注解默认按类型注入，多个候选配合@Qualifier/@Primary；@Resource是JDK标准注解默认按名称注入。


### Spring-002-010 | ★★★★☆

Spring Boot自动装配是通过哪个注解开启的？

**答案：**
@SpringBootApplication内的@EnableAutoConfiguration；基于spring.factories/AutoConfiguration.imports加载自动配置类并按@Conditional条件装配。


### Spring-002-011 | ★★★★★

事务注解（@Transactional）失效的情况有哪些？你是怎么避免的？

**答案：**
非public方法、同类自调用、异常被catch吞掉、默认不回滚受检异常、传播行为设置错误、多线程调用；避免自调用、指定rollbackFor、异常正确抛出。


### Spring-002-012 | ★★★★☆

Spring解决循环依赖只用两级缓存行不行？为什么需要第三级缓存？

**答案：**
不行：第三级存ObjectFactory，用于在需要时才提前生成AOP代理对象，保证代理的创建时机与Bean生命周期一致。


### Spring-002-013 | ★★★★☆

用AOP实现日志记录的具体实现细节怎么做？

**答案：**
自定义日志注解做切点，@Around环绕拦截获取方法出入参、耗时、异常并落库/发MQ，@Order控制与其他切面的顺序。


### Spring-002-014 | ★★★★☆

IoC解决了什么问题？

**答案：**
把对象创建和依赖装配交给容器，解耦硬编码依赖，便于单测、实现替换与统一生命周期管理。


### Spring-002-015 | ★★★★☆

Spring Bean是线程安全的吗？

**答案：**
取决于是否有状态：无状态的singleton天然安全；有状态的singleton并发修改共享变量则不安全，需加锁、ThreadLocal或改用prototype。


### Spring-002-016 | ★★★★☆

Spring AOP和AspectJ AOP有什么区别？

**答案：**
Spring AOP是运行时动态代理，只支持方法拦截；AspectJ支持编译期/加载期织入，能拦截字段、构造器，功能更强、性能更好。


### Spring-002-017 | ★★★★☆

SpringMVC的工作原理（一次请求的处理流程）了解吗？

**答案：**
请求→DispatcherServlet→HandlerMapping查Handler→HandlerAdapter执行Controller返回ModelAndView→ViewResolver解析→渲染响应；@ResponseBody则由HttpMessageConverter直接写回。


### Spring-002-018 | ★★★★★

Spring事务中的事务传播行为有哪几种？

**答案：**
七种：REQUIRED（默认）、REQUIRES_NEW、NESTED、SUPPORTS、NOT_SUPPORTED、MANDATORY、NEVER。


### Spring-002-019 | ★★★★☆

@Transactional(rollbackFor = Exception.class)注解了解吗？

**答案：**
默认只在RuntimeException和Error时回滚；指定rollbackFor让受检异常也触发回滚。


### Spring-002-020 | ★★★★☆

Spring Cloud Gateway的工作流程了解吗？

**答案：**
请求进入DispatcherHandler匹配Route，断言（Predicate）判断是否路由，经过滤器链（全局/局部Filter）前置处理后转发目标服务，响应再经后置过滤器返回。

