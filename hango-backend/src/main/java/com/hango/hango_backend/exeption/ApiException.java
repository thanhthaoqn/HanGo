package com.hango.hango_backend.exeption;

import org.springframework.http.HttpStatus;

/**
 * Exception nghiệp vụ dùng chung. Mang theo HttpStatus để GlobalExceptionHandler
 * trả đúng status code cho client (Flutter) mà không cần if/else dài dòng ở từng controller.
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;

    public ApiException(String message, HttpStatus status) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}