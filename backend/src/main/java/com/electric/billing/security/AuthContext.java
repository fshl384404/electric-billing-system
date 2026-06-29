package com.electric.billing.security;

/**
 * 当前登录用户上下文 — 基于 ThreadLocal
 */
public class AuthContext {

    private static final ThreadLocal<Long> USER_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> USERNAME = new ThreadLocal<>();
    private static final ThreadLocal<String> ROLE = new ThreadLocal<>();

    public static void set(Long userId, String username, String role) {
        USER_ID.set(userId);
        USERNAME.set(username);
        ROLE.set(role);
    }

    public static Long getCurrentUserId() {
        return USER_ID.get();
    }

    public static String getCurrentUsername() {
        return USERNAME.get();
    }

    public static String getCurrentRole() {
        return ROLE.get();
    }

    public static boolean isAdmin() {
        return "ADMIN".equals(ROLE.get());
    }

    public static boolean isCollector() {
        return "COLLECTOR".equals(ROLE.get());
    }

    public static boolean isResident() {
        return "RESIDENT".equals(ROLE.get());
    }

    public static void clear() {
        USER_ID.remove();
        USERNAME.remove();
        ROLE.remove();
    }
}
