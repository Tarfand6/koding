package machine

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"koding/klientctl/commands/cli"
	"koding/klientctl/ctlcli"
	"koding/klientctl/endpoint/machine"

	"github.com/spf13/cobra"
)

type execOptions struct{}

// NewExecCommand creates a command that can run arbitrary command on remote
// machine.
func NewExecCommand(c *cli.CLI, aliasPath ...string) *cobra.Command {
	opts := &execOptions{}

	cmd := &cobra.Command{
		Use:                "exec",
		Aliases:            []string{"e"},
		Short:              "Run a command on remote host",
		DisableFlagParsing: true,
		RunE:               execCommand(c, opts),
	}

	// Middlewares.
	cli.MultiCobraCmdMiddleware(
		cli.DaemonRequired,            // Deamon service is required.
		cli.WithMetrics(aliasPath...), // Gather statistics for this command.
		cli.MinArgs(2),                // At least two arguments are required.
	)(c, cmd)

	return cmd
}

func execCommand(c *cli.CLI, opts *execOptions) cli.CobraFuncE {
	return func(cmd *cobra.Command, args []string) (err error) {
		done := make(chan int, 1)

		execOpts := &machine.ExecOptions{
			Cmd:  args[1],
			Args: args[2:],
			Stdout: func(line string) {
				fmt.Fprintln(c.Out(), line)
			},
			Stderr: func(line string) {
				fmt.Fprintln(c.Err(), line)
			},
			Exit: func(exit int) {
				done <- exit
				close(done)
			},
		}

		if s := args[0]; strings.HasPrefix(s, "@") {
			execOpts.MachineID = s[1:]
		} else {
			if !filepath.IsAbs(s) {
				if s, err = filepath.Abs(s); err != nil {
					return err
				}
			}

			execOpts.Path = s
			if err := waitForMount(c, execOpts.Path); err != nil {
				return err
			}
		}

		pid, err := machine.Exec(execOpts)
		if err != nil {
			return err
		}

		ctlcli.CloseOnExit(ctlcli.CloseFunc(func() error {
			select {
			case <-done:
				return nil
			default:
				return machine.Kill(&machine.KillOptions{
					MachineID: execOpts.MachineID,
					Path:      execOpts.Path,
					PID:       pid,
				})
			}
		}))

		if exitCode := <-done; exitCode != 0 {
			return cli.NewError(exitCode, errors.New("command returned non zero exit code"))
		}

		return nil
	}
}

func waitForMount(c *cli.CLI, path string) (err error) {
	const timeout = 1 * time.Minute

	done := make(chan error)

	go func() {
		opts := &machine.SyncMountOptions{
			Identifier: path,
			Timeout:    timeout,
		}

		done <- machine.SyncMount(opts)
	}()

	notice := time.After(1 * time.Second)
	select {
	case err = <-done:
	case <-notice:
		fmt.Fprintf(c.Err(), "Waiting for mount... ")

		if err = <-done; err == nil {
			fmt.Fprintln(c.Err(), "ok")
		} else {
			fmt.Fprintln(c.Err(), "error")
		}
	}

	return err
}
