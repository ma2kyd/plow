
#######################
# TaskState
#

@cython.internal
cdef class _TaskState:
    cdef:
        readonly int INITIALIZE, WAITING, RUNNING
        readonly int DEAD, EATEN, DEPEND, SUCCEEDED

    def __cinit__(self):
        self.INITIALIZE = TASKSTATE_INITIALIZE
        self.WAITING = TASKSTATE_WAITING
        self.RUNNING = TASKSTATE_RUNNING
        self.DEAD = TASKSTATE_DEAD
        self.EATEN = TASKSTATE_EATEN
        self.DEPEND = TASKSTATE_DEPEND
        self.SUCCEEDED = TASKSTATE_SUCCEEDED

TaskState = _TaskState()


#######################
# TaskSpec
#

cdef class TaskSpec:
    """
    Defines a task specification

    :var name: string name 
    :var depends: list[:class:`.DependSpec`] 

    """
    cdef public string name
    cdef list depends

    def __init__(self, **kwargs):
        self.name = kwargs.get('name', '')
        self.depends = kwargs.get('depends', [])

    def __repr__(self):
        return "<TaskSpec: %s>" % self.name

    cdef TaskSpecT toTaskSpecT(self):
        cdef TaskSpecT s

        s.name = self.name 

        cdef: 
            DependSpecT specT
            DependSpec spec

        for spec in self.depends:
            specT = spec.toDependSpecT()
            s.depends.push_back(specT) 

        return s

    property depends:
        def __get__(self): return self.depends
        def __set__(self, val): self.depends = val


#######################
# TaskFilter
#
@cython.internal
cdef class TaskFilter:

    cdef TaskFilterT value

    def __init__(self, **kwargs):
        if 'jobId' in kwargs:
            self.value.jobId = kwargs['jobId']
            self.value.__isset.jobId = True

        if 'layerIds' in kwargs:
            self.value.layerIds = kwargs['layerIds']
            self.value.__isset.layerIds = True

        if 'taskIds' in kwargs:
            self.value.taskIds = kwargs['taskIds']
            self.value.__isset.taskIds = True

        if 'limit' in kwargs:
            self.value.limit = kwargs['limit']
            self.value.__isset.limit = True

        if 'offset' in kwargs:
            self.value.offset = kwargs['offset']
            self.value.__isset.offset = True

        if 'lastUpdateTime' in kwargs:
            self.value.lastUpdateTime = kwargs['lastUpdateTime']
            self.value.__isset.lastUpdateTime = True

        cdef TaskState_type i
        if 'states' in kwargs:
            for i in kwargs.get('states', []):
                self.value.states.push_back(i) 
            self.value.__isset.states = True


#######################
# Task
#

cdef inline Task initTask(TaskT& t):
    cdef Task task = Task()
    task.setTask(t)
    return task


cdef class Task:
    """
    Represents an existing Task

    :var id: str 
    :var name: str 
    :var number: int 
    :var dependCount: int  
    :var order: int 
    :var startTime: long msec epoch timestamp
    :var stopTime: long msec epoch timestamp
    :var lastNodeName: str 
    :var lastLogLine: str 
    :var retries: int 
    :var cores: int 
    :var ramMb: int 
    :var rssMb: int 
    :var maxRssMb: int 
    :var cpuPerc: int 
    :var maxCpuPerc: int 
    :var progress: int 
    :var state: :data:`.TaskState`

    """
    cdef TaskT _task 

    def __repr__(self):
        return "<Task: %s>" % self.name

    cdef setTask(self, TaskT& t):
        self._task = t

    property id:
        def __get__(self): return self._task.id

    property name:
        def __get__(self): return self._task.name

    property number:
        def __get__(self): return self._task.number

    property dependCount:
        def __get__(self): return self._task.dependCount

    property order:
        def __get__(self): return self._task.order

    property startTime:
        def __get__(self): return long(self._task.startTime)

    property stopTime:
        def __get__(self): return long(self._task.stopTime)

    property lastNodeName:
        def __get__(self): return self._task.lastNodeName

    property lastLogLine:
        def __get__(self): return self._task.lastLogLine

    property retries:
        def __get__(self): return self._task.retries

    property cores:
        def __get__(self): return self._task.cores

    property ramMb:
        def __get__(self): return self._task.ramMb

    property rssMb:
        def __get__(self): return self._task.rssMb

    property maxRssMb:
        def __get__(self): return self._task.maxRssMb

    property cpuPerc:
        def __get__(self): return self._task.cpuPerc

    property maxCpuPerc:
        def __get__(self): return self._task.maxCpuPerc

    property progress:
        def __get__(self): return self._task.progress

    property state:
        def __get__(self): return self._task.state

    cpdef refresh(self):
        """
        Refresh the attributes from the server
        """
        conn().proxy().getTask(self._task, self._task.id)

    def get_log_path(self):
        """
        Get the log path for the task 

        :returns: string path 
        """
        cdef string path 
        path = get_task_log_path(self)
        return path

    def retry(self):
        """
        Retry the task 
        """
        cdef list ids = [self.id]
        retry_tasks(taskIds=ids)

    def eat(self):
        """
        Eats the task. This is different than a kill, 
        indicating that the work should simply be "completed"
        """
        cdef list ids = [self.id]
        eat_tasks(taskIds=ids)        

    def kill(self):
        """
        Kill the task 
        """
        cdef list ids = [self.id]
        kill_tasks(taskIds=ids)  

    def get_depends(self):
        """
        Get a list of depends that others have 
        on this task

        :returns: list[:class:`.Depend`]
        """
        cdef list ret = get_depends_on_task(self)
        return ret 

    def get_depends_on(self):
        """
        Get a list of depends this task has on others

        :returns: list[:class:`.Depend`]
        """
        cdef list ret = get_task_depends_on(self)
        return ret


cdef inline TaskFilterT dict_to_taskFilter(dict d):
    cdef:
        TaskFilter filt 
        TaskFilterT f

    if 'tasks' in d:
        d['taskIds'] = [p.id for p in d.pop('tasks')]

    if 'layers' in d:
        d['layerIds'] = [p.id for p in d.pop('layers')]

    if 'job' in d:
        d['jobId'] = d.pop('job').id

    filt = TaskFilter(**d)
    f = filt.value   

    return f 

cpdef inline Task get_task(Guid& taskId):
    """
    Get a task by id 

    :param taskId: str 
    :returns: :class:`.Task`
    """
    cdef:
        TaskT taskT 
        Task task 

    conn().proxy().getTask(taskT, taskId)
    task = initTask(taskT)
    return task

def get_tasks(**kwargs):
    """
    Get a list of tasks by providing various 
    filtering parameters. 

    :param job: :class:`.Job` 
    :param layers: list of :class:`.Layer` 
    :param taskIds: list of str :class:`.Task` id's 
    :param limit: int 
    :param offset: int 
    :param lastUpdateTime: long msec epoch timestamp 

    :returns: list[:class:`.Task`]
    """
    cdef:
        TaskT taskT
        vector[TaskT] tasks 
        TaskFilterT f
        list ret 

    f = dict_to_taskFilter(kwargs)

    conn().proxy().getTasks(tasks, f)
    ret = [initTask(taskT) for taskT in tasks]
    return ret

cpdef inline string get_task_log_path(Task task):
    """
    Get a log path by task 

    :param task: :class:`.Task`
    :returns: str log path
    """
    cdef string path

    if not task.id:
        return path

    try:
        conn().proxy().getTaskLogPath(path, task.id)
    except RuntimeError:
        return path

    return path

def retry_tasks(**kwargs):
    """
    Retry tasks matching various keyword filter params 

    :param job: :class:`.Job` 
    :param layer: list of :class:`.Layer` 
    :param task: list of :class:`.Task` 
    :param limit: int 
    :param offset: int 
    :param lastUpdateTime: long msec epoch timestamp 

    """
    cdef TaskFilterT f = dict_to_taskFilter(kwargs)
    conn().proxy().retryTasks(f)

def eat_tasks(**kwargs):
    """
    Eat tasks matching various keyword filter params 

    :param job: :class:`.Job` 
    :param layer: list of :class:`.Layer` 
    :param task: list of :class:`.Task` 
    :param limit: int 
    :param offset: int 
    :param lastUpdateTime: long msec epoch timestamp 
    """
    cdef TaskFilterT f = dict_to_taskFilter(kwargs)
    conn().proxy().eatTasks(f)

def kill_tasks(**kwargs):
    """
    Kill tasks matching various filter params 

    :param job: :class:`.Job` 
    :param layer: list of :class:`.Layer` 
    :param task: list of :class:`.Task` 
    :param limit: int 
    :param offset: int 
    :param lastUpdateTime: long msec epoch timestamp 
    """
    cdef TaskFilterT f = dict_to_taskFilter(kwargs)
    conn().proxy().killTasks(f)


#######################
# TaskTotals
#
cdef TaskTotals initTaskTotals(TaskTotalsT& t):
    cdef TaskTotals totals = TaskTotals()
    totals.setTaskTotals(t)
    return totals


cdef class TaskTotals:
    """
    Data structure representing counts for a task

    :var total: int
    :var succeeded: int
    :var running: int
    :var dead: int
    :var eaten: int
    :var waiting: int
    :var depend: int  
      
    """
    cdef TaskTotalsT _totals

    cdef setTaskTotals(self, TaskTotalsT& t):
        self._totals = t 

    property total:
        def __get__(self): return self._totals.totalTaskCount

    property succeeded:
        def __get__(self): return self._totals.succeededTaskCount

    property running:
        def __get__(self): return self._totals.runningTaskCount

    property dead:
        def __get__(self): return self._totals.deadTaskCount

    property eaten:
        def __get__(self): return self._totals.eatenTaskCount

    property waiting:
        def __get__(self): return self._totals.waitingTaskCount

    property depend:
        def __get__(self): return self._totals.dependTaskCount

                                
                                