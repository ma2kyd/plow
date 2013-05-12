package com.breakersoft.plow.service;

import java.util.List;

import org.slf4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;

import com.breakersoft.plow.Depend;
import com.breakersoft.plow.ExitStatus;
import com.breakersoft.plow.Job;
import com.breakersoft.plow.Layer;
import com.breakersoft.plow.Proc;
import com.breakersoft.plow.Signal;
import com.breakersoft.plow.Task;
import com.breakersoft.plow.dispatcher.DispatchService;
import com.breakersoft.plow.event.EventManager;
import com.breakersoft.plow.event.JobFinishedEvent;
import com.breakersoft.plow.exceptions.RndClientExecuteException;
import com.breakersoft.plow.rndaemon.RndClient;
import com.breakersoft.plow.thrift.TaskFilterT;
import com.breakersoft.plow.thrift.TaskState;

@Component
public class StateManager {

    private static final Logger logger = org.slf4j.LoggerFactory.getLogger(StateManager.class);

    @Autowired
    JobService jobService;

    @Autowired
    DispatchService dispatchService;

    @Autowired
    NodeService nodeService;

    @Autowired
    DependService dependService;

    @Autowired
    EventManager eventManager;

    @Autowired
    RndProcessManager processManager;

    @Autowired
    ThreadPoolTaskExecutor stateChangeExecutor;

    public void killProc(Task task, boolean unbook) {
        final Proc proc = nodeService.getProc(task);
        if (unbook) {
            nodeService.setProcUnbooked(proc, true);
        }
        try {
            RndClient client = new RndClient(proc.getHostname());
            client.kill(proc, "Killed by user");
        } catch (RndClientExecuteException e) {
            logger.warn("Failed to stop running task: {}, {}", task.getTaskId(), e);
        }
    }

    public void killTask(Task task) {
        logger.info("Thread: {} Eating Task: {}", Thread.currentThread().getName(), task.getTaskId());

        if (dispatchService.stopTask(task, TaskState.WAITING, ExitStatus.FAIL, Signal.MANUAL_KILL)) {
            killProc(task, true);
        }
    }

    public void eatTask(Task task) {
        logger.info("Thread: {} Eating Task: {}", Thread.currentThread().getName(), task.getTaskId());

        if (dispatchService.stopTask(task, TaskState.EATEN, ExitStatus.FAIL, Signal.MANUAL_KILL)) {
            killProc(task, false);
        }
        else {
            jobService.setTaskState(task, TaskState.EATEN);
        }
    }

    public void retryTask(final Task task) {
        logger.info("Thread: {} Retrying Task: {}", Thread.currentThread().getName(), task.getTaskId());

        // First try to stop the task, if that works kill the
        // running task.
        if (dispatchService.stopTask(task, TaskState.WAITING, ExitStatus.FAIL, Signal.MANUAL_RETRY)) {
            killProc(task, false);
        }
        else {
            // The trigger trig_before_update_set_depend handles not allowing
            // depend frames to go waiting.
            jobService.setTaskState(task, TaskState.WAITING);
        }
    }

    @Async(value="stateChangeExecutor")
    public void retryTasks(TaskFilterT filter) {
        final List<Task> tasks = jobService.getTasks(filter);
        logger.info("Thread: {} Batch retrying {} Tasks", Thread.currentThread().getName(), tasks.size());
        for (final Task t: tasks) {
            stateChangeExecutor.execute(new Runnable() {
                @Override
                public void run() {
                    retryTask(t);
                }
            });
        }
    }

    @Async(value="stateChangeExecutor")
    public void eatTasks(TaskFilterT filter) {
        final List<Task> tasks = jobService.getTasks(filter);
        logger.info("Thread: {} Batch eating {} tasks", Thread.currentThread().getName(), tasks.size());
        for (final Task t: tasks) {
            stateChangeExecutor.execute(new Runnable() {
                @Override
                public void run() {
                    eatTask(t);
                }
            });
        }
    }

    @Async(value="stateChangeExecutor")
    public void killTasks(TaskFilterT filter) {
        final List<Task> tasks = jobService.getTasks(filter);
        logger.info("Thread: {} Batch killing {} tasks", Thread.currentThread().getName(), tasks.size());
        for (final Task t: tasks) {
            stateChangeExecutor.execute(new Runnable() {
                @Override
                public void run() {
                    killTask(t);
                }
            });
        }
    }

    public boolean killJob(Job job, String reason) {
        final boolean killResult = shutdownJob(job);
        if (killResult) {
            processManager.killProcs(job, reason);
        }
        return killResult;
    }

    public boolean shutdownJob(Job job) {
        if (jobService.shutdown(job)) {
            satisfyDependsOn(job);
            eventManager.post(new JobFinishedEvent(job));
            return true;
        }
        return false;
    }

    public void satisfyDependsOn(Job job) {
        for (Depend depend: dependService.getOnJobDepends(job)) {
            dependService.satisfyDepend(depend);
        }
    }

    public void satisfyDependsOn(Task task) {
        for (Depend depend: dependService.getOnTaskDepends(task)) {
            dependService.satisfyDepend(depend);
        }
    }

    public void satisfyDependsOn(Layer layer) {
        for (Depend depend: dependService.getOnLayerDepends(layer)) {
            dependService.satisfyDepend(depend);
        }
    }
}
