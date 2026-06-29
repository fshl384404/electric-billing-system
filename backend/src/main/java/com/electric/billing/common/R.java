package com.electric.billing.common;

/**
 * 统一 API 响应封装
 *
 * @param <T> data 字段的类型
 */
public class R<T> {

    private int code;
    private String message;
    private T data;

    private R() {}

    // ---- 成功 ----

    public static <T> R<T> ok(T data) {
        R<T> r = new R<>();
        r.code = 200;
        r.message = "ok";
        r.data = data;
        return r;
    }

    public static <T> R<T> ok() {
        return ok(null);
    }

    // ---- 失败 ----

    public static <T> R<T> fail(int code, String message) {
        R<T> r = new R<>();
        r.code = code;
        r.message = message;
        r.data = null;
        return r;
    }

    public static <T> R<T> fail(String message) {
        return fail(400, message);
    }

    // ---- getters (JSON 序列化需要) ----

    public int getCode() { return code; }
    public String getMessage() { return message; }
    public T getData() { return data; }
}
