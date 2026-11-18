use std::ffi::CString;
use std::sync::atomic::{AtomicI32, Ordering};

static SIG_RECEIVED: AtomicI32 = AtomicI32::new(0);

enum ShutdownAction {
    Halt,
    PowerOff,
    Reboot,
}

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

extern "C" fn handle_sigreceived(signal: libc::c_int) {
    SIG_RECEIVED.store(signal, Ordering::SeqCst)
}

fn shutdown(shell_pid: libc::pid_t, action: ShutdownAction) -> ! {
    println!("[olive-init] shutdown requested");
    println!("[olive-init] stopping shell");

    let kill_result = unsafe {
        libc::kill(shell_pid, libc::SIGKILL)
    };

    if kill_result < 0 {
        let error = std::io::Error::last_os_error();

        if error.raw_os_error() != Some(libc::ESRCH) {
            eprintln!("[olive-init] failed to terminate shell: {}", error);
        }
    }

       println!("[olive-init] waiting for remaining processes");

    loop {
        let mut status: libc::c_int = 0;

        let waited_pid = unsafe {
            libc::waitpid(-1, &mut status, 0)
        };

        if waited_pid > 0 {
            if libc::WIFEXITED(status) {
                println!(
                    "[olive-init] process {} exited with code {}",
                    waited_pid,
                    libc::WEXITSTATUS(status)
                );
            } else if libc::WIFSIGNALED(status) {
                println!(
                    "[olive-init] process {} terminated by signal {}",
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

        eprintln!("[olive-init] waitpid during shutdown failed: {}", error);
        break;
    }

    println!("[olive-init] all userspace processes stopped");
    println!("[olive-init] syncing filesystems");

    unsafe {
        libc::sync();
    }

    unmount_persist();
    
    println!("[olive-init] final filesystem sync");

    unsafe {
        libc::sync();
    }


    let reboot_cmd = match action {
	ShutdownAction::Halt => {
	    println!("[olive-init] halting system");
	    libc::RB_HALT_SYSTEM
	}
	ShutdownAction::PowerOff => {
	    println!("[olive-init] powering off system");
	    libc::RB_POWER_OFF
	}
	ShutdownAction::Reboot => {
	    println!("[olive-init] rebooting system");
	    libc::RB_AUTOBOOT
	}
    };    

    unsafe {
        libc::reboot(reboot_cmd);
    }

    panic!(
        "[olive-init] shutdown failed: {}",
        std::io::Error::last_os_error()
    );
}

fn mount_persist() {
    const PERSIST_DIR: &str = "/persist";
    const PERSIST_DEVICE: &str = "/dev/sda1";

    println!("[olive-init] mounting persistance");

    if let Err(error) = std::fs::create_dir_all(PERSIST_DIR) {
       eprintln!(
           "[olive-init] warning: could not create {PERSIST_DIR}: {error}"
       );
       return;
    }

    let source = std::ffi::CString::new(PERSIST_DEVICE).unwrap();
    let target = std::ffi::CString::new(PERSIST_DIR).unwrap();
    let filesystem = std::ffi::CString::new("ext2").unwrap();

    let result = unsafe {
        libc::mount(
            source.as_ptr(),
            target.as_ptr(),
            filesystem.as_ptr(),
            0,
            std::ptr::null(),
         )
    };

    if result == 0 {
        println!("[olive-init] persistance mounted at {PERSIST_DIR}");
    } else {
        eprintln!(
            "[olive-init] warning: failed to mount persistance: {}",
            std::io::Error::last_os_error()
        )
    }
}

fn unmount_persist() {
    let target = CString::new("/persist").unwrap();

    println!("[olive-init] unmounting persistance");

    let result = unsafe { 
        libc::umount(target.as_ptr())
    };

    if result == 0 {
        println!("[olive-init] persistance unmounted cleanly");
        return;
    }

    let error = std::io::Error::last_os_error();

    if error.raw_os_error() == Some(libc::EINVAL) {
        println!("[olive-init] persistance was not mounted");
        return;
    }

    eprintln!(
        "[olive-init] failed to mount persistance: {}",
        error
    );
}
fn main() {
    println!("================================");
    println!("      Olive Tree Linux");
    println!("           0.2.3");
    println!("================================");

    unsafe {
        let mut handler_config: libc::sigaction = std::mem::zeroed();
        
        handler_config.sa_sigaction =
            handle_sigreceived as *const () as libc::sighandler_t;

        libc::sigemptyset(&mut handler_config.sa_mask);

        for sig in [libc::SIGUSR1, libc::SIGUSR2, libc::SIGTERM] {
            if libc::sigaction(
                sig,
                &handler_config,
                std::ptr::null_mut(),
            ) < 0 {
                panic!(
                 "sigaction for {sig} failed: {}",
                 std::io::Error::last_os_error()
            );
            }
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
    mount_persist();

    println!("[olive-init] creating child process");

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
            "[olive-init] execv /bin/sh failed: {}",
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
                    "[olive-init] process {} exited with code {}",
                    waited_pid,
                    exit_code
                );
            } else if libc::WIFSIGNALED(status) {
               let signal = libc::WTERMSIG(status);
                println!(
                    "[olive-init] process {} terminated by signal {}",
                    waited_pid,
                    signal
                );
            }
        } else {
            let error = std::io::Error::last_os_error();

            if error.raw_os_error() == Some(libc::ECHILD) {
                println!("[olive-init] no child processes remaining");
                break;
            }

            if error.raw_os_error() == Some(libc::EINTR) {
                let sig_rec = SIG_RECEIVED.swap(0, Ordering::SeqCst);
		
		let action = match sig_rec {
			libc::SIGUSR1 => ShutdownAction::Halt,
			libc::SIGUSR2 => ShutdownAction::PowerOff,
			libc::SIGTERM => ShutdownAction::Reboot,
			_ => continue,
		};

		shutdown(pid, action)
	     }
		
            panic!("waitpid failed: {}", error);
        }
    }

    println!("[olive-init] shell exited");

    shutdown(pid, ShutdownAction::PowerOff);
}
