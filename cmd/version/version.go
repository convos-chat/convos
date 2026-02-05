package version

import (
	"context"
	"fmt"

	"github.com/convos-chat/convos/pkg/version"
	"github.com/urfave/cli/v3"
)

func Command() *cli.Command {
	return &cli.Command{
		Name:  "version",
		Usage: "Show version information",
		Action: func(ctx context.Context, cmd *cli.Command) error {
			fmt.Println(version.Version)
			return nil
		},
	}
}
