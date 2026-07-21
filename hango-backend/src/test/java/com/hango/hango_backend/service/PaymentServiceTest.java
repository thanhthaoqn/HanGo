package com.hango.hango_backend.service;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Map;
import java.util.TreeMap;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import static org.junit.jupiter.api.Assertions.*;

class PaymentServiceTest {

    private final String tmnCode = "KO4NTT6S";
    private final String hashSecret = "TVPDELDQJ9TWVLMFY5BLHWUUU0ID09WE";
    private final String paymentUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
    private final String returnUrl = "http://localhost:8080/api/v1/payment/vnpay-return";

    @Test
    void testHashSignature() {
        String txnRef = tmnCode + "_1721200000000_1";
        BigDecimal amount = new BigDecimal("50000");
        long vnpAmount = amount.multiply(new BigDecimal("100")).longValue();

        String createDate = "20260717150000";
        String expireDate = "20260717151500";

        Map<String, String> vnpParams = new TreeMap<>();
        vnpParams.put("vnp_Version", "2.1.0");
        vnpParams.put("vnp_Command", "pay");
        vnpParams.put("vnp_TmnCode", tmnCode);
        vnpParams.put("vnp_Amount", String.valueOf(vnpAmount));
        vnpParams.put("vnp_CurrCode", "VND");
        vnpParams.put("vnp_TxnRef", txnRef);
        vnpParams.put("vnp_OrderInfo", "Thanh toan khoa hoc: Basic Grammar");
        vnpParams.put("vnp_OrderType", "other");
        vnpParams.put("vnp_Locale", "vn");
        vnpParams.put("vnp_ReturnUrl", returnUrl);
        vnpParams.put("vnp_IpAddr", "127.0.0.1");
        vnpParams.put("vnp_CreateDate", createDate);
        vnpParams.put("vnp_ExpireDate", expireDate);

        String hashData = buildHashData(vnpParams);
        String secureHash = hmacSHA512(hashSecret, hashData);

        System.out.println("TEST HASH DATA: " + hashData);
        System.out.println("TEST SECURE HASH: " + secureHash);

        assertNotNull(secureHash);
        assertEquals(128, secureHash.length()); // HMAC-SHA512 is 128 characters in hex
    }

    private String buildHashData(Map<String, String> params) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (entry.getValue() != null && !entry.getValue().isEmpty()) {
                if (sb.length() > 0) sb.append("&");
                sb.append(URLEncoder.encode(entry.getKey(), StandardCharsets.UTF_8))
                        .append("=")
                        .append(URLEncoder.encode(entry.getValue(), StandardCharsets.UTF_8).replaceAll("\\+", "%20"));
            }
        }
        return sb.toString();
    }

    private String hmacSHA512(String key, String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA512");
            SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA512");
            mac.init(secretKey);
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
