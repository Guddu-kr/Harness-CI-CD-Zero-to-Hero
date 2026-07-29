package com.eazydeals.helper;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class OrderIdGeneratorTest {

    @Test
    void testGenerateOrderId() {
        String orderId = OrderIdGenerator.getOrderId();
        assertNotNull(orderId);
        assertFalse(orderId.isEmpty());
    }

    @Test
    void testOrderIdUniqueness() {
        String orderId1 = OrderIdGenerator.getOrderId();
        String orderId2 = OrderIdGenerator.getOrderId();
        assertNotEquals(orderId1, orderId2);
    }
}
