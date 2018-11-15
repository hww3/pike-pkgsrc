$NetBSD$

--- src/smartlink.c.orig	2015-12-31 19:50:31.000000000 +0000
+++ src/smartlink.c
@@ -8,7 +8,7 @@
  * smartlink - A smarter linker.
  * Based on the /bin/sh script smartlink 1.23.
  *
- * Henrik Grubbström 1999-03-04
+ * Henrik Grubbstrï¿½m 1999-03-04
  */
 
 #ifdef __MINGW32__
@@ -96,6 +96,13 @@ int main(int argc, char **argv)
   char *full_rpath;
   char **new_argv;
   char *ld_lib_path;
+  
+#if defined(USE_Wl_rpath_darwin)
+  char **darwin_argv;
+  char * darwin_arg;
+  int darwin_argc = 0;
+#endif
+
   int new_argc;
   int n32 = 0;
   int linking = 1;	/* Maybe */
@@ -157,6 +164,14 @@ int main(int argc, char **argv)
   if (!(new_argv = malloc(sizeof(char *)*(argc + 150)))) {
     fatal("Out of memory (5)!\n");
   }
+  
+#if defined(USE_Wl_rpath_darwin)
+  /* 50 rpath args should be enough... */
+    if (!(darwin_argv = malloc(sizeof(char *)*(argc + 50)))) {
+    fatal("Out of memory (6)!\n");
+  }
+#endif
+
 
   new_argc = 0;
   full_rpath = rpath;
@@ -192,21 +207,41 @@ int main(int argc, char **argv)
 	      new_argv[new_argc++] = argv[i];
 	      new_argv[new_argc++] = argv[i+1];
 	    }
+            i++;
 	  }
 	} else {
 	  if (add_path(lpath, argv[i]+2)) {
 	    new_argv[new_argc++] = argv[i];
 	  }
 	}
+        continue;
       } else if (argv[i][1] == 'R') {
 	/* -R */
 	if (!argv[i][2]) {
 	  i++;
 	  if (i < argc) {
 	    rpath_in_use |= add_path(rpath, argv[i]);
+#if defined(USE_Wl_rpath_darwin)
+           if(!(darwin_arg = malloc(sizeof(char *) * (strlen(argv[i]) + 12)))) /*  path lengh plus length of -Wl,-rpath, */
+           {
+             fatal("Out of memory (7)!\n");
+           }
+           darwin_arg = strcat(darwin_arg, "-Wl,-rpath,");
+           darwin_arg = strcat(darwin_arg, argv[i]);
+           darwin_argv[darwin_argc++] = darwin_arg;
+#endif
 	  }
 	} else {
 	  rpath_in_use |= add_path(rpath, argv[i] + 2);
+#if defined(USE_Wl_rpath_darwin)
+          if(!(darwin_arg = malloc(sizeof(char *) * (strlen(argv[i] + 2) + 12)))) /*  path lengh plus length of -Wl,-rpath, */
+          {
+            fatal("Out of memory (7.5)!\n");
+          }
+          darwin_arg = strcat(darwin_arg, "-Wl,-rpath,");
+          darwin_arg = strcat(darwin_arg, argv[i] + 2);
+          darwin_argv[darwin_argc++] = darwin_arg;
+#endif
 	}
 	continue;
       } else if ((argv[i][1] == 'n') && (argv[i][2] == '3') &&
@@ -344,6 +379,9 @@ int main(int argc, char **argv)
     }
 #elif defined(USE_R) || defined(USE_Wl_R)
     new_argv[new_argc++] = full_rpath;
+#elif defined(USE_Wl_rpath_darwin)
+   for(int darwin_argc_i = 0; darwin_argc_i < darwin_argc; darwin_argc_i++)
+    new_argv[new_argc++] = darwin_argv[darwin_argc_i];
 #elif defined(USE_LD_LIBRARY_PATH)
     if (putenv(full_rpath)) {
       fatal("Out of memory (6)!");
