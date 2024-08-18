---
title: Test order execution and flaky tests
description: How test order execution can make the test suite fail
date: 2024-08-18
tags:
  - flaky tests
  - test containers
layout: layouts/post.njk
---
Imagine being in a situation where, once you create a PR, you dread that some random test will sporadically fail and break the entire CI/CD pipeline. Disabling the entire test suite in the pipeline is obviously a no-go, so digging into the test suite configuration to find and fix the root cause is the obvious step. In this case, test suite configuration was handled by an internal library. 

# Configuration of the test suite

`./gradlew test` command runs the test suite, which is split into two: regular unit tests and DAL (*Data Access Layer*) tests, which require a single DB instance with all SQL migrations applied (thank you <a href="https://testcontainers.com/" target="_blank">test containers creators</a>). Unit test classes are configured to run in parallel, while DAL test classes are configured to run sequentially. All test methods in each class execute sequentially. 

All DAL tests extend a certain base class from the internal library which contains a static `@BeforeAll` method, which runs once for each DAL test class before any of it's tests are executed. It's main function is to instantiate a DB test container and run all SQL migrations if some previous DAL test hasn't done it already. Along with the method, this class also contains a static attribute `isDBTestContainerReady`, which is set to true once both of those processes are completed. **This is an important detail to remember.**

# Reproducing the issue locally

Issue at hand was that the first DAL test to run would fail with a wild `TimeoutException`. Since the issue was sporadic, test suite needed to be run a few times before the issue popped up. Parallel test execution brought the CPU to it's knees, so this was quite a tedious process. But once the test failed, something interesting happened: **two DB test containers were running**. Extracting the logs from both of them showed absolutely nothing, other than the fact that only one container, the one created later, was used for all tests, while the first one created remained unused. 

The next theory was truly a crazy one. Since the `@BeforeAll` method was instantiating the test container in a <a href="https://www.javatpoint.com/synchronized-block-example" target="_blank">synchronized</a> block of code, maybe the synchronization wasn't behaving properly. This has quickly proven to be incorrect, since all tests were run by a single thread. Also, the chances that a built-in language functionality doesn't work as expected is extremely low. 

Extracting the logs from both the successful and unsuccessful runs of the tests only revealed that something caused the two test containers to startup. The cause wasn't logged and it was unknown. It was time to dive deeper.

# Can't debug? No issues!
Running the tests in the debug mode and stopping in the internal library's `@BeforeAll` method wasn't something that was possible, due to some Gradle and IntelliJ configuration that was tedious to setup. The next step was to modify the internal library by strategically placing the logs with timestamps in the critical parts of the code, building and publishing that library locally and referencing it from the project. Custom logs were then visible when running `./gradlew test`. 

Custom logs discovered that the new DB test container starts up exactly 10 seconds after the first one has started, while SQL migrations were still being applied to the first container. What gives? Why is the new container starting while the first one hasn't even finished with applying all of the SQL migrations?

This is the only piece of code where 10 seconds are utilized inside of the `@BeforeAll` method:  
```kotlin
Unreliables.retryUntilSuccess(10, TimeUnit.SECONDS) {  
  Thread.sleep(300)  
  flywayMigrate(jdbcUrl, username, password)  
}
```
Hmm, let's take a look at this <a href="https://github.com/rnorth/duct-tape/blob/2a1c5be9f2ef3f16bf036cec8752a170d130b61e/src/main/java/org/rnorth/ducttape/unreliables/Unreliables.java#L31" target="_blank">retryUntilSuccess</a> from the `Unreliables` library:
```java
public static <T> T retryUntilSuccess(final int timeout, @NotNull final TimeUnit timeUnit, @NotNull final Callable<T> lambda) {

        check("timeout must be greater than zero", timeout > 0);

        final int[] attempt = {0};
        final Exception[] lastException = {null};

        final AtomicBoolean doContinue = new AtomicBoolean(true);
        try {
            return Timeouts.getWithTimeout(timeout, timeUnit, () -> {
                while (doContinue.get()) {
                    try {
                        return lambda.call();
                    } catch (Exception e) {
                        // Failed
                        LOGGER.trace("Retrying lambda call on attempt {}", attempt[0]++);
                        lastException[0] = e;
                    }
                }
                return null;
            });
        } catch (org.rnorth.ducttape.TimeoutException e) {
            if (lastException[0] != null) {
                throw new org.rnorth.ducttape.TimeoutException("Timeout waiting for result with exception", lastException[0]);
            } else {
                throw new org.rnorth.ducttape.TimeoutException(e);
            }
        } finally {
            doContinue.set(false);
        }
    }
```
There it was. The origin of the mysterious `TimeoutException` is finally found. 

# We now know "what?", but not the "why?"
Applying Flyway SQL migrations to the first DB test container would timeout after 10 seconds. Since no `try-catch` mechanism was implemented in the `@BeforeAll` method, `TimeoutException` would make the `@BeforeAll` method prematurely exit and **the static attribute `isDBTestContainerReady` would never be set to true.** Exception would propagate all the way to the JUnit library and it made the test fail, obviously. The next DAL test would come along, it's `@BeforeAll` would be executed, it would see that `isDBTestContainerReady` is false and **it would start a new container**. This time, Flyway SQL migrations finished on time, on the new DB test container, no `TimeoutException` occurred. But it's too late, the first `TimeoutException` broke everything.

 Now the question remains, **why does the first DAL test timeout on applying Flyway SQL migrations, but the second one doesn't?**

### Note

Even though `TimeoutException` occurs, Flyway migrations in this case will continue to run because that's how Java's [`Future`](https://www.baeldung.com/java-future) is implemented. Even when timeout happens, function (lambda) passed to it continues to run. More info could be found <a href="https://stackoverflow.com/questions/16231508/does-a-future-timeout-kill-the-thread-execution" target="_blank">here</a>. 

# The "Why?" requires a keen eye
After running the tests about 30-40 times, a pattern started to emerge. Every time when the first DAL test would **start a bit early**, it would fail with a `TimeoutException`. Let's go back to the beginning, to the test suite configuration. Unit tests run in parallel, right? Parallel execution brings the CPU to it's knees, right? So if the first DAL test starts a bit early while many of the unit tests are running in parallel, **Flyway migrations would run slower**. Slow enough to get over the 10 second mark, since the CPU is struggling. But if the first migration process fails, why doesn't the second one also fail? Simple, many of the unit tests already finished when the second DAL test came along so the CPU isn't stressed as it was. Second initiation of Flyway SQL migration easily passes under 10 seconds.  

# Resolving the issue

In the end, the issue was resolved by increasing the timeout for applying Flyway SQL migrations from 10 to 60 seconds by the library maintainers. This theoretically only postpones the issue, but practically that barrier should never be breached. At least not in a few years.  

Other possible fixes that could be talked and discussed about are:
- Separate DAL tests from unit tests in Gradle
    - and run them sequentially/separately
- Remove the timeout completely, give Flyway all the time it needs
	- only implement a simple attempt count retry mechanism
- Keep the timeout, but use attempt count with a back-off strategy
- Make DAL tests run last (implementing custom logic to make the tests pass is not a good design choice)