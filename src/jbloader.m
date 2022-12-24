#include "idownload/CFUserNotification.h"
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#include "support/libarchive.h"
#include "idownload/server.h"
#include "idownload/support.h"

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <termios.h>
#include <sys/clonefile.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <mach/mach.h>

bool deviceReady = false;

int loadDaemons(void){
  DIR *d = NULL;
  struct dirent *dir = NULL;

  if (!(d = opendir("/Library/LaunchDaemons/"))){
    printf("Failed to open dir with err=%d (%s)\n",errno,strerror(errno));
    return -1;
  }

  while ((dir = readdir(d))) { //remove all subdirs and files
      if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
          continue;
      }
      char *pp = NULL;
      asprintf(&pp,"/Library/LaunchDaemons/%s",dir->d_name);

      {
        const char *args[] = {
          "/bin/launchctl",
          "load",
          pp,
          NULL
        };
        run(args[0], args);
      }
      free(pp);
  }
  closedir(d);
  return 0;
}

int downloadAndInstallBootstrap() {
    loadDaemons();
    if (access("/jbin/post.sh", F_OK) != -1) {
        char *args[] = { "/bin/bash", "-c", "/jbin/post.sh", NULL };
        run("/bin/bash", args);
    } else {
        if (access("/.procursus_strapped", F_OK) == -1) {
            showSimpleMessage(@"hmmm", @"You don't seem to be using palera1n or something goofed very badly, iDownload is running on port 1337 for further inspection.");
        }
    }
    if (access("/.procursus_strapped", F_OK) != -1) {
        printf("palera1n: /.procursus_strapped exists, asking to enable tweaks\n");
        CFDictionaryRef dict = (__bridge CFDictionaryRef) @{
            (__bridge NSString*) kCFUserNotificationAlertTopMostKey: @1,
            (__bridge NSString*) kCFUserNotificationAlertHeaderKey: @"palera1n",
            (__bridge NSString*) kCFUserNotificationAlertMessageKey: @"Would you like to start tweaks?",
            (__bridge NSString*) kCFUserNotificationDefaultButtonTitleKey: @"Yes",
            (__bridge NSString*) kCFUserNotificationAlternateButtonTitleKey: @"No"
        };
        CFOptionFlags response = showMessage(dict);
        if (response == kCFUserNotificationDefaultResponse) {
            /*char *args[] = {"/etc/rc.d/substitute-launcher", NULL};
            run("/etc/rc.d/substitute-launcher", args);
            char *args_respring[] = { "/bin/bash", "-c", "killall -SIGTERM SpringBoard", NULL };
            run("/bin/bash", args_respring);*/
            DIR *d = NULL;
            struct dirent *dir = NULL;
            if (!(d = opendir("/etc/rc.d/"))) {
                printf("Failed to open dir with err=%d (%s)\n", errno, strerror(errno));
                return -1;
            }
            while ((dir = readdir(d))) { //remove all subdirs and files
                if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
                    continue;
                }
                char *pp = NULL;
                asprintf(&pp, "/etc/rc.d/%s", dir->d_name);

                {
                    const char *args[] = {
                        pp,
                        NULL
                    };
                    run(args[0], args);
                }
                free(pp);
            }
            closedir(d);
            char *args_respring[] = { "/bin/bash", "-c", "killall -SIGTERM SpringBoard", NULL };
            run("/bin/bash", args_respring);
        }
        return 0;
    }
    return 0;
}

SCNetworkReachabilityRef reachability;

void destroy_reachability_ref(void) {
    SCNetworkReachabilitySetCallback(reachability, nil, nil);
    SCNetworkReachabilitySetDispatchQueue(reachability, nil);
    reachability = nil;
}

void given_callback(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void *p) {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        NSLog(@"connectable");
        if (!deviceReady) {
            deviceReady = true;
            downloadAndInstallBootstrap();
        }
        destroy_reachability_ref();
    }
}

void startMonitoring(void) {
    struct sockaddr addr = {0};
    addr.sa_len = sizeof (struct sockaddr);
    addr.sa_family = AF_INET;
    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, &addr);
    if (!reachability && !deviceReady) {
        deviceReady = true;
        downloadAndInstallBootstrap();
        return;
    }

    SCNetworkReachabilityFlags existingFlags;
    // already connected
    if (SCNetworkReachabilityGetFlags(reachability, &existingFlags) && (existingFlags & kSCNetworkReachabilityFlagsReachable)) {
        deviceReady = true;
        downloadAndInstallBootstrap();
    }
    
    SCNetworkReachabilitySetCallback(reachability, given_callback, nil);
    SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_main_queue());
}

int main(int argc, char **argv){
    unlink(argv[0]);
    setvbuf(stdout, NULL, _IONBF, 0);

    printf("========================================\n");
    printf("palera1n: init!\n");
    printf("pid: %d",getpid());
    printf("uid: %d",getuid());
    printf("palera1n: goodbye!\n");
    printf("========================================\n");

    launchServer();

    startMonitoring();

    dispatch_main();

    return 0;
}