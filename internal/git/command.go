package git

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

var execCommand = exec.Command

// Git subprocess helpers
func gitCommand(glId string, glRepository string, name string, args ...string) *exec.Cmd {
	cmd := execCommand(name, args...)
	// Start the command in its own process group (nice for signalling)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	// Explicitly set the environment for the Git command
	cmd.Env = []string{
		fmt.Sprintf("HOME=%s", os.Getenv("HOME")),
		fmt.Sprintf("PATH=%s", os.Getenv("PATH")),
		fmt.Sprintf("LD_LIBRARY_PATH=%s", os.Getenv("LD_LIBRARY_PATH")),
		fmt.Sprintf("GL_ID=%s", glId),
		fmt.Sprintf("GL_PROTOCOL=http"),
	}

	if glRepository != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GL_REPOSITORY=%s", glRepository))
	}
	// If we don't do something with cmd.Stderr, Git errors will be lost
	cmd.Stderr = os.Stderr
	return cmd
}
