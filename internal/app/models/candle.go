package models

import "time"

type Candle struct {
	Low    string
	High   string
	Open   string
	Close  string
	Volume string
	Time   time.Time
}
