package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	goahttp "goa.design/goa/v3/http"

	clusteradmin "orce-clusteradmin/gen/clusteradmin"
	clusteradminserver "orce-clusteradmin/gen/http/clusteradmin/server"
	"orce-clusteradmin/internal/config"
	"orce-clusteradmin/internal/service"
)

func main() {
	configPath := flag.String("config", "", "Path to config.yaml; defaults to ORCE_CONFIG or ./config.yaml")
	flag.Parse()

	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		panic(err)
	}

	svc := service.New(cfg)
	endpoints := clusteradmin.NewEndpoints(svc)
	mux := goahttp.NewMuxer()
	server := clusteradminserver.New(endpoints, mux, goahttp.RequestDecoder, goahttp.ResponseEncoder, nil, nil)
	clusteradminserver.Mount(mux, server)

	httpServer := &http.Server{Addr: cfg.Server.Address, Handler: mux}
	errCh := make(chan error, 1)
	go func() {
		fmt.Printf("orce-clusteradmin listening on %s\n", cfg.Server.Address)
		errCh <- httpServer.ListenAndServe()
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	select {
	case err := <-errCh:
		if err != nil && err != http.ErrServerClosed {
			panic(err)
		}
	case <-sigCh:
		_ = httpServer.Shutdown(context.Background())
	}
}
