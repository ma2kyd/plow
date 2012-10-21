
import threading
import subprocess
import logging
import time

import conf
import client
import rpc.ttypes as ttypes

from datetime import datetime

from profile import SystemProfiler

logger = logging.getLogger(__name__)

class ResourceManager(object):
    """
    The ResourceManager keeps track of the bookable resources on the
    machine.  This is currently just cores, but memory and GPUS
    in the future.
    """

    def __init__(self):
        self.__slots = dict([(i, 0) for i in range(0, Profiler.physicalCpus)])
        self.__lock = threading.Lock()
        logger.info("Intializing resource manager with %d physical cores." % Profiler.physicalCpus)

    def checkout(self, numCores):
        if numCores < 1:
            raise ttypes.RndException(1, "Cannot reserve 0 slots")

        self.__lock.acquire(True)
        try:
            open_slots = self.getOpenSlots()
            logger.info(open_slots)
            if numCores > len(open_slots):
                raise ttypes.RndException(1, "No more open slots")
            result = open_slots[0:numCores]
            for i in result:
                self.__slots[i] = 1
            logger.info("Checked out CPUS: %s" % result)
            return result
        finally:
            self.__lock.release()

    def checkin(self, cores):
        self.__lock.acquire(True)
        try:
            for core in cores:
                if self.__slots[core] == 1:
                    self.__slots[core] = 0
                else:
                    logger.warn("Failed to check in core: %d" + core)
        finally:
            self.__lock.release()
        logger.info("Checked in CPUS: %s" % cores)

    def getSlots(self):
        return dict(self.__slots)

    def getOpenSlots(self):
        return [slot for slot in self.__slots if self.__slots[slot] == 0]

class ProcessManager(object):
    """
    The ProcessManager keeps track of the running tasks.  Each task
    is executed in a separate ProcessThread.
    """

    def __init__(self):
        self.__threads = { }
        self.__lock = threading.Lock()
        self.sendPing(True)

    def runProcess(self, processCmd):
        cpus = ResourceMgr.checkout(processCmd.cores)
        pthread = ProcessThread(processCmd)
        with self.__lock:
            self.__threads[processCmd.procId] = (processCmd, pthread, cpus)
        pthread.start()
        logger.info("procsss thread started");
        return pthread.getRunningTask()

    def processFinished(self, processCmd):
        ResourceMgr.checkin(self.__threads[processCmd.procId][2])
        with self.__lock:
            try:
                del self.__threads[processCmd.procId]
            except Exception, e:
                logger.warn("Process %s not found: %s" % (processCmd.procId, e))

    def sendPing(self, isReboot=False):
        tasks = [p[1].getRunningTask() for p in self.__threads]
        Profiler.sendPing(tasks, isReboot)

        self.__timer = threading.Timer(60.0, self.sendPing)
        self.__timer.daemon = True
        self.__timer.start()


class ProcessThread(threading.Thread):
    """
    The ProcessThreasd wraps a running task.
    """
    
    def __init__(self, rtc):
        threading.Thread.__init__(self)
        self.daemon = True

        self.__rtc = rtc
        self.__pptr = None
        self.__logfp = None
        self.__pid = 0

    def getRunningTask(self):
        rt = ttypes.RunningTask()
        rt.jobId = self.__rtc.jobId
        rt.procId = self.__rtc.procId
        rt.taskId = self.__rtc.taskId
        rt.maxRss = 0
        rt.pid = self.__pid
        return rt

    def run(self):
        retcode = 1
        try:
            logger.info("Opening log file: %s" % self.__rtc.logFile)
            self.__logfp = open(self.__rtc.logFile, "w")
            self.__writeLogHeader()
            self.__logfp.flush()

            logger.info("Running command: %s" % self.__rtc.command)
            self.__pptr = subprocess.Popen(self.__rtc.command,
                shell=False, stdout=self.__logfp, stderr=self.__logfp)
            
            self.__pid = self.__pptr.pid
            logger.info("PID: %d" % self.__pid)
            retcode = self.__pptr.wait()
        
        except Exception, e:
            logger.warn("Failed to execute command: %s" % e)
        finally:
            self.__completed(retcode)

    def __completed(self, retcode):

        result = ttypes.RunTaskResult()
        result.procId = self.__rtc.procId
        result.taskId = self.__rtc.taskId
        result.jobId = self.__rtc.jobId
        result.maxRss = 0
        if retcode < 0:
            result.exitStatus = 1
            result.exitSignal = retcode
        else:
            result.exitStatus = retcode
            result.exitSignal = 0

        logger.info("Process result %s" % result)
        if not conf.NETWORK_DISABLED:
            while True:
                try:
                    service, transport = client.getPlowConnection()
                    service.taskComplete(result)
                    transport.close()
                    break
                except Exception, e:
                    logger.warn("Error talking to plow server," + str(e) + ", sleeping for 30 seconds")
                    time.sleep(30)

        ProcessMgr.processFinished(self.__rtc)
        self.__writeLogFooter(result)
        self.__logfp.close()

    def __writeLogHeader(self):
        self.__logfp.write("Render Process Begin\n")
        self.__logfp.write("================================================================\n")

    def __writeLogFooter(self, result):
        # TODO: Add more stuff here
        self.__logfp.flush()
        self.__logfp.write("\n\n\n")
        self.__logfp.write("Render Process Complete\n")
        self.__logfp.write("=====================================\n")
        self.__logfp.write("Exit Status: %d\n" % result.exitStatus)
        self.__logfp.write("Signal: %d\n" % result.exitSignal)
        self.__logfp.write("MaxRSS: 0\n")
        self.__logfp.write("=====================================\n\n")

Profiler = SystemProfiler()
ResourceMgr = ResourceManager()
ProcessMgr = ProcessManager()

def runProcess(rtc):
    return ProcessMgr.runProcess(rtc)







