package memory

import (
	"context"
	"fmt"

	"cryptocurrencyaggregate/internal/app/models"
	"cryptocurrencyaggregate/internal/app/repository"
)

func (r *Repository) ListBooks(ctx context.Context, arg *repository.ListBooksParam) ([]*models.Book, error) {
	r.muLock.RLock()
	defer r.muLock.RUnlock()

	currencyPair := fmt.Sprintf("%s-%s", arg.BaseCurrency, arg.QuoteCurrency)

	list, ok := r.Books[currencyPair]
	if !ok || len(list) == 0 {
		return nil, ErrRecordNotFound
	}

	return list, nil
}

func (r *Repository) ListCandles(ctx context.Context, arg *repository.ListCandlesParam) ([]*models.Candle, error) {
	r.muLock.RLock()
	defer r.muLock.RUnlock()

	currencyPair := fmt.Sprintf("%s-%s", arg.BaseCurrency, arg.QuoteCurrency)

	list, ok := r.Candles[currencyPair]
	if !ok || len(list) == 0 {
		return nil, ErrRecordNotFound
	}

	return list, nil
}
