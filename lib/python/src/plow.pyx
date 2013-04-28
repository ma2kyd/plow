cimport cython
from plow_types cimport *
from client cimport getClient, PlowClient

include "project.pxi"
include "folder.pxi"
include "job.pxi"
include "layer.pxi"
include "task.pxi"
include "node.pxi"
include "cluster.pxi"
include "filter.pxi"
include "quota.pxi"
include "depend.pxi"

#
# Python imports
#

# from datetime import datetime
import uuid


HOST = "localhost"
PORT = 11336

cdef inline PlowClient* conn(bint reset=0) except NULL:
    return getClient(HOST, PORT, reset)


cpdef inline reconnect():
    """
    Re-establish the connection to the Plow server
    """
    getClient(HOST, PORT, True).reconnect()


def set_host(str host="localhost", int port=11336):
    """
    Set the host and port of the Plow server

    :param host: str = "localhost"
    :param port: int = 11336
    """
    global HOST, PORT
    HOST = host
    PORT = port
    reconnect()    


def get_host():
    """
    Get the current host and port of the Plow server

    :returns: (str host, int port)
    """
    return HOST, PORT


def is_uuid(str identifier):
    """
    Test if a string is a valid UUID 

    :param identifier: string to test 
    :type identifier: str
    :returns: bool - True if valid UUID
    """
    cdef bint ret = False
    try:
        uuid.UUID(identifier)
        ret = True
    except ValueError:
        pass

    return ret 


def get_plow_time():
    """
    Get the Plow server time in msec since the epoch 

    :returns: long - msec since epoch
    """
    cdef long epoch
    epoch = conn().proxy().getPlowTime()
    # plowTime = datetime.fromtimestamp(epoch / 1000)
    # return plowTime
    return long(epoch)




