package com.qujianma.qujianma;

interface IShizukuKeepAliveService {
    boolean ensureAccessibilityEnabled(String packageName, String serviceComponent) = 1;
    void destroy() = 16777114;
}
