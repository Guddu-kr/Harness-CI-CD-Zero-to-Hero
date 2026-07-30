package com.eazydeals.helper;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class OrderIdGeneratorTest {

    @Test
    void testGenerateOrderId() {
        String orderId = OrderIdGenerator.getOrderId();
        assertNotNull(orderId);
        assertFalse(orderId.isEmpty());
        assertTrue(orderId.startsWith("ORD-"));
    }

    @Test
    void testOrderIdFormat() {
        String orderId = OrderIdGenerator.getOrderId();
        // Format: ORD-YYYYMMDDHHmmss (18 chars)
        assertEquals(18, orderId.length());
    }
}
