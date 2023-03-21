package repository

import (
	"context"
	"time"

	"cryptocurrencyaggregate/internal/app/models"
)

type Repository interface {
	ListBooks(ctx context.Context, arg *ListBooksParam) ([]*models.Book, error)
	ListCandles(ctx context.Context, arg *ListCandlesParam) ([]*models.Candle, error)
}

type ListBooksParam struct {
	BaseCurrency  string // BTC
	QuoteCurrency string // USDT
}

type ListCandlesParam struct {
	BaseCurrency  string // BTC
	QuoteCurrency string // USDT
	StartTime     time.Time
	EndTime       time.Time
}
