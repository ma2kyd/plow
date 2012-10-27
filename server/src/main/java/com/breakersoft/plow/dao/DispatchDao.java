package com.breakersoft.plow.dao;

import java.util.List;
import java.util.UUID;

import com.breakersoft.plow.Job;
import com.breakersoft.plow.Node;
import com.breakersoft.plow.dispatcher.domain.DispatchFolder;
import com.breakersoft.plow.dispatcher.domain.DispatchJob;
import com.breakersoft.plow.dispatcher.domain.DispatchLayer;
import com.breakersoft.plow.dispatcher.domain.DispatchNode;
import com.breakersoft.plow.dispatcher.domain.DispatchProc;
import com.breakersoft.plow.dispatcher.domain.DispatchProject;
import com.breakersoft.plow.dispatcher.domain.DispatchResource;
import com.breakersoft.plow.dispatcher.domain.DispatchTask;
import com.breakersoft.plow.rnd.thrift.RunTaskCommand;

/**
 * A DAO for obtaining Dispatch brand objects.
 *
 * @author chambers
 *
 */
public interface DispatchDao {

    DispatchJob getDispatchJob(Job job);

    List<DispatchProject> getSortedProjectList(Node node);

    DispatchNode getDispatchNode(String name);

    DispatchProc getDispatchProc(UUID id);

    List<DispatchLayer> getDispatchLayers(Job job, DispatchResource resource);

    List<DispatchTask> getDispatchTasks(DispatchLayer layer,
            DispatchResource resource);

    List<DispatchJob> getDispatchJobs();

    DispatchFolder getDispatchFolder(UUID folder);

    RunTaskCommand getRunTaskCommand(DispatchTask task, DispatchProc proc);
}
