package memory

import (
	"sync"

	"cryptocurrencyaggregate/internal/app/models"
)

type Repository struct {
	Books   map[string][]*models.Book
	Candles map[string][]*models.Candle

	muLock sync.RWMutex
}

func NewRepository() *Repository {
	return &Repository{
		Books:   make(map[string][]*models.Book),
		Candles: make(map[string][]*models.Candle),
	}
}
