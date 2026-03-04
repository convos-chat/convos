package get

import (
	"context"
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/storage"
	"github.com/urfave/cli/v3"
)

func usersCommand() *cli.Command {
	return &cli.Command{
		Name:  "users",
		Usage: "List users",
		Action: func(ctx context.Context, cmd *cli.Command) error {
			cfg, err := config.Load()
			if err != nil {
				return err
			}

			// Initialize core with file backend
			backend := storage.NewFileBackend(cfg.Home)
			c := core.New(
				core.WithHome(cfg.Home),
				core.WithBackend(backend),
			)

			if err := c.Initialize(); err != nil {
				return fmt.Errorf("failed to initalize core: %w", err)
			}

			w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
			fmt.Fprintln(w, "EMAIL\tREGISTERED")

			for _, user := range c.Users() {
				fmt.Fprintf(w, "%s\t%s\n", user.Email(), user.Registered().Format("2006-01-02T15:04:05"))
			}

			w.Flush()
			return nil
		},
	}
}
