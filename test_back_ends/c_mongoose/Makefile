CC = gcc
CFLAGS = -O2 -Wall -Wextra -DMG_ENABLE_LINES=1
LDFLAGS = -lpq -lpthread

all: server

server: main.c mongoose.c mongoose.h
	$(CC) $(CFLAGS) -o server main.c mongoose.c $(LDFLAGS)

clean:
	rm -f server
