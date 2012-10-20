package com.breakersoft.plow.dispatcher;

import java.util.List;
import java.util.UUID;

import com.breakersoft.plow.Job;
import com.breakersoft.plow.Proc;
import com.breakersoft.plow.Task;
import com.breakersoft.plow.dispatcher.domain.DispatchFolder;
import com.breakersoft.plow.dispatcher.domain.DispatchJob;
import com.breakersoft.plow.dispatcher.domain.DispatchLayer;
import com.breakersoft.plow.dispatcher.domain.DispatchNode;
import com.breakersoft.plow.dispatcher.domain.DispatchProc;
import com.breakersoft.plow.dispatcher.domain.DispatchProject;
import com.breakersoft.plow.dispatcher.domain.DispatchResource;
import com.breakersoft.plow.dispatcher.domain.DispatchTask;
import com.breakersoft.plow.event.JobLaunchEvent;

/**
 * Transactional dispatcher opterations.
 *
 * @author chambers
 *
 */
public interface DispatchService {

    List<DispatchProject> getSortedProjectList(DispatchNode node);

    DispatchNode getDispatchNode(String name);

    void createDispatchProc(DispatchProc proc);

    boolean reserveTask(Task task);

    boolean unreserveTask(Task task);

    DispatchJob getDispatchJob(JobLaunchEvent event);

    boolean removeProc(Proc proc);

    DispatchProc allocateDispatchProc(DispatchNode node, DispatchTask task);

    void unbookProc(DispatchProc proc);

    DispatchProc getDispatchProc(String id);

    List<DispatchTask> getDispatchTasks(DispatchLayer layer,
            DispatchResource resource);

    List<DispatchLayer> getDispatchLayers(Job job, DispatchResource resource);

    List<DispatchJob> getDispatchJobs();

    void assignProc(DispatchProc proc, DispatchTask task);

    void unassignProc(DispatchProc proc);

    DispatchFolder getDispatchFolder(UUID folder);

}
