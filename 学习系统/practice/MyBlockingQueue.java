// ============================================================
// 题目：生产者 - 消费者（阻塞队列）
// ============================================================
// 用 Java 实现一个容量为 N 的阻塞队列 MyBlockingQueue，
// 两个角色并发访问它：
//
//   - 生产者：队列满时 put(e) 阻塞，腾出空位后再放入；
//   - 消费者：队列空时 take() 阻塞，有数据后再取出。
//
// 要求
//   1. 自己实现 MyBlockingQueue 类，含 put(E e) 与 take() 两个方法；
//   2. 内部数据结构自选（数组循环队列 / LinkedList 均可）；
//   3. 写一个 main：各起若干生产者/消费者线程，
//      验证不丢数据、不死等（如：生产者共放入 100 个数，
//      消费者共取出 100 个数后程序正常结束，打印统计）。
//
// 提示（仅运行方式，非算法提示）
//   编译运行:
//     javac MyBlockingQueue.java && java MyBlockingQueue
//
// ============================================================
// 请在下方写出完整的可运行代码（含 main 验证）。

public class MyBlockingQueue<E> {
    E[] queue;
    int head;
    int tail;
    int size;
    public MyBlockingQueue(int capacity) {
        queue = (E[]) new Object[capacity];
        head=0;
        tail=0;
        size=0;
    }
     public synchronized void put(E e) throws InterruptedException {
        while (size==queue.length){
            wait();
        }
        queue[tail]=e;
        tail=(tail+1)%queue.length;
        size++;
        notifyAll();
    }

    public synchronized E take() throws InterruptedException {
        while (size==0){
            wait();
        }
        E e=queue[head];
        head=(head+1)%queue.length;
        size--;
        notifyAll();
        return e;
    }

    public static void main(String[] args) throws InterruptedException {
        MyBlockingQueue<Integer> queue = new MyBlockingQueue<>(100);
        Runnable producer = () -> {
            for (int i = 0; i < 100; i++) {
                try {
                    queue.put(i);
                    System.out.println("Produced: " + i);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        };
        Runnable consumer = () -> {
            for (int i = 0; i < 100; i++) {
                try {
                    int value = queue.take();
                    System.out.println("Consumed: " + value);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        };
        Thread producerThread = new Thread(producer);
        Thread consumerThread = new Thread(consumer);
        producerThread.start();
        consumerThread.start();
        producerThread.join();
        consumerThread.join();
        System.out.println("All items produced and consumed.");
    }
}