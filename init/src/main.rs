use std::ffi::CString;
use std::sync::atomic::{AtomicBool, Ordering};

static SIGTERM_RECEIVED: AtomicBool = AtomicBool::new(false);

fn mount_fs(source: &str, target: &str, filesystem: &str) {
    let source = CString::new(source).unwrap();
    let target = CString::new(target).unwrap();
    let filesystem = CString::new(filesystem).unwrap();

    let result = unsafe {
        libc::mount(
            source.as_ptr(),
            target.as_ptr(),
            filesystem.as_ptr(),
            0,
            std::ptr::null(),
        )
    };

    if result != 0 {
        eprintln!(
            "Failed to mount {} on {}: {}",
            filesystem.to_string_lossy(),
            target.to_string_lossy(),
            std::io::Error::last_os_error()
        );
    } else {
        println!(
            "Mounted {} on {}",
            filesystem.to_string_lossy(),
            target.to_string_lossy()
        );
    }
}

fn create_child() -> libc::pid_t {
    let pid = unsafe {
        libc::fork()
    };

    if pid < 0 {
        panic!(
            "fork failed: {}",
            std::io::Error::last_os_error()
        );
    }

    pid
}

extern "C" fn handle_sigterm(_signal: libc::c_int) {
    SIGTERM_RECEIVED.store(true, Ordering::SeqCst);
}

fn shutdown(shell_pid: libc::pid_t) -> ! {
    println!("Olive init: shutdown requested");
    println!("Olive init: stopping shell");

    let kill_result = unsafe {
        libc::kill(shell_pid, libc::SIGKILL)
    };

    if kill_result < 0 {
        let error = std::io::Error::last_os_error();

        if error.raw_os_error() != Some(libc::ESRCH) {
            eprintln!("Olive init: failed to terminate shell: {}", error);
        }
    }

       println!("Olive init: waiting for remaining processes");

    loop {
        let mut status: libc::c_int = 0;

        let waited_pid = unsafe {
            libc::waitpid(-1, &mut status, 0)
        };

        if waited_pid > 0 {
            if libc::WIFEXITED(status) {
                println!(
                    "Olive init: process {} exited with code {}",
                    waited_pid,
                    libc::WEXITSTATUS(status)
                );
            } else if libc::WIFSIGNALED(status) {
                println!(
                    "Olive init: process {} terminated by signal {}",
                    waited_pid,
                    libc::WTERMSIG(status)
                );
            }

            continue;
        }

        let error = std::io::Error::last_os_error();

        if error.raw_os_error() == Some(libc::ECHILD) {
            break;
        }

        if error.raw_os_error() == Some(libc::EINTR) {
            continue;
        }

        eprintln!("Olive init: waitpid during shutdown failed: {}", error);
        break;
    }

    println!("Olive init: all userspace processes stopped");
    println!("Olive init: syncing filesystems");

    unsafe {
        libc::sync();
    }

    println!("Olive init: powering off");

    unsafe {
        libc::reboot(libc::RB_POWER_OFF);
    }

    panic!(
        "Olive init: power off failed: {}",
        std::io::Error::last_os_error()
    );
}

fn main() {
    println!("================================");
    println!("      Olive Tree Linux");
    println!("           0.1.0");
    println!("================================");

    unsafe {
        let mut action: libc::sigaction = std::mem::zeroed();
        
        action.sa_sigaction =
            handle_sigterm as *const () as libc::sighandler_t;

        libc::sigemptyset(&mut action.sa_mask);

        if libc::sigaction(
            libc::SIGTERM,
            &action,
            std::ptr::null_mut(),
        ) < 0 {
            panic!(
             "sigaction failed: {}",
             std::io::Error::last_os_error()
        );
        }
    }

    // Set hostname
    let hostname = b"olive-tree";

    unsafe {
        libc::sethostname(
            hostname.as_ptr() as *const libc::c_char,
            hostname.len(),
        );
    }

    // Mount kernel virtual filesystems
    mount_fs("proc", "/proc", "proc");
    mount_fs("sysfs", "/sys", "sysfs");
    mount_fs("devtmpfs", "/dev", "devtmpfs");

    println!("Olive init: creating child process");

    let pid = create_child();
    
    if pid == 0 {
        println!("Hello from Olive Tree child!");

        let session_id = unsafe {
            libc::setsid()
        };

        if session_id < 0 {
            panic!(
                "setsid failed: {}",
                std::io::Error::last_os_error()
            );
        }

        println!("Child became session leader SID {}", session_id);
        let console = CString::new("/dev/console").unwrap();

        let console_fd = unsafe {
            libc::open(console.as_ptr(), libc::O_RDWR)
        };

        if console_fd < 0 {
            panic!(
                "Failed to open /dev/console: {}",
                std::io::Error::last_os_error()
            );
        }

        println!("Opened /dev/console as file descriptor {}", console_fd);

        let ioctl_result = unsafe {
            libc::ioctl(console_fd, libc::TIOCSCTTY as _, 0)
        };

        if ioctl_result < 0 {
            panic!(
                "Failed to acquire controlling terminal: {}",
                std::io::Error::last_os_error()
            );
        }

        println!("Acquired /dev/console as controlling terminal");

        if unsafe { libc::dup2(console_fd, 0) } < 0 {
            panic!(
                "dup2 stdin failed: {}",
                std::io::Error::last_os_error()
            );
        }

        if unsafe { libc::dup2(console_fd, 1) } < 0 {
            panic!(
                "dup2 stdout failed: {}",
                std::io::Error::last_os_error()
            );
        }

        if unsafe { libc::dup2(console_fd, 2) } < 0 {
            panic!(
                "dup2 stderr failed: {}",
                std::io::Error::last_os_error()
            );
        }

        if console_fd > 2 {
            unsafe {
                libc::close(console_fd);
            }
        }

        println!("Console connected to stdin, stdout and stderr");

        let shell = CString::new("/bin/sh").unwrap();

        let argv = [
            shell.as_ptr(),
            std::ptr::null(),
        ];

        unsafe {
            libc::execv(shell.as_ptr(), argv.as_ptr());
        }

        panic!(
            "execv /bin/sh failed: {}",
            std::io::Error::last_os_error()
        );
    } else {
        println!("Hello from Olive Tree PID1!");
        println!("Created child with PID {}", pid);
    }

    // PID 1 must not exit.
    loop {
        let mut status: libc::c_int = 0;

        let waited_pid = unsafe {
            libc::waitpid(-1, &mut status, 0)
        };

        if waited_pid > 0 {
            if libc::WIFEXITED(status) {
                let exit_code = libc::WEXITSTATUS(status);
             
                println!(
                    "Olive init: process {} exited with code {}",
                    waited_pid,
                    exit_code
                );
            } else if libc::WIFSIGNALED(status) {
               let signal = libc::WTERMSIG(status);
                println!(
                    "Olive init: process {} terminated by signal {}",
                    waited_pid,
                    signal
                );
            }
        } else {
            let error = std::io::Error::last_os_error();

            if error.raw_os_error() == Some(libc::ECHILD) {
                println!("Olive init: no child processes remaining");
                break;
            }

            if error.raw_os_error() == Some(libc::EINTR) {
                if SIGTERM_RECEIVED.swap(false, Ordering::SeqCst) {
                    println!("Olive init: received SIGTERM");
                    shutdown(pid);
                }
                
                continue;
            }


            panic!("waitpid failed: {}", error);
        }
    }

    println!("Olive init: shell exited");
    shutdown(pid);
}
