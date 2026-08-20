use std::ffi::CString;

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

fn main() {
    println!("================================");
    println!("      Olive Tree Linux");
    println!("           0.0.2");
    println!("================================");

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
        std::thread::park();
    }
}
