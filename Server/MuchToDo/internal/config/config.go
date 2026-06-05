package config

import (
	"os"
	"strconv"
	"strings"
)

// Config stores all configuration of the application.
type Config struct {
	ServerPort         string
	MongoURI           string
	DBName             string
	JWTSecretKey       string
	JWTExpirationHours int
	EnableCache        bool
	RedisAddr          string
	RedisPassword      string
	LogLevel           string
	LogFormat          string
	CookieDomains      []string
	SecureCookie       bool
	AllowedOrigins     []string
	RedisTLS           bool
}

// helper functions
func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func getEnvBool(key string, fallback bool) bool {
	value := os.Getenv(key)

	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}

	return parsed
}

func getEnvInt(key string, fallback int) int {
	value := os.Getenv(key)

	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}

func getEnvSlice(key string, fallback []string) []string {
	value := os.Getenv(key)

	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")

	var cleaned []string

	for _, p := range parts {
		trimmed := strings.TrimSpace(p)
		trimmed = strings.Trim(trimmed, "\"'")
		if trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}

	return cleaned
}

// LoadConfig reads configuration from environment variables.
func LoadConfig(path string) (Config, error) {

	config := Config{
		ServerPort: getEnv("PORT", "8080"),

		MongoURI: getEnv(
			"MONGO_URI",
			"mongodb://muchtodousr:Password!234@mongodb:27017/?authSource=admin",
		),

		DBName: getEnv("DB_NAME", "much_todo_db"),

		JWTSecretKey: getEnv(
			"JWT_SECRET_KEY",
			"supersecret",
		),

		JWTExpirationHours: getEnvInt(
			"JWT_EXPIRATION_HOURS",
			72,
		),

		EnableCache: getEnvBool(
			"ENABLE_CACHE",
			false,
		),

		RedisAddr: getEnv(
			"REDIS_ADDR",
			"redis:6379",
		),

		RedisPassword: getEnv(
			"REDIS_PASSWORD",
			"",
		),

		LogLevel: getEnv(
			"LOG_LEVEL",
			"INFO",
		),

		LogFormat: getEnv(
			"LOG_FORMAT",
			"json",
		),

		CookieDomains: getEnvSlice(
			"COOKIE_DOMAINS",
			[]string{"localhost"},
		),

		SecureCookie: getEnvBool(
			"SECURE_COOKIE",
			false,
		),

		AllowedOrigins: getEnvSlice(
			"ALLOWED_ORIGINS",
			[]string{"http://localhost:5173"},
		),

		RedisTLS: getEnvBool(
			"REDIS_TLS",
			false,
		),
	}

	return config, nil
}
