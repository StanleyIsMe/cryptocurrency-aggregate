package memory

type memoryError string

func (me memoryError) Error() string {
	return string(me)
}

const (
	ErrRecordNotFound = memoryError("record not found")
)
