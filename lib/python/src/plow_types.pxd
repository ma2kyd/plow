from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.set cimport set as c_set
from libcpp.map cimport map 


cdef extern from "rpc/common_types.h" namespace "Plow":
    ctypedef string Guid
    ctypedef int Timestamp
    ctypedef map[string, string] Attrs



cdef extern from "rpc/plow_types.h" namespace "Plow":

    ctypedef enum JobState_type "Plow::JobState::type":
        JOBSTATE_INITIALIZE "Plow::JobState::INITIALIZE"
        JOBSTATE_RUNNING "Plow::JobState::RUNNING"
        JOBSTATE_FINISHED "Plow::JobState::FINISHED" 

    ctypedef enum TaskState_type "Plow::TaskState::type":
        TASKSTATE_INITIALIZE "Plow::TaskState::INITIALIZE"
        TASKSTATE_WAITING "Plow::TaskState::WAITING" 
        TASKSTATE_RUNNING "Plow::TaskState::RUNNING"
        TASKSTATE_DEAD "Plow::TaskState::DEAD"
        TASKSTATE_EATEN "Plow::TaskState::EATEN"
        TASKSTATE_DEPEND "Plow::TaskState::DEPEND"
        TASKSTATE_SUCCEEDED "Plow::TaskState::SUCCEEDED"

    ctypedef enum NodeState_type "Plow::NodeState::type":
        NODESTATE_UP "Plow::NodeState::UP"
        NODESTATE_DOWN "Plow::NodeState::DOWN"
        NODESTATE_REPAIR "Plow::NodeState::REPAIR" 

    ctypedef enum DependType_type "Plow::DependType::type":
        JOB_ON_JOB "Plow::DependType::JOB_ON_JOB"
        LAYER_ON_LAYER "Plow::DependType::LAYER_ON_LAYER"
        LAYER_ON_TASK "Plow::DependType::LAYER_ON_TASK"
        TASK_ON_LAYER "Plow::DependType::TASK_ON_LAYER"
        TASK_ON_TASK "Plow::DependType::TASK_ON_TASK"
        TASK_BY_TASK "Plow::DependType::TASK_BY_TASK"

    ctypedef enum MatcherType_type "Plow::MatcherType::type": 
        MATCH_CONTAINS "Plow::MatcherType::CONTAINS"
        MATCH_NOT_CONTAINS "Plow::MatcherType::NOT_CONTAINS"
        MATCH_IS "Plow::MatcherType::IS"
        MATCH_IS_NOT "Plow::MatcherType::IS_NOT"
        MATCH_BEGINS_WITH "Plow::MatcherType::BEGINS_WITH"
        MATCH_ENDS_WITH "Plow::MatcherType::ENDS_WITH"
    
    ctypedef enum MatcherField_type "Plow::MatcherField::type":
        MATCH_JOB_NAME "Plow::MatcherField::JOB_NAME"
        MATCH_PROJECT_CODE "Plow::MatcherField::PROJECT_CODE"
        MATCH_USER "Plow::MatcherField::USER"
        MATCH_ATTR "Plow::MatcherField::ATTR"
    
    cdef cppclass MatcherT:
        Guid id
        MatcherType_type type
        MatcherField_type field
        string value
    
    ctypedef enum ActionType_type "Plow::ActionType::type":
        ACTION_SET_FOLDER "Plow::ActionType::SET_FOLDER"
        ACTION_SET_MIN_CORES "Plow::ActionType::SET_MIN_CORES"
        ACTION_SET_MAX_CORES "Plow::ActionType::SET_MAX_CORES"
        ACTION_PAUSE "Plow::ActionType::PAUSE"
        ACTION_STOP_PROCESSING "Plow::ActionType::STOP_PROCESSING"

    cdef cppclass ActionT:
        Guid id
        ActionType_type type
        string value
    

    cdef cppclass FilterT:
        Guid id
        string name
        int order
        bint enabled
        vector[MatcherT] matchers
        vector[ActionT] actions
    

    cdef cppclass PlowException:
        int what
        string why

    cdef cppclass TaskTotalsT:
        int totalTaskCount
        int succeededTaskCount
        int runningTaskCount
        int deadTaskCount
        int eatenTaskCount
        int waitingTaskCount
        int dependTaskCount

    cdef cppclass ProjectT:
        Guid id
        string code
        string title
        bint isActive

    cdef cppclass ClusterCountsT:
        int nodes
        int upNodes
        int downNodes
        int repairNodes
        int lockedNodes
        int unlockedNodes
        int cores
        int upCores
        int downCores
        int repairCores
        int lockedCores
        int unlockedCores
        int runCores
        int idleCores                

    cdef cppclass ClusterT:
        Guid id
        string name
        c_set[string] tags
        bint isLocked
        bint isDefault
        ClusterCountsT total

    cdef cppclass QuotaT:
        Guid id
        Guid clusterId
        Guid projectId
        string name
        bint isLocked
        int size
        int burst
        int runCores

    cdef cppclass NodeSystemT:
        int physicalCores
        int logicalCores
        int totalRamMb
        int freeRamMb
        int totalSwapMb
        int freeSwapMb
        string cpuModel
        string platform
        vector[int] load        

    cdef cppclass NodeT:
        Guid id
        Guid clusterId
        string name
        string clusterName
        string ipaddr
        c_set[string] tags
        NodeState_type state
        bint locked
        Timestamp createdTime
        Timestamp updatedTime
        Timestamp bootTime
        int totalCores
        int idleCores
        int totalRamMb
        int freeRamMb
        NodeSystemT system

    cdef cppclass ProcT:
        Guid id
        Guid hostId
        string jobName
        string taskName
        int cores
        int ramMb
        int usedRamMb
        int highRamMb
        bint unbooked

    cdef cppclass JobT:
        Guid id
        Guid folderId
        string name
        string username
        int uid
        JobState_type state
        bint paused
        int minCores
        int maxCores
        int runCores
        Timestamp startTime
        Timestamp stopTime
        TaskTotalsT totals
        int maxRssMb

    cdef cppclass LayerT:
        Guid id
        string name
        string range
        int chunk
        c_set[string] tags
        bint threadable
        int minCores
        int maxCores
        int minRamMb
        int runCores
        TaskTotalsT totals
        int maxRssMb
        int maxCpuPerc

    cdef cppclass TaskT:
        Guid id
        string name
        int number
        int dependCount
        int order
        TaskState_type state
        Timestamp startTime
        Timestamp stopTime
        string lastNodeName
        string lastLogLine
        int retries
        int cores
        int ramMb
        int rssMb
        int maxRssMb
        int cpuPerc
        int maxCpuPerc
        int progress

    cdef cppclass FolderT:
        Guid id
        string name
        int minCores
        int maxCores
        int runCores
        int order
        TaskTotalsT totals
        vector[JobT] jobs

    cdef cppclass DependSpecT:
        DependType_type type
        string dependentJob
        string dependOnJob
        string dependentLayer
        string dependOnLayer
        string dependentTask
        string dependOnTask

    cdef cppclass DependT:
        Guid id        
        DependType_type type
        string dependentJob
        string dependOnJob
        string dependentLayer
        string dependOnLayer
        string dependentTask
        string dependOnTask

    cdef cppclass TaskSpecT:
        string name 
        vector[DependSpecT] depends 

    cdef struct _LayerSpecT__isset:
        bint range

    cdef cppclass LayerSpecT:
        string name
        vector[string] command
        c_set[string] tags
        string range
        int chunk
        int minCores
        int maxCores
        int minRamMb
        bint threadable
        vector[DependSpecT] depends
        vector[TaskSpecT] tasks
        _LayerSpecT__isset __isset

    cdef cppclass JobSpecT:
        string name
        string project
        bint paused
        string username
        int uid
        string logPath
        vector[LayerSpecT] layers
        vector[DependSpecT] depends

    cdef cppclass JobFilterT:
        bint matchingOnly
        vector[string] project 
        vector[string] user 
        string regex 
        vector[JobState_type] states 
        vector[Guid] jobIds
        vector[string] name 

    cdef cppclass TaskFilterT:
        Guid jobId 
        vector[Guid] layerIds
        vector[TaskState_type] states 
        vector[Guid] taskIds
        int limit 
        int offset 
        Timestamp lastUpdateTime

    cdef cppclass NodeFilterT:
        vector[Guid] hostIds
        vector[Guid] clusterIds
        string regex
        vector[string] hostnames
        vector[NodeState_type] states
        bint locked

    cdef cppclass QuotaFilterT:
        vector[Guid] project
        vector[Guid] cluster

    cdef cppclass OutputT:
        string path 
        Attrs attrs



