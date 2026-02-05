package recoveraccount

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"

	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/storage"
	"github.com/urfave/cli/v3"
)

var (
	errEmailRequired = errors.New("email is required")
	errUserNotFound  = errors.New("user not found")
)

func passwordCommand() *cli.Command {
	return &cli.Command{
		Name:  "password",
		Usage: "Reset password for a user",
		Arguments: []cli.Argument{
			&cli.StringArg{Name: "email"},
		},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "password",
				Aliases: []string{"p"},
				Usage:   "New password (generated if not set)",
			},
		},
		Action: func(ctx context.Context, cmd *cli.Command) error {
			if cmd.NArg() < 1 {
				return errEmailRequired
			}
			email := cmd.Args().Get(0)

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

			if err := c.Start(); err != nil {
				return fmt.Errorf("failed to start core: %w", err)
			}

			user := c.GetUser(email)
			if user == nil {
				return fmt.Errorf("%w: %s", errUserNotFound, email)
			}

			password := cmd.String("password")
			if password == "" {
				b := make([]byte, 12)
				_, err := rand.Read(b)
				if err != nil {
					return fmt.Errorf("failed to generate password: %w", err)
				}
				password = base64.StdEncoding.EncodeToString(b)
			}

			if err := user.SetPassword(password); err != nil {
				return fmt.Errorf("failed to set password: %w", err)
			}

			if err := user.Save(); err != nil {
				return fmt.Errorf("failed to save user: %w", err)
			}

			fmt.Printf("Updated password for %s: %s\n", email, password)
			return nil
		},
	}
}
