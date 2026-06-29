package com.electric.billing.common;

/**
 * 业务异常 — 由 GlobalExceptionHandler 统一捕获返回给前端
 */
public class BusinessException extends RuntimeException {

    private final int code;

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
    }

    public BusinessException(String message) {
        this(400, message);
    }

    public int getCode() { return code; }
}
