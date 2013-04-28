#include <arpa/inet.h>
#include <sys/socket.h>

#include <thrift/transport/TSocket.h>
#include <thrift/transport/TBufferTransports.h>
#include <thrift/protocol/TBinaryProtocol.h>

#include <boost/thread/tss.hpp>

#include <iostream>
#include <vector>

#include "client.h"

using namespace apache::thrift;
using namespace apache::thrift::protocol;
using namespace apache::thrift::transport;

PLOW_NAMESPACE_ENTER

class PlowClient::Connection
{
    public:
        Connection();
        Connection(const std::string& host, const int32_t port);
        void connect();
        void disconnect();
        void reconnect();
        RpcServiceClient proxy();        
    private:
        boost::shared_ptr<TSocket> socket;
        boost::shared_ptr<TTransport> transport;
        boost::shared_ptr<TProtocol> protocol;
        RpcServiceClient service;
};

PlowClient::Connection::Connection():
    socket(new TSocket("localhost", 11336)),
    transport(new TFramedTransport(socket)),
    protocol(new TBinaryProtocol(transport)),
    service(protocol)
{}

PlowClient::Connection::Connection(const std::string& host, const int32_t port):
    socket(new TSocket(host, port)),
    transport(new TFramedTransport(socket)),
    protocol(new TBinaryProtocol(transport)),
    service(protocol)
{}


void PlowClient::Connection::connect()
{
    transport->open();
}

void PlowClient::Connection::disconnect()
{
    transport->close();
}

void PlowClient::Connection::reconnect()
{
    transport->close();
    transport->open();
}

RpcServiceClient PlowClient::Connection::proxy()
{
    return service;
}

PlowClient::PlowClient():
    m_conn(new PlowClient::Connection)
{
    m_conn->connect();
}

PlowClient::PlowClient(const std::string& host, const int32_t port):
    m_conn(new PlowClient::Connection(host, port))
{
    m_conn->connect();
}

PlowClient::~PlowClient()
{
    m_conn->disconnect();
}

RpcServiceClient PlowClient::proxy()
{
    return m_conn->proxy();
}

void PlowClient::reconnect()
{
    m_conn->reconnect();
}

PlowClient* getClient(const bool reset)
{
    return _getClient("localhost", 11336, reset);
}

PlowClient* getClient(const std::string& host, const int32_t port, const bool reset)
{
    return _getClient(host, port, reset);
}

PlowClient* _getClient(const std::string& host, const int32_t port, bool reset)
{
    static boost::thread_specific_ptr<PlowClient> instance;
    if(reset || !instance.get())
    {
        instance.reset(new PlowClient(host, port));
    }
    return instance.get();
}

PLOW_NAMESPACE_EXIT




