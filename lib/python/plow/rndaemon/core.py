
import threading
import subprocess
import logging
import time
import os
import traceback
import errno

from collections import namedtuple, deque

import psutil

import conf
import client
import utils
import rpc.ttypes as ttypes

from profile import SystemProfiler as _SystemProfiler

logger = logging.getLogger(__name__)


__all__ = ['Profiler', 'ResourceMgr', 'ProcessMgr']


_RunningProc = namedtuple("RunningProc", "processCmd pthread cpus")


#
# _ResourceManager
#
class _ResourceManager(object):
    """
    The ResourceManager keeps track of the bookable resources on the
    machine.  This is currently just cores, but memory and GPUS
    in the future.
    """

    def __init__(self):
        self.__slots = deque(xrange(Profiler.physicalCpus))
        self.__slots_all = tuple(self.__slots)
        self.__lock = threading.RLock()

        logger.info("Intializing resource manager with %d physical cores.", 
                    Profiler.physicalCpus)

    def checkout(self, numCores):
        if numCores < 1:
            raise ttypes.RndException(1, "Cannot reserve 0 slots")

        result = []

        with self.__lock:
            open_slots = self.__slots
            logger.info("Open slots: %s", list(open_slots))

            if numCores > len(open_slots):
                raise ttypes.RndException(1, "No more open slots")

            result = [open_slots.pop() for _ in xrange(numCores)]
    
        logger.info("Checked out CPUS: %s", result)
        return result

    def checkin(self, cores):
        with self.__lock:
            self.__slots.extend(cores)
            logger.info("Checked in CPUS: %s; Now available: %s", cores, list(self.__slots))

    def getSlots(self):
        return list(xrange(Profiler.physicalCpus))

    def getOpenSlots(self):
        with self.__lock:
            return list(self.__slots)


#
# _ProcessManager
#
class _ProcessManager(object):
    """
    The ProcessManager keeps track of the running tasks.  Each task
    is executed in a separate ProcessThread.
    """

    SAMPLE_INTERVAL_SEC = 10

    def __init__(self):
        self.__threads = {}
        self.__lock = threading.RLock()
        self.__timer = None 
        self.__isReboot = threading.Event()

        self.__sampler = threading.Thread(target=self._processSampler)
        self.__sampler.daemon = True 
        self.__sampler.start()

        self.sendPing(True)

    def runProcess(self, processCmd, wait=-1):
        cpus = ResourceMgr.checkout(processCmd.cores)
        pthread = _ProcessThread(processCmd, cpus)
        pthread.start()

        with self.__lock:
            self.__threads[processCmd.procId] = _RunningProc(processCmd, pthread, cpus)

        task = pthread.getRunningTask(wait)
        logger.info("process thread started")

        return task

    def processFinished(self, processResult):
        with self.__lock:
            cpus = self.__threads[processResult.procId].cpus
            ResourceMgr.checkin(cpus)
            try:
                del self.__threads[processResult.procId]
            except Exception, e:
                logger.warn("Process %s not found: %s", processResult.procId, e)

    def sendPing(self, isReboot=False, repeat=True):
        # TODO: What is the purpose of the isReboot flag?
        # Using the internal flag to determine if we are in a 
        # reboot state.
        isReboot = self.__isReboot.isSet()

        with self.__lock:
            tasks = self.getRunningTasks()
        Profiler.sendPing(tasks, isReboot)

        # TODO: Maybe there needs to be a seperate thread for this check
        # but for now it is part of the ping loop.
        if isReboot and not tasks:
            logger.info("Task queue is empty and daemon is scheduled for reboot")
            try:
                Profiler.reboot()
            except ttypes.RndException, e:
                # on next loop, the server will see that the system
                # is no longer in isReboot state
                logger.warn(e.why)
                self.__isReboot.clear()
            else:
                # just in case
                return

        if repeat:
            self.__timer = threading.Timer(conf.NETWORK_PING_INTERVAL, self.sendPing)
            self.__timer.daemon = True
            self.__timer.start()

    def killRunningTask(self, procId, reason):
        logger.info("kill requested for procId %s, %s", procId, reason)

        with self.__lock:
            try:
                pthread = self.__threads[procId].pthread
            except KeyError:
                err = "Process %s not found" % procId
                logger.warn(err)
                # TODO: Raise a proper exception type? or
                # fail quietly?
                raise ttypes.RndException(1, err)

        _, not_killed = pthread.killProcess()

        if not_killed:
            err = "Failed to kill the following pids for prodId %s: %s" % \
                    (procId, ','.join(not_killed))
            logger.warn(err)
            raise ttypes.RndException(1, err)

    def getRunningTasks(self):
        return [t.pthread.getRunningTask() for t in self.__threads.itervalues()]

    def reboot(self, now=False):
        """
        reboot (bool now=False)

        Reboot the system as soon as it becomes idle. That is, 
        when no tasks are running. 

        If now == True, reboot immediately, regardless of any 
        in-progress render tasks. 
        """
        # TODO: For now, assuming that even if they aren't root,
        # that they may have permission to reboot. This means a
        # reboot(now=False) will not raise an exception to the caller.
        #
        # if os.geteuid() != 0:
        #     err = "rndaemon not running as user with permission to reboot system"
        #     raise ttypes.RndException(1, err)

        self.__isReboot.set() 

        if now:
            logger.info("*SYSTEM GOING DOWN FOR IMMEDIATE REBOOT*")
            with self.__lock:
                if self.__timer:
                    self.__timer.cancel()
                # The reboot could happen from the ping if the task
                # queue is empty. 
                self.sendPing(repeat=False)
            # Otherwise, the reboot will happen here, regardless
            # of whether there are active tasks running.
            Profiler.reboot()

        else:
            logger.info("*Reboot scheduled at next idle event*")

    def _processSampler(self):
        """
        Loop that updates metrics on every running process 
        at intervals.
        """
        while True:
            with self.__lock:
                pthreads = [t.pthread for t in self.__threads.itervalues()]

            for pthread in pthreads:
                pthread.updateMetrics()

            time.sleep(self.SAMPLE_INTERVAL_SEC)


#
# RunningTask
#
class RunningTask(ttypes.RunningTask):
    def __repr__(self):
        D = self.__dict__.copy()

        # elide the log string if its too big
        lastLog = D.get('lastLog')
        if lastLog and len(lastLog) > 50:
            D['lastLog'] = '%s...' % lastLog[:47]

        L = ('%s=%r' % (key, value) for key, value in D.iteritems())
        return '%s(%s)' % (self.__class__.__name__, ', '.join(L))        


#
# _ProcessThread
#
class _ProcessThread(threading.Thread):
    """
    The _ProcessThread wraps a running task.
    """
    def __init__(self, rtc, cpus=None):
        threading.Thread.__init__(self)
        self.daemon = True

        self.__logfp = None
        self.__cpus = cpus or set()

        self.__lock = threading.RLock()
        self.__rtc = rtc
        self.__pptr = None
        self.__logfp = None
        self.__pid = -1

        self.__wasKilled = False
        self.__hasStarted = threading.Event()

        self.__progressLock = threading.Lock()
        self.__progress = 0.0
        self.__lastLog = ""

        self.__metricsLock = threading.Lock()
        self.__metrics = {
            'rssMb': 0,
            'cpuPercent': 0,
        }

    def __repr__(self):
        return "<%s: (procId: %s, pid: %d)>" % (
            self.__class__.__name__, 
            self.__rtc.procId, 
            self.__pid)


    def getRunningTask(self, wait=-1):
        """
        getRunningTask(float wait=-1) -> RunningTask

        Returns a RunningTask instance representing 
        the current state of the task.

        If wait > 0, then wait that many seconds for
        the process to start. This is useful if you are
        creating the process and then checking its running
        task right away. Some information may not be 
        available until after the thread has gotten the
        process running.
        """
        if wait > 0:
            self.__hasStarted.wait(wait)

        rt = RunningTask()

        with self.__lock:
            rt.jobId = self.__rtc.jobId
            rt.procId = self.__rtc.procId
            rt.taskId = self.__rtc.taskId
            rt.layerId = self.__rtc.layerId
            rt.pid = self.__pid

        with self.__metricsLock:
            rt.rssMb = self.__metrics['rssMb']
            rt.cpuPercent = self.__metrics['cpuPercent']

        with self.__progressLock:
            rt.progress = self.__progress 
            rt.lastLog = self.__lastLog or None 

        return rt

    def run(self):
        rtc = self.__rtc 
        retcode = 1

        try:
            logger.info("Opening log file: %s", rtc.logFile)
            self.__logfp = utils.ProcessLog(self.__rtc.logFile)
            self.__logfp.writeLogHeader(rtc)

            env = os.environ.copy()
            env.update(rtc.env)

            parser = None
            if rtc.taskTypes:
                parser = utils.ProcessLogParser.fromTaskTypes(rtc.taskTypes)
                if not parser.progress:
                    parser = None

            opts = {
                'stdout': subprocess.PIPE, 
                'stderr': subprocess.STDOUT,
                'uid': self.__rtc.uid,
                'cpus': self.__cpus,
                'env': env,
            }

            cmd, opts = Profiler.getSubprocessOpts(rtc.command, **opts)

            logger.info("Running command: %s", rtc.command)
            p = subprocess.Popen(cmd, **opts)

            with self.__lock:
                self.__pptr = p
                self.__pid = p.pid

            self.__hasStarted.set()
            logger.info("PID: %d", p.pid)

            self.updateMetrics()

            writeLog = self.__logfp.write
            r_pipe = self.__pptr.stdout 
            lock = self.__progressLock

            for line in iter(r_pipe.readline, ""):
                writeLog(line)

                with lock:
                    self.__lastLog = line

                    if parser:
                        prog = parser.parseProgress(line)
                        if prog is not None:
                            self.__progress = prog 

            try:
                retcode = p.wait()
            except OSError, e:
                if e.errno == errno.ECHILD:
                    pass
                else:
                    raise

            r_pipe.close()

            logger.debug("Return code: %s", retcode)

        except Exception, e:
            logger.warn("Failed to execute command: %s", e)
            logger.debug(traceback.format_exc())

        finally:
            self.__completed(retcode)

    def updateMetrics(self):
        """
        updateMetrics()

        Resample information about the currently running 
        process tree, and update member attributes. 

        i.e. rss 
        """
        # logger.debug("updateMetrics(): %r", self)
        try:
            p = psutil.Process(self.__pid)
        except psutil.NoSuchProcess:
            return

        rss_bytes = 0
        cpu_perc = 0

        try:
            rss_bytes = p.get_memory_info().rss
            cpu_perc = p.get_cpu_percent(None)
        except psutil.Error:
            return

        children = [child for child in p.get_children(True) 
                        if child.status != psutil.STATUS_ZOMBIE]

        for child in children:
            try:
                rss_bytes += child.get_memory_info().rss
            except psutil.Error:
                pass            
            try:
                cpu_perc += child.get_cpu_percent(None) 
            except psutil.Error:
                pass
        
        cpu_perc = int(round(cpu_perc))

        with self.__metricsLock:
            self.__metrics.update({
                'rssMb': rss_bytes / 1024 / 1024,
                'cpuPercent': cpu_perc,
            })
            # logger.debug("metrics: %s", self.__metrics)

    def killProcess(self):
        """
        killProcess() -> (list killed_pids, list not_killed)

        Stop the entire process tree

        Returns a tuple of two lists. The first list contains 
        the pids from the process tree that were successfully 
        stopped. The second list contains pids that were not 
        able to be stopped successfully.
        """
        p = psutil.Process(self.__pid)
        children = p.get_children(recursive=True)

        self.__wasKilled = True

        # kill the top parent
        self.__killOneProcess(p)

        # make sure each process in the tree is really dead
        killed = []
        not_killed = []

        for child in children:
            success = self.__killOneProcess(child)
            if success:
                killed.append(child.pid)
            else:
                not_killed.append(child.pid)

        return killed, not_killed

    def __killOneProcess(self, p):
        """
        __killOneProcess(psutil.Process p) -> bool

        Try and nicely stop a Process first, then kill it. 
        Return True if process was killed.
        """
        try: 
            p.wait(0.001)
        except psutil.TimeoutExpired: 
            pass
        if not p.is_running():
            return True

        pid = p.pid 

        logger.info("Asking nicely for pid %d (%s) to stop", pid, p.name)
        p.terminate()
        try: 
            p.wait(5)
        except psutil.TimeoutExpired: 
            pass

        if not p.is_running():
            return True

        logger.info("Killing pid %d (%s)", pid, p.name)
        p.kill()
        try: 
            p.wait(1)
        except psutil.TimeoutExpired: 
            pass

        if p.is_running():
            logger.warn("Failed to properly kill pid %d (taskId: %s)", pid, self.__rtc.taskId)
            return False 

        return True

    def __completed(self, retcode):
        result = ttypes.RunTaskResult()
        result.maxRssMb = 0

        with self.__lock:
            result.procId = self.__rtc.procId
            result.taskId = self.__rtc.taskId
            result.jobId = self.__rtc.jobId

        if self.__wasKilled:
            result.exitStatus = 1
            result.exitSignal = retcode if retcode < 0 else -9
        elif retcode < 0:
            result.exitStatus = 1
            result.exitSignal = retcode
        else:
            result.exitStatus = retcode
            result.exitSignal = 0

        logger.info("Process result %s", result)
        if not conf.NETWORK_DISABLED:
            while True:
                try:
                    service, transport = client.getPlowConnection()
                    service.taskComplete(result)
                    transport.close()
                    break
                except Exception, e:
                    logger.warn("Error talking to plow server, %s, sleeping for 30 seconds", e)
                    time.sleep(30)

        ProcessMgr.processFinished(result)
        if self.__logfp is not None:
            self.__logfp.writeLogFooterAndClose(result)


#
# Singleton Instances
#
Profiler = _SystemProfiler()
ResourceMgr = _ResourceManager()
ProcessMgr = _ProcessManager()
