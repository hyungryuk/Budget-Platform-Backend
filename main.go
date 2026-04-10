package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const queueKey = "messages"

func main() {
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "localhost"
	}
	redisPort := os.Getenv("REDIS_PORT")
	if redisPort == "" {
		redisPort = "6379"
	}

	rdb := redis.NewClient(&redis.Options{
		Addr:     redisHost + ":" + redisPort,
		Username: os.Getenv("REDIS_USER"),
		Password: os.Getenv("REDIS_PASSWORD"),
	})

	r := gin.Default()
	r.GET("/health", func(c *gin.Context) {
		if err := rdb.Ping(context.Background()).Err(); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "redis unavailable"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	r.POST("/messages", handleMessage(rdb))

	log.Fatal(r.Run(":8080"))
}

type MessageRequest struct {
	Text      string `json:"text"       binding:"required"`
	CreatedBy string `json:"created_by" binding:"required"`
}

type Message struct {
	ID        string    `json:"id"`
	Text      string    `json:"text"`
	CreatedBy string    `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
}

func handleMessage(rdb *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req MessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		msg := Message{
			ID:        uuid.New().String(),
			Text:      req.Text,
			CreatedBy: req.CreatedBy,
			CreatedAt: time.Now().UTC(),
		}

		payload, err := json.Marshal(msg)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to encode message"})
			return
		}

		if err := rdb.LPush(context.Background(), queueKey, payload).Err(); err != nil {
			log.Printf("redis error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to enqueue message"})
			return
		}

		c.JSON(http.StatusAccepted, gin.H{"status": "queued", "id": msg.ID})
	}
}
