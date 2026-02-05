package recoveraccount

import (
	"github.com/urfave/cli/v3"
)

func Command() *cli.Command {
	return &cli.Command{
		Name:  "recover",
		Usage: "Recover data or reset passwords",
		Commands: []*cli.Command{
			passwordCommand(),
		},
	}
}
