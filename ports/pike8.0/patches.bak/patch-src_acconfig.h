$NetBSD$

--- src/acconfig.h.orig	2015-12-31 19:50:31.000000000 +0000
+++ src/acconfig.h
@@ -111,6 +111,9 @@
 /* Define this if your ld uses -rpath, but your cc wants -Wl,-rpath, */
 #undef USE_Wl
 
+/* Define this if your ld uses Darwin-style -rpath, but your cc wants -Wl,-rpath, */
+#undef USE_Wl_rpath_darwin
+
 /* Define this if your ld uses -R, but your cc wants -Wl,-R */
 #undef USE_Wl_R
 
