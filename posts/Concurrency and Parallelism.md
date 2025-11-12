---
title: Concurrency and Parallelism
description: Showcasing the difference between the two and how they work together
date: 2025-11-09
tags:
  - concurrency
  - parallelism
  - operating system
layout: layouts/post.njk
---

TL;DR  
**Parallelism** – actually doing multiple things at the same time (requires multiple execution units - CPUs, cores, hardware threads...)  
**Concurrency** – dealing with multiple things by switching between them efficiently (may or may not happen simultaneously)

In real systems, concurrency is a software-level concept (managed by scheduling or async programming), while parallelism depends on hardware capabilities. 

# Real World Example

You are making a simple breakfast and you need to do two things: make "sunny side up" eggs and a cup of instant coffee. Let's break both of these tasks down into smaller ones.

**Making "sunny side up" eggs**
1. Crack a few eggs in a bowl
2. Put oil in a pan
3. Put pan on a stove
4. When oil heats up, gently put the eggs from a bowl into a pan
5. Cover the pan with a lid
6. Remove pan from the stove when eggs are done

**Making a cup of coffee**
1. Put water in an electric kettle
2. When water boils, put instant coffee in the cup
3. Pour hot water into the cup
4. Add sugar
5. Stir

Now let's explain each of the combination of parallelism and concurrency.

## Neither Parallelism nor Concurrency

**Only you are working in the kitchen. You can take only one task at a time and not start anything else until you finish that task completely, even if it involves waiting for something.**

1. You crack a few eggs in a bowl
2. You put oil in a pan
3. **You stand in front of the stove, watching the oil get hot. You don't take any other task in the meantime, you just stand there and watch**
4. When oil heats up, you put the eggs in the pan
5. You put a lid on a pan
6. **You stand in front of a stove and watch the eggs cook. Again, you don't start anything else while waiting, you stand there completely still and watch**
7. Once the eggs are done, remove the pan from the stove

Only now you can start making coffee.

1. You put water in an electric kettle and turn it on
2. **You stand in front of a kettle and watch the water heat up. You don't do absolutely anything in the meantime**
3. Once the water boils, you put instant coffee in the cup
4. You pour water from the kettle in the cup
5. You add sugar to the coffee
6. You stir until mixed properly

<img src="{{ '/img/concurrency-and-parallelism/NCNP.png' | url }}" alt="Neither concurrency nor parallelism" width="100%" height="auto" />

The issue with this approach is clearly visible. A bunch of time is spent waiting, while it can be utilized to finish other tasks which do not depend on the task we are waiting for: *"waiting time = wasted time"*

## Parallelism Only

Your family member or significant other joins to help you. Unfortunately, you still do things in a non-optimized way.

**There are two of you in the kitchen now and you can each start a task simultaneously, but not start anything else until you finish that task completely, even if it involves waiting for something.**

The scenario is exactly the same as above. The only difference is that, while you are making eggs, the other person is making the coffee. Neither one of you take up tasks of another person, both of you are fully dedicated to your own tasks. Since there is no concurrency, both you and the other person still cannot tackle any other task while waiting for something (oil to heat up, water to boil...).

<img src="{{ '/img/concurrency-and-parallelism/NCP.png' | url }}" alt="Parallelism only" width="100%" height="auto" />

Even though there is a second person helping us, we still didn't get rid of the fact that *"waiting time = wasted time"*.

## Concurrency Only

Your family member or significant other is not at home. You are alone once again, but much wiser now.

**Only you are working in the kitchen. You can take only one task at a time, but if the task requires waiting for something, you can start something else which doesn't depend on the task you are waiting for.**

1. You crack a few eggs in a bowl
2. You put oil in the pan
3. You put the pan on the stove
4. **You don't just stand there, look at the pan and wait for oil to heat up. You leave it to be and start making coffee**
5. You put water in an electric kettle
6. **You don't just stand there waiting for water to boil**
7. You put coffee in the cup
8. While water is heating up and as soon as you put coffee in the cup, you notice that the oil has heated up
9. You put eggs in the pan
10. You cover the pan with a lid
11. **You don't just stand there waiting for eggs to be done**
12. As soon as you cover the pan, you notice that the water has boiled
13. You pour water in the cup
14. You add sugar
15. You stir the coffee
16. Once you're done with that, let's say the eggs are **not** done yet. Since there is nothing else to be done, there is some time spent waiting and doing nothing (unlike previously, this is not *"wasted time"*)
17. After some time, you notice that the eggs are done
18. You remove the pan from the stove

<img src="{{ '/img/concurrency-and-parallelism/CNP.png' | url }}" alt="Concurrency only" width="100%" height="auto" />

Concurrency helps us get rid of the *"waiting time = wasted time"* by taking other tasks while we are waiting for something.

## Parallelism and Concurrency

Your family member or significant other is at home again and this time both of you know how to do things properly.

**There are two of you in the kitchen now and can start 2 tasks simultaneously, but if the task requires waiting for something, both of you can start something else which doesn't depend on the task you are waiting for.**

1. You crack a few eggs in a bowl and another person puts oil in the pan
2. The other person puts a pan on the stove and you put water in a kettle
3. You put coffee in the cup
4. **Both of you were so fast and efficient that you have nothing to do now, both of you wait a bit for oil to heat up and water to boil**
5. Oil got hot, but the water didn't boil. You decide to tackle that one and put eggs in the pan while the other person is still waiting for the water to boil. As soon as you do that, the other person realizes that the water has boiled
6. You put the lid on the pan. The other person pours the water into the cup
7. Now you have nothing to do
8. The other person puts sugar in the cup
9. The other person is stirring the coffee
10. The coffee is done
11. Let's say the eggs are **not** done yet. Since there is nothing else to be done, there is some time spent waiting and doing nothing (again, this is not *"wasted time"*)
12. After some time, you notice that the eggs are done
13. You remove the pan from the stove


<img src="{{ '/img/concurrency-and-parallelism/CP.png' | url }}" alt="Concurrency and parallelism" width="100%" height="auto" />


# Hardware and software analogy

- The kitchen represents the hardware, it can only fit N people (CPU cores or hardware threads)
- If there are multiple kitchens, that represents multiple CPUs in a system
- The people represent software threads, they want to work but can only enter the kitchen if there’s enough space
- When a person steps out because they’re waiting (e.g., for oil to heat up), someone else can step in, that’s concurrency. That person can also not step out, but immediately start something else instead
- If multiple people are working at the same time, that’s parallelism

In short, concurrency helps keeping you busy while waiting, which will improve latency and utilization, while parallelism helps you truly do things at the same time, which will increase throughput. They don't exclude one another, they are complementary.
Together, they maximize efficiency, whether you’re making breakfast or building software.

# Additional Details

- Explained above, where a person notices that something in the kitchen is done and only then switches to that task, is cooperative concurrency. There exists a preemptive concurrency as well, where you get put on a pause even when you are not supposed to wait for anything. But in our kitchen example, that could cause burnt eggs, oil catching fire... More on this topic [here](https://stackoverflow.com/a/55703529)
- The people not only represent software threads, but can also represent virtual threads, coroutines, goroutines, async tasks...
- Parallelism primarily boosts throughput for CPU-bound work. Concurrency primarily reduces latency and keeps systems responsive, especially for I/O-bound workload (database and network calls)
- Some parallelism is possible even on a single physical core, via simultaneous multithreading ([Hyper‑Threading](https://superuser.com/a/122571)) and via vector units ([SIMD](https://celerdata.com/glossary/single-instruction-multiple-data-simd)). Keep in mind that both are very limited compared to multiple cores
- There exists a concept called [**thread pool**](https://softwareengineering.stackexchange.com/a/173581), which includes creating N amount of OS/software threads and utilizing them when necessary, instead of creating new threads on demand, since creating them is a costly operation
- Perfect example of a system which is concurrent, but not parallel by default is [JavaScript's event loop](https://www.youtube.com/watch?v=8aGhZQkoFbQ)
- Beautiful presentation about coroutines, Kotlin's concurrency model can be found [here](https://www.youtube.com/watch?v=e7tKQDJsTGs)