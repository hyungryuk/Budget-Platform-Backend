package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

func setupRouter(rdb *redis.Client) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/messages", handleMessage(rdb))
	return r
}

func newTestRedis(t *testing.T) (*miniredis.Miniredis, *redis.Client) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	return mr, rdb
}

func TestHandleMessage_Success(t *testing.T) {
	mr, rdb := newTestRedis(t)

	r := setupRouter(rdb)
	body, _ := json.Marshal(map[string]string{"text": "hello world"})
	req := httptest.NewRequest(http.MethodPost, "/messages", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", w.Code)
	}

	items := mr.Lrange(queueKey, 0, -1)
	if len(items) != 1 || items[0] != "hello world" {
		t.Fatalf("expected queue to contain 'hello world', got %v", items)
	}
}

func TestHandleMessage_MissingText(t *testing.T) {
	_, rdb := newTestRedis(t)

	r := setupRouter(rdb)
	body, _ := json.Marshal(map[string]string{})
	req := httptest.NewRequest(http.MethodPost, "/messages", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestHandleMessage_InvalidJSON(t *testing.T) {
	_, rdb := newTestRedis(t)

	r := setupRouter(rdb)
	req := httptest.NewRequest(http.MethodPost, "/messages", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}
