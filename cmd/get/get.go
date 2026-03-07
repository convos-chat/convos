// Package get implements the "get" command for the Convos CLI tool.
package get

import (
	"github.com/urfave/cli/v3"
)

func Command() *cli.Command {
	return &cli.Command{
		Name:  "get",
		Usage: "Get information about Convos resources",
		Commands: []*cli.Command{
			usersCommand(),
		},
	}
}
