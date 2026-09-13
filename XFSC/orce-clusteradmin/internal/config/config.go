package config

import (
	"encoding/base64"
	"os"

	"sigs.k8s.io/yaml"
)

const (
	EnvConfigBase64 = "ORCE_CONFIG_BASE64"
	EnvConfigPath   = "ORCE_CONFIG_PATH"
	DefaultPath     = "config.yaml"
)

type Config struct {
	Server ServerConfig `json:"server" yaml:"server"`
	Helm   HelmConfig   `json:"helm" yaml:"helm"`
}

type ServerConfig struct {
	Address string `json:"address" yaml:"address"`
}

type HelmConfig struct {
	Repositories []Repository `json:"repositories" yaml:"repositories"`
}

type Repository struct {
	Name     string `json:"name" yaml:"name"`
	URL      string `json:"url" yaml:"url"`
	Username string `json:"username,omitempty" yaml:"username,omitempty"`
	Password string `json:"password,omitempty" yaml:"password,omitempty"`
}

func LoadConfig(configPath *string) (*Config, error) {

	if raw := os.Getenv(EnvConfigBase64); raw != "" {
		decoded, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			return nil, err
		}
		return parse(decoded)
	}
	path := os.Getenv(EnvConfigPath)
	if path == "" {
		if EnvConfigPath == "" {
			if configPath != nil {
				path = *configPath
			} else {
				path = DefaultPath
			}
		} else {
			path = EnvConfigPath
		}
	}
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parse(content)

}

func parse(content []byte) (*Config, error) {

	cfg := &Config{}
	if err := yaml.Unmarshal(content, cfg); err != nil {
		return nil, err
	}
	return cfg, nil

}
