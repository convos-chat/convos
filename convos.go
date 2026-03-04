package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/convos-chat/convos/cmd/daemon"
	"github.com/convos-chat/convos/cmd/get"
	recoveraccount "github.com/convos-chat/convos/cmd/recover"
	"github.com/convos-chat/convos/cmd/version"
	convosVersion "github.com/convos-chat/convos/pkg/version"
	"github.com/urfave/cli/v3"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, nil)))
	run(os.Args)
}

func run(args []string) {
	convos := &cli.Command{
		Name:                  "convos",
		Version:               convosVersion.Version,
		EnableShellCompletion: true,
		Commands: []*cli.Command{
			daemon.Command(),
			get.Command(),
			recoveraccount.Command(),
			version.Command(),
		},
	}

	err := convos.Run(context.Background(), args)
	if err != nil {
		slog.Error("Command failed", "error", err)
		os.Exit(1)
	}
}
