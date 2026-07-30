package com.eazydeals.entities;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ProductTest {

    @Test
    void testProductCreation() {
        Product product = new Product();
        product.setProductId(1);
        product.setProductName("Test Product");
        product.setProductPrice(99.99f);
        product.setProductQunatity(10);

        assertEquals(1, product.getProductId());
        assertEquals("Test Product", product.getProductName());
        assertEquals(99.99f, product.getProductPrice());
        assertEquals(10, product.getProductQunatity());
    }

    @Test
    void testProductDiscount() {
        Product product = new Product();
        product.setProductPrice(100.0f);
        product.setProductDiscount(15);

        assertEquals(15, product.getProductDiscount());
        assertEquals(85, product.getProductPriceAfterDiscount());
    }
}
