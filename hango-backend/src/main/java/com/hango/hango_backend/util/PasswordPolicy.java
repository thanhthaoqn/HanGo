package com.hango.hango_backend.util;

public final class PasswordPolicy {
    public static final String PATTERN = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z0-9]).{8,64}$";
    public static final String MESSAGE = "Password must be 8-64 characters and include an uppercase letter, a lowercase letter, a number, and a special character.";

    private PasswordPolicy() {
    }
}
