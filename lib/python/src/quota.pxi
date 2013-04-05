

#######################
# QuotaFilter
#

@cython.internal
cdef class QuotaFilter:

    cdef QuotaFilterT value

    def __init__(self, **kwargs):
        self.value.project = kwargs.get('project', [])
        self.value.cluster = kwargs.get('cluster', [])


#######################
# Quote
#

cdef inline Quota initQuota(QuotaT& q):
    cdef Quota quota = Quota()
    quota.setQuota(q)
    return quota


cdef class Quota:
    """
    TODO

    :var id: str
    :var clusterId: str :class:`.Cluster` id
    :var projectId: str :class:`.Project` id 
    :var name: str 
    :var isLocked: bool
    :var size: int 
    :var burst: int 
    :var runCores: int

    """
    cdef QuotaT _quota

    cdef setQuota(self, QuotaT& q):
        self._quota = q

    property id:
        def __get__(self): return self._quota.id

    property clusterId:
        def __get__(self): return self._quota.clusterId

    property projectId:
        def __get__(self): return self._quota.projectId

    property name:
        def __get__(self): return self._quota.name

    property isLocked:
        def __get__(self): return self._quota.isLocked

    property size:
        def __get__(self): return self._quota.size

    property burst:
        def __get__(self): return self._quota.burst

    property runCores:
        def __get__(self): return self._quota.runCores

    def set_size(self, int size):
        """ :param size: int """
        set_quota_size(self.id, size)
        self._quota.size = size

    def set_burst(self, int burst):
        """ :param burst: int """
        set_quota_burst(self.id, burst)
        self._quota.burst = burst

    def set_locked(self, bint locked):
        """
        Set the lock state

        :param locked: bool
        """
        set_quota_locked(self.id, locked)
        self._quota.isLocked = locked


def get_quota(Guid& id):
    """
    Get a quota by id 

    :param id: :class:`.Quota` id 
    :returns: :class:`.Quota`
    """
    cdef: 
        QuotaT qT
        Quota q 

    getClient().proxy().getQuota(qT, id)
    q = initQuota(qT)
    return q

def get_quotas(**kwargs):
    """
    Get quotas matching various keyword filter params

    :param project: list[:class:`.Project`]
    :param cluster: list[:class:`.Cluster`]
    :returns: list[:class:`.Quota`]
    """
    cdef:
        QuotaT qT
        vector[QuotaT] quotas 
        list ret
        QuotaFilter filter = QuotaFilter(**kwargs)
        QuotaFilterT f = filter.value

    cdef str name 
    for name in ('project', 'cluster'):
        try:
            kwargs[name] = [p.id for p in kwargs[name]]
        except:
            pass

    getClient().proxy().getQuotas(quotas, f)
    ret = [initQuota(qT) for qT in quotas]
    return ret

def create_quota(Project project,  Cluster cluster, int size, int burst):
    """
    Create a quota for a project and cluster 

    :param project: The target :class:`.Project` 
    :param cluster: The target :class:`.Cluster` 
    :param size: int 
    :param burst: int 
    :return: :class:`.Quota`
    """
    cdef:
        QuotaT qT
        Quota q 

    getClient().proxy().createQuota(qT, project.id, cluster.id, size, burst)
    q = initQuota(qT)
    return q


def set_quota_size(Cluster cluster, int size):
    """
    Set the quota size 

    :param cluster: :class:`.Quota` 
    :param size: int 
    """
    getClient().proxy().setQuotaSize(cluster.id, size)

def set_quota_burst(Cluster cluster, int burst):
    """
    Set the quota burst 

    :param cluster: :class:`.Quota` 
    :param burst: int 
    """
    getClient().proxy().setQuotaBurst(cluster.id, burst)

def set_quota_locked(Cluster cluster, bint locked):
    """
    Set the lock state of the quota

    :param cluster: :class:`.Quota` 
    :param locked: bool 
    """
    getClient().proxy().setQuotaLocked(cluster.id, locked)
