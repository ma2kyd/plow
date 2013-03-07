package com.breakersoft.plow.test.thrift;

import static org.junit.Assert.*;
import javax.annotation.Resource;

import org.apache.thrift.TException;
import org.junit.Test;

import com.breakersoft.plow.test.AbstractTest;
import com.breakersoft.plow.thrift.ClusterT;
import com.breakersoft.plow.thrift.PlowException;
import com.breakersoft.plow.thrift.RpcService;
import com.google.common.collect.Sets;

public class RpcThriftServiceTests extends AbstractTest {

    @Resource
    RpcService.Iface rpcService;

    @Test
    public void testLaunch() throws PlowException, TException {
        rpcService.launch(getTestJobSpec());
    }

    @Test
    public void testCreateCluster() throws PlowException, TException {
    	ClusterT cluster = rpcService.createCluster(
    			"bing", Sets.newHashSet("bang", "bong"));
    	assertEquals("bing", cluster.name);
    	assertTrue(cluster.tags.contains("bang"));
    	assertTrue(cluster.tags.contains("bong"));
    }
}
