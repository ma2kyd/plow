Plow
====

Plow is render farm management software specifically designed for VFX workloads.

There are currently no official releases of Plow, so the following instructions will get
you started with a source checkout of Plow.  Please report any issues on
our Google code page.

Google Project home: http://code.google.com/p/plow/

Developent Environment Requirements
===================================

Server
------

* Postgresql 9.2

http://www.postgresql.org

* Java7

http://www.java.com/en/download/index.jsp

Client and Tools
----------------

* Python 2.6 or 2.7
* Qt 4.7+
* Thrift 0.9
* Boost
* Cmake

Installing the Server
=====================

The plow server acts as the central brain for your render farm.  It contains the plow
dispatcher and exposes a thrift API for interacting with jobs.

For convinience a binary distributation of the server can be found here:
http://code.google.com/p/plow/downloads

Setting up Postgres
-------------------

Install Postgresql 9.2.

Create a database called 'plow' for user 'plow'.
set password: abcdefg123
(This is configurable in the plow-server-bin/resources/plow.properties )

Execute the sql file:

    $ psql -h <hostname> -U <username> -d <dbname> -f ddl/plow-schema.sql
    $ psql -h <hostname> -U <username> -d <dbname> -f ddl/plow-triggers.sql
    $ psql -h <hostname> -U <username> -d <dbname> -f ddl/plow-functions.sql
    $ psql -h <hostname> -U <username> -d <dbname> -f ddl/plow-data.sql


Generating the Thrift Bindings
------------------------------

Plow uses Apache Thrift for client/server communication.  You can download thrift from here.

http://thrift.apache.org

To generate the bindings code for all languages:

    > cd lib/thrift
    > ./generate-sources.sh

You can skip the next step if your using the plow server binary release.

For Java, you then need to compile these sources and install the plow-bindings JAR into your local maven repo.  Running
mvn intall does this for you.

    > cd lib/java
    > mvn install


Install the Python Library and Tools
====================================

The latest Python client can be install from the source checkout using the following:

(first make sure to generate the thift bindings)

```
> cd lib/python
> python setup.py install
```

You will still want to manually copy the `etc/*.cfg` files to either `/usr/local/etc/plow/` or `~/.plow/`


Compiling the C++ Library
-------------------------

    $ cd lib/cpp/build
    $ cmake ../
    $ make


Running the Tools
=================

First thing you need to do if you are using a git checkout of plow is setup your environment.

    $ export PLOW_ROOT="/path/to/plow/checkout"
    $ export PYTHONPATH="/path/to/plow/checkout/lib/python"
    $ export PATH="$PATH:$PLOW_ROOT/bin"

Starting the Server
-------------------

    > tar -zxvf plow-server-bin-0.1-alpha.tar.gz
    > cd plow-server-bin-0.1-alpha
    > ./plow.sh

    If Java7 is not in your path, plow will pick it up if the JAVA_HOME env var is set.  On Mac, this will
    be something like this:

    > export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.7.0_10.jdk/Contents/Home"
    > ./plow.sh


Running the Render Node Daemon
------------------------------

Currently supported on Mac/Linux

If you have installed the client tools using the `setup.py`, then you should now have `rndaemon` command in your path:

    $ rndaemon

Otherwise, you can launch rndaemon from your git checkout (after setting your environment variables and ensuring you have all python dependencies installed).

    $ bin/rndaemon

The daemon will first look for an optional config file explicitely set with the `PLOW_RNDAEMON_CFG` environment variable:

    $ export PLOW_RNDAEMON_CFG="/path/to/etc/plow/rndaemon.cfg"

Otherwise, it will search for: `/usr/local/etc/rndaemon.cfg`, `$PLOW_ROOT/etc/plow/rndaemon.cfg`, and then `~/.plow/rndaemon.cfg`

Launching the Test Job
----------------------

Plow includes the blueprint module for job launching and description.

    > plowrun $PLOW_ROOT/share/blueprint/examples/script.bp 1-100 -debug

