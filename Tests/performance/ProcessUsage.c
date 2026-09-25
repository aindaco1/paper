// Developer-only process counters; never linked into Paper.
#include <libproc.h>
#include <sys/resource.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 3) return 64;
    int pid = atoi(argv[1]), seconds = atoi(argv[2]);
    if (pid <= 0 || seconds < 1 || seconds > 3600) return 64;
    uint64_t start = 0;
    struct timespec began, now;
    clock_gettime(CLOCK_MONOTONIC, &began);
    for (;;) {
        struct rusage_info_v6 r = {0};
        if (proc_pid_rusage(pid, RUSAGE_INFO_V6, (rusage_info_t *)&r)) { perror("proc_pid_rusage"); return 1; }
        if (start && start != r.ri_proc_start_abstime) return 2;
        start = r.ri_proc_start_abstime;
        clock_gettime(CLOCK_MONOTONIC, &now);
        double elapsed = now.tv_sec - began.tv_sec + (now.tv_nsec - began.tv_nsec)/1e9;
        printf("{\"elapsed\":%.3f,\"userNs\":%llu,\"systemNs\":%llu,\"idleWakeups\":%llu,\"interruptWakeups\":%llu,\"physicalBytes\":%llu,\"readBytes\":%llu,\"writeBytes\":%llu,\"energyNanojoules\":%llu}\n", elapsed,
            r.ri_user_time,r.ri_system_time,r.ri_pkg_idle_wkups,r.ri_interrupt_wkups,r.ri_phys_footprint,r.ri_diskio_bytesread,r.ri_diskio_byteswritten,r.ri_energy_nj);
        fflush(stdout);
        if (elapsed >= seconds) break;
        sleep(5);
    }
}
