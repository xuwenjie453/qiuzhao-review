import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** 压力测试v2: 毒丸终止协议. 4生产者x50 + 4消费者, 容量10; 附快产慢消/慢产快消 */
public class StressTest {
    static final Integer PILL = Integer.MIN_VALUE;

    public static void main(String[] args) throws Exception {
        // ── Test 1: 多对多, 小容量, 毒丸终止, 验证不丢数据且全部线程正常退出 ──
        MyBlockingQueue<Integer> q = new MyBlockingQueue<>(10);
        int producers = 4, perProducer = 50, total = producers * perProducer;
        long expectedSum = 0;
        for (int p = 0; p < producers; p++)
            for (int i = 0; i < perProducer; i++) expectedSum += p * perProducer + i;

        long[] consumedSum = new long[1];
        AtomicInteger consumedCount = new AtomicInteger();
        List<Thread> ts = new ArrayList<>();

        for (int p = 0; p < producers; p++) {
            final int base = p * perProducer;
            ts.add(new Thread(() -> {
                for (int i = 0; i < perProducer; i++) {
                    try { q.put(base + i); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
                }
            }));
        }
        for (int c = 0; c < 4; c++) {
            ts.add(new Thread(() -> {
                try {
                    while (true) {
                        int v = q.take();
                        if (v == PILL) return;              // 毒丸: 收到即退出
                        consumedCount.incrementAndGet();
                        synchronized (StressTest.class) { consumedSum[0] += v; }
                    }
                } catch (InterruptedException e) { return; }
            }));
        }
        for (Thread t : ts) t.start();
        // 每个生产者干完后各投 4 颗毒丸(每个消费者一颗)
        for (int p = 0; p < producers; p++) {
            final int base = p * perProducer;
            for (int i = 0; i < perProducer; i++) q.put(base + i);
            for (int c = 0; c < 4; c++) q.put(PILL);
        }
        for (Thread t : ts) t.join(10_000);

        boolean countOk = consumedCount.get() == total;
        boolean sumOk = consumedSum[0] == expectedSum;
        boolean exitOk = ts.stream().noneMatch(Thread::isAlive);
        System.out.println("Test1 多对多(容量10): 消费" + consumedCount.get() + "/" + total
            + " 和校验" + consumedSum[0] + "/" + expectedSum
            + " => " + (countOk && sumOk ? "数据PASS" : "数据FAIL")
            + " | 全线程退出: " + (exitOk ? "PASS" : "FAIL"));

        // ── Test 2: 快产慢消, 容量5 ──
        MyBlockingQueue<Integer> q3 = new MyBlockingQueue<>(5);
        List<Integer> got3 = Collections.synchronizedList(new ArrayList<>());
        Thread p3 = new Thread(() -> { for (int i = 0; i < 50; i++) try { q3.put(i); } catch (InterruptedException e) {} });
        Thread c3 = new Thread(() -> {
            for (int i = 0; i < 50; i++) try { got3.add(q3.take()); Thread.sleep(5); } catch (InterruptedException e) { return; }
        });
        p3.start(); c3.start(); p3.join(10_000); c3.join(10_000);
        boolean t2ok = got3.size() == 50 && got3.stream().sorted().mapToInt(Integer::intValue).sum() == 1225;
        System.out.println("Test2 快产慢消(容量5): 取到" + got3.size() + "/50 => " + (t2ok ? "PASS" : "FAIL"));

        // ── Test 3: 慢产快消, 容量3 ──
        MyBlockingQueue<Integer> q4 = new MyBlockingQueue<>(3);
        List<Integer> got4 = Collections.synchronizedList(new ArrayList<>());
        Thread p4 = new Thread(() -> { for (int i = 0; i < 20; i++) try { q4.put(i); Thread.sleep(3); } catch (InterruptedException e) { return; } });
        Thread c4 = new Thread(() -> { for (int i = 0; i < 20; i++) try { got4.add(q4.take()); } catch (InterruptedException e) { return; } });
        p4.start(); c4.start(); p4.join(10_000); c4.join(10_000);
        boolean t3ok = got4.size() == 20 && got4.stream().mapToInt(Integer::intValue).sum() == 190;
        System.out.println("Test3 慢产快消(容量3): 取到" + got4.size() + "/20 => " + (t3ok ? "PASS" : "FAIL"));

        System.exit(exitOk && countOk && sumOk && t2ok && t3ok ? 0 : 1);
    }
}
