package config

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/ilyakaznacheev/cleanenv"
)

type Config[BinConfigT any] struct {
	Env           string `yaml:"-" json:"-"`
	Name          string `yaml:"name" json:"name"`
	PrettyLog     bool   `yaml:"prettyLog" json:"prettyLog"`
	LogLevel      string `yaml:"logLevel" json:"logLevel"`
	DebugProfiler bool   `yaml:"debugProfiler" json:"debugProfiler"`
	Version       string `yaml:"version" json:"version"`
	HTTP          struct {
		Port     int `yaml:"port" toml:"port" json:"port"`
		Timeouts struct {
			ReadTimeout       time.Duration `yaml:"readTimeout" json:"readTimeout"`
			ReadHeaderTimeout time.Duration `yaml:"readHeaderTimeout" json:"readHeaderTimeout"`
			WriteTimeout      time.Duration `yaml:"writeTimeout" json:"writeTimeout"`
			IdleTimeout       time.Duration `yaml:"idleTimeout" json:"idleTimeout"`
		} `yaml:"timeouts" toml:"timeouts" json:"timeouts"`
	} `yaml:"http" toml:"http" json:"http"`

	BinConfig BinConfigT `yaml:"binConfig" json:"binConfig"`
}

func LoadWithEnv[BinConfigT any](ctx context.Context, configPath string) (*Config[BinConfigT], error) {
	// configuration
	currEnv := "local"
	if e := os.Getenv("APP_ENV"); e != "" {
		currEnv = e
	}

	var cfg Config[BinConfigT]
	cfg.Env = currEnv

	if err := cleanenv.ReadConfig(configPath+"/base.yaml", &cfg); err != nil {
		return nil, fmt.Errorf("read base config failed: %w", &MissingBaseConfigError{Err: err})
	}

	if err := cleanenv.ReadConfig(fmt.Sprintf("%s/%s.yaml", configPath, currEnv), &cfg); err != nil {
		return nil, fmt.Errorf("read %s config failed: %w", currEnv, &MissingEnvConfigError{Env: currEnv, Err: err})
	}

	return &cfg, nil
}
